#version 120

//#define AUTO_NORMAL_SPEC // Enables automatic generation of normal and specular data from base color textures. Only works well for lower resolution resource packs. Make sure to set Surface Options > Texture Resolution properly according to your resource pack!

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;


attribute vec3 mc_Entity;

uniform int worldTime;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float aspectRatio;

uniform sampler2D noisetex;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec2 waves;
varying vec3 worldNormal;

varying float distance;
//varying float idCheck;

varying float materialIDs;

varying mat3 tbnMatrix;
varying vec4 vertexPos;
varying vec3 vertexViewVector;

uniform int entityId;

varying vec2 blockLight;

varying vec4 autoMaterialProperties;

uniform vec2 taaJitter;

varying vec3 viewPos;

vec4 GetAutoMaterialProperties(vec4 color)
{
	float id = mc_Entity.x;
	float colorSaturation = abs(color.r - color.g) + abs(color.r - color.b) + abs(color.g - color.b);

	float normalStrength = 1.0;
	float smoothnessStrength = 0.1;
	float smoothnessVariance = 1.0;
	float metalness = 0.0;



	//Stone
	if (id == 1 || id == 70)
	{
		normalStrength = 0.8;
		smoothnessStrength = 0.8;
		smoothnessVariance = 1.7;
	}



	//Grass and dirt
	bool grass = id == 2 && colorSaturation > 0.01 || id == 31;
	bool dirt = id == 2 && colorSaturation < 0.01 || id == 3;

	if (grass)
	{
		normalStrength = 0.8;
		smoothnessStrength = 0.5;
		smoothnessVariance = 1.5;
	}

	if (dirt)
	{
		normalStrength = 0.8;
		smoothnessStrength = 0.6;
		smoothnessVariance = 2.5;
	}



	//Cobblestone
	if (id == 4 || id == 67)
	{
		normalStrength = 1.0;
		smoothnessStrength = 0.6;
		smoothnessVariance = 1.5;
	}

	//Stone bricks
	if (id == 98 || id == 109)
	{
		normalStrength = 1.0;
		smoothnessStrength = 0.6;
		smoothnessVariance = 1.5;
	}

	//brick
	if (id == 45 || id == 108)
	{
		normalStrength = 1.0;
		smoothnessStrength = 0.6;
		smoothnessVariance = 1.5;
	}


	//Wood planks
	if (id == 5)
	{
		normalStrength = 0.8;
		smoothnessStrength = 0.5;
		smoothnessVariance = 1.5;
	}



	//Sand
	if (id == 12)
	{
		normalStrength = 0.6;
		smoothnessStrength = 0.5;
		smoothnessVariance = 1.5;
	}



	//Gravel
	if (id == 13)
	{
		normalStrength = 0.5;
		smoothnessStrength = 0.5;
		smoothnessVariance = 1.5;
	}



	//leaves
	if (id == 18)
	{
		normalStrength = 0.5;
		smoothnessStrength = 0.5;
		smoothnessVariance = 0.5;
	}


	//lapis lazuli block
	if (id == 22)
	{
		normalStrength = 1.0;
		smoothnessStrength = 1.0;
		smoothnessVariance = 1.3;
	}

	//gold block
	if (id == 41)
	{
		normalStrength = 0.2;
		smoothnessStrength = 1.0;
		smoothnessVariance = 0.0;
		metalness = 1.0;
	}

	//Iron block
	if (id == 42)
	{
		normalStrength = 0.2;
		smoothnessStrength = 1.0;
		smoothnessVariance = 0.0;
		metalness = 1.0;
	}






	return vec4(smoothnessStrength, smoothnessVariance, normalStrength, metalness);
}

void main() {



	texcoord = gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;


	blockLight.x = clamp((lmcoord.x * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	blockLight.y = clamp((lmcoord.y * 33.75f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);



	vec4 viewpos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewpos;

	worldPosition = viewpos.xyz + cameraPosition.xyz;


	materialIDs = 4;


	//Entity checker
	// if (mc_Entity.x == 1920.0f)
	// {
	// 	texcoord.st = vec2(0.2f);
	// }


	vec4 locposition = gl_ModelViewMatrix * gl_Vertex;

	viewPos = locposition.xyz;

	distance = length(locposition.xyz);


	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	//Temporal jitter
#ifdef TAA_ENABLED
	gl_Position.xyz /= gl_Position.w;
	gl_Position.xy += taaJitter;
	gl_Position.xyz *= gl_Position.w;
#endif

	color = gl_Color;

#ifdef AUTO_NORMAL_SPEC
	autoMaterialProperties = GetAutoMaterialProperties(color);
#else
	autoMaterialProperties = vec4(0.0);
#endif

	//color.rgb *= float(mod(entityId, 8)) / 8.0;

	// float colorDiff = abs(color.r - color.g);
	// 	  colorDiff += abs(color.r - color.b);
	// 	  colorDiff += abs(color.g - color.b);

	// if (colorDiff < 0.001f && mc_Entity.x != -1.0f && mc_Entity.x != 63 && mc_Entity.x != 68 && mc_Entity.x != 323) {

	// 	float lum = color.r + color.g + color.b;
	// 		  lum /= 3.0f;

	// 	if (lum < 0.92f) {
	// 		color.rgb = vec3(1.0f);
	// 	}

	// }

	gl_FogFragCoord = gl_Position.z;




	normal = normalize(gl_NormalMatrix * gl_Normal);
	worldNormal = gl_Normal;

	//if(distance < 80.0f){
		if (gl_Normal.x > 0.5) {
			//  1.0,  0.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
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
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		}
	//}


	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                     tangent.y, binormal.y, normal.y,
                     tangent.z, binormal.z, normal.z);

	vertexPos = gl_Vertex;
}
