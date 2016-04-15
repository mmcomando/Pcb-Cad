module drawables;

import std.array : uninitializedArray;
import std.conv : to;
import std.stdio : writeln;

import derelict.sdl2.ttf;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.opengl3.gl3;
import gl3n.linalg;

import engine;
import engine.renderer;
import engine.renderer.memory;
import utils;
import shaders;

//TODO this objects are using allocators with fixed memory size (too many objects and there will be exception :/)

//// Draw lines, triangles with color
final class Something : Drawable {
    GpuMemory data;
	Transform trf;
    /*vec2 pos = vec2(0, 0);
    vec2 scale = vec2(1, 1);
    float rot = 0;*/
    vec3 color = vec3(0, 0, 0);
    GLenum mode = GL_TRIANGLES;

    void onBind() {
        auto tmp = SomethingProgram.get;
        tmp.shader.bind();
        glUniformBlockBinding(tmp.shader.program, tmp.renderData, 2);
        glUniformBlockBinding(tmp.shader.program, tmp.renderData2, 3);
    }

    void onUnbind() {
        auto tmp = SomethingProgram.get;
        glBindVertexArray(0);
        tmp.shader.unbind();
    }

    void draw() {
        auto tmp = SomethingProgram.get;
        glBindVertexArray(vao);
        glUniform3f(tmp.color, color.x, color.y, color.z);
		//gameEngine.renderer.setModelMatrix(getModelMatrix(this));
		gameEngine.renderer.setModelMatrix(trf.toMatrix);
        glDrawArrays(mode, data.start / vec2.sizeof, (data.end - data.start) / vec2.sizeof);
    }

    static Something fromPoints(in vec2[] points) {
        GpuMemory m = gameEngine.renderer.verticesAllocator.allocate(points.length * vec2.sizeof);
        m.write(points);
        Something meta = new Something;
        meta.data = m;
        return meta;
    }

    static void remove(Something sm) {
        gameEngine.renderer.verticesAllocator.deallocate(sm.data);
    }

    static void init() {
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, gameEngine.renderer.verticesAllocator.vbo);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
        glBindVertexArray(0);
        glDisableVertexAttribArray(0);
    }

    private static uint vao;
}

//// Draw lines, triangles with color
final class SomethingNoTransform : Drawable {
	GpuMemory data;
	vec3 color = vec3(0, 0, 0);
	GLenum mode = GL_TRIANGLES;
	
	void onBind() {
		auto tmp = SomethingProgram.get;
		tmp.shader.bind();
		glUniformBlockBinding(tmp.shader.program, tmp.renderData, 2);
		glUniformBlockBinding(tmp.shader.program, tmp.renderData2, 3);
	}
	
	void onUnbind() {
		auto tmp = SomethingProgram.get;
		glBindVertexArray(0);
		tmp.shader.unbind();
	}
	
	void draw() {
		auto tmp = SomethingProgram.get;
		glBindVertexArray(Something.vao);
		glUniform3f(tmp.color, color.x, color.y, color.z);
		glDrawArrays(mode, data.start / vec2.sizeof, (data.end - data.start) / vec2.sizeof);
	}
	
	static SomethingNoTransform fromPoints(in vec2[] points) {
		GpuMemory m = gameEngine.renderer.verticesAllocator.allocate(points.length * vec2.sizeof);
		m.write(points);
		SomethingNoTransform meta = new SomethingNoTransform;
		meta.data = m;
		return meta;
	}
	
	static void remove(SomethingNoTransform sm) {
		gameEngine.renderer.verticesAllocator.deallocate(sm.data);
	}
}
///Group of SomethingNoTransform
final class Group : Drawable {
	Transform trf;
	private SomethingNoTransform[] drawables;

	void add(SomethingNoTransform obj){
		drawables~=obj;
	}
	void remove(SomethingNoTransform obj){
		drawables.removeElementInPlace(obj);
	}
	// :]
	void destroy(){
		foreach(d;drawables)SomethingNoTransform.remove(d);
	}
	void onBind() {}
	
	void onUnbind() {}
	
	void draw() {
		if(drawables.length==0)return;
		writeln(trf);
		gameEngine.renderer.setModelMatrix(trf.toMatrix);
		drawables[0].onBind();
		foreach(d;drawables){
			d.onBind();
			d.draw();
			d.onUnbind();
		}
		drawables[0].onUnbind();


	}
}

