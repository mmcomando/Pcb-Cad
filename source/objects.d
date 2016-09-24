module objects;
import std.math : abs,PI;
import std.stdio : writeln,writefln;
import std.algorithm : remove, min, max, find, map, joiner, each;
import std.range : chain, empty, take, lockstep;

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
import shapes;

struct PadID {
    Footprint footprint;
    uint shapeNum;
}

struct ConnectionsManager {
    Connection[] connections;
    void add(Footprint footprint) {
        foreach (uint shapeNum, conName; footprint.f.shapeConnection) {
            if (conName.empty || conName == "?")
                continue;

            Connection con;
            con.name = conName;
            con.pads ~= PadID(footprint, shapeNum);
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
            bool added=false;
            Connection* conAddedIn;
            uint[] consToRemove;
            foreach (uint conIter,ref conn; connections) {
                if (conn.name != trace.connection)
                    continue;
                bool collide=false;
                foreach (pad_id; conn.pads) {
                    TrShape trShape=pad_id.footprint.f.shapes[pad_id.shapeNum];
                    if (collideUniversal(Transform(),pad_id.footprint.trf*trShape.trf,trace.polyLine,trShape.shape)) {
                        collide=true;
                        break;
                    }
                }
                if(!collide){
                    foreach (tr; conn.traces) {				
                        if (collideUniversal(Transform(),Transform(),tr.polyLine, trace.polyLine)) {
                            collide=true;
                            break;
                        }
                    }
                }
                if(collide){
                    if(!added){
                        conn.traces ~= trace;
                        conAddedIn=&conn;
                        added=true;
                    }else{
                        //merge connections
                        conAddedIn.traces~=conn.traces;
                        conAddedIn.pads~=conn.pads;
                        consToRemove~=conIter;
                    }
                }				
            }
            foreach_reverse(el;consToRemove){
                connections.removeInPlace(el);
            }
            if(added){
                return;
            }
        } else {
            foreach (ref conn; connections) {
                foreach (tr; conn.traces) {
                    if (collideUniversal(Transform(),Transform(),tr.polyLine, trace.polyLine)) {
                        conn.traces ~= trace;
                        trace.connection=conn.name;
                        trace.refreshDraw();
                        return;
                    }
                }
                foreach (pad_id; conn.pads) {
                    TrShape trShape=pad_id.footprint.f.shapes[pad_id.shapeNum];
                    if (collideUniversal(Transform(),pad_id.footprint.trf*trShape.trf,trace.polyLine,trShape.shape)) {
                        conn.traces ~= trace;
                        trace.connection=conn.name;
                        trace.refreshDraw();
                        return;
                    }
                }
            }

        }

        Connection con;
        con.name=trace.connection;
        con.traces ~= trace;
        connections ~= con;
    }

    void remove(Trace trace) {
        uint[] consToRemove;
        Connection[] consToAdd;
        foreach (conIter, ref conn; connections) {
            bool removed=conn.traces.removeElementInPlace(trace);

        }

    }

}

struct Connection {
    string name;
    PadID[] pads;
    Trace[] traces;
}

/*void addRandomConnections(PcbProject proj) {
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
}*/

