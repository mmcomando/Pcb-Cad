module project_actions;

import std.math : PI_4, sqrt;
import std.stdio : writeln;
import std.algorithm : find;
import std.array : empty;
import std.range : lockstep;
import gl3n.linalg;

import derelict.opengl3.gl3;

import engine;
import objects;
import action;
import utils;
import engine.renderer;
import engine.window;
import gui_data;
import drawables;
import shapes;

Trace tmpTrace;

Trace[] traces;

bool snapEnabled = true;
Footprint grabbed;
Something traceRend;
float traceWidth = 0.001;

vec2 grabbedDT;
void update(PcbProject proj, vec2 globalMousePos) {
	if (tmpTrace !is null) {
		tmpTrace.polyLine.traceWidth=traceWidth;
	}
    snapEnabled = true;
    if (grabbed !is null || tmpTrace !is null)
        snapEnabled = false;
    try {
        addFootprint(proj, globalMousePos);
		addTraceDifferent(proj, globalMousePos);
		//addTrace(proj, globalMousePos);
		//addTraceSimple(proj, globalMousePos);
    }
    catch (Exception e) {
        writeln("Exception message: ", e.msg);
    }
    updateTrace(proj, globalMousePos);
}

void updateTrace(PcbProject proj, vec2 globalMousePos) {
    if (gameEngine.window.keyPressed('r'))
        if (Trace t = proj.getTrace(globalMousePos)) {
            proj.actions.add(new RemoveTrace(proj,t));
        }

}

