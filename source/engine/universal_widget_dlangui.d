module engine.universal_widget_dlangui;


import dlangui;
import gl3n.linalg;
import std.range:isForwardRange;
import std.conv:to;
import std.stdio:writeln;
import std.algorithm:remove,startsWith;
import meta;



private immutable string[] mapColor=["#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111","#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111","#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111","#EEEEEE","#DDDDDD","#CCCCCC","#BBBBBB","#AAAAAA","#999999","#888888","#777777","#666666","#555555","#444444","#333333","#222222","#111111"];

private class updateValueHandler(T):OnKeyHandler{
	T* pointerToValue;
	UpdateDelegate onUpdate;
	this(T* pointer,UpdateDelegate onUpdate){
		pointerToValue=pointer;
		this.onUpdate=onUpdate;
	}
	bool onKey(Widget src,KeyEvent key) {
		if(key.action!=KeyAction.KeyUp || key.keyCode!=13){//13==Enter
			return false;
		}
		writeln(key.action);
		writeln(key.keyCode);
		EditLine www=cast(EditLine)src;
		try{
			*pointerToValue=www.content.text.to!T;
			//writeln(&onUpdate);
			if(onUpdate !is null){
				onUpdate();
			}
		}catch(Exception e){
			www.content.text=(*pointerToValue).to!dstring;
		}
		return  false;
	}
}
private class removeFromSliceHandler(Array,alias customWidget):OnClickHandler{
	Widget table;
	Array* arr;
	uint elementToRemove;
	string path;
	WidgetGenerator!customWidget gen;
	this(Widget table,Array* arr,uint element,string path,WidgetGenerator!customWidget gen){
		this.table=table;
		this.arr=arr;
		elementToRemove=element;
		this.path=path;
		this.gen=gen;
	}
	bool onClick(Widget w) {
		*arr=remove(*arr,elementToRemove);
		table.removeAllChildren;
		gen.universaladdToTableArray(table,*arr,path);
		return true;
	}
}


private alias void delegate() UpdateDelegate;
struct RefreshEvent{
	string refreshPath;
	UpdateDelegate del;
}

class WidgetGenerator(alias customWidgetCreator){
	RefreshEvent[] events;
	
	uint level=0;
	private alias void delegate() DgType;
	DgType[string] arrayOfDelegates;
	UpdateDelegate getDelegatForPath(string path){
		size_t pathLength=0;
		UpdateDelegate del;
		foreach(ev;events){
			size_t len=ev.refreshPath.length ;
			if(pathLength<len&& path.startsWith(ev.refreshPath)){
				pathLength=len;
				del=ev.del;
			}
		}
		return del;
	}
	
	
	Widget universalMakeWidget(T)(ref T obj,string name=T.stringof,string path=""){
		level++;
		scope(exit)level--;
		HorizontalLayout hLayout=new HorizontalLayout();
		VerticalLayout vLayout=new VerticalLayout();
		hLayout.addChild(new TextWidget(null, name.to!dstring));
		hLayout.addChild(vLayout);
		hLayout.backgroundColor=mapColor[level];
		vLayout.backgroundColor=mapColor[level];
		vLayout.addChild(getEditWidgetForType(obj,path));
		
		return hLayout;
	}
	
	private void universaladdToTableArray(T)(Widget table,ref T obj,string path){
		enum bool canEdit=isDynamicArray!T && !is(ForeachType!(T)==class);//only buildin arrays
		TableLayout tableArray = new TableLayout(null);
		tableArray.colCount = 1+canEdit;
		tableArray.layoutWidth=FILL_PARENT;
		tableArray.layoutHeight=FILL_PARENT;
		tableArray.backgroundColor=mapColor[level];
		foreach(uint j,ref val;obj){
			tableArray.addChild(getEditWidgetForType(val,path));
			static if(canEdit){
				Button removeButton=new Button(null, "-"d);
				removeButton.alignment(Align.Left | Align.VCenter);
				auto removeAction=new removeFromSliceHandler!(T,customWidgetCreator)(table,&obj,j,path,this);
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
				universaladdToTableArray(table,obj,path);
				return true;
			};
			table.addChild(addButton);
		}
	}
	
	
	
