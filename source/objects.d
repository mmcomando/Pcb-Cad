module objects;
import std.math : abs;
import std.stdio : writeln;
import std.algorithm : remove, min, max, find, map, joiner, each;
import std.range : chain, empty, take;

import derelict.opengl3.gl3 : GL_TRIANGLES, GL_LINES;
import gl3n.linalg;

import engine;
import engine.renderer;
import engine.window;

import gui_data;
import kicad_interop;
import footprint_renderer;
import action;
import utils;
import drawables;

struct PadID {
    Footprint footprint;
    uint padNum;
}

struct ConnectionsManager {
    Connection[] connections;
    void add(Footprint footprint) {
        foreach (uint padNum, conName; footprint.padConnections) {
            if (conName.empty || conName == "?")
                continue;

            Connection con;
            con.name = conName;
            con.pads ~= PadID(footprint, padNum);
            connections ~= con;
        }
    }

    void remove(Footprint footprint) {
        foreach (kk, ref conns; connections) {
            foreach_reverse (i, pad_id; conns.pads) {
                if (pad_id.footprint == footprint) {
                    conns.pads = conns.pads.remove(i);
                }
            }
        }
    }

    void add(Trace trace) {
        if (!trace.connection.empty) {
            vec2[2] closestPoints;
            foreach (ref conn; connections) {
                if (conn.name != trace.connection)
                    continue;
                foreach (tr; conn.traces) {
                    if (traceCollide(trace, tr, closestPoints)) {
                        conn.traces ~= trace;
                        return;
                    }
                }
                foreach (pad_id; conn.pads) {
                    if (traceCollideWithPad(trace, pad_id.footprint, pad_id.padNum)) {
                        conn.traces ~= trace;
                        return;
                    }
                }
            }

            /*foreach (ref conn; connections) {
				if(conn.name==trace.connection){
					conn.traces~=trace;
					return;
				}
			}*/
        } else {
            vec2[2] closestPoints;
            foreach (ref conn; connections) {
                foreach (tr; conn.traces) {
                    if (traceCollide(trace, tr, closestPoints)) {
                        conn.traces ~= trace;
                        return;
                    }
                }
                foreach (pad_id; conn.pads) {
                    if (traceCollideWithPad(trace, pad_id.footprint, pad_id.padNum)) {
                        conn.traces ~= trace;
                        return;
                    }
                }
            }

        }

        Connection con;
        con.traces ~= trace;
        connections ~= con;
    }

    void remove(Trace trace) {
        foreach (kk, ref conns; connections) {
            foreach_reverse (i, tr; conns.traces) {
                if (tr == trace) {

                    conns.traces[i] = conns.traces[$ - 1];
                    conns.traces = conns.traces[0 .. $ - 1];
                }
            }
        }
    }

}

struct Connection {
    string name;
    PadID[] pads;
    Trace[] traces;
}

