module shapes;


import std.conv:to;
import std.format:format;

import gl3n.linalg;

import utils;

void test(){
	AnyShape A,B;
	A.set(Circle());
	B.set(Rectangle());		
	collide(&A,&B);
}
struct Triangle{
	vec2 p1;
	vec2 p2;
	vec2 p3;
	Triangle[] getTriangles(){
		return [];
	}
}
struct Rectangle {
	vec2 wh;
	Triangle[] getTriangles(){
		return [];
	}
}
struct Circle {
	float radius;
	Triangle[] getTriangles(){
		return [];
	}
}


bool isShape(T)(){
	//has collide, aabb
	//no references
	bool ok=__traits ( isPOD , T );
	return ok;
}


/**
 * Template to generate Universal shape
 */
struct AnyShapeTemplate(Types...) {
	alias FromTypes=Types;
	/** 
	 * Generates code for universal shape
	 * types which can be packed to union are packed others are allocated and there is stored their pointer
	 */
	static string getShapeCode(types...)(uint unionSize){
		string codeChecks;
		string codeEnum="enum types:ubyte{\n";
		string code="private union{\n";
		foreach(uint i,type;types){
			string typeName=type.stringof;
			//string valueName=toLower(typeName[0..1])~typeName[1..$];
			string valueName="_"~i.to!string;
			string ampChar="&";
			string pointer="";
			//if(typeName==valueName)valueName="_"~valueName;
			codeEnum~=typeName~"="~i.to!string~",\n";
			if(type.sizeof>unionSize){
				pointer="*";
				ampChar="";
			}
			code~= typeName~pointer;
			
			code~=" "~valueName~";\n";
			
			
		}
		codeEnum~="none\n}\n";
		return codeEnum~code~"}\n"~codeChecks~"types currentType=types.none;\n";
	}
	mixin(getShapeCode!(Types)(8));
	/**
	 * returns given type with check
	 */
	auto get(T)(){
		foreach(i,type;FromTypes){
			static if(is(type==T)){
				assert(currentType==i,"got type which is not currently bound");
				static if(T.sizeof>8){
					mixin("return _"~i.to!string~";");
				}else{
					mixin("return &_"~i.to!string~";");
				}
			}
		}
		assert(false);
	}
	/*
	 * sets given shape
	 */
	auto  set(T)(T obj){
		foreach(i,type;FromTypes){
			static if(is(type==T)){
				currentType=cast(types)i;
				static if(T.sizeof>8){
					T* pointer=cast(T*)GC.malloc(T.sizeof);
					memcpy(&obj,pointer,T.sizeof);
					mixin("_"~i.to!string~"= pointer;");
				}else{
					mixin("_"~i.to!string~"=obj;");
				}
			}
		}
	}
}
alias AnyShape=AnyShapeTemplate!(Rectangle,Circle,Triangle);

//Collision functions

bool collideUniversal(T1,T2)(T1 a ,T2 b){	
	return collide(a.getTriangles,b.getTriangles);
}

bool collide(AnyShape* sA,AnyShape* sB){
	bool function(void*,void*)[Types.length*Types.length] getJumpTable(Types...)(){
		bool function(void*,void*)[Types.length*Types.length] jumpTable;
		AnyShape shapeA,shapeB;
		string getCode(Types...)(){
			string code;
			foreach(i,typeA;Types){
				foreach(j,typeB;Types){
					uint num=i*Types.length+j;
					static if(__traits(compiles,collide(shapeA.get!typeA,shapeB.get!typeB))){
						code~=format("bool function(%s*,%s*) ___%d=&collide;\n",typeA.stringof,typeB.stringof,num);
					}else{
						code~=format("bool function(%s*,%s*) ___%d=&collideUniversal!(%s*,%s*);\n",typeA.stringof,typeB.stringof,num,typeA.stringof,typeB.stringof);
					}
					
				}
			}
			foreach(i;0..Types.length*Types.length){
				code~=format("jumpTable[%d]=cast(bool function(void*,void*))___%d;\n",i,i);
				
			}
			return code;
		}
		//writeln(getCode!Types);
		mixin(getCode!Types);
		return jumpTable;
	}
	if(sA.currentType==AnyShape.types.none || sB.currentType==AnyShape.types.none)return false;
	enum jumpTable=getJumpTable!(AnyShape.FromTypes);
	auto funcPointer=jumpTable[sA.currentType*AnyShape.FromTypes.length+sB.currentType];
	return funcPointer(cast(void*)sA,cast(void*)sB);
	
}

bool collide(Triangle[] trA,Triangle[] trB){	
	return false;
}
bool collide(Rectangle* r,Circle* c){
	return true;
}
bool collide(Circle* c,Rectangle* r){
	return true;
}

