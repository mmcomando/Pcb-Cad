module engine.window_gtk;

import std.c.string : memset;
import std.exception;
import std.stdio;

import derelict.opengl3.gl3;

import engine.window;

import gdk.DragContext;
import gdk.GLContext;
import gdk.Keymap;
import gtk.TargetEntry;
import gtk.TargetList;

import gl3n.linalg;
import glib.Timeout;
import gobject.Type;

import gtk.Box;
import gtk.Builder;
import gtk.CellRendererText;
import gtk.GLArea;
import gtk.ListStore;
import gtk.Main;
import gtk.MainWindow;
import gtk.SelectionData;
import gtk.TreeIter;
import gtk.TreeNode;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gui_data;
import glib.ListG;
import gtk.TreeSelection;

//

static import gtk.Window;

class MyArea : GLArea {
    void delegate() onUpdate;
    void delegate() updateWindow;

    bool render(GLContext, GLArea) {
        makeCurrent();
        DerelictGL3.reload();
        onUpdate();
        updateWindow();
        //queueRender();
        return true;
    }

}

final class WindowGtk : Window {
    float ratio() {
        vec2i s = size();
        return cast(float) s.x / s.y;
    }

    vec2i size() {
        return windowSize;
    }

    vec2i mousePos() {
        return _mousePos;
    }

    vec2i mouseWheel() {
        return _mouseWheel;
    }

    void mousePos(vec2i p) {

    }

    bool mouseButtonDown(MouseButton b) {
        if (mouseDownKeys[b]) {
            return true;
        }
        return false;
    }

    bool mouseButtonPressed(MouseButton b) {

        if (mousePressedKeys[b]) {
            return true;
        }
        return false;
    }

    bool mouseButtonReleased(MouseButton b) {
        if (mouseReleasedKeys[b]) {
            return true;
        }
        return false;
    }

    bool keyPressed(short k) {
        if (k < 256) {
            return pressedKeys[k];
        } else {
            return false;
        }
    }

    bool keyReleased(short k) {
        if (k < 256) {
            return releasedKeys[k];
        } else {
            return false;
        }
    }

    bool keyDown(short k) {
        if (k < 256) {
            return downKeys[k];
        } else {
            return false;
        }
    }

    bool keyPressed(Key k) {
        if (k < 256) {
            return pressedKeysSpecial[k];
        } else {
            return false;
        }
    }

    bool keyReleased(Key k) {
        if (k < 256) {
            return releasedKeysSpecial[k];
        } else {
            return false;
        }
    }

    bool keyDown(Key k) {
        if (k < 256) {
            return downKeysSpecial[k];
        } else {
            return false;
        }
    }

    void setResizeDelegate(void delegate(int, int) del) {
        onResize = del;
    }

    void setUpdateDelegate(void delegate() del) {
        glarea.onUpdate = del;
    }

    class HTreeNode : TreeNode {

        string gtkDL;

        this(string gtkDL) //, TestTreeView ttv)
        {
            this.gtkDL = gtkDL;

        }

        int columnCount() {
            return 1;
        }

        string getNodeValue(int column) {
            string value;
            switch (column) {
                //case 0: value = pixbuf; break;
            case 0:
                value = gtkDL;
                break;
            default:
                value = "N/A";
                break;
            }
            return value;
        }
    }

    void setTitle(string) {
        assert(0);
    }

    this() {
        string[] str;
        Main.init(str); //GTKD
        Builder g = new Builder();
        if (!g.addFromFile("ui.glade"))
            throw new Exception("Oops, could not create Glade object, check your glade file.");

        gtkWindow = cast(gtk.Window.Window) g.getObject("window1");
        if (gtkWindow is null)
            throw new Exception("There is no window1 object in your flade file.");

        gtkWindow.setTitle("This is a glade window");
        gtkWindow.addOnHide(delegate void(Widget aux) { Main.quit(); });
        setGLArea(g);

        footprintsView = cast(TreeView) g.getObject("footprints_view");
        auto sel = footprintsView.getSelection();
        sel.addOnChanged(&on_change);

        store = new TreeStore([GType.STRING]);
        footprintsView.setModel(store);
        refreshFootprintsView();

        gtkWindow.showAll();
    }

    void start() {
        m_timeout = new Timeout(10, &onElapsed, false);
        Main.run();
    }

    bool on_drag_fail(DragContext, GtkDragResult res, Widget) {
        writeln(res);
        return true;
    }

private:
    MyArea glarea;
    TreeView footprintsView;
    gtk.Window.Window gtkWindow;
    TreeStore store;
    Timeout m_timeout;

