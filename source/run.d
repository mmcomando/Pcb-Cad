module run;

import core.memory;
import std.stdio : writeln, writefln;
import std.format:format;
import std.algorithm : min,max;

import gl3n.linalg;

import engine;
import engine.window;
import engine.renderer;

import utils;
import pcb_project;
import gui_data;
import project_actions;
import drawables;
import connections_manager;

import debuger;

bool initialized = false;
PcbProject project;
Renderer renderer;
Circles cursor;
DynamicText debugText;
void initProject(){

    project = new PcbProject;
    project.name = "test";
    try {
        project.footprintsLibraries ~= new FootprintsLibrary("libcms.mod");
        //project.footprintsLibraries~=new FootprintsLibrary("sockets.mod");//TODO won't load, fix kicad_loader
        //project.footprintsLibraries~=new FootprintsLibrary("connect.mod");
    }
    catch (Exception e) {
        printException(e);
    }
    int perRow = 16;
    int i = 0;
    foreach (ii; 0 .. 1)
    foreach (lib; project.footprintsLibraries) {
        foreach (libF; lib.footprints[0..$]) {
            Footprint f = new Footprint(libF);
            project.addFootprint(f);
            f.trf =Transform( vec2(i % perRow, i / perRow) * 0.04,0,1);
            i++;
        }
    }
}
void init() {
	renderer = gameEngine.renderer;
	renderer.init();
	Something.init();
	Circles.init();
	Text.init();

	debugText = new DynamicText(100);
	debugText.trf=Transform(vec2(20,-20),0,10);
	debugText.color=vec3(0,0,0);

	cursor = Circles.addCircles([Circles.CircleData(vec3(1, 0, 0), vec2(0, 0), 1)], true);
	cursor.trf.pos = vec2(0, 0);
	cursor.trf.scale = 0.0001;

    initProject();

	GC.disable();
}
void handleInput(){
    gameEngine.globalMousePos = renderer.camera.cameraToGlobal(gameEngine.window.mousePos);
    vec2 snapPoint = gameEngine.globalMousePos;
    // -- Snap support
    if (snapEnabled) {
        float minLength = 1;
        project.snap(gameEngine.globalMousePos, snapPoint, minLength);
        project.grid.snapPos(gameEngine.globalMousePos, snapPoint, minLength);
        cursor.trf.pos = snapPoint;
        cursor.trf.scale=0.5/renderer.camera.zoom;
    }
    
    float camPosDelta = gameEngine.dtf * 100 / renderer.camera.zoom;
    float camZoomSpeed = 1 + gameEngine.dtf * 5;
    if (gameEngine.window.keyDown('w'))
        renderer.camera.pos.y += camPosDelta;
    if (gameEngine.window.keyDown('s'))
        renderer.camera.pos.y -= camPosDelta;
    if (gameEngine.window.keyDown('a'))
        renderer.camera.pos.x -= camPosDelta;
    if (gameEngine.window.keyDown('d'))
        renderer.camera.pos.x += camPosDelta;
    
    if (gameEngine.window.keyDown('q'))
        renderer.camera.zoom *= camZoomSpeed;
    if (gameEngine.window.keyDown('e'))
        renderer.camera.zoom /= camZoomSpeed;
    // -- Zoom with mouse
    int wheelY = gameEngine.window.mouseWheel.y;
    if (wheelY > 0) {
        renderer.camera.zoom *= 1.5 * wheelY;
        vec2 newMousePos = renderer.camera.cameraToGlobal(gameEngine.window.mousePos);
        vec2 dt = gameEngine.globalMousePos - newMousePos;
        renderer.camera.pos += dt;
    } else if (wheelY < 0) {
        renderer.camera.zoom /= 1.5 * wheelY * -1;
        vec2 newMousePos = renderer.camera.cameraToGlobal(gameEngine.window.mousePos);
        vec2 dt = gameEngine.globalMousePos - newMousePos;
        renderer.camera.pos += dt;
    }
    
    if (gameEngine.window.keyPressed('o'))
        snapEnabled = !snapEnabled;
    
    
    project.update(snapPoint);//Add,delete footprint. Add,delete trace
    if (gameEngine.window.keyDown('=')) {
        traceWidth = min(0.01,traceWidth+camZoomSpeed / 4000) ;
        project.grid.size = vec2(1,1)*traceWidth;
    }
    if (gameEngine.window.keyDown('-')) {
        traceWidth = max(0.00001,traceWidth-camZoomSpeed / 4000) ;
        project.grid.size = vec2(1,1)*traceWidth;
    }
    
    // -- Back support
    if (gameEngine.window.keyPressed('z') && gameEngine.window.keyDown(Key.ctrl)) {
        if (gameEngine.window.keyDown(Key.shift)) {
            project.actions.forward();
        } else {
            project.actions.back();
        }
    }
    if ( gameEngine.window.keyDown(Key.shift)) writeln("ztrl");
    
    // -- Grab support
    {
        static vec2 grabPoint;
        static bool mouseGrab = false;
        if (gameEngine.window.mouseButtonPressed(MouseButton.middle)) {
            grabPoint = gameEngine.globalMousePos;
            mouseGrab = true;
        }
        if (gameEngine.window.mouseButtonReleased(MouseButton.middle)) {
            mouseGrab = false;
        }
        if (mouseGrab) {
            vec2 dt = renderer.camera.cameraToGlobal(gameEngine.window.size / 2) - gameEngine.globalMousePos;
            gameEngine.renderer.camera.pos = grabPoint + dt;
        }
    }
}
bool snapEnabled = false;
void run() {
	if (initialized == false) {
		init();
		initialized = true;
		gameEngine.window.setTitle("");
	}
	
    handleInput();
	
	{
		string sss = format("fps: %8.2f  %4.2fms %4.2fms\nx: %10.5f\ny: %10.5f",
			gameEngine.fps,gameEngine.minTime * 1000, gameEngine.maxTime * 1000,gameEngine.globalMousePos.x,gameEngine.globalMousePos.y);
		debugText.set(sss);
	}
    displayConnections(project);
	Footprint.rend.addToDraw(renderer.renderList);
	drawTmpTrace(tmpTrace,traceRend);
	project.grid.addToDraw(renderer.renderList);
	renderer.renderList.add(cursor, Priority(250));
	renderer.guiRenderList.add(debugText, Priority(251));
    foreach (tr; project.traces)
        tr.addToDraw(renderer.renderList);
    foreach (sm; somethingAutoRender)
        renderer.renderList.add(sm, Priority(200));
	renderer.draw();
	drawDebug();
	debugResetAll();
}


