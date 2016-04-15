module engine.renderer.render;

import std.algorithm : sort, remove;
import std.stdio : writeln;

import gl3n.linalg;
import glamour.shader : Shader;
import derelict.opengl3.gl3;

import engine;
import engine.renderer.memory;

import shaders = engine.renderer.shaders;

interface Drawable {
    void onBind();
    void onUnbind();
    void draw();
}

struct Priority {
    ubyte sort;
    ubyte p1;
    ubyte p2;
    ubyte p3;

    uint toUlong() const {
        return sort * 256 * 256 * 256 + p1 * 256 * 256 + p2 * 256 + p3;
    }

    int opCmp(ref const Priority b) const {
        return toUlong - b.toUlong;
    }
}

class RenderList {
    static struct Item {
        Drawable drawable;
        Priority priority;
        int opCmp(ref const Item b) const {
            return priority.opCmp(b.priority);
        }
    }

    Item[] items;
    void add(Drawable d, Priority p) {
        Item item;
        item.drawable = d;
        item.priority = p;
        items ~= item;
    }

    void draw() {
        foreach (item; items) {
            item.drawable.onBind();
            item.drawable.draw();
            item.drawable.onUnbind();
        }
    }

    void reset() {
        items.length = 0;
    }

    void sort() {
        items.sort!"a.priority.sort<b.priority.sort"();
        //writeln(items.length);
    }
}

class Renderer {
public:
    alias Allocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    Allocator verticesAllocator; //for vec2

    GLuint projectionMatrixUbo;
    GLuint modelMatrixUbo;
    GLuint projectionBindingPoint = 2;
    GLuint modelBindingPoint = 3;
    Camera camera = Camera(vec2(640, 480), vec2(0, 0), 1000);
	RenderList renderList;
	RenderList guiRenderList;
    void init() {
        verticesAllocator = new Allocator;
		renderList = new RenderList;
		guiRenderList = new RenderList;
        const char* ver = glGetString(GL_VERSION);
        const char* ver2 = glGetString(GL_SHADING_LANGUAGE_VERSION);
        writeln("opengl version: ", *ver);
        writeln("glsl version: ", *ver2);
        glGenBuffers(1, &projectionMatrixUbo);
        glBindBuffer(GL_UNIFORM_BUFFER, projectionMatrixUbo);
        glBufferData(GL_UNIFORM_BUFFER, mat4.sizeof, null, GL_DYNAMIC_DRAW);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);

        glGenBuffers(1, &modelMatrixUbo);
        glBindBuffer(GL_UNIFORM_BUFFER, modelMatrixUbo);
        glBufferData(GL_UNIFORM_BUFFER, mat4.sizeof, null, GL_DYNAMIC_DRAW);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);
    }

    void draw() {
        glViewport(0, 0, cast(int) camera.wh.x, cast(int) camera.wh.y);
        glClearColor(1, 1, 1, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        mat4 projection = buildProjectionMatrix(camera);
        setProjectionMatrix(projection);
        renderList.sort();
        renderList.draw();
        renderList.reset();

		Camera guiCamera=camera;
		guiCamera.pos=vec2(guiCamera.wh.x,-guiCamera.wh.y);
		projection = buildProjectionMatrixForGui(guiCamera);
		setProjectionMatrix(projection);
		guiRenderList.sort();
		guiRenderList.draw();
		guiRenderList.reset();
    }

    void setProjectionMatrix(mat4 mat) {
        glBindBuffer(GL_UNIFORM_BUFFER, projectionMatrixUbo);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, mat4.sizeof, &mat);
        glBindBufferBase(GL_UNIFORM_BUFFER, projectionBindingPoint, projectionMatrixUbo);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);
    }

    void setModelMatrix(mat4 mat) {
        glBindBuffer(GL_UNIFORM_BUFFER, modelMatrixUbo);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, mat4.sizeof, &mat);
        glBindBufferBase(GL_UNIFORM_BUFFER, modelBindingPoint, modelMatrixUbo);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);
    }

    void onResize(int x, int y) {
        camera.wh.x = x;
        camera.wh.y = y;
    }

}

struct Camera {
    vec2 wh;
    vec2 pos;
    float zoom;
    float rot;

    vec2 getCameraGlobalSize() {
        float windowRatio = cast(float) wh.y / wh.x;
        vec2 size = vec2(1 / windowRatio, 1);
        size /= zoom;
        return size;
    }

    vec2 cameraToGlobal(vec2i sreenPos) {
        vec2 global = sreenPos;
        float f = cast(float) wh.y / wh.x;
        global -= wh * 0.5;
        global.x /= f * wh.x;
        global.y /= -1 * wh.y;
        global /= zoom / 50;
        global += pos;
        return global;
    }

    vec2i globalToCamera(vec2 pos) {
        float f = cast(float) wh.y / wh.x;
        pos -= this.pos;
        pos *= zoom / 50;
        pos.x *= f * wh.x;
        pos.y *= -1 * wh.y;
        pos += wh * 0.5;
        return vec2i(cast(int) pos.x, cast(int) pos.y);
    }
    ///In pixels
    vec2 vectorSize(vec2 v) {
        float f = cast(float) wh.y / wh.x;
        v *= zoom / 50;
        v.x *= f * wh.x;
        v.y *= wh.y;
        //	v+=wh*0.5;
        return v;
    }
}

// Convert from world coordinates to normalized device coordinates.
// http://www.songho.ca/opengl/gl_projectionmatrix.html
private mat4 buildProjectionMatrix(Camera cam) {
    mat4 m = void;
    float w = cam.wh.x;
    float h = cam.wh.y;
    float ratio = w / h;
    vec2 extents = vec2(ratio * 25.0f, 25.0f);
    extents /= cam.zoom;

    vec2 lower = cam.pos - extents;
    vec2 upper = cam.pos + extents;

    m[0][0] = 2.0f / (upper.x - lower.x);
    m[1][0] = 0.0f;
    m[2][0] = 0.0f;
    m[3][0] = 0.0f;

    m[0][1] = 0.0f;
    m[1][1] = 2.0f / (upper.y - lower.y);
    m[2][1] = 0.0f;
    m[3][1] = 0.0f;

    m[0][2] = 0.0f;
    m[1][2] = 0.0f;
    m[2][2] = 1.0f;
    m[3][2] = 0.0f;

    m[0][3] = -(upper.x + lower.x) / (upper.x - lower.x);
    m[1][3] = -(upper.y + lower.y) / (upper.y - lower.y);
    m[2][3] = 0.0f; //zBias;
    m[3][3] = 1.0f;
    return m;
}

private mat4 buildProjectionMatrixForGui(Camera cam) {
	mat4 m = void;
	float w = cam.wh.x;
	float h = cam.wh.y;
	vec2 extents = vec2(w,h);	
	vec2 lower = cam.pos - extents;
	vec2 upper = cam.pos + extents;
	
	m[0][0] = 4.0f / (upper.x - lower.x);
	m[1][0] = 0.0f;
	m[2][0] = 0.0f;
	m[3][0] = 0.0f;
	
	m[0][1] = 0.0f;
	m[1][1] = 4.0f / (upper.y - lower.y);
	m[2][1] = 0.0f;
	m[3][1] = 0.0f;
	
	m[0][2] = 0.0f;
	m[1][2] = 0.0f;
	m[2][2] = 1.0f;
	m[3][2] = 0.0f;

	m[0][3] = -(upper.x + lower.x) / (upper.x - lower.x);
	m[1][3] = -(upper.y + lower.y) / (upper.y - lower.y);
	m[2][3] = 0.0f; //zBias;
	m[3][3] = 1.0f;
	return m;
}