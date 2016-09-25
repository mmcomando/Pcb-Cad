module engine.window_dlangui;

import core.stdc.string : memset;
import std.exception;
import std.stdio;

import derelict.opengl3.gl3;

import engine.window:WindowEngine=Window,Key,MouseButton;
import gl3n.linalg;
import dlangui;
import engine.universal_widget_dlangui;

final class WindowDlanGUI : WindowEngine {
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
		onUpdate = del;
		openglWidget.onUpdate = &update;
	}
	void setTitle(string) {
		import run;
		auto customWidget=universalMakeWidget!(customGetEditWidgetForType)(project.grid);
		//auto customWidget=universalMakeWidget!(customGetEditWidgetForType)(example);
		//layout.addChild(new ResizerWidget());
		//layout.addChild(customWidget);
		layout.addChild(customWidget).layoutWidth(400);
		
	}

	HorizontalLayout layout;
	Window window;
	this() {

		Platform.instance.GLVersionMinor=3;
		window = Platform.instance.createWindow("DlangUI OpenGL Example", null, WindowFlag.Resizable, 800, 700);

		openglWidget=new MyOpenglWidget();
		openglWidget.layoutWidth(FILL_PARENT);
		openglWidget.layoutHeight(FILL_PARENT);
		openglWidget.mouseEvent=&mouseHandler;

		layout=new HorizontalLayout();
		layout.keyEvent=&keyHandler;
		layout.layoutWidth=FILL_PARENT;
		layout.layoutHeight=FILL_PARENT;
		layout.addChild(openglWidget);
		window.mainWidget = layout;				
		window.show();

	}

	void start() {
		// run message loop
		Platform.instance.enterMessageLoop();
	}

private:
	MyOpenglWidget openglWidget;

	

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
	void delegate() onUpdate;
	vec2i windowSize = vec2i(300, 700);
	vec2i _mousePos = vec2i(100, 100);
	vec2i _mouseWheel;

	static void dlanguiOnResize( int width, 
		int height ){

	}

	
	bool  keyHandler(Widget source,KeyEvent event) {
		if(event.action==KeyAction.KeyDown){
			switch (event.keyCode) {
				case KeyCode.LSHIFT:
					downKeysSpecial[Key.shift] = true;
					pressedKeysSpecial[Key.shift] = true;
					break;
				case KeyCode.LALT:
					downKeysSpecial[Key.alt] = true;
					pressedKeysSpecial[Key.alt] = true;
					break;
				case KeyCode.LCONTROL:
					downKeysSpecial[Key.ctrl] = true;
					pressedKeysSpecial[Key.ctrl] = true;
					break;
				default:break;
			}
		}else if(event.action==KeyAction.KeyUp){
			switch (event.keyCode) {
				case KeyCode.LSHIFT:
					downKeysSpecial[Key.shift] = false;
					releasedKeysSpecial[Key.shift] = true;
					break;
				case KeyCode.LALT:
					downKeysSpecial[Key.alt] = false;
					releasedKeysSpecial[Key.alt] = true;
					break;
				case KeyCode.LCONTROL:
					downKeysSpecial[Key.ctrl] = false;
					releasedKeysSpecial[Key.ctrl] = true;
					break;
				default:break;
			}
		}	
		if(event.keyCode>=KeyCode.KEY_A && event.keyCode<=KeyCode.KEY_Z){
			ubyte add=32;
			if(event.action==KeyAction.KeyDown){
				downKeys[event.keyCode+add] = true;
				pressedKeys[event.keyCode+add] = true;
			}else if(event.action==KeyAction.KeyUp){
				downKeys[event.keyCode+add] = false;
				releasedKeys[event.keyCode+add] = true;					
			}

			
		}
		return true;

	}

	bool mouseHandler(Widget source,MouseEvent event) {
		MouseButton b;
		if(event.action==MouseAction.ButtonDown){
			switch (event.button) {
				case dlangui.MouseButton.Left:
					b = MouseButton.left;
					break;
				case dlangui.MouseButton.Middle:
					b = MouseButton.middle;
					break;
				case dlangui.MouseButton.Right:
					b = MouseButton.right;
					break;
				default:
					return true;
			}
			mouseDownKeys[b] = true;
			mousePressedKeys[b] = true;
		}else if(event.action==MouseAction.ButtonUp){
			switch (event.button) {
				case dlangui.MouseButton.Left:
					b = MouseButton.left;
					break;
				case dlangui.MouseButton.Middle:
					b = MouseButton.middle;
					break;
				case dlangui.MouseButton.Right:
					b = MouseButton.right;
					break;
				default:
					return true;
			}
			mouseDownKeys[b] = false;
			mouseReleasedKeys[b] = true;
		}
		_mouseWheel.y=event.wheelDelta;
		_mousePos = vec2i(event.pos.x, event.pos.y);

		return true;
	}
	void update() {
		onUpdate();
		_mouseWheel = vec2i(0, 0);
		memset(&pressedKeys, 0, 256);
		memset(&releasedKeys, 0, 256);
		memset(&mousePressedKeys, 0, MouseButton.max + 1);
		memset(&mouseReleasedKeys, 0, MouseButton.max + 1);
		memset(&pressedKeysSpecial, 0, Key.max + 1);
		memset(&releasedKeysSpecial, 0, Key.max + 1);
		vec2i wSize=size;
		if(size.x!=openglWidget.width || size.y!=openglWidget.height){
			resize(openglWidget.width,openglWidget.height);
		}
	}

	
	void resize(int x, int y) {
		windowSize = vec2i(x, y);
		onResize(x, y);
	}

	

}


import dlangui.graphics.glsupport;
import dlangui.graphics.gldrawbuf;

class MyOpenglWidget : VerticalLayout {
	this() {
		super("OpenGLView");
		layoutWidth = FILL_PARENT;
		layoutHeight = FILL_PARENT;
		margins=0;
		padding=0;
		backgroundDrawable = DrawableRef(new OpenGLDrawable(&doDraw));
		addChild(new TextWidget(null,""d));
	}
	void delegate() onUpdate;
	/// returns true is widget is being animated - need to call animate() and redraw
	@property override bool animating() { return true; }
	/// animates window; interval is time left from previous draw, in hnsecs (1/10000000 of second)
	override void animate(long interval) {
		invalidate();
	}
	
	/// this is OpenGLDrawableDelegate implementation
	private void doDraw(Rect windowRect, Rect rc) {
		if(onUpdate !is null){
			onUpdate();
		}
	}
}

