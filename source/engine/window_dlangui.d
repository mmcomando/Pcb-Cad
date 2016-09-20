module engine.window_dlangui;

import std.c.string : memset;
import std.exception;
import std.stdio;

import derelict.opengl3.gl3;


import engine.window:WindowEngine=Window,Key,MouseButton;
import gl3n.linalg;


import dlangui;
import std.traits;
import std.range:isForwardRange;
import std.conv:to;
import std.stdio:writeln;
import std.algorithm:remove;
import meta;



immutable string[] mapColor=["#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111","#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111","#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111","#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111"];

private class updateValueHandler(T):OnKeyHandler{
	T* pointerToValue;
	this(T* pointer){
		pointerToValue=pointer;
	}
	bool onKey(Widget src,KeyEvent key) {
		EditLine www=cast(EditLine)src;
		try{
			*pointerToValue=www.content.text.to!T;
		}catch(Exception e){
			www.content.text=(*pointerToValue).to!dstring;
		}
		return  false;
	}
}
private class removeFromSliceHandler(Array):OnClickHandler{
	Widget table;
	Array* arr;
	uint elementToRemove;
	this(Widget table,Array* arr,uint element){
		this.table=table;
		this.arr=arr;
		elementToRemove=element;
	}
	bool onClick(Widget w) {
		*arr=remove(*arr,elementToRemove);
		table.removeAllChildren;
		universaladdToTableArray(table,*arr);
		return true;
	}
}



private void universaladdToTableArray(T)(Widget table,ref T obj){
	enum bool canEdit=isDynamicArray!T && !is(ForeachType!(T)==class);//only buildin arrays
	TableLayout tableArray = new TableLayout(null);
	tableArray.colCount = 1+canEdit;
	tableArray.layoutWidth=FILL_PARENT;
	tableArray.layoutHeight=FILL_PARENT;
	tableArray.backgroundColor=mapColor[level];
	foreach(uint j,ref val;obj){
		tableArray.addChild(getEditWidgetForType(val));
		static if(canEdit){
			Button removeButton=new Button(null, "-"d);
			removeButton.alignment(Align.Left | Align.VCenter);
			auto removeAction=new removeFromSliceHandler!(T)(table,&obj,j);
			removeButton.click=removeAction;
			tableArray.addChild(removeButton);
		}
	}
	if(obj.length==0){
		tableArray.addChild((new TextWidget(null, "Empty array"d)).alignment(Align.Left | Align.VCenter));
	}
	table.addChild(tableArray);
	static if(canEdit){
		table.addChild((new TextWidget(null, ""d)).alignment(Align.Right | Align.VCenter));
		Button addButton=new Button(null, "+"d);
		addButton.alignment(Align.Left | Align.VCenter);
		addButton.click=delegate(Widget w){
			table.removeAllChildren;
			obj~=ForeachType!(T).init;
			universaladdToTableArray(table,obj);
			return true;
		};
		table.addChild(addButton);
	}
}



Widget getEditWidgetForType(T)(ref T obj){
	static if (typeInTypes!(T,float,int,uint,string)) {
		EditLine widget=new EditLine(null, obj.to!dstring);
		auto eventAction=new updateValueHandler!(T)(&obj);
		widget.keyEvent=eventAction;
		return widget;
	}else static if(isArray!(T)){
		VerticalLayout vLayout=new VerticalLayout();
		vLayout.backgroundColor=mapColor[level];
		universaladdToTableArray(vLayout,obj);

		return vLayout;
	}else static if(is(T==struct) ){
		VerticalLayout vLayout=new VerticalLayout();
		vLayout.backgroundColor=mapColor[level];
		foreach(i, ref value; obj.tupleof) {
			alias typeof(value) Type;
			enum string varName =__traits(identifier, obj.tupleof[i]);
			vLayout.addChild(universalMakeWidget(value,varName));
		}
		return vLayout;
		
	}else static if(is(T==class)){
		VerticalLayout vLayout=new VerticalLayout();
		vLayout.backgroundColor=mapColor[level];
		if(obj !is null){
			foreach(i, ref value; obj.tupleof) {
				alias typeof(value) Type;
				enum string varName =__traits(identifier, obj.tupleof[i]);
				vLayout.addChild(universalMakeWidget(value,varName));
			}
		}else{
			return new TextWidget(null, "null"d);
		}
		return vLayout;
		
	}else{
		return new TextWidget(null, "Can't edit unimplemented"d);
	}
}