void drawDebug(){


	static Text[] texts;
	//DynamicText dText;
	static Something[] soms;
	foreach(s;soms){
		Something.remove(s);
	}
	soms.length=0;
	foreach(t;texts){
		Text.removeText(t);
	}
	texts.length=0;



	/*if (tmpTrace !is null) {
		if (traceRend !is null)
		traceRend = Something.fromPoints(tmpTrace.polyLine.getTriangles);
		traceRend.trf.pos = vec2(0, 0);
		traceRend.color = vec3(1, 0, 0);
		traceRend.mode = GL_TRIANGLES;
		gameEngine.renderer.renderList.add(traceRend, Priority(10));
	}*/

	/*recDrawA=somShapeA.toDrawable();
	recDrawB=somShapeB.toDrawable();
	recDrawB.color=vec3(1,0,1);
	recDrawA.color=vec3(0,0,1);*/
	int hh=-20;
	void addText(string str){
		Text tt=Text.fromString(str);
		tt.trf=Transform(vec2(400,hh),0,10);
		tt.color=vec3(1,0,1);
		renderer.guiRenderList.add(tt, Priority(251));
		texts~=tt;
		hh-=20;
	}
	/*synchronized(debugSynchronization){
		foreach(DebugRoot[]* rootsLocal;globalRoots){
			foreach(ref DebugRoot root;*rootsLocal){
				bool draw=false;
				foreach(Container* con;root.getter.get()){
					foreach(iii,ref ReusingArray arr;con.arr){
						draw=draw || arr.get!(float).length>0;
					}
				}
				if(draw){
					addText(root.rootName);
					foreach(Container* con;root.getter.get()){
						addText(con.name);
						foreach(iii,ref ReusingArray arr;con.arr){
							if(arr.get!(float).length>0){
								addText(arr.get!(float).length.to!string);
								//addText(arr.get!(float).to!string);

							}
							//write(iii," ");
							//writeln(arr.get!int());
						}
					}
				}
			}
		}
	}*/
}