	Widget getEditWidgetForType(T)(ref T obj,string path){
		Widget custom=customWidgetCreator(this,obj,path);
		if(custom !is null){
			return custom;
		}
		static if (typeInTypes!(T,float,int,uint,string)) {
			EditLine widget=new EditLine(null, obj.to!dstring);
			auto del=getDelegatForPath(path);
			auto eventAction=new updateValueHandler!(T)(&obj,del);
			widget.keyEvent=eventAction;
			return widget;
		}else static if(isArray!(T)){
			VerticalLayout vLayout=new VerticalLayout();
			vLayout.backgroundColor=mapColor[level];
			universaladdToTableArray(vLayout,obj,path);
			
			return vLayout;
		}else static if(is(T==struct) ){
			VerticalLayout vLayout=new VerticalLayout();
			vLayout.backgroundColor=mapColor[level];
			foreach(i, ref value; obj.tupleof) {
				alias typeof(value) Type;
				enum string varName =__traits(identifier, obj.tupleof[i]);
				vLayout.addChild(universalMakeWidget(value,varName,path~"."~varName));
			}
			return vLayout;
			
		}else static if(is(T==class)){
			VerticalLayout vLayout=new VerticalLayout();
			vLayout.backgroundColor=mapColor[level];
			if(obj !is null){
				foreach(i, ref value; obj.tupleof) {
					alias typeof(value) Type;
					enum string varName =__traits(identifier, obj.tupleof[i]);
					vLayout.addChild(universalMakeWidget(value,varName,path~"."~varName));
				}
			}else{
				return new TextWidget(null, "null"d);
			}
			return vLayout;
			
		}else{
			return new TextWidget(null, "Can't edit unimplemented"d);
		}
	}
	
	
	private void addItems(W,T)(W items,Widget place,ref T obj,string name=T.stringof,string path=""){
		static if(isArray!(T)){
			name~="[]";
		}
		TreeItem root=items.newChild("id", name.to!dstring);
		
		static if(isArray!(T)){
			foreach(i,ref value;obj){
				addItems(root,place,value,i.to!string,path);
			}
			if(obj.length==0){
				string id="id_"~arrayOfDelegates.length.to!string;
				root.id=id;
				arrayOfDelegates[id]= delegate() {
					place.removeAllChildren();
					auto customWidget=getEditWidgetForType(obj,path);
					//auto customWidget=universalMakeWidget(tttt,true);
					place.addChild(customWidget);
				};
			}
		}else static if(is(T==struct) || is(T==class) ){
			foreach(i, ref value; obj.tupleof) {
				alias typeof(value) Type;
				enum varName =__traits(identifier, obj.tupleof[i]);
				static if(maxNestageLevel!(Type)()>4){
					addItems(root,place,value,varName,path~"."~varName);
				}else{
					string id="id_"~arrayOfDelegates.length.to!string;
					TreeItem item=root.newChild(id, varName.to!dstring);
					arrayOfDelegates[id]= delegate() {
						place.removeAllChildren();
						auto customWidget=getEditWidgetForType(value,path~"."~varName);
						//auto customWidget=universalMakeWidget(tttt,true);
						place.addChild(customWidget);
					};
				}
			}
		}else{
			assert(0);
		}
		
	}
	
	Widget universalMakeWidgetView(T)(ref T obj){
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
		
		ScrollWidget scroll = new ScrollWidget("SCROLL1");
		scroll.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
		scroll.contentWidget(treeControlledPanel);
		treeLayout.addChild(scroll);
		addItems(tree.items,treeControlledPanel,obj);
		
		tree.selectionChange = delegate(TreeItems source, TreeItem selectedItem, bool activated) {
			if(auto item=selectedItem.id in arrayOfDelegates){
				(*item)();
			}else{
				
			}
		};
		
		tree.items.selectItem(tree.items.child(0));
		return treeLayout;
		
	}
	
}

Widget customGetEditWidgetForType(Gen,T)(Gen gen,ref T obj,string path){
	
	static if(is(T==Vector!(float, 2))){
		LinearLayout layout = new HorizontalLayout();
		layout.addChild(gen.getEditWidgetForType(obj.x,path));
		layout.addChild(gen.getEditWidgetForType(obj.y,path));
		return layout;
	}else static if(is(T==Vector!(float, 3))){
		LinearLayout layout = new HorizontalLayout();
		layout.addChild(gen.getEditWidgetForType(obj.x,path));
		layout.addChild(gen.getEditWidgetForType(obj.y,path));
		layout.addChild(gen.getEditWidgetForType(obj.z,path));
		return layout;
	}else{
		return null;
	}
	
	
}



Widget universalMakeWidgetView(alias customWidgetGenerator,T)(ref T obj,RefreshEvent[] events=null){
	alias Generator=WidgetGenerator!customWidgetGenerator;
	Generator gen=new Generator();
	gen.events=events;
	return gen.universalMakeWidgetView(obj);
}
Widget universalMakeWidget(alias customWidgetGenerator,T)(ref T obj,RefreshEvent[] events=null){
	alias Generator=WidgetGenerator!customWidgetGenerator;
	Generator gen=new Generator();
	gen.events=events;
	return gen.getEditWidgetForType(obj,"");
	
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
