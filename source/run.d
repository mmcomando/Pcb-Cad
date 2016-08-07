module run;

import core.memory;
import std.stdio : writeln, writefln;
import std.algorithm : min,max;
import std.random:uniform;
import std.math:sqrt;

import gl3n.linalg;
import derelict.opengl3.gl3;

import engine;
import engine.window;
import engine.renderer;

import utils;
import objects;
import gui_data;
import project_actions;
import shaders;
import drawables;
import sect_dist;
import shapes:AnyShape,test,Rectangle,collide,CircleAny=Circle,PolyLine,smallestEnclosingCircle,CC;

bool initialized = false;
PcbProject project;
Renderer renderer;
Circles centralCircle;
Circles cursor;
Text testText;
DynamicText dText;
Something recDrawA,recDrawB;
//ectangle recA,recB;
bool isColliding=false;

AnyShape somShapeA,somShapeB;
Something somDraw;
//TODO :
//shapes <- very importatnt :/
// connection nets from string to uint ID

vec2[] pps;
Circles.CircleData[] ccc;
void init() {

	renderer = gameEngine.renderer;
	renderer.init();
	SomethingProgram.init();
	TextProgram.init();
	CirclesInstancedProgram.init();
	Something.init();
	Circles.init();
	Text.init();
	dText = new DynamicText(100);
	dText.trf=Transform(vec2(20,-20),0,10);
	dText.color=vec3(0,0,0);

	testText = Text.fromString("adfghALSJIDb asdasud7asud,a896412';][;/.\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';\nSJIDb asdasud7asud,a896412';");
	testText.trf.pos=vec2(0,0);
	project = new PcbProject;
	cursor = Circles.addCircles([Circles.CircleData(vec3(1, 0, 0), vec2(0, 0), 1)], true);
	cursor.trf.pos = vec2(0, 0);
	cursor.trf.scale = 0.0001;

	uint num = 7;
	float n = num;
	ccc.reserve(num);
	foreach (i; 0 .. num) {
		ccc ~= Circles.CircleData(vec3((i + 1) / n, 0, 0), vec2(2 * (i + 1) / n, 0), 2);
	}
	foreach(o;0..150){
		pps~=vec2(uniform(0,50),uniform(0,50))*0.0001;
	}
	foreach (p; pps) {
		ccc ~= Circles.CircleData(vec3(0.7,0.2,0.7), p, 0.0001);
	}
	CC c=smallestEnclosingCircle(pps);
	ccc ~= Circles.CircleData(vec3(1,0.1,0.3), c.pos, sqrt(c.r));

	centralCircle = Circles.addCircles(ccc);
	centralCircle.trf.pos = vec2(0, 0);


	test();
	PolyLine traceA,traceB;
	traceA.traceWidth=traceB.traceWidth=0.001;
	traceA.points~=vec2(0.000,0.000);
	traceA.points~=vec2(0.01,0.000);
	traceA.points~=vec2(0.01,0.01);

	traceB.points~=vec2(0.000,0.000);
	traceB.points~=vec2(0.01,0.01);
	traceB.points~=vec2(0.01,0.02);
	//somShapeA.set(Rectangle(vec2(0.004,0.004)));
	//somShapeB.set(Rectangle(vec2(0.02,0.02)));
	somShapeA.set(traceA);
	somShapeB.set(traceB);
	recDrawA=somShapeA.toDrawable();
	recDrawB=somShapeB.toDrawable();
	recDrawB.color=vec3(1,0,1);
	recDrawA.color=vec3(0,0,1);
	writeln(recDrawA);


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

	GC.disable();


}

