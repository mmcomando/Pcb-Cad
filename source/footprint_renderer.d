module footprint_renderer;

import std.math : round, atan2f;
import std.stdio : writeln, writefln;
import std.range : lockstep;
import std.algorithm : min, remove;

import gl3n.linalg;
import derelict.opengl3.gl3;
import glamour.shader : Shader;

import engine;
import engine.renderer.render;
import engine.renderer.memory;
import utils;
import objects;
import drawables;

class FootprintRenderer : Drawable {
    alias PosAllocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    alias MetaAllocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    PosAllocator vertexAllocator;

    static struct TextPos {
        Text text;
        vec2 pos;
        float rot = 0;
    }

    static class Data {
        void pos(vec2 p) {
            _pos = p;
            lines.pos = p;
            points.pos = p;
            triangles.pos = p;
            background.pos = p;
            r.pos = p;
            foreach (tt; texts)
                tt.text.pos = rotateVector(tt.pos, rot) + pos; //pos+tt.pos;
        }

        vec2 pos() {
            return _pos;
        }

        void rot(float r) {
            _rot = r;
            lines.rot = r;
            points.rot = r;
            triangles.rot = r;
            background.rot = r;
            this.r.rot = r;
            foreach (tt; texts) {
                tt.text.rot = r + tt.rot;
                tt.text.pos = rotateVector(tt.pos, rot) + pos;
            }
        }

        float rot() {
            return _rot;
        }

    private:
        Something lines;
        Something points;
        Something triangles;
        Something background;
        TextPos[] texts;
        Circles r;
        vec2 _pos;
        float _rot;
    }

    Data[] datas;
    this() {
        vertexAllocator = new PosAllocator;
    }

    Data addFootprint(Footprint footprint) {
        const FootprintData f = footprint.f;
        Data d = new Data;
        vec2[2] b = f.boundingBox;
        vec2 v1 = vec2(b[0].x, b[1].y);
        vec2 v2 = b[1];
        vec2 v3 = vec2(b[1].x, b[0].y);
        vec2 v4 = b[0];
        d.background = Something.fromPoints([v1, v2, v4, v4, v2, v3]);
        d.background.pos = footprint.pos;
        d.background.color = vec3(0.8, 0.8, 0.8);
        d.background.mode = GL_TRIANGLES;
        foreach (ref p; f.points) {
        }
        foreach (ref a; f.arcs) {
        }

        vec2[] rendLines;
        rendLines.reserve(f.lines.length * 2);
        foreach (ref l; f.lines) {
            rendLines ~= l[0];
            rendLines ~= l[1];
        }
        d.lines = Something.fromPoints(rendLines);
        d.lines.pos = footprint.pos;
        d.lines.color = vec3(0, 1, 1);
        d.lines.mode = GL_LINES;

        d.points = Something.fromPoints(f.points);
        d.points.pos = footprint.pos;
        d.points.color = vec3(0, 1, 0);
        d.points.mode = GL_POINTS;
        Circles.CircleData[] metas;
        foreach (ref c; f.circles) {
            metas ~= Circles.CircleData(vec3(0, 0, 1), c.pos, c.radius);
        }
        vec2[] trianglePoints;
        foreach (Shape shape; f.shapes) {
            final switch (shape.type) {
            case ShapeType.Circle:
                metas ~= Circles.CircleData(vec3(1, 0, 0), shape.pos, shape.xy.x / 2);
                break;
            case ShapeType.Rectangle:
                vec2 half = shape.xy / 2;
                vec2 v11 = shape.pos + vec2(-half.x, half.y);
                vec2 v22 = shape.pos + half;
                vec2 v33 = shape.pos + vec2(half.x, -half.y);
                vec2 v44 = shape.pos - half;
                trianglePoints ~= v11;
                trianglePoints ~= v22;
                trianglePoints ~= v44;
                trianglePoints ~= v44;
                trianglePoints ~= v22;
                trianglePoints ~= v33;
                break;
            }
        }
        d.triangles = Something.fromPoints(trianglePoints);
        d.r = Circles.addCircles(metas);
        d.r.pos = footprint.pos;
        d.triangles.pos = footprint.pos;
        d.triangles.rot = footprint.rot;
        d.triangles.color = vec3(0.9, 0, 0);
        d.triangles.mode = GL_TRIANGLES;

        foreach (name, pad; lockstep(footprint.padConnections, f.pads)) {
            float rot;
            if (name == "?" || name == "")
                continue;
            auto data = Text.fromString(name);
            data.pos = footprint.pos;
            rot = data.rot = 0;
            Shape sh = footprint.f.shapes[pad.shapeID];
            if (sh.type == ShapeType.Rectangle && sh.xy.x < sh.xy.y) {
                rot = 3.14 / 2; //data.rot=
            }
            data.scale = vec2(1, 1) * min(sh.xy.x, sh.xy.y);
            d.texts ~= TextPos(data, sh.pos, rot);

        }

        datas ~= d;
        d.pos = footprint.pos;
        d.rot = footprint.rot;
        return d;
    }

