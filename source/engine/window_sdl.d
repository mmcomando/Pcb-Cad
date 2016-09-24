module engine.window_sdl;

import std.stdio;
import std.conv : to;
import core.stdc.string : memset;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import gl3n.linalg;
import engine.window;

final class WindowSDL : Window {
    float ratio() {
        vec2i s = size();
        return cast(float) s.x / s.y;
    }

    vec2i size() {
        return windowSize;
    }

    vec2i mousePos() {
        return _mousePos;
    }

    vec2i mouseWheel() {
        return _mouseWheel;
    }

    void mousePos(vec2i p) {
        SDL_WarpMouseInWindow(sdlwindow, p.x, p.y);
    }

    bool mouseButtonDown(MouseButton b) {
        if (mouseDownKeys[b]) {
            return true;
        }
        return false;
    }

    bool mouseButtonPressed(MouseButton b) {

        if (mousePressedKeys[b]) {
            return true;
        }
        return false;
    }

    bool mouseButtonReleased(MouseButton b) {
        if (mouseReleasedKeys[b]) {
            return true;
        }
        return false;
    }

    bool keyPressed(short k) {
        if (k < 256) {
            return pressedKeys[k];
        } else {
            return false;
        }
    }

    bool keyReleased(short k) {
        if (k < 256) {
            return releasedKeys[k];
        } else {
            return false;
        }
    }

    bool keyDown(short k) {
        if (k < 256) {
            return downKeys[k];
        } else {
            return false;
        }
    }

    bool keyPressed(Key k) {
        if (k < 256) {
            return pressedKeysSpecial[k];
        } else {
            return false;
        }
    }

    bool keyReleased(Key k) {
        if (k < 256) {
            return releasedKeysSpecial[k];
        } else {
            return false;
        }
    }

    bool keyDown(Key k) {
        if (k < 256) {
            return downKeysSpecial[k];
        } else {
            return false;
        }
    }

    void setResizeDelegate(void delegate(int, int) del) {
        onResize = del;
    }

    void setUpdateDelegate(void delegate() del) {
        onUpdate = del;
    }

    void setTitle(string) {
        //assert(0);
    }

    void start() {
        onResize(windowSize.x, windowSize.y);
        mainLoop();
    }

    this() {
        //DerelictSDL2Image.load();
        DerelictSDL2.load();
        if (SDL_Init(SDL_INIT_VIDEO) < 0) {
            throw new Exception("Failed to initialize SDL: " ~ to!string(SDL_GetError()));
        }

        // Set OpenGL version
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);

        // Set OpenGL attributes
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);

        sdlwindow = SDL_CreateWindow("PCB CAD", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            windowSize.x, windowSize.y, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
        if (!sdlwindow)
            throw new Exception("Failed to create a SDL window: " ~ to!string(SDL_GetError()));

        SDL_GL_CreateContext(sdlwindow);
		try{
        	DerelictGL3.reload();
		}catch(Exception e){
			throw new Exception("Can not load given opengl context(3.3).");
		}
        auto hookDebugCallback = cast(typeof(glDebugMessageCallbackARB)) glDebugMessageCallback;
        hookDebugCallback(cast(GLDEBUGPROCARB)&glErrorCallback, null);
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS_ARB);
    }

