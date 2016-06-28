﻿module shapes;

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
	//collide(trA,trB,&A,&B);
}
struct Triangle{
	vec2 p1;
	vec2 p2;
	vec2 p3;
	Triangle[] getTriangles(){
		return [Triangle(p1,p2,p3)];
	}
	vec2[] getPoints(){
		return [p1,p2,p3];
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
	Triangle[] getTriangles() {
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
	//enum types{...}    //from mixin
	//types currentType; //from mixin

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
	Triangle[] getTriangles(){
		final switch(currentType){
			case types.Rectangle:
				return get!(Rectangle).getTriangles();
			case types.Circle:
				return get!(Circle).getTriangles();
			case types.Triangle:
				return get!(Triangle).getTriangles();
			case types.none:return [];
		}
	}

	//  --  Mixin --
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
	vec2 dt=trB.pos-trA.pos;
	vec2 dtRotated=rotateVector(dt,-trA.rot);
	foreach(triA;trianglesA){
		foreach(i,triB;trianglesB){
			triB.p1 = dtRotated + rotateVector(triB.p1,trB.rot-trA.rot);
			triB.p2 = dtRotated + rotateVector(triB.p2,trB.rot-trA.rot);
			triB.p3 = dtRotated + rotateVector(triB.p3,trB.rot-trA.rot);

			//triB.p1+=dt;
			//triB.p2+=dt;
			//triB.p3+=dt;
			if(triangleTtiangle(triA,triB)){
				return true;
			}
		}
	}
	return false;
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

bool collide(Transform transform,AnyShape* shape,vec2 p){
	p-=transform.pos;
	p=rotateVector(p,-transform.rot);
	Triangle[] triangles=shape.getTriangles();
	foreach(tr;triangles){
		if(pointInTriangle(tr,p)){
			return true;
		}
	}
	return false;
}
bool collide(Transform trA,Transform trB,Circle* c,Rectangle* r){
	return true;
}
bool collide(Transform trA,Transform trB,Rectangle* r,Circle* c){
	return collide(trA,trB,c,r);
}


//////////////////
///
bool pointInTriangle(Triangle tr,vec2 P){
	float cross(vec2 u,vec2 v){
		return u.x*v.y-u.y*v.x;
	}
	auto A=tr.p1;
	auto B=tr.p2;
	auto C=tr.p3;
	vec2 v0 = [C.x-A.x, C.y-A.y];
	vec2 v1 = [B.x-A.x, B.y-A.y];
	vec2 v2 = [P.x-A.x, P.y-A.y];
	auto u = cross(v2,v0);
	auto v = cross(v1,v2);
	auto d = cross(v1,v0);
	if (d<0){
		u=-u;
		v=-v;
		d=-d;
	}
	return u>=0 && v>=0 && (u+v) <= d;
	
}
import sect_dist;
bool line_intersect2(vec2 v1,vec2 v2,vec2 v3,vec2 v4){

	auto d = (v4.y-v3.y)*(v2.x-v1.x)-(v4.x-v3.x)*(v2.y-v1.y);
	auto u = (v4.x-v3.x)*(v1.y-v3.y)-(v4.y-v3.y)*(v1.x-v3.x);
	auto v = (v2.x-v1.x)*(v1.y-v3.y)-(v2.y-v1.y)*(v1.x-v3.x);
	if (d<0){
		u=-u;
		v=-v;
		d=-d;
	}
	return (0<=u && u<=d) && (0<=v && v<=d);
}
bool triangleTtiangle(Triangle t1,Triangle t2){
	
	if (line_intersect2(t1.p1,t1.p2,t2.p1,t2.p2))return true;
	if (line_intersect2(t1.p1,t1.p2,t2.p1,t2.p3))return true;
	if (line_intersect2(t1.p1,t1.p2,t2.p2,t2.p3))return true;
	if (line_intersect2(t1.p1,t1.p3,t2.p1,t2.p2))return true;
	if (line_intersect2(t1.p1,t1.p3,t2.p1,t2.p3))return true;
	if (line_intersect2(t1.p1,t1.p3,t2.p2,t2.p3))return true;
	if (line_intersect2(t1.p2,t1.p3,t2.p1,t2.p2))return true;
	if (line_intersect2(t1.p2,t1.p3,t2.p1,t2.p3))return true;
	if (line_intersect2(t1.p2,t1.p3,t2.p2,t2.p3))return true;
	bool inTri = true ;
	inTri = inTri && pointInTriangle(t1, t2.p1);
	inTri = inTri && pointInTriangle(t1, t2.p2);
	inTri = inTri && pointInTriangle(t1, t2.p3);
	if (inTri)  return true;
	inTri = true;
	inTri = inTri && pointInTriangle(t2, t1.p1);
	inTri = inTri && pointInTriangle(t2, t1.p2);
	inTri = inTri && pointInTriangle(t2, t1.p3);
	if (inTri) return true;
	
	return false;
}