private static level=0;
Widget universalMakeWidget(T)(ref T obj,string name=T.stringof){
	level++;
	scope(exit)level--;
	HorizontalLayout hLayout=new HorizontalLayout();
	VerticalLayout vLayout=new VerticalLayout();
	hLayout.addChild(new TextWidget(null, name.to!dstring));
	hLayout.addChild(vLayout);
	hLayout.backgroundColor=mapColor[level];
	vLayout.backgroundColor=mapColor[level];
	vLayout.addChild(getEditWidgetForType(obj));

	return hLayout;
}
private void addItems(W,T)(W items,ref DgType[string] arrayOfDelegates,Widget place,ref T obj,string name=T.stringof){
	static if(isArray!(T)){
		name~="[]";
	}
	TreeItem root=items.newChild("id", name.to!dstring);

	static if(isArray!(T)){
		foreach(i,ref value;obj){
			addItems(root,arrayOfDelegates,place,value,i.to!string);
		}
		if(obj.length==0){
			string id="id_"~arrayOfDelegates.length.to!string;
			root.id=id;
			arrayOfDelegates[id]= delegate() {
				place.removeAllChildren();
				auto customWidget=getEditWidgetForType(obj);
				//auto customWidget=universalMakeWidget(tttt,true);
				place.addChild(customWidget);
			};
		}
	}else static if(is(T==struct) || is(T==class) ){
		foreach(i, ref value; obj.tupleof) {
			alias typeof(value) Type;
			enum varName =__traits(identifier, obj.tupleof[i]);
			static if(maxNestageLevel!(Type)()>2){
				addItems(root,arrayOfDelegates,place,value,varName);
			}else{
				string id="id_"~arrayOfDelegates.length.to!string;
				TreeItem item=root.newChild(id, varName.to!dstring);
				arrayOfDelegates[id]= delegate() {
					place.removeAllChildren();
					auto customWidget=getEditWidgetForType(value);
					//auto customWidget=universalMakeWidget(tttt,true);
					place.addChild(customWidget);
				};
			}
		}
	}else{
		assert(0);
	}

}
private alias void delegate() DgType;

Widget universalMakeWidgetView(T)(ref T obj,bool addScroll=false){
	DgType[string] arrayOfDelegates;
	// tree view example
	TreeWidget tree = new TreeWidget("TREE1");
	tree.layoutWidth(FILL_PARENT).layoutHeight(500);	
	LinearLayout treeLayout = new VerticalLayout("TREE");
	LinearLayout treeControlledPanel = new VerticalLayout();
	treeLayout.layoutWidth = FILL_PARENT;
	treeControlledPanel.layoutWidth = FILL_PARENT;
	//treeControlledPanel.layoutHeight = FILL_PARENT;
	treeControlledPanel.addChild(new TextWidget("TREE_ITEM_DESC","Sample text"d));
	treeLayout.addChild(tree);
	treeLayout.addChild(new ResizerWidget());
	treeLayout.addChild(treeControlledPanel);
	addItems(tree.items,arrayOfDelegates,treeControlledPanel,obj);
	
	tree.selectionChange = delegate(TreeItems source, TreeItem selectedItem, bool activated) {
		if(auto item=selectedItem.id in arrayOfDelegates){
			(*item)();
		}else{

		}
	};
	
	tree.items.selectItem(tree.items.child(0));
	return treeLayout;

}


class Tralala{
	float xxxxxxxx;
}
struct InnerType2{
	float rot2;
	int integer2;
	int[3] ints2;
	string str2;
	InnerType tt2;
}
struct InnerType{
	float rot;
	int integer;
	int[3] ints;
	string str;
}
struct vec2{
	float x;
	float y;
}
struct ExampleType{
	float ex_rot;
	float ex_rot2;
	int ex_integer;
	int[] ex_ints;
	string ex_str;
	InnerType2 ex_inner;
	Tralala ex_trala;
}


ExampleType example;