    bool[256] downKeys;
    bool[256] pressedKeys;
    bool[256] releasedKeys;
    bool[Key.max + 1] downKeysSpecial;
    bool[Key.max + 1] pressedKeysSpecial;
    bool[Key.max + 1] releasedKeysSpecial;

    bool[MouseButton.max + 1] mouseDownKeys;
    bool[MouseButton.max + 1] mousePressedKeys;
    bool[MouseButton.max + 1] mouseReleasedKeys;

    void delegate(int, int) onResize;
    vec2i windowSize = vec2i(100, 100);
    vec2i _mousePos = vec2i(100, 100);
    vec2i _mouseWheel;

    void setGLArea(Builder g) {
        Box box = cast(Box) g.getObject("main_box");
        glarea = new MyArea();
        glarea.updateWindow = &update;
        glarea.addOnRender(&glarea.render);

        gtkWindow.addOnKeyPress(&keyPressedImpl);
        gtkWindow.addOnKeyRelease(&keyReleasedImpl);
        glarea.addOnMotionNotify(&motion_notify_event);
        glarea.addOnButtonPress(&button_press_event);
        glarea.addOnButtonRelease(&button_release_event);
        glarea.addOnResize(&resize);
        glarea.setHexpand(true);
        glarea.setVexpand(true);
        box.add(glarea);
    }

    void refreshFootprintsView() {
        store.clear();
        TreeIter[string] iters;
        foreach (p; guiData.footprints.byKeyValue) {
            TreeIter it;
            TreeIter* is_it = p.key in iters;
            if (is_it is null) {
                it = store.createIter();
                auto parent = new HTreeNode(p.key);
                store.set(it, parent);
                iters[p.key] = it;
            } else {
                it = *is_it;
            }
            foreach (value; p.value) {

                auto child = new HTreeNode(value);
                auto myIt = store.append(it);
                store.set(myIt, child);
            }
        }
    }

    void on_change(TreeSelection sel) {
        auto it = sel.getSelected();
        auto model = footprintsView.getModel();
        if (it !is null) {

            auto v = model.getValue(it, 0);
            string s = v.getString();
            guiData.selectedFootprint = s.dup;
        }
    }

    bool keyPressedImpl(GdkEventKey* e, Widget) {
        char ch = cast(char) Keymap.keyvalToUnicode(e.keyval);
        downKeys[ch] = true;
        pressedKeys[ch] = true;
        return true;

    }

    bool keyReleasedImpl(GdkEventKey* e, Widget) {
        ubyte ch = cast(ubyte) Keymap.keyvalToUnicode(e.keyval);
        downKeys[ch] = false;
        releasedKeys[ch] = true;
        return true;

    }

    bool button_press_event(GdkEventButton* event, Widget widget) {
        MouseButton b;
        switch (event.button) {
        case 1:
            b = MouseButton.left;
            break;
        case 2:
            b = MouseButton.middle;
            break;
        case 3:
            b = MouseButton.right;
            break;
        default:
            return true;
        }
        mouseDownKeys[b] = true;
        mousePressedKeys[b] = true;
        return true;
    }

    bool button_release_event(GdkEventButton* event, Widget widget) {
        MouseButton b;
        switch (event.button) {
        case 1:
            b = MouseButton.left;
            break;
        case 2:
            b = MouseButton.middle;
            break;
        case 3:
            b = MouseButton.right;
            break;
        default:
            return true;
        }
        mouseDownKeys[b] = false;
        mouseReleasedKeys[b] = true;
        return true;
    }

    bool motion_notify_event(GdkEventMotion* event, Widget widget) {
        int x, y;
        x = cast(int) event.x;
        y = cast(int) event.y;
        _mousePos = vec2i(x, y);
        return true;
    }

    void update() {
        _mouseWheel = vec2i(0, 0);
        memset(&pressedKeys, 0, 256);
        memset(&releasedKeys, 0, 256);
        memset(&mousePressedKeys, 0, MouseButton.max + 1);
        memset(&mouseReleasedKeys, 0, MouseButton.max + 1);
        memset(&pressedKeysSpecial, 0, Key.max + 1);
        memset(&releasedKeysSpecial, 0, Key.max + 1);
        if (guiData.footprintsChanged == true) {
            refreshFootprintsView();
            guiData.footprintsChanged = false;
        }
    }

    bool onElapsed() {
        glarea.queueRender();
        //onUpdate();		
        return true;
    }

    void resize(int x, int y, GLArea) {
        windowSize = vec2i(x, y);
        onResize(x, y);
    }

}