void addRandomConnections(PcbProject proj) {
    import std.random : uniform;

    immutable connections = ["GND", "?", "Vcc", "sens1", "sens2"];

    foreach (i; 0 .. 10) {
        if (proj.footprints.length == 0)
            continue;
        Footprint f = proj.footprints[uniform(0, proj.footprints.length)];

        foreach (j; 0 .. min(f.padConnections.length, 15)) {
            f.padConnections[uniform(0, f.padConnections.length)] = connections[uniform(0, connections.length)];
        }
    }
}
/*
void addConnections(PcbProject proj){
	foreach(footprint;proj.footprints){
		foreach(uint padNum,conName;footprint.padConnections){
			if(conName.empty || conName=="?")continue;

			Connection con;
			con.name=conName;
			con.pads~=PadID(footprint,padNum);
			proj.connectionsManager.connections~=con;
			//con.name.writeln;
		}
	}
}*/
void displayConnections(PcbProject proj) {
    auto getPoints(Connection* conn) {
        static vec2 getPos(T)(T a) {
            Footprint f = a.footprint;
            vec2 padPos = f.f.shapes[f.f.pads[a.padNum].shapeID].pos;
            return rotateVector(padPos, f.trf.rot) + a.footprint.trf.pos;
        }
        //auto padPoints=conn.pads.map!(a=>a.footprint.f.shapes[a.footprint.f.pads[a.padNum].shapeID].pos+a.footprint.pos)();
        auto padPoints = conn.pads.map!getPos();
        auto tracePoints = conn.traces.map!("a.points").joiner; //.take(1)
        //padPoints.each!writeln;
        return chain(padPoints, tracePoints);
        //return chain(padPoints,trac.poi); 

    }

    vec2[] lines;
    Connection*[][string] toConnect;
    foreach (ref conn; proj.connectionsManager.connections) {
        if (conn.name == "?")
            continue;
        toConnect[conn.name] ~= &conn;
    }
    foreach (name; toConnect.byKey) {
        //	writeln(name);
    }

    foreach (toConn; toConnect) {
        foreach (i, conn1; toConn) {
            bool found = false;
            float minLength = float.max;
            vec2[2] line;
            auto points1 = getPoints(conn1);
            foreach (conn2; toConn[min(i + 1, toConn.length - 1) .. $]) {
                auto points2 = getPoints(conn2);
                foreach (p1; points1) {
                    foreach (p2; points2) {
                        float length = (p1 - p2).length_squared;
                        if (length < minLength) {
                            minLength = length;
                            line = [p1, p2];
                            found = true;
                        }
                    }
                }

            }
            if (found)
                lines ~= line;
        }
    }
    static Something drawLines;
    if (drawLines !is null) {
        Something.remove(drawLines);
        foreach (i, s; somethingAutoRender) {
            if (s == drawLines) {
                somethingAutoRender[i] = somethingAutoRender[$ - 1];
                somethingAutoRender = somethingAutoRender[0 .. $ - 1];
                break;
            }
        }
    }
    drawLines = Something.fromPoints(lines);
    drawLines.mode = GL_LINES;
	drawLines.trf.pos = vec2(0, 0);
	drawLines.trf.rot = 0;
    drawLines.color = vec3(1, 0, 1);
    somethingAutoRender = somethingAutoRender ~= drawLines;

}

void displayTraceConnections(PcbProject proj) {
    vec2[] lines;
    foreach (traceA; proj.traces) {
        foreach (traceB; proj.traces) {
            vec2[2] closestPoints;
            if (!traceCollide(traceA, traceB, closestPoints)) {
                //writeln("--");
                lines ~= [closestPoints[0], closestPoints[1]];

            }
        }
    }
    static Something drawLines;
    if (drawLines !is null) {
        Something.remove(drawLines);
        foreach (i, s; somethingAutoRender) {
            if (s == drawLines) {
                somethingAutoRender[i] = somethingAutoRender[$ - 1];
                somethingAutoRender = somethingAutoRender[0 .. $ - 1];
                break;
            }
        }
    }
    drawLines = Something.fromPoints(lines);
    drawLines.mode = GL_LINES;
	drawLines.trf.pos = vec2(0, 0);
	drawLines.trf.rot = 0;
    drawLines.color = vec3(0.3, 0.5, 0);
    somethingAutoRender = somethingAutoRender ~= drawLines;

}

class PcbProject {
    string name;
    ActionList actions;

    FootprintsLibrary[] footprintsLibraries;
    Footprint[] footprints;
    Trace[] traces;

    ConnectionsManager connectionsManager;
    GridDraw grid;
    this() {
        actions = new ActionList;
        grid = new GridDraw();
    }

    void addTrace(Trace t) {
        t.init();
        traces ~= t;
        connectionsManager.add(t);
    }

    void removeTrace(Trace trace) {
        foreach (i, t; traces) {
            if (t == trace) {
                traces[i] = traces[$ - 1];
                traces = traces[0 .. $ - 1];
                Circles.remove(trace.rendWheels);
                Something.remove(trace.rendPoints);
            }
        }
        //remove from connections
        connectionsManager.remove(trace);
    }

    void addFootprint(Footprint f) {
        f.addToDraw();
        footprints ~= f;
        connectionsManager.add(f);
    }

    void removeFootprint(size_t i) {
        footprints = footprints.remove(i);
    }

    void removeFootprint(Footprint footprint) {
        footprint.removeFromDraw();
        foreach (i, f; footprints) {
            if (f == footprint) {
                footprints = footprints.remove(i);
            }
        }
        //remove from connections
        connectionsManager.remove(footprint);
    }

    vec2[] getSnapPoints() {
        vec2[] snapPoints;
        foreach (f; footprints) {
            vec2[] points = f.f.snapPoints.dup;
            foreach (ref p; points)
                p += f.trf.pos;
            snapPoints ~= points;
        }
        return snapPoints;
    }

