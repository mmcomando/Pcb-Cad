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

vec2 rotateVector(vec2 p, float r) {
    float c = cos(r);
    float s = sin(r);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec2[] getPointsOnCircle(vec2 pos, float r) {
    int segments = 64;
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

mat4 getModelMatrix(T)(T o) if (__traits(hasMember, T, "pos") && is(typeof(T.pos) == vec2)
        && __traits(hasMember, T, "scale") && is(typeof(T.scale) == vec2) && __traits(hasMember, T,
        "rot") && is(typeof(T.rot) == float)) {
    alias c = cos;
    alias s = sin;

    return mat4(o.scale.x * c(o.rot), -o.scale.y * s(o.rot), 0, o.pos.x, o.scale.x * s(o.rot),
        o.scale.y * c(o.rot), 0, o.pos.y, 0, 0, 1, 0, 0, 0, 0, 1);

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
        writeln(i, " ", lines);
        assert(!slinesColide(lines[0], lines[1]));
    }
    foreach (i, lines; linesNotToCollide) {
        writeln(i, " ", lines);
        assert(linesColide(lines[0], lines[1]));
    }
}

import objects;
import std.array;

bool traceCollide(Trace a, Trace b, ref vec2[2] closestPoints) {
    vec2[2][] linesATrace;
    vec2[2][] linesBTrace;

    linesATrace = uninitializedArray!(vec2[2][])(a.points.length - 1);
    linesBTrace = uninitializedArray!(vec2[2][])(b.points.length - 1);

    for (int i = 1; i < a.points.length; i++) {
        linesATrace[i - 1] = [a.points[i - 1], a.points[i]];
    }
    for (int i = 1; i < b.points.length; i++) {
        linesBTrace[i - 1] = [b.points[i - 1], b.points[i]];
    }

    float minLength = float.max;
    float qLengthCollide = (a.traceWidth + b.traceWidth) * (a.traceWidth + b.traceWidth);
    foreach (lineA; linesATrace) {
        foreach (lineB; linesBTrace) {
            //float qLength=linesColide(lineA,lineB);
            sect asd = sect(lineA[0], lineA[1]);
            float qLength = sect_dist_nxt(sect(lineA[0], lineA[1]), sect(lineB[0], lineB[1]), 100)[0];
            if (qLength < qLengthCollide) {
                return true;
            } else if (qLength < minLength) {
                minLength = qLength;
                closestPoints = [lineA[0], lineB[0]];
            }
        }
    }
    return false;

}
//from internet
float minimum_distance(vec2 v, vec2 w, vec2 p) {
    const float l2 = (v - w).length_squared;
    if (l2 == 0.0)
        return (p - v).length_squared; 
    const float t = max(0, min(1, dot(p - v, w - v) / l2));
    const vec2 projection = v + t * (w - v); 
    return (p - projection).length_squared;
}

bool traceCollideWithPoint(Trace trace, vec2 point) {
    for (int i = 1; i < trace.points.length; i++) {
        float qLength = minimum_distance(trace.points[i - 1], trace.points[i], point);
        if (qLength < trace.traceWidth) {
            return true;
        }
    }
    return false;
}

bool traceCollideWithPad(Trace trace, Footprint footprint, uint shapeID) {
    //writeln(shapeID);
    Shape shape = footprint.f.shapes[shapeID];
    vec2 point = footprint.pos + rotateVector(shape.pos, footprint.rot);
    float minDistance = trace.traceWidth + min(shape.xy.x, shape.xy.y);
    for (int i = 1; i < trace.points.length; i++) {
        float qLength = minimum_distance(trace.points[i - 1], trace.points[i], point);
        if (qLength < minDistance) {
            return true;
        }
    }
    return false;
}

///auto render chack, need because i had such a system before, have to be deleted

Something[] somethingAutoRender;
