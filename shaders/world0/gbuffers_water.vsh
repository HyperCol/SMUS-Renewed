#version 120

//#define WAVING_WATER

uniform int worldTime;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;

varying vec3 worldNormal;

varying vec3 normal;
varying vec3 globalNormal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;
varying vec3 viewVector2;
varying float distance;

attribute vec4 mc_Entity;

varying float iswater;
varying float isice;
varying float isGlass;
varying float isGlassP;
varying float isStainedGlass;
varying float isStainedGlassP;
varying float isSlimeBlock;

uniform vec2 resolution;
uniform vec2 texel;

uniform int frameCounter;

uniform vec2 taaJitter;

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.

void main() {

	iswater = 0.0f;
	isice = 0.0f;
	isGlass = 0.0f;
	isGlassP = 0.0f;
	isStainedGlass = 0.0f;
	isStainedGlassP = 0.0f;
	isSlimeBlock = 0.0f;

	if(mc_Entity.y == 1 || mc_Entity.x == 8 || mc_Entity.x == 9 || mc_Entity.x == 1971)
	{
		iswater = 1.0;
	}
	else if(mc_Entity.x == 20)
	{
		isGlass = 1.0f;
	}
	else if (mc_Entity.x == 79) {
		isice = 1.0f;
		iswater = 0.0;
	}
	else if (mc_Entity.x == 95)
	{
		isStainedGlass = 1.0f;
		iswater = 0.0;
	}
	else if(mc_Entity.x == 102)
	{
		isGlassP = 1.0f;
	}
	else if (mc_Entity.x == 160)
	{
		isStainedGlassP = 1.0f;
		iswater = 0.0;
	}
	else if (mc_Entity.x == 165)
	{
		isSlimeBlock = 1.0f;
		iswater = 0.0;
	}
		 vertexPos = gl_Vertex;

	
		
	vec4 viewPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewPos;

	worldPosition.xyz = viewPos.xyz + cameraPosition.xyz;

	vec4 localPosition = gl_ModelViewMatrix * gl_Vertex;

	distance = length(localPosition.xyz);

	gl_Position = gl_ProjectionMatrix * (gbufferModelView * position);



	//Temporal jitter
#ifdef TAA_ENABLED
	gl_Position.xyz /= gl_Position.w;
	gl_Position.xy += taaJitter;
	gl_Position.xyz *= gl_Position.w;
#endif

	gl_Position.z -= 0.0001;

	
	color = gl_Color;
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	


	gl_FogFragCoord = gl_Position.z;


	
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	globalNormal = normalize(gl_Normal);

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                          tangent.y, binormal.y, normal.y,
                          tangent.z, binormal.z, normal.z);

	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector2 = normalize(viewVector);
	viewVector = normalize(tbnMatrix * viewVector);


	worldNormal = gl_Normal.xyz;
}