    Footprint getFootprint(vec2 pos) {
        foreach (i, f; footprints) {
            if (f.collide(pos)) {
                return f;
            }
        }
        return null;
    }

    Trace getTrace(vec2 pos) {
        foreach (i, t; traces) {
            if (traceCollideWithPoint(t, pos)) {
                return t;
            }
        }
        return null;
    }
}

class TransformFootprint : Action {
    Transform before;
	Transform after;
    Footprint footprint;
	this(Footprint ft, Transform before, Transform after) {
        footprint = ft;
        this.before = before;
        this.after = after;
    }

    void doAction() {
        footprint.trf = after;
    }

    void undoAction() {
        footprint.trf = before;
    }

}
/*
class RotateFootprint : Action {
    float from;
    float to;
    Footprint footprint;
    this(Footprint ft, float from, float to) {
        footprint = ft;
        this.from = from;
        this.to = to;
    }

    void doAction() {
        footprint.rot = to;
    }

    void undoAction() {
        footprint.rot = from;
    }

}*/

class RemoveFootprint : Action {
    PcbProject project;
    Footprint footprint;
    this(PcbProject project, Footprint ft) {
        this.project = project;
        footprint = ft;
    }

    void doAction() {
        project.removeFootprint(footprint);
    }

    void undoAction() {
        project.addFootprint(footprint);
    }

}

class Trace {
    string connection;
    vec2[] points;
    Something rendPoints;
    Circles rendWheels;
    float traceWidth;
    this(float traceWidth) {
        this.traceWidth = traceWidth;
    }

    void init() {
        vec2[] trianglePoints = getTrianglePoints();
        Circles.CircleData[] metas;
        foreach (p; points) {
            metas ~= Circles.CircleData(vec3(1, 0, 0), p, traceWidth / 2);
        }
        rendWheels = Circles.addCircles(metas, true);
        rendWheels.trf.pos = vec2(0, 0);
        rendPoints = Something.fromPoints(trianglePoints);
		rendPoints.trf.pos = vec2(0, 0);
        rendPoints.color = vec3(1, 0, 0);
        rendPoints.mode = GL_TRIANGLES;
    }

    void addToDraw(RenderList list) {
        list.add(rendPoints, Priority(18));
        list.add(rendWheels, Priority(18));
    }

    vec2[] getTrianglePoints() {
        vec2 last = points[0];
        vec2[] trianglePoints;
        foreach (p; points[1 .. $]) {
            vec2 normal = (p - last).normalized();
            vec2 tangent = vec2(normal.y, -normal.x) * traceWidth / 2;
            vec2 v1 = last + tangent;
            vec2 v2 = p + tangent;
            vec2 v3 = p - tangent;
            vec2 v4 = last - tangent;
            trianglePoints ~= v1;
            trianglePoints ~= v2;
            trianglePoints ~= v4;
            trianglePoints ~= v4;
            trianglePoints ~= v2;
            trianglePoints ~= v3;
            last = p;
        }
        return trianglePoints;
    }
}

class FootprintsLibrary {
    this(string name) {
        this.name = name;
        footprints = getFootprintsFromModFile(name);
        guiData.addFootprints(footprints, name);
    }

    string name;
    FootprintData[] footprints;
}

//TODO component system?? move->event->move rendering??
class Footprint {
    static FootprintRenderer rend;
    FootprintRenderer.Data rendData;

    const FootprintData f;
   /*private vec2 _pos = vec2(0, 0);
    private float _rot = 0;*/
	Transform _trf;
    string name;
    string[] padConnections;

	/* @property vec2 pos() {
        return _pos;
    }

    @property vec2 pos(vec2 p) {
        if (rendData !is null)
            rendData.pos = _pos = p;
        return _pos;
    }

    @property float rot() {
        return _rot;
    }

    @property void rot(float r) {
        if (rendData !is null)
            rendData.rot = _rot = r; //bug
    }*/
	void trf(Transform t) {
		_trf = t;
		rendData.trf=t;
	}
	
	const(Transform) trf() {
		return _trf;
	}

    this(FootprintData f) {
        if (rend is null)
            rend = new FootprintRenderer;
        this.f = f;
        padConnections.length = f.pads.length;
        foreach (i, ref p; padConnections)
            p = f.pads[i].connection;
    }

