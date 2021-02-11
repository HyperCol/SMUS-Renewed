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


/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define MOTION_BLUR // Motion blur. Makes motion look blurry.
	#define MOTION_BLUR_SAMPLES 4.0  //Motion blur samples. [4.0 8.0 16.0 24.0 32.0 48.0 64.0 128.0 256.0 512.0 1024.0]
	#define MOTIONBLUR_STRENGTH 1.0		// Default is 1.0. [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0]
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////

/* DRAWBUFFERS:67 */



uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux3;
uniform sampler2D noisetex;

varying vec4 texcoord;
varying vec3 lightVector;

uniform int worldTime;

uniform float near;
uniform float far;
uniform vec2 resolution;
uniform vec2 texel;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

uniform float frameTime;

uniform float nightVision;

#include "Common.inc"

vec3 GetColorTexture(vec2 coord)
{
	return GammaToLinear(texture2DLod(gaux3, coord, 0.0).rgb);
}

void 	MotionBlur(inout vec3 color)
{
	float depth1 = texture2D(depthtex1, texcoord.st).x;
	float depth2 = texture2D(depthtex2, texcoord.st).x;

	if(depth2 > depth1)
	{
		color = GetColorTexture(texcoord.st);
		return;
	}

	vec4 currentPosition = vec4(texcoord.st * 2.0 - 1.0, depth2 * 2.0 - 1.0, 1.0);

	vec4 fragposition = gbufferProjectionInverse * currentPosition;
	fragposition = gbufferModelViewInverse * fragposition;
	fragposition /= fragposition.w;
	fragposition.xyz += cameraPosition;

	vec4 previousPosition = fragposition;
	previousPosition.xyz -= previousCameraPosition;
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	previousPosition /= previousPosition.w;

	float intensity = MOTIONBLUR_STRENGTH * 0.5;
	vec2 velocity = currentPosition.xy - previousPosition.xy;
		 velocity = (exp(abs(velocity)) - 1.0) * sign(velocity) * intensity;

	if(length(velocity) < 0.00001)
	{
		color = GetColorTexture(texcoord.st);
		return;
	}

	float dither = rand(texcoord.st).x * 1.0;

	color.rgb = vec3(0.0);

	float samples = MOTION_BLUR_SAMPLES;

	for (float i = 0.0; i < samples; i++) {
		vec2 coord = texcoord.st + velocity * ((i + dither) / samples);
			 coord = saturate(coord);

		color += GetColorTexture(coord);
	}

	color.rgb /= samples;


}


/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 color = vec3(0.0);

	#ifdef MOTION_BLUR
		MotionBlur(color);
	#else
		color = GetColorTexture(texcoord.st);
	#endif




	color = LinearToGamma(color);

	gl_FragData[0] = vec4(color, 1.0);
	//Write color for previous frame here
	gl_FragData[1] = texture2D(gaux3, texcoord.st).rgba;

}
