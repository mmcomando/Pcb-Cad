module shapes;

import std.conv:to;
import std.format:format;
import std.array:uninitializedArray;

import gl3n.linalg;

import utils;

void test(){
	AnyShape A,B;
	A.set(Circle());
	B.set(Rectangle());	
	Transform trA, trB;
	collide(trA,trB,&A,&B);
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
	vec2[] getPoints(){
		vec2 half = wh / 2;
		vec2 v11 = vec2(-half.x, half.y);
		vec2 v22 = half;
		vec2 v33 = vec2(half.x, -half.y);
		vec2 v44 = -half;
		return [v11,v22,v33,v33,v11,v44];
	}
	Triangle[] getTriangles(){
		vec2 half = wh / 2;
		vec2 v11 = vec2(-half.x, half.y);
		vec2 v22 = half;
		vec2 v33 = vec2(half.x, -half.y);
		vec2 v44 = -half;
		return [Triangle(v11,v22,v33),Triangle(v33,v11,v44)];
	}
}
struct Circle {
	float radius;
	Triangle[] getTriangles(){
		vec2[] points = getPointsOnCircle(vec2(0, 0), radius,16);
		Triangle[] triangles=uninitializedArray!(Triangle[])(points.length);
		vec2 o = vec2(0, 0);
		vec2 last = points[$ - 1];
		foreach (i, p; points) {
			triangles[i]=Triangle(o,last,p);
			last = p;
		}
		return triangles;
	}
}


bool isShape(T)(){
	//has collide, aabb
	//no references
	bool ok=__traits ( isPOD , T );    
	ok&=__traits(hasMember, T, "getTriangles"); // t
	return ok;
}


/**
 * Template to generate Universal shape
 */
struct AnyShapeTemplate(Types...) {
	enum maxUnionSize=63;
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
	mixin(getShapeCode!(Types)(maxUnionSize));
	/**
	 * returns given type with check
	 */
	auto get(T)(){
		foreach(i,type;FromTypes){
			static if(is(type==T)){
				assert(currentType==i,"got type which is not currently bound");
				static if(T.sizeof>maxUnionSize){
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
				static if(T.sizeof>maxUnionSize){
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

bool collideUniversal(T1,T2)(Transform trA,Transform trB,T1 a ,T2 b){	
	return collide(trA,trB,a.getTriangles,b.getTriangles);
}

bool collide(Transform trA,Transform trB,AnyShape* sA,AnyShape* sB){
	bool function(Transform trA,Transform trB,void*,void*)[Types.length*Types.length] getJumpTable(Types...)(){
		bool function(Transform trA,Transform trB,void*,void*)[Types.length*Types.length] jumpTable;
		AnyShape shapeA,shapeB;
		string getCode(Types...)(){
			string code;
			foreach(i,typeA;Types){
				foreach(j,typeB;Types){
					uint num=i*Types.length+j;
					static if(__traits(compiles,collide(shapeA.get!typeA,shapeB.get!typeB))){
						code~=format("bool function(Transform trA,Transform trB,%s*,%s*) ___%d=&collide;\n",typeA.stringof,typeB.stringof,num);
					}else{
						code~=format("bool function(Transform trA,Transform trB,%s*,%s*) ___%d=&collideUniversal!(%s*,%s*);\n",typeA.stringof,typeB.stringof,num,typeA.stringof,typeB.stringof);
					}
					
				}
			}
			foreach(i;0..Types.length*Types.length){
				code~=format("jumpTable[%d]=cast(bool function(Transform trA,Transform trB,void*,void*))___%d;\n",i,i);
				
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
	return funcPointer(trA,trB,cast(void*)sA,cast(void*)sB);
	
}

bool collide(Transform trA,Transform trB,Triangle[] trianglesA,Triangle[] trianglesB){	
	//assert(false);
	return true;
}
//scale
bool collide(Transform trA,Transform trB,Circle* cA,Circle* cB){
	float dtSq=(trA.pos-trB.pos).length_squared;
	if(dtSq<cA.radius*cA.radius+cB.radius*cB.radius){
		return true;
	}else{
		return false;
	}
}
bool collide(Transform tr,Circle* c,vec2 p){
	float dtSq=(tr.pos-p).length_squared;
	if(dtSq<c.radius*c.radius){
		return true;
	}else{
		return false;
	}
}
//scale rot
bool collide(Transform trAA,Transform trBB,Rectangle* rAA,Rectangle* rBB){

	static bool collideAB(Transform trA,Transform trB,Rectangle* rA,Rectangle* rB){
		vec2 dt=trB.pos-trA.pos;
		vec2 halfA = rA.wh / 2;
		vec2 halfB = rB.wh / 2;
		
		vec2 pA1 =  vec2(-halfA.x, halfA.y);
		vec2 pA2 =   halfA;
		vec2 pA3 =  vec2(halfA.x, -halfA.y);
		vec2 pA4 =  - halfA;
		
		vec2 dtRotated=rotateVector(dt,-trA.rot);
		vec2 pB1 = dtRotated + rotateVector(  vec2(-halfB.x, halfB.y),trB.rot-trA.rot);
		vec2 pB2 = dtRotated + rotateVector( halfB,trB.rot-trA.rot);
		vec2 pB3 = dtRotated + rotateVector(vec2(halfB.x, -halfB.y),trB.rot-trA.rot);
		vec2 pB4 = dtRotated + rotateVector( - halfB,trB.rot-trA.rot);

		if(
			((min(pB1.x,pB2.x,pB3.x,pB4.x)<=max(pA1.x,pA2.x,pA3.x,pA4.x))  &&
				(max(pB1.x,pB2.x,pB3.x,pB4.x)>=min(pA1.x,pA2.x,pA3.x,pA4.x)))  
			&&
			((min(pB1.y,pB2.y,pB3.y,pB4.y)<=max(pA1.y,pA2.y,pA3.y,pA4.y))  &&
				(max(pB1.y,pB2.y,pB3.y,pB4.y)>=min(pA1.y,pA2.y,pA3.y,pA4.y)))
			
			){
			return true;
		}
		return false;
	}

	if(collideAB(trAA,trBB,rAA,rBB) && collideAB(trBB,trAA,rBB,rAA)){
		return true;
	}
	return false;

}
bool collide(Transform tr,Rectangle* r,vec2 p){
	vec2 half = r.wh / 2;
	vec2 minn = tr.pos - half;
	vec2 maxx = tr.pos + half;
	if (p.x > minn.x && p.y > minn.y && p.x < maxx.x && p.y < maxx.y) {
		return true;
	}
	return false;
}
bool collide(Transform trA,Transform trB,Circle* c,Rectangle* r){
	return true;
}
bool collide(Transform trA,Transform trB,Rectangle* r,Circle* c){
	return collide(trA,trB,c,r);
}