    this() {
        if (rend is null)
            rend = new FootprintRenderer;
        f = new FootprintData();
        padConnections.length = f.pads.length;
        foreach (ref p; padConnections)
            p = "?";
        assert(0);
    }

    void addToDraw() {
        rendData = rend.addFootprint(this);

    }

    void removeFromDraw() {
        rend.removeFootprint(rendData);
    }

    //TODO rotation
    bool collide(vec2 point) {
        vec2 minn = trf.pos + f.boundingBox[0];
        vec2 maxx = trf.pos + f.boundingBox[1];
        if (point.x > minn.x && point.y > minn.y && point.x < maxx.x && point.y < maxx.y) {
            return true;
        }
        return false;
    }

}

enum PadType {
    SMD,
    THT
}

enum ShapeType {
    Circle,
    Rectangle
}

// Remove pad completely?? use traces, shapes, itd with some ID??
struct Pad {
    string connection;
    uint shapeID;
    PadType type;
    //uint wireID;
}

struct Shape {
    vec2 pos;
    vec2 xy; ///For Circle size?, for Rectangle size
    ShapeType type;
}

struct Copper {
    Shape shape;
    uint wireID;
}

struct Circle {
    vec2 pos;
    float radius;
}

struct Arc {
    vec2 pos;
    vec2 start_end;
    float radius;
}

class FootprintData {
    string name;
    Pad[] pads;
    Copper[] coppers;
    Shape[] shapes;
    vec2[] points;
    vec2[2][] lines;
    Circle[] circles;
    Arc[] arcs;
    vec2[] snapPoints;

    vec2[2] boundingBox;
    this() {
    }

    this(FootprintData f) {

        name = f.name;
        pads = f.pads.dup;
        coppers = f.coppers.dup;
        shapes = f.shapes.dup;
        points = f.points.dup;
        lines = f.lines.dup;
        circles = f.circles.dup;
        arcs = f.arcs.dup;
        boundingBox = f.boundingBox;
        snapPoints = f.snapPoints;
    }

    vec2[2] computeBoundingBox() const {
        vec2 minn;
        vec2 maxx;
        if (points.length) {
            minn = points[0];
        } else if (lines.length) {
            minn = lines[0][0];
        } else if (circles.length) {
            minn = circles[0].pos;
        } else if (arcs.length) {
            minn = arcs[0].pos;
        } else if (shapes.length) {
            minn = shapes[0].pos;
        } else {
            minn = vec2(0, 0);
        }
        maxx = minn + vec2(0.1, 0.1);
        foreach (p; points) {
            minn.x = min(p.x, minn.x);
            minn.y = min(p.y, minn.y);
            maxx.x = max(p.x, maxx.x);
            maxx.y = max(p.y, maxx.y);
        }
        foreach (l; lines) {
            minn.x = min(l[0].x, l[1].x, minn.x);
            minn.y = min(l[0].y, l[1].y, minn.y);
            maxx.x = max(l[0].x, l[1].x, maxx.x);
            maxx.y = max(l[0].y, l[1].y, maxx.y);
        }
        foreach (c; circles) {
            minn.x = min(c.pos.x - c.radius, minn.x);
            minn.y = min(c.pos.y - c.radius, minn.y);
            maxx.x = max(c.pos.x + c.radius, maxx.x);
            maxx.y = max(c.pos.y + c.radius, maxx.y);
        }
        foreach (c; arcs) {
            minn.x = min(c.pos.x - c.radius, minn.x);
            minn.y = min(c.pos.y - c.radius, minn.y);
            maxx.x = max(c.pos.x + c.radius, maxx.x);
            maxx.y = max(c.pos.y + c.radius, maxx.y);
        }
        foreach (s; shapes) {
            final switch (s.type) {
            case ShapeType.Circle:
                float radius = s.xy.x;
                minn.x = min(s.pos.x - radius, minn.x);
                minn.y = min(s.pos.y - radius, minn.y);
                maxx.x = max(s.pos.x + radius, maxx.x);
                maxx.y = max(s.pos.y + radius, maxx.y);
                break;
            case ShapeType.Rectangle:
                minn.x = min(s.pos.x - s.xy.x / 2, minn.x);
                minn.y = min(s.pos.y - s.xy.y / 2, minn.y);
                maxx.x = max(s.pos.x + s.xy.x / 2, maxx.x);
                maxx.y = max(s.pos.y + s.xy.y / 2, maxx.y);
                break;
            }
        }
        return [minn, maxx];
    }
}