//////////////////////////////////////








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
		openglWidget.onUpdate = del;
	}
	ExampleType tttt;
	void setTitle(string) {
		struct BBB{
			union{
				float fff;
				int xxx;
				string sss;
			}
		}
		import run;
		auto customWidget=universalMakeWidgetView(project.footprints[0]);
		writeln(maxNestageLevel!(typeof(project.footprints[0].f)));
		//auto customWidget=universalMakeWidget(tttt);
		layout.addChild(customWidget).layoutWidth(400);
		//layout.addChild(customWidget);
		BBB bbb;
		foreach(i, ref value; bbb.tupleof) {
			alias typeof(value) Type;
			enum string varName =__traits(identifier, bbb.tupleof[i]);
			writeln(varName);
		}
	}

	HorizontalLayout layout;
	this() {

		Platform.instance.GLVersionMinor=3;
		Window window = Platform.instance.createWindow("DlangUI OpenGL Example", null, WindowFlag.Resizable, 800, 700);

		openglWidget=new MyOpenglWidget();
		openglWidget.layoutWidth(FILL_PARENT);
		openglWidget.layoutHeight(FILL_PARENT);
		
		//auto tree1=getTreeWidget();
		//import run;
		//auto customWidget=universalMakeWidget(example,true);

		//	example.ints~=[1,2,3,4,50];
		//example.trala=new Tralala;
		
		
		layout=new HorizontalLayout();
		layout.layoutWidth=FILL_PARENT;
		layout.layoutHeight=FILL_PARENT;
		layout.addChild(openglWidget);
		//layout.addChild(tree1);
		//layout.addChild(customWidget).layoutWidth(200);
		
		//window.windowIcon = drawableCache.getImage("dlangui-logo1");
		
		
		
		
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
	vec2i windowSize = vec2i(300, 700);
	vec2i _mousePos = vec2i(100, 100);
	vec2i _mouseWheel;

	

	

	
	bool keyPressedImpl() {
		char ch = 1;
		downKeys[ch] = true;
		pressedKeys[ch] = true;
		return true;

	}

	bool keyReleasedImpl() {
		ubyte ch = 1;
		downKeys[ch] = false;
		releasedKeys[ch] = true;
		return true;

	}

	bool button_press_event() {
		MouseButton b;
		int a;
		switch (a) {
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

	bool button_release_event() {
		MouseButton b;
		int a;
		switch (a) {
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

	bool motion_notify_event() {
		int x, y;
		//  x = cast(int) event.x;
		//  y = cast(int) event.y;
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
		
		VerticalLayout layout=new VerticalLayout();
		layout.layoutWidth=FILL_PARENT;
		layout.layoutHeight=FILL_PARENT;
		layout.margins=0;
		layout.padding=0;
		layout.backgroundDrawable = DrawableRef(new OpenGLDrawable(&doDraw));
		layout.addChild(new TextWidget(null,""d));
		addChild(layout);
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





///////////

auto getTreeWidget(){
	TreeWidget tree = new TreeWidget("TREE1");
	//tree.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
	//tree.layoutHeight(FILL_PARENT);
	TreeItem tree1 = tree.items.newChild("group1", "Group 1"d, "document-open");
	tree1.newChild("g1_1", "Group 1 item 1"d);
	tree1.newChild("g1_2", "Group 1 item 2"d);
	tree1.newChild("g1_3", "Group 1 item 3"d);
	TreeItem tree2 = tree.items.newChild("group2", "Group 2"d, "document-save");
	tree2.newChild("g2_1", "Group 2 item 1"d, "edit-copy");
	tree2.newChild("g2_2", "Group 2 item 2"d, "edit-cut");
	tree2.newChild("g2_3", "Group 2 item 3"d, "edit-paste");
	tree2.newChild("g2_4", "Group 2 item 4"d);
	TreeItem tree3 = tree.items.newChild("group3", "Group 3"d);
	tree3.newChild("g3_1", "Group 3 item 1"d);
	tree3.newChild("g3_2", "Group 3 item 2"d);
	TreeItem tree32 = tree3.newChild("g3_3", "Group 3 item 3"d);
	tree3.newChild("g3_4", "Group 3 item 4"d);
	tree32.newChild("group3_2_1", "Group 3 item 2 subitem 1"d);
	tree32.newChild("group3_2_2", "Group 3 item 2 subitem 2"d);
	tree32.newChild("group3_2_3", "Group 3 item 2 subitem 3"d);
	tree32.newChild("group3_2_4", "Group 3 item 2 subitem 4"d);
	tree32.newChild("group3_2_5", "Group 3 item 2 subitem 5"d);
	tree3.newChild("g3_5", "Group 3 item 5"d);
	tree3.newChild("g3_6", "Group 3 item 6"d);
	return tree;
}