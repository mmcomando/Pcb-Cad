module engine.window;

import gl3n.linalg;

enum MouseButton {
    left = 0,
    right = 1,
    middle = 2,

}

enum Key {
    ctrl,
    alt,
    shift,
    esc

}

interface Window {
    void setTitle(string);
    float ratio();
    vec2i size();
    vec2i mousePos();
    vec2i mouseWheel();
    void mousePos(vec2i);
    bool mouseButtonDown(MouseButton);
    bool mouseButtonPressed(MouseButton);
    bool mouseButtonReleased(MouseButton);
    bool keyPressed(short);
    bool keyReleased(short);
    bool keyDown(short);
    bool keyPressed(Key);
    bool keyReleased(Key);
    bool keyDown(Key);

    void setResizeDelegate(void delegate(int, int));
    void setUpdateDelegate(void delegate());
    void start();
}
