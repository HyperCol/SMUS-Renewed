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

#define BLOOM_ENABLED

#define BLOOM_AMOUNT 1.0 // Amount of bloom to apply to the image. [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define MICRO_BLOOM // Very fine-scale bloom. Very bright areas will have a fine-scale bleed-over to dark areas.

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////

/* DRAWBUFFERS:6 */



uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gaux1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux3;
uniform sampler2D noisetex;

varying vec4 texcoord;
varying vec3 lightVector;

uniform int worldTime;
uniform float sunAngle;
uniform float shadowAngle;

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

#include "/Common.inc"


float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

vec4 cubic(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord)
{

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    fx -= 0.5;
    fy -= 0.5;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec3 GetBloomTap(vec2 coord, const float octave, const vec2 offset)
{
	float scale = exp2(octave);

	coord /= scale;
	coord -= offset;

	return GammaToLinear(BicubicTexture(gaux1, coord).rgb);
}

vec2 CalcOffset(float octave)
{
    vec2 offset = vec2(0.0);

    vec2 padding = vec2(30.0) * texel;

    offset.x = -min(1.0, floor(octave / 3.0)) * (0.25 + padding.x);

    offset.y = -(1.0 - (1.0 / exp2(octave))) - padding.y * octave;

	offset.y += min(1.0, floor(octave / 3.0)) * 0.35;

 	return offset;
}



vec3 GetBloom(vec2 coord)
{
	vec3 bloom = vec3(0.0);

	bloom += GetBloomTap(coord, 1.0, CalcOffset(0.0)) * 2.0;
	bloom += GetBloomTap(coord, 2.0, CalcOffset(1.0)) * 1.5;
	bloom += GetBloomTap(coord, 3.0, CalcOffset(2.0)) * 1.2;
	bloom += GetBloomTap(coord, 4.0, CalcOffset(3.0)) * 1.3;
	bloom += GetBloomTap(coord, 5.0, CalcOffset(4.0)) * 1.4;
	bloom += GetBloomTap(coord, 6.0, CalcOffset(5.0)) * 1.5;
	bloom += GetBloomTap(coord, 7.0, CalcOffset(6.0)) * 1.6;
	bloom += GetBloomTap(coord, 8.0, CalcOffset(7.0)) * 1.7;
	bloom += GetBloomTap(coord, 9.0, CalcOffset(8.0)) * 0.4;

	bloom /= 12.6;


	//bloom = mix(bloom, vec3(dot(bloom, vec3(0.3333))), vec3(-0.1));
	//bloom = mix(bloom, vec3(dot(bloom, vec3(0.3333))), vec3(0.1));

	//bloom = length(bloom) * pow(normalize(bloom + 0.00001), vec3(1.5));

	return bloom;
}

void FogScatter(inout vec3 color, in vec3 bloomData)
{
	float linearDepth = GetDepthLinear(texcoord.st);
	float ifIsInWater = saturate(float(isEyeInWater));

	float fogDensity = 0.0125 * rainStrength * (1.0 - ifIsInWater);
	fogDensity += ifIsInWater * 0.75;

	float visibility = 1.0 / (pow(exp(linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0 - visibility;
		  fogFactor = saturate(fogFactor);

	fogFactor *= 1.0 + ifIsInWater * (mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f)) - 1.0);

	color = mix(color, bloomData, vec3((0.08 + fogFactor) * BLOOM_AMOUNT));
}

void MicroBloom(inout vec3 color, in vec2 uv)
{

	vec3 bloom = vec3(0.0);
	float allWeights = 0.0f;

	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 4; j++)
		{
			float weight = 1.0f - distance(vec2(i, j), vec2(2.5f)) / 2.5;
				  weight = clamp(weight, 0.0f, 1.0f);
				  weight = 1.0f - cos(weight * 3.1415 / 2.0f);
				  weight = pow(weight, 2.0f);
			vec2 coord = vec2(i - 2.5, j - 2.5);
				 coord *= texel;

			vec2 finalCoord = (uv.st + coord.st * 1.0);

			if (weight > 0.0f)
			{
				bloom += pow(clamp(texture2DLod(gaux3, finalCoord, 0).rgb, vec3(0.0f), vec3(1.0f)), vec3(2.2f)) * weight;
				allWeights += 1.0f * weight;
			}
		}
	}
	bloom /= allWeights;

	color = mix(color, bloom, vec3(0.35));
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 color = GammaToLinear(texture2DLod(gaux3, texcoord.st, 0).rgb);

	//color = mix(color, GetBloom(coord.st), vec3(0.16 * BLOOM_AMOUNT + isEyeInWater * 0.7));
#ifdef BLOOM_ENABLED
	vec3 bloomData = GetBloom(texcoord.st);
	FogScatter(color, bloomData);

	#ifdef MICRO_BLOOM
		MicroBloom(color, texcoord.st);
	#endif
#endif


	color = LinearToGamma(color);

	gl_FragData[0] = vec4(color, 1.0);

}
