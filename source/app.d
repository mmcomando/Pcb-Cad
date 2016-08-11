import std.stdio;
import std.datetime;

import derelict.opengl3.gl3;
import derelict.util.exception;

import engine;

import utils;

static import run;

version (window_dlangui) {
	import dlangui;
	mixin APP_ENTRY_POINT;
	
	/// entry point for dlangui based application
	extern (C) int UIAppMain(string[] args) {
		return maintImpl();
	}
}else{
	int main(){
		return maintImpl();
	}
}
int maintImpl(){

    import etc.linux.memoryerror;

    registerMemoryErrorHandler();

    try {
        StopWatch sw;
        sw.start();
        auto startTime = sw.peek();

        gameEngine = new Engine();
        gameEngine.initAll();
        auto engineInitTime = sw.peek();

        gameEngine.onUpdate = &run.run;
        auto endTime = sw.peek();
        writeln("Engine initialization in: ", engineInitTime.msecs - startTime.msecs, "ms");
        writeln("Aplication initialization in: ", endTime.msecs - engineInitTime.msecs, "ms");

        gameEngine.mainLoop();
        gameEngine.remove();
        endTime = sw.peek();

        long ttTime = endTime.msecs;

        writefln("Total time:  %10dms  %10.3f of total time", ttTime, cast(float) ttTime * 100 / ttTime);

    }
    catch (SharedLibLoadException e) {
        writeln("Failed to load shared library. Whole exception message:");
        writeln("---------------------");
        writeln(e.msg);
        writeln("---------------------");
        writeln("You should propably install required library.");
    }
    catch (SymbolLoadException e) {
        writeln("Failed to load symbol: ", e.symbolName(), " Whole exception message:",);
        writeln("---------------------");
        writeln(e.msg);
        writeln("---------------------");
        writeln("You propably have wrong version of library installed.");
    }
    catch (Exception e) {
        printException(e);
    } /*catch(Throwable e){
	    printException(e);
    }*/

    return 0;
}
