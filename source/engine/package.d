module engine;

import engine.window;

version (window_gtk) {
    import engine.window_gtk : WindowProvider = WindowGtk;
}
version (window_sdl) {
    import engine.window_sdl : WindowProvider = WindowSDL;
}
import core.memory;
import std.datetime;
import std.stdio : writefln;

import derelict.opengl3.gl3;
import gl3n.linalg;

import engine.renderer.render;

Engine gameEngine;

class Engine {
    uint referencesNum;
    StopWatch watch;
    TickDuration dt;
    float dtf;
    Window window;
    Renderer renderer;

    TickDuration oldTime;
    TickDuration newTime;
    float fpsTimer = 0;
    float frames = 0;
    float fps = 0;
    float minTime = 0;
    float maxTime = 0;
    vec2 globalMousePos;

    void function() onUpdate;

    void initAll() {
        watch.start();
        oldTime = newTime = watch.peek;

        DerelictGL3.load();
        window = new WindowProvider();
        renderer = new Renderer();
        window.setUpdateDelegate(&update);
        window.setResizeDelegate(&renderer.onResize);
        renderer.camera.wh = vec2(window.size);
    }

    void remove() {
    }

    void update() {
        fpsCounter();
        onUpdate();
    }

    void mainLoop() {
        window.start();

    }

    void fpsCounter() {
        static float miTime, maTime;
        frames++;
        oldTime = newTime;
        newTime = watch.peek();
        dt = newTime - oldTime;
        dtf = cast(float) dt.nsecs / 1000_000_000;
        fpsTimer += dtf;
        if (miTime < dtf)
            miTime = dtf;
        if (maTime > dtf)
            maTime = dtf;
        if (fpsTimer >= 1) {
            minTime = miTime;
            maxTime = maTime;
            maTime = miTime = dtf;
            fps = frames / fpsTimer;
            fpsTimer -= 1;
            frames = 0;
            GC.collect();
        }

    }

}