private:
    void mainLoop() {
        while (!end) {
            update();
            pollEvents();
            onUpdate();
            SDL_GL_SwapWindow(sdlwindow);
        }
    }

    void update() {
        _mouseWheel = vec2i(0, 0);
        memset(&pressedKeys, 0, 256);
        memset(&releasedKeys, 0, 256);
        memset(&mousePressedKeys, 0, MouseButton.max + 1);
        memset(&mouseReleasedKeys, 0, MouseButton.max + 1);
        memset(&pressedKeysSpecial, 0, Key.max + 1);
        memset(&releasedKeysSpecial, 0, Key.max + 1);
    }

    void pollEvents() {
        int[2] xy;
        SDL_GetMouseState(&xy[0], &xy[1]);
        _mousePos = vec2i(xy[0], xy[1]);
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
            case SDL_KEYDOWN:
                specialKeysImpl(event.key.keysym.sym, false);
                if (event.key.keysym.sym < 256) {
                    downKeys[event.key.keysym.sym] = true;
                    pressedKeys[event.key.keysym.sym] = true;
                }

                break;
            case SDL_KEYUP:
                specialKeysImpl(event.key.keysym.sym, true);
                if (event.key.keysym.sym < 256) {
                    downKeys[event.key.keysym.sym] = false;
                    releasedKeys[event.key.keysym.sym] = true;
                }
                break;
            case SDL_MOUSEBUTTONDOWN:
                switch (event.button.button) {
                case SDL_BUTTON_LEFT:
                    mouseDownKeys[MouseButton.left] = true;
                    mousePressedKeys[MouseButton.left] = true;
                    break;
                case SDL_BUTTON_RIGHT:
                    mouseDownKeys[MouseButton.right] = true;
                    mousePressedKeys[MouseButton.right] = true;
                    break;
                case SDL_BUTTON_MIDDLE:
                    mouseDownKeys[MouseButton.middle] = true;
                    mousePressedKeys[MouseButton.middle] = true;
                    break;
                default:
                    break;
                }
                break;
            case SDL_MOUSEBUTTONUP:
                switch (event.button.button) {
                case SDL_BUTTON_LEFT:
                    mouseDownKeys[MouseButton.left] = false;
                    mouseReleasedKeys[MouseButton.left] = true;
                    break;
                case SDL_BUTTON_RIGHT:
                    mouseDownKeys[MouseButton.right] = false;
                    mouseReleasedKeys[MouseButton.right] = true;
                    break;
                case SDL_BUTTON_MIDDLE:
                    mouseDownKeys[MouseButton.middle] = false;
                    mouseReleasedKeys[MouseButton.middle] = true;
                    break;
                default:
                    break;
                }
                break;
            case SDL_MOUSEWHEEL:
                _mouseWheel.x = event.wheel.x;
                _mouseWheel.y = event.wheel.y;

                break;
            case SDL_QUIT:
                end = true;
                break;
            case SDL_WINDOWEVENT:
                switch (event.window.event) {
                case SDL_WINDOWEVENT_RESIZED:
                    windowSize = vec2i(event.window.data1, event.window.data2);
                    onResize(event.window.data1, event.window.data2);
                    break;
                default:
                    break;
                }
                break;
            default:
                break;
            }
        }
    }

    private void specialKeysImpl(uint sym, bool up) {
        Key key;
        switch (sym) {
        case SDLK_ESCAPE:
            key = Key.esc;
            break;
        case SDLK_LCTRL:
            key = Key.ctrl;
            break;
        case SDLK_LSHIFT:
            key = Key.shift;
            break;
        case SDLK_LALT:
            key = Key.alt;
            break;
        default:
            return;
        }
        if (!up) {
            downKeysSpecial[key] = true;
            pressedKeysSpecial[key] = true;
        } else {
            downKeysSpecial[key] = false;
            releasedKeysSpecial[key] = true;
        }
    }

    bool end = false;

    bool[256] downKeys;
    bool[256] pressedKeys;
    bool[256] releasedKeys;
    bool[Key.max + 1] downKeysSpecial;
    bool[Key.max + 1] pressedKeysSpecial;
    bool[Key.max + 1] releasedKeysSpecial;

    bool[MouseButton.max + 1] mouseDownKeys;
    bool[MouseButton.max + 1] mousePressedKeys;
    bool[MouseButton.max + 1] mouseReleasedKeys;

    void delegate(int, int) onResize;
    void delegate() onUpdate;
    vec2i windowSize = vec2i(800, 500);
    vec2i _mousePos = vec2i(100, 100);
    vec2i _mouseWheel;

    private SDL_Window* sdlwindow;
}

private extern (C) void glErrorCallback(GLenum source, GLenum type, GLuint id, GLenum severity,
    GLsizei length, in GLchar* message, GLvoid* userParam) {
    if (type == GL_DEBUG_TYPE_PERFORMANCE || (severity != GL_DEBUG_SEVERITY_LOW
            && severity != GL_DEBUG_SEVERITY_MEDIUM && severity != GL_DEBUG_SEVERITY_HIGH))
        return;
    writeln("---------------------opengl-callback-start------------");
    writeln("message: ", message.to!string);
    write("type: ");
    switch (type) {
    case GL_DEBUG_TYPE_ERROR:
        write("ERROR");
        break;
    case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
        write("DEPRECATED_BEHAVIOR");
        break;
    case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
        write("UNDEFINED_BEHAVIOR");
        break;
    case GL_DEBUG_TYPE_PORTABILITY:
        write("PORTABILITY");
        break;
    case GL_DEBUG_TYPE_PERFORMANCE:
        write("PERFORMANCE");
        break;
    case GL_DEBUG_TYPE_OTHER:
        write("OTHER");
        break;
    default:
        write("Undefined type: ", type, " ");
    }
    writeln();
    write("id: ", id, " severity: ");
    switch (severity) {
    case GL_DEBUG_SEVERITY_LOW:
        write("LOW");
        break;
    case GL_DEBUG_SEVERITY_MEDIUM:
        write("MEDIUM");
        break;
    case GL_DEBUG_SEVERITY_HIGH:
        write("HIGH");
        break;
    default:
        write("Undefined severity: ", severity, " ");
    }

    throw new Exception(message.to!string);
    /*try
	 {
	 }
	 catch (Throwable e)
	 {
	 //writeln("----",msg);
	 writeln("Call stack4----------");
	 foreach(i,b;e.info){
	 writeln(b,"\n");
	 if(i>4)break;
	 }
	 }*/
}
