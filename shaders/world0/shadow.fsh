#version 120

#define TRANSLUCENT_SHADOWS // Translucent shadows.

#define WAVE_CAUSTICS_SAMPLES 3 // Higher is better, but costs more performance. [2 3 4 5]

uniform sampler2D tex;
uniform vec3 cameraPosition;
uniform sampler2D noisetex;
uniform float wetness;
uniform float nightVision;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float shadowAngle;

uniform float rainStrength;
uniform int isEyeInWater;

varying vec4 texcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 rawNormal;
varying vec4 shadowSpacePos;

varying float materialIDs;
varying float isice;
varying float iswater;
varying float isStainedGlass;
varying float isSlimeBlock;

varying vec4 lmcoord;

#include "/Common.inc"

#include "/lib/Waves.glsl"

vec3 GetWavesNormal(vec3 position) {

	const float sampleDistance = 13.0f;

	position -= vec3(0.005f, 0.0f, 0.005f) * sampleDistance;

	float wavesCenter = GetWaves(position, WAVE_CAUSTICS_SAMPLES, 1);
	float wavesLeft = GetWaves(position + vec3(0.01f * sampleDistance, 0.0f, 0.0f), WAVE_CAUSTICS_SAMPLES, 1);
	float wavesUp   = GetWaves(position + vec3(0.0f, 0.0f, 0.01f * sampleDistance), WAVE_CAUSTICS_SAMPLES, 1);

	vec3 wavesNormal;
		 wavesNormal.r = wavesCenter - wavesLeft;
		 wavesNormal.g = wavesCenter - wavesUp;

		 wavesNormal.rg *= 20.0 / sampleDistance;


    wavesNormal.b = 1.0;
	wavesNormal.rgb = normalize(wavesNormal.rgb);



	return wavesNormal.rgb;
}

vec4 GetCausticsMap(vec3 pos)
{
	vec3 wavesNorm = GetWavesNormal(pos).xzy;
	vec3 rayVec = vec3(0.0, 1.0, 0.0);

	vec3 refractVec = refract(rayVec, wavesNorm, 1.3333);

	float dist = dot(refractVec, pos) * 0.01;

	float caustics = saturate(dist * dist);
	return vec4(wavesNorm.xzy, caustics * caustics);
}

void main() {

	vec4 tex = texture2D(tex, texcoord.st, 0) * color;

	//Fix wrong normals on some entities
	float skylight = saturate((lmcoord.t * 33.05 - 1.05) * 0.03125);



	vec3 shadowNormal = normal.xyz;

	float na = skylight * 0.8 + 0.2;

	if (isStainedGlass > 0.5 || isSlimeBlock > 0.5)
	{
		tex.rgb *= 0.55;
		na = 0.1;
	}

#ifdef TRANSLUCENT_SHADOWS
	if (iswater > 0.5)
	{
		vec4 caustics = GetCausticsMap(shadowSpacePos.xyz + cameraPosition);
			 caustics.a = saturate(caustics.a);
		tex.rgb = vec3(caustics.a);
		shadowNormal = caustics.xyz;
		na = 40.0 / 255.0;
	}
#endif

	if (isice > 0.5)
	{
		tex.rgb = vec3(0.1, 0.3, 0.5);
		na = 0.1;
	}

	if (normal.z < 0.0)
	{
		tex.rgb = vec3(0.0);
	}

	gl_FragData[0] = vec4(tex.rgb, tex.a);
	gl_FragData[1] = vec4(shadowNormal.xyz * 0.5 + 0.5, na);
}
