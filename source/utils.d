module utils;
/**
 * Some random functions immiedately required
 */

import std.stdio : writeln, writefln;
import std.algorithm : min, max;
import std.math;
import gl3n.linalg;
import std.traits;
import drawables;
import sect_dist;
import shapes;



vec2[] getPointsOnCircle(vec2 pos, float r,int segments=64) {
	vec2[] points;
	points.reserve(segments);
	float delta = PI * 2 / (segments - 1);
	foreach (i; 0 .. segments) {
		float x = r * cos(delta * i);
		float y = r * sin(delta * i);
		points ~= vec2(x, y) + pos;
	}
	return points;
}

vec2[] getGridLines(vec2 dieSize, vec2 dimensions) {
	vec2 halfScreen = dieSize / 2;
	vec2i linesNum;
	linesNum.x = cast(int)(dieSize.x / dimensions.x);
	linesNum.y = cast(int)(dieSize.y / dimensions.y);
	linesNum.x += linesNum.x % 2 + 1;
	linesNum.y += linesNum.y % 2 + 1;
	immutable vec2i middle = linesNum / 2;
	vec2[] vertices;
	vertices.reserve = linesNum.x + linesNum.y;
	for (int i = -middle.x; i <= middle.x; i++) {
		vec2 p1 = vec2(dimensions.x * i, -dimensions.y * middle.y);
		vec2 p2 = vec2(dimensions.x * i, dimensions.y * middle.y);
		vertices ~= p1;
		vertices ~= p2;
	}
	for (int i = -middle.y; i <= middle.y; i++) {
		vec2 p1 = vec2(-dimensions.x * middle.x, dimensions.y * i);
		vec2 p2 = vec2(dimensions.x * middle.x, dimensions.y * i);
		vertices ~= p1;
		vertices ~= p2;
	}
	return vertices;
}

void printException(Exception e, int maxStack = 4) {
	writeln("Exception message: ", e.msg);
	writeln("File: ", e.file, " Line Number: ", e.line);
	writeln("Call stack:");
	foreach (i, b; e.info) {
		writeln(b, "\n");
		if (i >= maxStack)
			break;
	}
	writeln("--------------");
}
float vectorToAngle(vec2 p) {
	return atan2(p.y,p.x);
}
vec2 rotateVector(vec2 p, float r) {
	float c = cos(r);
	float s = sin(r);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

struct Transform{
	vec2 pos=vec2(0,0);
	float rot=0;
	float scale=1;

	Transform opBinary(string op)(Transform r) const
	{
		static if (op != "*")static assert(0, "Operator "~op~" not implemented");
		alias c = cos;
		alias s = sin;
		auto rPos=rotateVector(r.pos,rot);
		return Transform(
			rPos+pos,
			rot+r.rot,
			r.scale*scale
			);
	}

	mat4 toMatrix(){
		alias c = cos;
		alias s = sin;
		
		return mat4(scale * c(rot), -scale * s(rot), 0, pos.x,
			scale * s(rot),  scale * c(rot), 0, pos.y,
			0, 0, 1, 0,
			0, 0, 0, 1);
	}
	unittest{
		Transform t1,t2;
		t1=Transform(vec2(0,10),0,1);
		t2=Transform(vec2(0,20),0,1);
		assert((t1*t2).pos.y==30);

	}
}

float linesColide(vec2[2] first, vec2[2] second) {
	float denominator = ((first[1].x - first[0].x) * (second[1].y - second[0].y)) - (
		(first[1].y - first[0].y) * (second[1].x - second[0].x));
	float numerator1 = ((first[0].y - second[0].y) * (second[1].x - second[0].x)) - (
		(first[0].x - second[0].x) * (second[1].y - second[0].y));
	float numerator2 = ((first[0].y - second[0].y) * (first[1].x - first[0].x)) - (
		(first[0].x - second[0].x) * (first[1].y - first[0].y));

	bool collide;
	// Detect coincident lines (has a problem, read below)
	if (denominator == 0) {
		collide = numerator1 == 0 && numerator2 == 0;
	} else {
		float r = numerator1 / denominator;
		float s = numerator2 / denominator;
		collide = (r >= 0 && r <= 1) && (s >= 0 && s <= 1);
	}

	if (collide) {
		return 0;
	} else {
		float l1 = (first[0] - second[0]).length_squared;
		float l2 = (first[1] - second[0]).length_squared;
		float l3 = (first[0] - second[1]).length_squared;
		float l4 = (first[1] - second[1]).length_squared;
		return min(l1, l2, l3, l4);
	}
}

unittest {
	vec2[2][2][] linesToCollide = [[[vec2(0, -10), vec2(0, 10)], [vec2(-10, 0), vec2(10, 0)]]];
	vec2[2][2][] linesNotToCollide = [[[vec2(0, -10), vec2(0, -5)], [vec2(-10, 0), vec2(10, 0)]],
		[[vec2(0, -10), vec2(0, -5)], [vec2(4, -10), vec2(4, -5)]], [
			[vec2(0, 10), vec2(0, 5)
			], [vec2(0, 3), vec2(0, 1)]]];

	foreach (i, lines; linesToCollide) {
	//	assert(!linesColide(lines[0], lines[1]));
	}
	foreach (i, lines; linesNotToCollide) {
	//	assert(linesColide(lines[0], lines[1]));
	}
}

import objects;
import std.array;

//for build in arrays
void removeInPlace(R, N)(ref R haystack, N index)
{
	haystack[index] = haystack[$ - 1];
	haystack=haystack[0 .. $ - 1];
}
bool removeElementInPlace(R, N)(ref R arr, N obj)
{
	foreach(i,a;arr){
		if(a==obj){
			arr.removeInPlace(i);
			return true;
		}
	}
	return false;
}


///auto render chack, need because i had such a system before. have to be deleted

Something[] somethingAutoRender;
