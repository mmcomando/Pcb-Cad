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

class FootprintRenderer  {
    alias PosAllocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    alias MetaAllocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    PosAllocator vertexAllocator;

    static struct TextPos {
        Text text;
		Transform trf;
    }

    static class Data {
		void trf(Transform t) {
			_trf = t;
			group.trf=t;
			r.trf=t;
			foreach (ref tt; texts) {
				//writeln("-");
				//writeln(tt.trf);
				tt.text.trf=_trf*tt.trf;
				//writeln(tt.trf);

			}
		}
		
		const(Transform) trf() {
			return _trf;
		}
		this(){
			group=new Group();
		}

    private:
		Group group;
        TextPos[] texts;
        Circles r;
		Transform _trf;
    }

    Data[] datas;
    this() {
        vertexAllocator = new PosAllocator;
    }

    Data addFootprint(Footprint footprint) {
		SomethingNoTransform lines;
		SomethingNoTransform points;
		SomethingNoTransform triangles;
		SomethingNoTransform background;
        const FootprintData f = footprint.f;
        Data d = new Data;
        vec2[2] b = f.boundingBox;
        vec2 v1 = vec2(b[0].x, b[1].y);
        vec2 v2 = b[1];
        vec2 v3 = vec2(b[1].x, b[0].y);
        vec2 v4 = b[0];
        background = SomethingNoTransform.fromPoints([v1, v2, v4, v4, v2, v3]);
        background.color = vec3(0.8, 0.8, 0.8);
        background.mode = GL_TRIANGLES;
        foreach (ref p; f.points) {
        }

        vec2[] rendLines;
        rendLines.reserve(f.lines.length * 2);
        foreach (ref l; f.lines) {
            rendLines ~= l[0];
            rendLines ~= l[1];
        }
		lines = SomethingNoTransform.fromPoints(rendLines);
        lines.color = vec3(0, 1, 1);
        lines.mode = GL_LINES;

		points = SomethingNoTransform.fromPoints(f.points);
        points.color = vec3(0, 1, 0);
        points.mode = GL_POINTS;
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
		triangles = SomethingNoTransform.fromPoints(trianglePoints);
        d.r = Circles.addCircles(metas);
        d.r.trf =footprint.trf;
        triangles.color = vec3(0.9, 0, 0);
        triangles.mode = GL_TRIANGLES;

		//pad's names
        foreach (name, pad; lockstep(footprint.padConnections, f.pads)) {
			Transform trf;
            
            if (name == "?" || name == "")
                continue;
            auto data = Text.fromString(name);
			Shape sh = footprint.f.shapes[pad.shapeID];
            data.trf=footprint.trf;
			data.trf.pos=vec2(0,0);
			trf.rot=data.trf.rot = 0;
			trf.pos=sh.pos;
            if (sh.type == ShapeType.Rectangle && sh.xy.x < sh.xy.y) {
				trf.rot+= 3.14 / 2;
            }
            data.trf.scale =min(sh.xy.x, sh.xy.y);
			writeln(TextPos(data,trf));
            d.texts ~= TextPos(data,trf);
			assert(0);

        }

		auto data = Text.fromString(f.name);
		vec2 bb_dt=f.boundingBox[1]-f.boundingBox[0];
		d.texts ~= TextPos(data,Transform(vec2(0,0),0,0.2*bb_dt.y));

        datas ~= d;
		d.group.add(background);
		d.group.add(triangles);
		d.group.add(lines);
		d.group.add(points);
        return d;
    }

    void removeFootprint(Data d) {
        Circles.remove(d.r);
		d.group.destroy();
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
			list.add(d.group, Priority(18));
            list.add(d.r, Priority(20));
            foreach (tt; d.texts)
                list.add(tt.text, Priority(22));

        }
    }



}

class GridDraw : Drawable {
    vec2 pos = vec2(0, 0);
    vec2 dieSize = vec2(0.2, 0.2);
    vec2 size = vec2(0.001, 0.001);
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
        v = vec2(size.x * s2.x, size.y * s2.y);
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
            meta.trf.pos = pos;
			meta.trf.rot = 0;
            meta.color = vec3(0.75, 0.75, 0.75);
            meta.mode = GL_LINES;

            lpos = pos;
            ldieSize = dieSize;
            lv = v;
        }
    }
}