//// TEXT

private enum vec2i texSize = vec2i(1024, 512);

final class Text : Drawable {
    GpuMemory data;
	Transform trf;
    /*vec2 pos = vec2(0, 0);
    vec2 scale = vec2(1, 1);
    float rot = -3.14f / 4f;*/
    vec3 color = vec3(0, 0, 1);

    void onBind() {
        auto tmp = TextProgram.get;
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texId);
        tmp.shader.bind();
        glUniformBlockBinding(tmp.shader.program, tmp.renderData, 2);
        glUniformBlockBinding(tmp.shader.program, tmp.renderData2, 3);
    }

    void onUnbind() {
        auto tmp = TextProgram.get;
        glBindVertexArray(0);
        tmp.shader.unbind();
        glDisable(GL_BLEND);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    void draw() {
        auto tmp = TextProgram.get;
        glBindVertexArray(vao);
		glUniform3f(tmp.color, color.x, color.y, color.z);
        gameEngine.renderer.setModelMatrix(trf.toMatrix);
		//gameEngine.renderer.setModelMatrix(fin.toMatrix);
        glDrawArrays(GL_TRIANGLES, data.start / (vec2.sizeof * 2), (data.end - data.start) / (vec2.sizeof * 2));
    }

    static void init() {
        DerelictSDL2ttf.load();
        DerelictSDL2Image.load();
        TTF_Init();

        allocator = new Allocator;
        makeVao();
        makeTextTexture();
    }

    static Text fromString(string txt) {
        vec2[] posCord = getTextPosCords(txt);
        GpuMemory m = allocator.allocate(posCord.length * vec2.sizeof);
        m.write(posCord);
        Text meta = new Text;
        meta.data = m;
        return meta;
    }

    static Text getDebugText() {
        vec2 charHalfSize = vec2(1, 0.5);
        vec2[] posCord;
        vec2 v11 = vec2(-charHalfSize.x, charHalfSize.y);
        vec2 v22 = charHalfSize;
        vec2 v33 = vec2(charHalfSize.x, -charHalfSize.y);
        vec2 v44 = -charHalfSize;

        posCord ~= [v11, vec2(0, 0)];
        posCord ~= [v22, vec2(1, 0)];
        posCord ~= [v44, vec2(0, 1)];
        posCord ~= [v44, vec2(0, 1)];
        posCord ~= [v22, vec2(1, 0)];
        posCord ~= [v33, vec2(1, 1)];
        GpuMemory m = allocator.allocate(posCord.length * vec2.sizeof);
        m.write(posCord);
        Text meta = new Text;
        meta.data = m;
        return meta;
    }

    void removeText(Text meta) {
        allocator.deallocate(meta.data);
    }

private:
    alias Allocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    static Allocator allocator;
    static uint vao;
    static GLuint texId;

    static void makeVao() {
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, allocator.vbo);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * vec2.sizeof, null);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * vec2.sizeof, cast(void*) vec2.sizeof);
        glBindVertexArray(0);
        glDisableVertexAttribArray(0);

    }

    static void makeTextTexture() {
        ubyte[] pixelData = getFontTextureData();
        glGenTextures(1, &texId);
        glBindTexture(GL_TEXTURE_2D, texId);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texSize.x, texSize.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixelData.ptr);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    /**
	 * Returns texture containing ANSI characters, with proper order
	 */
    static ubyte[] getFontTextureData() {
        TTF_Font* font = TTF_OpenFont("Inconsolata.otf", 62);
        if (font == null)
            throw new Exception("Font draw exception: " ~ to!string(TTF_GetError()));

        scope (exit)
            TTF_CloseFont(font);

        SDL_Color colorFg = {255, 255, 255};
        SDL_Surface* surface;

        ubyte[] pixelData = uninitializedArray!(ubyte[])(texSize.x * texSize.y * 4); //RGBA
        vec2i wh = vec2i(32, 64);
        SDL_Surface* s = SDL_CreateRGBSurface(0, wh.x, wh.y, 32, 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000);
        uint inRow = texSize.x / wh.x;
        foreach (ushort c; 1 .. 256) {
            surface = TTF_RenderGlyph_Blended(font, c, colorFg);
            scope (exit)
                SDL_FreeSurface(surface);
            if (surface == null) {
                writeln("TTF_RenderText error: ", to!string(TTF_GetError()));
                continue;
            }
            assert(surface.w <= wh.x && surface.h <= wh.y);
            SDL_FillRect(s, null, 0x000000);
            SDL_BlitSurface(surface, null, s, null);
            ubyte* surfaceData = cast(ubyte*) s.pixels;
            vec2i start = vec2i(wh.x * (c % inRow) * 4, wh.y * (c / inRow));
            foreach (y; 0 .. surface.h) {
                foreach (x; 0 .. surface.w * 4) {
                    uint index = (start.y + y) * texSize.x * 4 + start.x + x;
                    pixelData[index] = surfaceData[4 * y * s.w + x];
                }
            }
        }
        return pixelData;
    }

    static vec2[] getTextPosCords(string txt) {
        vec2[] posCord;
        posCord.reserve(12 * txt.length);

        vec2 charHalfSize = vec2(0.5, 1);
        vec2 charPos = vec2(0, 0);
        foreach (ubyte c; txt) {
            if (c == '\n') {
                charPos.x = 0;
                charPos.y -= charHalfSize.y * 2;
                continue;
            }
            vec2 uvdt = vec2(32f / texSize.x, 64f / texSize.y);
            vec2 uvx = vec2((c % 32) * uvdt.x, (c / 32) * uvdt.y);

            vec2 v11 = charPos + vec2(-charHalfSize.x, charHalfSize.y);
            vec2 v22 = charPos + charHalfSize;
            vec2 v33 = charPos + vec2(charHalfSize.x, -charHalfSize.y);
            vec2 v44 = charPos - charHalfSize;

            posCord ~= [v11, vec2(uvx.x, uvx.y)];
            posCord ~= [v22, vec2(uvx.x + uvdt.x, uvx.y)];
            posCord ~= [v44, vec2(uvx.x, uvx.y + uvdt.y)];
            posCord ~= [v44, vec2(uvx.x, uvx.y + uvdt.y)];
            posCord ~= [v22, vec2(uvx.x + uvdt.x, uvx.y)];
            posCord ~= [v33, vec2(uvx.x + uvdt.x, uvx.y + uvdt.y)];
            charPos.x += charHalfSize.x * 2;
        }
        return posCord;
    }

}