    void removeFootprint(Data d) {
        Something.remove(d.background);
        Something.remove(d.triangles);
        Circles.remove(d.r);
        Something.remove(d.lines);
        Something.remove(d.points);
        foreach (i, dddd; datas) {
            auto m = dddd.r;
            if (dddd == d) {
                datas = datas.remove(i);
                return;
            }
        }
        assert(0);
    }

    void addToDraw(RenderList list) {
        foreach (i, d; datas) {
            list.add(d.background, Priority(17));
            list.add(d.triangles, Priority(19));
            list.add(d.r, Priority(20));
            list.add(d.lines, Priority(20));
            list.add(d.points, Priority(21));
            foreach (tt; d.texts)
                list.add(tt.text, Priority(22));

        }
    }

    void onBind() {
    }

    void onUnbind() {
    }

    void draw() {
        foreach (i, d; datas) {
            d.r.onBind();
            d.r.draw();
            d.r.onUnbind();
        }

    }

}

class GridDraw : Drawable {
    vec2 pos = vec2(0, 0);
    vec2 dieSize = vec2(2000, 2000);
    vec2 size = vec2(1, 1);
    Something meta;
    this() {
    }

    void addToDraw(RenderList list) {
        draw();
        if (meta !is null)
            list.add(meta, Priority(1));
    }

    void onBind() {
    }

    void onUnbind() {
    }

    vec2 getDrawnSize() {
        vec2 v = gameEngine.renderer.camera.vectorSize(size) * 0.1;
        vec2i s2 = vec2i(cast(int)(1 / v.x), cast(int)(1 / v.y));
        v = vec2(size.x * s2.x + 1, size.y * s2.y + 1);
        if (size.x > v.x)
            v = size;
        return v;
    }

    bool snapPos(vec2 mousePos, ref vec2 newMousePos, ref float minLength) {
        mousePos += pos;
        vec2i numToBack = vec2i(cast(int) round(mousePos.x / size.x), cast(int) round(mousePos.y / size.y));
        vec2 newMousePosTmp = vec2(size.x * numToBack.x, size.y * numToBack.y);
        mousePos -= newMousePosTmp;
        vec2 dt = mousePos;
        float len2 = dt.length_squared;
        if (len2 < 1 * 1 && len2 < minLength) {
            newMousePos = newMousePosTmp;
            minLength = len2;
            return true;
        }
        return false;
    }

    void draw() {
        __gshared static vec2 lpos, ldieSize, lv; //l - last
        vec2 v = getDrawnSize();
        if (lv != v || lpos != pos || ldieSize != dieSize) {
            vec2[] gridLines = getGridLines(dieSize, v);
            if (meta !is null) {
                Something.remove(meta);
                meta = null;
            }
            if (gridLines.length == 0) {
                return;
            }

            meta = Something.fromPoints(gridLines);
            meta.pos = pos;
            meta.rot = 0;
            meta.color = vec3(0.75, 0.75, 0.75);
            meta.mode = GL_LINES;

            lpos = pos;
            ldieSize = dieSize;
            lv = v;
        }
    }
}