bool snapEnabled = false;
void run() {
	if (initialized == false) {
		init();
		initialized = true;
	}
	auto renderer = gameEngine.renderer;
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

	if (gameEngine.window.keyPressed('f'))
		writefln("%5.3f (%5.2fms, %5.2fms)", gameEngine.fps, gameEngine.minTime * 1000, gameEngine.maxTime * 1000);

	if (gameEngine.window.keyPressed('o'))
		snapEnabled = !snapEnabled;

	// -- Add,delete footprint. Add,delete trace
	project.update(snapPoint);
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
	static int num=3;
	void xxx(){
		if(num==pps.length){
			num=3;
		}
		Circles.remove(centralCircle);
		ccc.length=0;
		foreach (p; pps[0..num]) {
		//	ccc ~= Circles.CircleData(vec3(0.7,0.2,0.7), p, 0.0001);
		}
		CC c=smallestEnclosingCircle(pps[0..num]);
		ccc ~= Circles.CircleData(vec3(1,0.1,0.3), c.pos, sqrt(c.r));
		//CC x1=somShapeA.getBoundingCircle();
		//CC x2=somShapeB.getBoundingCircle();
		//ccc ~= Circles.CircleData(vec3(0.5,0.1,0.3), x1.pos, sqrt(x1.r));
		//ccc ~= Circles.CircleData(vec3(0,0.1,0.3), x2.pos, sqrt(x2.r));
		//ccc ~= Circles.CircleData(vec3(1,0.1,0.3), c.pos, sqrt(c.r));
		centralCircle = Circles.addCircles(ccc);
		centralCircle.trf.pos = vec2(0, 0);
		num++;
	}
	/*if (gameEngine.window.keyPressed(';')){
		pps.length=0;
		foreach(o;0..15){
			pps~=vec2(uniform(0,50),uniform(0,50))*0.0001;
		}
		num=14;
		xxx();
	}
	if (gameEngine.window.keyPressed('f')){
		xxx();
	}
	if (gameEngine.window.keyPressed('g')){
		num=max(num-2,3);

		xxx();
	}
	if(tmpTrace !is null && tmpTrace.polyLine.points.length>2){
		pps.length=0;//tmpTrace.polyLine.points.length;
		foreach(p;tmpTrace.polyLine.points){
			pps~=vec2(p);
		}
		num=cast(uint)(tmpTrace.polyLine.points.length-1);
		xxx();
	}*/
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
	if (gameEngine.window.keyPressed('b'))recDrawA.trf.rot+=3.141541/8;
	if (gameEngine.window.keyPressed('n'))recDrawB.trf.rot+=3.141541/8;
	//isColliding=collide(recDrawA.trf,recDrawB.trf,&recA,&recB);
	//if(collide(recDrawA.trf,&recA,gameEngine.globalMousePos)){
	isColliding=collide(recDrawA.trf,recDrawB.trf,&somShapeA,&somShapeB);
	//isColliding=collide(recDrawA.trf,&somShapeA,gameEngine.globalMousePos);
	if(collide(recDrawA.trf,&somShapeA,gameEngine.globalMousePos)){
		if(gameEngine.window.mouseButtonDown(MouseButton.right)){
			recDrawA.trf.pos=gameEngine.globalMousePos;
		}
	}
	{
		import std.conv;
		import std.format;
		string sss = format("fps: %8.2f  %4.2fms %4.2fms\nx: %10.5f\ny: %10.5f\ncollide: %s",
			gameEngine.fps,gameEngine.minTime * 1000, gameEngine.maxTime * 1000,gameEngine.globalMousePos.x,gameEngine.globalMousePos.y,isColliding);
		dText.set(sss);
	}

	displayConnections(project);
	Footprint.rend.addToDraw(renderer.renderList);
	drawTmpTrace(tmpTrace,traceRend);
	project.grid.addToDraw(renderer.renderList);
	foreach (tr; project.traces)
		tr.addToDraw(renderer.renderList);
	renderer.renderList.add(centralCircle, Priority(250));
	renderer.renderList.add(cursor, Priority(250));
	//renderer.renderList.add(somDraw, Priority(255));
	renderer.renderList.add(recDrawA, Priority(240));
	renderer.renderList.add(recDrawB, Priority(240));
	//renderer.renderList.add(testText, Priority(251));
	renderer.guiRenderList.add(dText, Priority(251));
	foreach (sm; somethingAutoRender)
		renderer.renderList.add(sm, Priority(200));
	renderer.draw();
}