/**
 * Requires Text init()
 * changes GpuMemory internals to meet actual string size
 */
final class DynamicText : Drawable {
    GpuMemory data;
	Transform trf;
    /*vec2 pos = vec2(0, 0);
    vec2 scale = vec2(1, 1);
    float rot = 0;*/
    vec3 color = vec3(0, 1, 1);

    private size_t size; //actual string size
    private size_t maxSize;
    this(uint recommendedSize) {
        data = Text.allocator.allocate(getRequiredGPUSize(recommendedSize));
        maxSize = recommendedSize;
        size = 0;
    }

    void set(string str) {
        if (str.length <= maxSize) {
            data.write(Text.getTextPosCords(str));
        } else {
            maxSize = str.length;
            Text.allocator.deallocate(data);
            data = Text.allocator.allocate(getRequiredGPUSize(str.length));
            data.write(Text.getTextPosCords(str));
        }
        size = str.length;

    }

    private size_t getRequiredGPUSize(size_t length) {
        return 12 * length * vec2.sizeof;
    }

    void onBind() {
        auto tmp = TextProgram.get;
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, Text.texId);
        tmp.shader.bind();
        glUniformBlockBinding(tmp.shader.program, tmp.renderData, 2);
        glUniformBlockBinding(tmp.shader.program, tmp.renderData2, 3);
    }

    void onUnbind() {
        auto tmp = TextProgram.get;
        glBindVertexArray(0);
        tmp.shader.unbind();
        glDisable(GL_BLEND);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    void draw() {
        //writeln(size);
        auto tmp = TextProgram.get;
        glBindVertexArray(Text.vao);
        glUniform3f(tmp.color, color.x, color.y, color.z);
        gameEngine.renderer.setModelMatrix(trf.toMatrix);
        glDrawArrays(GL_TRIANGLES, data.start / (vec2.sizeof * 2), cast(uint) size * 6);
    }
}

////Circles

