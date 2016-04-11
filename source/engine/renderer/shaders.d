module engine.renderer.shaders;

static immutable string textProgram = `
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
    //gl_Position = vec4(scale*position+pos, 1,1)*projectionMatrix;
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
	//vec4 color=vec4(1,0,0,1);
    //outputColor = vec4(color,1);
}
        
`;

static immutable string renderer2Program = `
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
   // gl_Position = vec4(position+pos, 1,1)*projectionMatrix;
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

static immutable string circleInnstancesProgram2 = `
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
