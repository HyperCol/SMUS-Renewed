#version 120


/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/

////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////


#define WAVE_HEIGHT 0.5
#define WAVE_SURFACE_SAMPLES 4 // Higher is better. [3 4 5]

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////



uniform sampler2D texture;
uniform sampler2D specular;
uniform sampler2D normals;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;
uniform int worldTime;
uniform int frameCounter;

uniform float wetness;
uniform int isEyeInWater;
uniform float rainStrength;

varying vec3 normal;
varying vec3 globalNormal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec3 worldNormal;

uniform float eyeAltitude;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;
varying float distance;

varying float iswater;
varying float isice;
varying float isGlass;
varying float isGlassP;
varying float isStainedGlass;
varying float isStainedGlassP;
varying float isSlimeBlock;

uniform float nightVision;

#include "Common.inc"

#define ANIMATION_SPEED 1.0f


/* DRAWBUFFERS:01235 */


float CurveBlockLightTorch(float blockLight)
{
	float falloff = 10.0;

	blockLight = exp(-(1.0 - blockLight) * falloff);
	blockLight = max(0.0, blockLight - exp(-falloff));

	return blockLight;
}

void main() {

	vec4 tex = texture2D(texture, texcoord.st);
		 tex.rgb *= tex.a;
		 //tex.a = 0.85f;
		 tex.a = saturate(tex.a) * 0.85;

	vec4 transparentAlbedo = tex;

	float zero = 1.0f;
	float transx = 0.0f;
	float transy = 0.0f;

	//float iswater = 0.0f;

	float texblock = 0.0625f;

	bool backfacing = false;

	if (viewVector.z > 0.0f) {
		//backfacing = true;
	} else {
		//backfacing = false;
	}


	if (iswater > 0.5 || isice > 0.5 || isGlass > 0.5 || isGlassP > 0.5 || isStainedGlass > 0.5 || isStainedGlassP > 0.5 || isSlimeBlock > 0.5)
	{
		tex = vec4(0.0, 0.0, 0.0f, 0.2);
	}

	if(isGlass > 0.5 || isGlassP > 0.5)
	{
		transparentAlbedo.rgb = vec3(transparentAlbedo.a * 0.35 + 0.65) ;
	}

	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.

	//Separate lightmap types
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);







	float matID = 1.0f;

	if (iswater > 0.5f)
	{
			matID = 6.0;
	}

	if (isice > 0.5)
	{
		matID = 8.0;
	}

	if (isStainedGlass > 0.5 || isGlass > 0.5)
	{
		matID = 7.0;
	}


	if (isStainedGlassP > 0.5 || isGlassP > 0.5)
	{
		matID = 50.0;
	}

	if (isSlimeBlock > 0.5)
	{
		matID = 51.0;
	}

	matID += 0.1f;


	mat3 tbnMatrix = mat3 (tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
					     	tangent.z, binormal.z, normal.z);

	vec3 texNormal = texture2D(normals, texcoord.st).rgb * 2.0f - 1.0f;
		 texNormal = texNormal * tbnMatrix;

	lightmap.r = CurveBlockLightTorch(lightmap.r);
	lightmap.r = pow(lightmap.r, 0.25);

	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(lightmap.rg, 0.0, tex.a * 5.0);
	gl_FragData[2] = vec4(EncodeNormal(texNormal), 0.0, tex.a);

	gl_FragData[3] = vec4(1.0, 0.0, (matID) / 255.0, tex.a * 5.0);
	gl_FragData[4] = vec4(transparentAlbedo);

}