void addFootprint(PcbProject proj, vec2 globalMousePos) {
    static Transform before;
    if (grabbed !is null) {
		Transform tmp=grabbed.trf;
		tmp.pos=globalMousePos + grabbedDT;
		grabbed.trf=tmp;
        if (gameEngine.window.mouseButtonReleased(MouseButton.left) || gameEngine.window.keyPressed('m')) {
            proj.actions.add(new TransformFootprint(grabbed, before, grabbed.trf));
            grabbed = null;
        }
    } else {
        if (Footprint f = proj.getFootprint(globalMousePos)) {
            if (gameEngine.window.mouseButtonPressed(MouseButton.left) || gameEngine.window.keyPressed('m')) {
                grabbedDT = f.trf.pos - globalMousePos;
                before = f.trf;
                grabbed = f;
            } else if (gameEngine.window.keyPressed('r')) {
                //removeFootprint(i);
                proj.actions.add(new RemoveFootprint(proj, f));
            } else if (gameEngine.window.keyPressed('t')) {
				Transform after=f.trf;
				after.rot+=PI_4;
                proj.actions.add(new TransformFootprint(f, f.trf, after));
            }
        }

    }

    if (gameEngine.window.keyPressed('i')) {
        foreach (library; proj.footprintsLibraries) {
            auto footprints = library.footprints;
            auto ff = footprints.find!("a.name==b")(guiData.selectedFootprint);
            if (ff.length > 0) {
                Footprint f = new Footprint(ff[0]);
                //footprints ~= f;
				Transform tmp=f.trf;
				tmp.pos=globalMousePos;
                f.trf = tmp;
                proj.addFootprint(f);
                grabbed = f;
                grabbedDT = vec2(0, 0);
            }
        }

    }
}
/// Moves last point in trace
void addTraceSimple(PcbProject proj, vec2 globalMousePos) {
	if (tmpTrace is null) {
		if (gameEngine.window.keyPressed('l')) {
			tmpTrace = new Trace(traceWidth);
			tmpTrace.polyLine.points ~= globalMousePos;
			tmpTrace.polyLine.points ~= globalMousePos + vec2(0.01, 0.05);
			AnyShape sh;
			sh.set(tmpTrace.polyLine);
			string connName = proj.collideWithConnection(Transform(), sh);
			if (!connName.empty) {
				tmpTrace.connection = connName;
			}
			writeln("My name is: ", tmpTrace.connection);
		}
	} else {
		auto tmpTrace=&tmpTrace.polyLine;
		if (gameEngine.window.keyPressed('l')) {
			tmpTrace.points ~= globalMousePos;
		}
		tmpTrace.points[$ - 1] = globalMousePos;

	}
	if (gameEngine.window.keyPressed(Key.esc) && tmpTrace !is null) {
		if (traceRend !is null) {
			Something.remove(traceRend);
			traceRend = null;
		}
		tmpTrace = null;
	}
}
/// Moves last point in trace angles 45
void addTrace(PcbProject proj, vec2 globalMousePos) {
    if (tmpTrace is null) {
        if (gameEngine.window.keyPressed('l')) {
            tmpTrace = new Trace(traceWidth);
            tmpTrace.polyLine.points ~= globalMousePos;
            tmpTrace.polyLine.points ~= globalMousePos + vec2(0.01, 0.05);
			AnyShape sh;
			sh.set(tmpTrace.polyLine);
            string connName = proj.collideWithConnection(Transform(), sh);
            if (!connName.empty) {
                tmpTrace.connection = connName;
            }
            writeln("My name is: ", tmpTrace.connection);
        }
    } else {
		auto tmpTrace=&tmpTrace.polyLine;
        if (gameEngine.window.keyPressed('l')) {
            tmpTrace.points ~= globalMousePos;
        }
        import std.math : sqrt, abs;

        vec2 dt = globalMousePos - tmpTrace.points[$ - 2];
        float tg = sqrt((dt.y * dt.y) / (dt.x * dt.x));
        if (tg < 0.3773) {
            tmpTrace.points[$ - 1].x = globalMousePos.x;
            tmpTrace.points[$ - 1].y = tmpTrace.points[$ - 2].y;
        } else if (tg > 2.7320) {
            tmpTrace.points[$ - 1].y = globalMousePos.y;
            tmpTrace.points[$ - 1].x = tmpTrace.points[$ - 2].x;
        } else {
            float len = dt.length * 0.7;
            if (len > 0) {
                tmpTrace.points[$ - 1].x = tmpTrace.points[$ - 2].x + dt.x / abs(dt.x) * len;
                tmpTrace.points[$ - 1].y = tmpTrace.points[$ - 2].y + dt.y / abs(dt.y) * len;
            }
        }
        if (tmpTrace.points[$ - 1].x == float.nan)
            assert(0);
        //tmpTrace.draw();
    }
    if (tmpTrace !is null) {
		AnyShape sh;
		sh.set(tmpTrace.polyLine);
		string connName = proj.collideWithConnection(Transform(), sh,tmpTrace.connection);
        writeln(tmpTrace.connection, " vs ", connName);

        if (gameEngine.window.keyPressed('k') && tmpTrace !is null) {

            if (connName.empty || connName == tmpTrace.connection) {
                proj.actions.add(new AddTrace(proj,tmpTrace));
                writeln("added: ", tmpTrace.connection);
                tmpTrace = null;
            }
        }
    }
    if (gameEngine.window.keyPressed(Key.esc) && tmpTrace !is null) {
        if (traceRend !is null) {
            Something.remove(traceRend);
            traceRend = null;
        }
        tmpTrace = null;
    }
}