final class Circles : Drawable {
    static struct CircleData {
        vec3 color;
        vec2 pos;
        float radius;
    }

    GpuMemory data;
	Transform trf;
    /*vec2 pos = vec2(0, 0);
    vec2 scale = vec2(1, 1);
    float rot = 0;*/
    bool filled = false;
    void onBind() {
        auto tmp = CirclesInstancedProgram.get;
        tmp.shader.bind();
        glUniformBlockBinding(tmp.shader.program, tmp.renderData, gameEngine.renderer.projectionBindingPoint);
        glUniformBlockBinding(tmp.shader.program, tmp.renderData2, 3);
    }

    void onUnbind() {
        auto tmp = CirclesInstancedProgram.get;
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        tmp.shader.unbind();
    }

    void draw() {
        auto tmp = CirclesInstancedProgram.get;
        glBindVertexArray(vao);
        gameEngine.renderer.setModelMatrix(trf.toMatrix);
        glUniform2f(tmp.everythingPos, trf.pos.x, trf.pos.y);
        uint instancesStart = data.start;
        uint instancesCount = (data.end - data.start) / CircleData.sizeof;
        glBindBuffer(GL_ARRAY_BUFFER, metaAllocator.vbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, CircleData.sizeof,
            cast(void*)(instancesStart + CircleData.pos.offsetof));
        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, CircleData.sizeof,
            cast(void*)(instancesStart + CircleData.radius.offsetof));
        glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, CircleData.sizeof,
            cast(void*)(instancesStart + CircleData.color.offsetof));
        if (!filled) {
            uint start = circleData.start / vec2.sizeof;
            uint count = (circleData.end - circleData.start) / vec2.sizeof;
            glDrawArraysInstanced(GL_LINE_STRIP, start, count, cast(uint) instancesCount);
        } else {
            uint start = wheelData.start / vec2.sizeof;
            uint count = (wheelData.end - wheelData.start) / vec2.sizeof;
            glDrawArraysInstanced(GL_TRIANGLES, start, count, cast(uint) instancesCount);
        }

    }

    static Circles addCircles(CircleData[] tab, bool filled = false) {
        GpuMemory m = metaAllocator.allocate(CircleData.sizeof * tab.length);
        m.write(tab);
        Circles r = new Circles;
        r.data = m;
        r.filled = filled;
        return r;
    }

    static void remove(Circles r) {
        metaAllocator.deallocate(r.data);
    }

    static void init() {
        vec2[] points = getPointsOnCircle(vec2(0, 0), 1);

        vec2[] trianglePoints;
        vec2 o = vec2(0, 0);
        vec2 last = points[$ - 1];
        foreach (i, p; points) {
            trianglePoints ~= o;
            trianglePoints ~= last;
            trianglePoints ~= p;
            last = p;
        }

        vertexAllocator = new PosAllocator((points.length + trianglePoints.length) * vec2.sizeof);
        circleData = vertexAllocator.allocate(points.length * vec2.sizeof);
        circleData.write(points);
        wheelData = vertexAllocator.allocate(trianglePoints.length * vec2.sizeof); //have to have the same id like cicleData
        wheelData.write(trianglePoints);
        metaAllocator = new MetaAllocator(1024 * 8096);

        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glEnableVertexAttribArray(2);
        glEnableVertexAttribArray(3);
        glBindBuffer(GL_ARRAY_BUFFER, circleData.id);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
        glBindBuffer(GL_ARRAY_BUFFER, metaAllocator.vbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, CircleData.sizeof, cast(void*) CircleData.pos.offsetof);
        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, CircleData.sizeof, cast(void*) CircleData.radius.offsetof);
        glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, CircleData.sizeof, cast(void*) CircleData.color.offsetof);
        glVertexAttribDivisor(1, 1);
        glVertexAttribDivisor(2, 1);
        glVertexAttribDivisor(3, 1);
        glBindVertexArray(0);

        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);
        glDisableVertexAttribArray(3);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

    }

private:
    alias PosAllocator = GpuChunkAllocator!GL_ARRAY_BUFFER;
    alias MetaAllocator = GpuChunkAllocator!GL_ARRAY_BUFFER;

    static GpuMemory circleData;
    static GpuMemory wheelData;
    static GLuint vao;
    static MetaAllocator metaAllocator;
    static PosAllocator vertexAllocator;
}
