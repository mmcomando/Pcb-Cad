module shapes;

import std.conv:to;
import std.format:format;
import std.array:uninitializedArray;
import std.math:sqrt;
import std.algorithm:min,max;

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
	vec2[] getPoints(){
		return [p1,p2,p3];
	}
	CC getBoundingCircle(){
		return makeCircumcircle(p1,p2,p3);
	}
	Triangle[] getTriangles(){
		return [Triangle(p1,p2,p3)];
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
	CC getBoundingCircle(){
		vec2 wh2=wh/2;
		return CC(vec2(0,0),wh2.x*wh2.x+wh2.y*wh2.y);
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
	CC getBoundingCircle(){
		return CC(vec2(0,0),radius*radius);
	}
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
struct PolyLine {
	vec2[] points;
	float traceWidth;

	CC getBoundingCircle(){
		CC c=smallestEnclosingCircle(points);
		float d=sqrt(c.r)+traceWidth/2;
		c.r=d*d;
		return c;
	}
	//TODO no corners
	Triangle[] getTriangles() {
		vec2 last = points[0];
		Triangle[] triangles;
		foreach (p; points[1 .. $]) {
			vec2 normal = (p - last).normalized();
			vec2 tangent = vec2(normal.y, -normal.x) * traceWidth / 2;
			vec2 v1 = last + tangent;
			vec2 v2 = p + tangent;
			vec2 v3 = p - tangent;
			vec2 v4 = last - tangent;
			triangles~= [Triangle(v1,v2,v4),Triangle(v4,v2,v3)];
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
struct AnyShapeTemplate(ShapeTypes...) {
	enum maxUnionSize=63;
	alias FromTypes=ShapeTypes;
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
				currentType=cast(Types)i;
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
			case Types.Rectangle:
				return get!(Rectangle).getTriangles();
			case Types.Circle:
				return get!(Circle).getTriangles();
			case Types.Triangle:
				return get!(Triangle).getTriangles();
			case Types.PolyLine:
				return get!(PolyLine).getTriangles();
			case Types.none:return [];
		}
	}
	CC getBoundingCircle(){
		final switch(currentType){
			case Types.Rectangle:
				return get!(Rectangle).getBoundingCircle();
			case Types.Circle:
				return get!(Circle).getBoundingCircle();
			case Types.Triangle:
				return get!(Triangle).getBoundingCircle();
			case Types.PolyLine:
				return get!(PolyLine).getBoundingCircle();
			case Types.none:return CC();
		}
	}

	//  --  Mixin --
	/** 
	 * Generates code for universal shape
	 * types which can be packed to union are packed, others are allocated and there is stored their pointer
	 */
	static string getShapeCode(ShapeTypes...)(uint unionSize){
		string codeChecks;
		string codeEnum="enum Types:ubyte{\n";
		string code="private union{\n";
		foreach(uint i,type;ShapeTypes){
			string typeName=type.stringof;
			string valueName="_"~i.to!string;
			string ampChar="&";
			string pointer="";
			codeEnum~=typeName~"="~i.to!string~",\n";
			if(type.sizeof>unionSize){
				pointer="*";
				ampChar="";
			}
			code~= typeName~pointer;
			
			code~=" "~valueName~";\n";
			
			
		}
		codeEnum~="none\n}\n";
		return codeEnum~code~"}\n"~codeChecks~"Types currentType=Types.none;\n";
	}
	mixin(getShapeCode!(ShapeTypes)(maxUnionSize));
}
alias AnyShape=AnyShapeTemplate!(Rectangle,Circle,Triangle,PolyLine);

//Collision functions

bool collideUniversal(T1,T2)(Transform trA,Transform trB,T1 a ,T2 b){
	CC circleA=a.getBoundingCircle();
	CC circleB=b.getBoundingCircle();
	vec2 dt=trB.pos-trA.pos+circleB.pos-circleA.pos;
	float sum=sqrt(circleA.r)+sqrt(circleB.r);
	if(dt.length_squared>sum*sum){
		return false;
	}
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
	if(sA.currentType==AnyShape.Types.none || sB.currentType==AnyShape.Types.none)return false;
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
//scale
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
bool collide(Transform transform,PolyLine* polyLine, vec2 point) {
	for (int i = 1; i < polyLine.points.length; i++) {
		float qLength = minimum_distance(polyLine.points[i - 1], polyLine.points[i], point);
		if (qLength < polyLine.traceWidth) {//TODO FIX?
			return true;
		}
	}
	return false;
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

/////
///helper functions


//from internet
float minimum_distance(vec2 v, vec2 w, vec2 p) {
	const float l2 = (v - w).length_squared;
	if (l2 == 0.0)
		return (p - v).length_squared; 
	const float t = max(0, min(1, dot(p - v, w - v) / l2));
	const vec2 projection = v + t * (w - v); 
	return (p - projection).length_squared;
}


struct CC{
	vec2 pos;
	float r;
}
CC makeCircumcircle(vec2 p0,vec2  p1,vec2  p2) {
	// Mathematical algorithm from Wikipedia: Circumscribed circle
	float ax = p0.x, ay = p0.y;
	float bx = p1.x, by = p1.y;
	float cx = p2.x, cy = p2.y;
	float d = (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by)) * 2;
	if (d == 0){
		return CC();
	}
	float x = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d;
	float y = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d;
	vec2 xy=vec2(x,y);
	return CC(xy,(xy-vec2(ax,ay)).length_squared);
}
CC makeDiameter(vec2 p0,vec2  p1) {
	return CC((p0+p1)/2,((p0-p1)/2).length_squared);
	//return CC((p0+p1)/2,0.0001);
}
bool contains(CC c,vec2 p){
	return (c.pos-p).length_squared<=c.r;
}
bool contains(CC c,vec2[] ps){
	foreach ( p ; ps) {
		if (!c.contains(p))
			return false;
	}
	return true;
}



CC smallestEnclosingCircle(vec2[] points) {
	vec2 farestPoint(vec2[] points,vec2 point){
		float maxDistance=0;
		int index=0;
		foreach(int i,p;points){
			float qLength=(p-point).length_squared;
			if(maxDistance<qLength){
				maxDistance=qLength;
				index=i;
			}
		}
		return points[index];
	}
	vec2 pointA=farestPoint(points,points[0]);
	vec2 pointB=farestPoint(points,pointA);


	CC c=CC((pointA+pointB)/2,((pointA-pointB)/2).length_squared);
	while(points.length!=0){
		float dt=(c.pos-points[0]).length_squared-c.r;
		if(dt>0){
				c.r+=dt;
		}
		points=points[1..$];
	}
	return c;
}



/////////