/// Moves last two points in trace
void addTraceDifferent(PcbProject proj, vec2 globalMousePos) {
    static bool normal;
    if (tmpTrace is null) {
        if (gameEngine.window.keyPressed('l')) {
            normal = true;
            tmpTrace = new Trace(traceWidth);
            tmpTrace.polyLine.points ~= globalMousePos;
			tmpTrace.polyLine.points ~= globalMousePos + vec2(0.00, 0.05) * 0.001;
            tmpTrace.polyLine.points ~= globalMousePos + vec2(0.01, 0.05) * 0.002;
			AnyShape sh;
			sh.set(tmpTrace.polyLine);
			string connName = proj.collideWithConnection(Transform(), sh);
            if (!connName.empty) {
                tmpTrace.connection = connName;
            }
            writeln("My name is: ", tmpTrace.connection);
        }
    } else {
		auto tmpTrace=&tmpTrace.polyLine;
        if (gameEngine.window.keyPressed('j'))
            normal = !normal;
        if (gameEngine.window.keyPressed('l')) {
            tmpTrace.points ~= globalMousePos;
            vec2 dt02 = tmpTrace.points[$ - 3] - tmpTrace.points[$ - 1];
            float tg01 = sqrt((dt02.y * dt02.y) / (dt02.x * dt02.x));
            if (tg01 < 0.3773 || tg01 > 2.7320) { //90 degree
                normal = true;
            } else {
                normal = false;
            }
        }
        //vertices [0,1,2],edit vertices 1 and 2 
        import std.math : sqrt, abs;

        tmpTrace.points[$ - 1] = globalMousePos;

        vec2 dt02 = tmpTrace.points[$ - 3] - tmpTrace.points[$ - 1];
        vec2 absVec = vec2(abs(dt02.x), abs(dt02.y));
        vec2 signVec = vec2(dt02.x / absVec.x, dt02.y / absVec.y);
        if (normal) {
            if (absVec.x < absVec.y) {
                tmpTrace.points[$ - 2] = vec2(tmpTrace.points[$ - 1].x + dt02.x,
                    tmpTrace.points[$ - 1].y + absVec.x * signVec.y);
            } else {
                tmpTrace.points[$ - 2] = vec2(tmpTrace.points[$ - 1].x + absVec.y * signVec.x,
                    tmpTrace.points[$ - 1].y + dt02.y);
            }
        } else { //45 degree
            if (absVec.x < absVec.y) {
                tmpTrace.points[$ - 2] = vec2(tmpTrace.points[$ - 3].x - dt02.x,
                    tmpTrace.points[$ - 3].y - absVec.x * signVec.y);
            } else {
                tmpTrace.points[$ - 2] = vec2(tmpTrace.points[$ - 3].x - absVec.y * signVec.x,
                    tmpTrace.points[$ - 3].y - dt02.y);
            }
        }
    }

    if (gameEngine.window.keyPressed('k') && tmpTrace !is null) {
		
		AnyShape sh;
		sh.set(tmpTrace.polyLine);
		string connName = proj.collideWithConnection(Transform(), sh,tmpTrace.connection);
		writeln(tmpTrace.connection, " vs ", connName);
		if (tmpTrace.connection.empty|| connName.empty || connName == tmpTrace.connection) {
            proj.actions.add(new AddTrace(proj,tmpTrace));
            writeln("added: ", tmpTrace.connection);
            tmpTrace = null;
        }
    }

    if (gameEngine.window.keyPressed(Key.esc) && tmpTrace !is null) {
        if (traceRend !is null) {
            Something.remove(traceRend);
            traceRend = null;
        }
        tmpTrace = null;
    }
}

bool snap(PcbProject proj, vec2 mousePos, ref vec2 newMousePos, ref float minLength) {
    vec2 nearestSnapPoint;
    float shortestLength = float.max;
    bool snaped = false;
    foreach (p; proj.getSnapPoints) { //quadtree
        vec2 dt = p - mousePos;
        float len2 = dt.x * dt.x + dt.y * dt.y;
        if (len2 < 1 * 1 && len2 < shortestLength && len2 < minLength) {
            shortestLength = len2;
            nearestSnapPoint = p;
            snaped = true;
        }
    }
    if (snaped) {
        newMousePos = nearestSnapPoint;
        minLength = shortestLength;
        return true;
    }
    return false;
}

void snapMouse(PcbProject proj, vec2 globalMousePos) {
    vec2 nearestSnapPoint;
    float shortestLength = float.max;
    bool snaped = false;
    foreach (p; proj.getSnapPoints) { //quadtree
        vec2 dt = p - globalMousePos;
        float len2 = dt.x * dt.x + dt.y * dt.y;
        if (len2 < 1 * 1 && len2 < shortestLength) {
            shortestLength = len2;
            nearestSnapPoint = p;
            snaped = true;
        }
    }
    if (snaped) {
        vec2i newMousePos = gameEngine.renderer.camera.globalToCamera(nearestSnapPoint);
        gameEngine.window.mousePos = vec2i(newMousePos);
    }
}

void drawTmpTrace(Trace tmpTrace,Something traceRend) {
    if (tmpTrace !is null) {
		tmpTrace.refreshDraw();
		tmpTrace.addToDraw(gameEngine.renderer.renderList);
        /*if (traceRend !is null)
            Something.remove(traceRend);
        traceRend = Something.fromPoints(tmpTrace.polyLine.getTriangles);
		traceRend.trf.pos = vec2(0, 0);
        traceRend.color = vec3(1, 0, 0);
        traceRend.mode = GL_TRIANGLES;
        gameEngine.renderer.renderList.add(traceRend, Priority(10));*/
    }
}