void displayConnections(PcbProject proj) {
    auto getPoints(Connection* conn) {
        static vec2 getPos(T)(T a) {
            Footprint f = a.footprint;
            vec2 padPos = f.f.shapes[a.shapeNum].trf.pos;
            return rotateVector(padPos, f.trf.rot) + a.footprint.trf.pos;
        }
        auto padPoints = conn.pads.map!getPos();
        auto tracePoints = conn.traces.map!("a.polyLine.points").joiner; //.take(1)
        //padPoints.each!writeln;
        return chain(padPoints, tracePoints);

    }

    vec2[] lines;
    Connection*[][string] toConnect;
    foreach (ref conn; proj.connectionsManager.connections) {
        if (conn.name == "?")
            continue;
        toConnect[conn.name] ~= &conn;
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
                        import debuger;
                        static auto dd=Debug("debug in lines");
                        dd.init();
                        dd.ddd!"varA"(length);
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
            if (!collideUniversal(Transform(),Transform(),traceA.polyLine, traceB.polyLine)) {
                lines ~= [traceA.polyLine.points[0], traceB.polyLine.points[0]];
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
        traces ~= t;
        connectionsManager.add(t);
        t.refreshDraw();
    }

    void removeTrace(Trace trace) {
        trace.removeDraw();
        traces.removeElementInPlace(trace);
        //remove from connections
        connectionsManager.remove(trace);
    }

    void addFootprint(Footprint f) {
        footprints ~= f;
        connectionsManager.add(f);
        f.addToDraw();
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
            if (collide(Transform(),&t.polyLine, pos)) {
                return t;
            }
        }
        return null;
    }

    string collideWithConnection(Transform trf, AnyShape shape, string ignore = "") {
        writeln("traceCollideWithSomethingInProject");
        writefln("traces: %d, footprints: %d",traces.length,footprints.length);
        foreach (i,tr; traces) {
            string name = tr.connection;
            if (name == ignore) {
                continue;
            }
            //if (collideUniversal(Transform(),Transform(),trace.polyLine, tr.polyLine)) {
            if (collideUniversal(Transform(),trf,tr.polyLine, shape)) {
                writeln("colide with trace: ", name, " num: ",i);
                return name;
            }
        }
        foreach (i,ff; footprints) {
            foreach (j,name, trShape; lockstep(ff.f.shapeConnection, ff.f.shapes)) {
                //foreach (pNum, pad; ff.f.shapesRectangle) {
                //string name = ff.padConnections[pNum];
                if (name == ignore)
                    continue;
                //TrShape trShape=ff.f.shapes[pad.shapeID];
                if (collideUniversal(trf,trShape.trf*ff.trf,shape,trShape.shape)) {
                    writefln("colide with %s  pad(%s): %s", i,j, name);
                    return name;
                }
            }
        }
        return "";
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
class RemoveTrace : Action {
    PcbProject project;
    Trace trace;
    this(PcbProject project, Trace tr) {
        this.project = project;
        trace = tr;
    }

    void doAction() {
        project.removeTrace(trace);
    }
    
    void undoAction() {
        project.addTrace(trace);
    }    
}
class AddTrace : Action {
    PcbProject project;
    Trace trace;
    this(PcbProject project, Trace tr) {
        this.project = project;
        trace = tr;
    }
    
    void doAction() {
        project.addTrace(trace);
    }
    
    void undoAction() {
        project.removeTrace(trace);
    }    
}

class Trace {
    string connection;
    PolyLine polyLine;
    Something rendPoints;
    Circles rendWheels;
    Text[] texts;
    this(float traceWidth) {
        this.polyLine.traceWidth = traceWidth;
    }
    void initDraw() {
        Triangle[] trianglePoints = polyLine.getTriangles();
        Circles.CircleData[] metas;
        foreach (p; polyLine.points) {
            metas ~= Circles.CircleData(vec3(1, 0, 0), p, polyLine.traceWidth / 2);
        }
        vec2 last_point=polyLine.points[0];
        foreach (p; polyLine.points[1..$]) {
            Text txt=Text.fromString(connection);
            vec2 pointsDt=p-last_point;
            float scale=polyLine.traceWidth*0.5;
            float rot=vectorToAngle(pointsDt);
            if(abs(rot)>PI/2){
                rot+=PI;
            }
            vec2 textSize=Text.getTextSize(connection)*scale/2;
            if(textSize.length<pointsDt.length){
                vec2 textDt=textSize/2;
                textDt=rotateVector(vec2(textDt.x,0),rot);
                txt.trf.pos=(last_point+p)/2-textDt;
                txt.trf.rot=rot;
                txt.trf.scale=scale;
                texts~=txt;
            }
            last_point=p;
        }
        rendWheels = Circles.addCircles(metas, true);
        rendWheels.trf.pos = vec2(0, 0);
        rendPoints = Something.fromPoints(trianglePoints);
        rendPoints.trf.pos = vec2(0, 0);
        rendPoints.color = vec3(1, 0, 0);
        rendPoints.mode = GL_TRIANGLES;
    }
    void removeDraw(){
        if(rendPoints !is null){
            Something.remove(rendPoints);
            Circles.remove(rendWheels);
            foreach(t;texts)Text.removeText(t);
            texts.length=0;
            rendPoints=null;
            rendWheels=null;
        }
    }
    void refreshDraw(){
        removeDraw();
        initDraw();
    }

    void addToDraw(RenderList list) {
        list.add(rendPoints, Priority(18));
        list.add(rendWheels, Priority(18));
        foreach(t;texts)list.add(t, Priority(19));
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

//TODO event system?? move->event->move rendering??
class Footprint {
    static FootprintRenderer rend;
    FootprintRenderer.Data rendData;
    FootprintData f;
    Transform _trf;
    string name;
    // string[] padConnections;

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
        //rendData = rend.addFootprint(this);
        //padConnections.length = f.pads.length;
        // foreach (i, ref p; padConnections)
        //    p = f.pads[i].connection;
    }
    void addToDraw() {
        rendData = rend.addFootprint(this);
        rendData.trf=_trf;
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





// Remove pad completely?? use traces, shapes, itd with some ID??
struct Pad {
    string connection;
    uint shapeID;
}

struct TrShape {
    AnyShape shape;
    Transform trf;
}
struct TrCircle {
    Transform trf;
    Circle circle;
}
struct TrRectangle {
    Transform trf;
    Rectangle rectangle;
}



class FootprintData {
    string name;
    // Pad[] pads;

    //shapes
    TrShape[] shapes;
    //and theirs connection (array indexes had to match)
    string[] shapeConnection;

    vec2[2][] lines;
    vec2[] snapPoints;
    vec2[2] boundingBox;
    this() {
    }
    void addShape(TrShape trShape,string connection){
        shapes~=trShape;
        shapeConnection~=connection;
        assert(shapes.length==shapeConnection.length);
    }

    
    this(FootprintData f) {
        name = f.name;
        shapes = f.shapes.dup;
        shapeConnection = f.shapeConnection.dup;
        lines = f.lines.dup;
        boundingBox = f.boundingBox;
        snapPoints = f.snapPoints;
    }

    vec2[2] computeBoundingBox() const {
        vec2 minn;
        vec2 maxx;
        if (lines.length) {
            minn = lines[0][0];
        } else if (shapes.length) {
            minn = shapes[0].trf.pos;
        } else {
            minn = vec2(0, 0);
        }
        maxx = minn + vec2(0.00001, 0.00001);
       
        foreach (l; lines) {
            minn.x = min(l[0].x, l[1].x, minn.x);
            minn.y = min(l[0].y, l[1].y, minn.y);
            maxx.x = max(l[0].x, l[1].x, maxx.x);
            maxx.y = max(l[0].y, l[1].y, maxx.y);
        }
        
        foreach (s; shapes) {
            AnyShape anyShape=s.shape;
            Triangle[] tris=anyShape.getTriangles();
            foreach(tr;tris){
                foreach(point;tr.tupleof){
                    vec2 p=s.trf.pos+point;
                    minn.y = min(p.y, minn.y);
                    maxx.x = max(p.x, maxx.x);
                }
            }
        }
        return [minn, maxx];
    }
}
