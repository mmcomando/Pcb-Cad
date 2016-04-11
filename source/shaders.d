module shaders;

import glamour.shader : Shader;
import derelict.opengl3.gl3;

struct TextProgram {
    static immutable string source = `
#version 330
vertex:
layout (std140) uniform rendererData
{ 
  mat4 projectionMatrix;
};
layout (std140) uniform rendererData2
{ 
  mat4 modelMatrix;
};

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 inCoord;

uniform vec2 pos;
uniform float scale;

out vec2 texCoord;
void main(void)
{
    gl_Position = vec4(position,0,1)*modelMatrix*projectionMatrix;
    texCoord = inCoord;
}


fragment:
in vec2 texCoord;
out vec4 outputColor;
uniform vec3 color;

uniform sampler2D gSampler;

void main(void)
{
	outputColor=vec4(color,1)*texture2D(gSampler, texCoord);
}
        
`;
    __gshared static TextProgram prog;
    static TextProgram* get() {
        return &prog;
    }

    static void init() {
        prog.shader = new Shader("", source);
        prog.pos = glGetUniformLocation(prog.shader, "pos");
        prog.color = glGetUniformLocation(prog.shader, "color");
        prog.scale = glGetUniformLocation(prog.shader, "scale");
        prog.renderData = glGetUniformBlockIndex(prog.shader, "rendererData");
        prog.renderData2 = glGetUniformBlockIndex(prog.shader, "rendererData2");

    }

    Shader shader;
    uint renderData;
    uint renderData2;
    uint pos;
    uint scale;
    uint color;
}

struct SomethingProgram {
    static immutable string source = `
#version 330
vertex:
layout (std140) uniform rendererData
{ 
  mat4 projectionMatrix;
};
layout (std140) uniform rendererData2
{ 
  mat4 modelMatrix;
};

layout (location = 0) in vec2 position;

uniform vec2 pos;

void main(void)
{
    gl_Position = vec4(position,0,1)*modelMatrix*projectionMatrix;
}



fragment:
out vec4 outputColor;
uniform vec3 color;

void main(void)
{
    outputColor = vec4(color,1);
}
        
`;
    __gshared static SomethingProgram prog;
    static SomethingProgram* get() {
        return &prog;
    }

    static void init() {
        prog.shader = new Shader("", source);
        prog.pos = glGetUniformLocation(prog.shader, "pos");
        prog.color = glGetUniformLocation(prog.shader, "color");
        prog.renderData = glGetUniformBlockIndex(prog.shader, "rendererData");
        prog.renderData2 = glGetUniformBlockIndex(prog.shader, "rendererData2");

    }

    Shader shader;
    uint renderData;
    uint renderData2;
    uint pos;
    uint color;
}

struct CirclesInstancedProgram {
    static immutable string source = `
#version 330
vertex:
layout (std140) uniform rendererData
{ 
  mat4 projectionMatrix;
};
layout (std140) uniform rendererData2
{ 
  mat4 modelMatrix;
};
layout (location = 0) in vec2 vertexPos;
layout (location = 1) in vec2 instancePos;
layout (location = 2) in float radius;
layout (location = 3) in vec3 color;

uniform vec2 everythingPos;

out vec3 colorr;
void main(void)
{
  	colorr=color;
    gl_Position = vec4(vertexPos*radius+instancePos, 0,1)*modelMatrix*projectionMatrix;//
}


fragment:
out vec4 outputColor;
in vec3 colorr;

void main(void)
{
    outputColor = vec4(colorr,1);
}

`;
    __gshared static CirclesInstancedProgram prog;
    static CirclesInstancedProgram* get() {
        return &prog;
    }

    static void init() {
        prog.shader = new Shader("", source);
        prog.everythingPos = glGetUniformLocation(prog.shader, "everythingPos");
        prog.renderData = glGetUniformBlockIndex(prog.shader, "rendererData");
        prog.renderData2 = glGetUniformBlockIndex(prog.shader, "rendererData2");

    }

    Shader shader;
    uint renderData;
    uint renderData2;
    uint everythingPos;
}
