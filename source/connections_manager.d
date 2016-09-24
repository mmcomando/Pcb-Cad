module connections_manager;

import pcb_project;
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
struct Connection {
    string name;
    ShapeID[] shapes;
    Trace[] traces;
}
struct ShapeID {
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
            con.shapes ~= ShapeID(footprint, shapeNum);
            connections ~= con;
        }
    }
    
    void remove(Footprint footprint) {
        foreach (kk, ref conns; connections) {
            foreach_reverse (i, shape_id; conns.shapes) {
                if (shape_id.footprint == footprint) {
                    conns.shapes = conns.shapes.remove(i);
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
                foreach (shape_id; conn.shapes) {
                    TrShape trShape=shape_id.footprint.f.shapes[shape_id.shapeNum];
                    if (collideUniversal(Transform(),shape_id.footprint.trf*trShape.trf,trace.polyLine,trShape.shape)) {
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
                        conAddedIn.shapes~=conn.shapes;
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
                foreach (shape_id; conn.shapes) {
                    TrShape trShape=shape_id.footprint.f.shapes[shape_id.shapeNum];
                    if (collideUniversal(Transform(),shape_id.footprint.trf*trShape.trf,trace.polyLine,trShape.shape)) {
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
        foreach (uint conIter, ref conn; connections) {
            bool removed=conn.traces.removeElementInPlace(trace);
            if(removed){
                Connection[] cons=checkConnectionUnity(conn);
                if(cons !is null){
                    consToRemove~=conIter;
                    consToAdd~=cons;
                }
            }
        }
        foreach_reverse(num;consToRemove){
            connections.removeInPlace(num);
        }
        connections~=consToAdd;
        
    }
    Connection[] checkConnectionUnity(Connection connection){
        struct Group{
            uint[] traces;
            uint[] shapes;
        }
        Group[] groups;
        bool collideWithGroupTrace(Group con,uint traceNum){
            Trace trace=connection.traces[traceNum];
            foreach (num; con.traces) {
                Trace tr=connection.traces[num];
                if (collideUniversal(Transform(),Transform(),tr.polyLine, trace.polyLine)) {
                    return  true;
                }
            }
            foreach (num; con.shapes) {
                ShapeID shape_id=connection.shapes[num];
                TrShape trShape=shape_id.footprint.f.shapes[shape_id.shapeNum];
                if (collideUniversal(Transform(),shape_id.footprint.trf*trShape.trf,trace.polyLine,trShape.shape)) {
                    return true;
                }
            }
            return false;
        }
        bool collideWithGroupShape(Group con,uint shapeNum){
            ShapeID shape_id_tmp=connection.shapes[shapeNum];
            TrShape shape=shape_id_tmp.footprint.f.shapes[shape_id_tmp.shapeNum];
            Transform shapeTrf=shape_id_tmp.footprint.trf*shape.trf;
            foreach (num; con.traces) {
                Trace tr=connection.traces[num];
                if (collideUniversal(Transform(),shapeTrf,tr.polyLine, shape.shape)) {
                    return  true;
                }
            }
            foreach (num; con.shapes) {
                ShapeID shape_id=connection.shapes[num];
                TrShape trShape=shape_id.footprint.f.shapes[shape_id.shapeNum];
                if (collideUniversal(shapeTrf,shape_id.footprint.trf*trShape.trf,shape.shape,trShape.shape)) {
                    return true;
                }
            }
            return false;
        }
        //traces 
        foreach(uint traceNum,trace;connection.traces){
            uint[] collideWithGroups;
            foreach(uint i,group;groups){
                if(collideWithGroupTrace(group,traceNum)){
                    collideWithGroups~=i;
                }
            }
            if(collideWithGroups.length==0){
                Group newGroup;
                newGroup.traces~=traceNum;
                groups~=newGroup;
            }else{
                Group* firstGroup=&groups[collideWithGroups[0]];
                firstGroup.traces~=traceNum;
                foreach_reverse(groupNum;collideWithGroups[1..$]){
                    Group group=groups[groupNum];
                    firstGroup.traces~=group.traces;
                    firstGroup.shapes~=group.shapes;
                    groups.removeInPlace(groupNum);                    
                }
            }
        }
        //pads
        foreach(uint padNum,trace;connection.shapes){
            uint[] collideWithGroups;
            foreach(uint i,group;groups){
                if(collideWithGroupShape(group,padNum)){
                    collideWithGroups~=i;
                }
            }
            if(collideWithGroups.length==0){
                Group newGroup;
                newGroup.shapes~=padNum;
                groups~=newGroup;
            }else{
                Group* firstGroup=&groups[collideWithGroups[0]];
                firstGroup.shapes~=padNum;
                foreach_reverse(groupNum;collideWithGroups[1..$]){
                    Group group=groups[groupNum];
                    firstGroup.traces~=group.traces;
                    firstGroup.shapes~=group.shapes;
                    groups.removeInPlace(groupNum);                    
                }
            }
        }
        Connection[] cons_return;
        foreach(group;groups){
            Connection con;
            con.name=connection.name;
            foreach(num;group.traces){
                con.traces~=connection.traces[num];
            }
            foreach(num;group.shapes){
                con.shapes~=connection.shapes[num];
            }
            cons_return~=con;
        }
        
        return cons_return;
    }
    
}


void displayConnections(PcbProject proj) {
    auto getPoints(Connection* conn) {
        static vec2 getPos(T)(T a) {
            Footprint f = a.footprint;
            vec2 padPos = f.f.shapes[a.shapeNum].trf.pos;
            return rotateVector(padPos, f.trf.rot) + a.footprint.trf.pos;
        }
        auto padPoints = conn.shapes.map!getPos();
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
