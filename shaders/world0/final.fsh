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

#define EXPOSURE 1.0 // Controls overall brightness/exposure of the image. Higher values give a brighter image. Default: 1.0 [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define GAMMA 1.0 // Gamma adjust. Lower values make shadows darker. Higher values make shadows brighter. Default: 1.0 [0.7 0.8 0.9 1.0 1.1 1.2 1.3]

#define LUMA_GAMMA 1.0 // Gamma adjust of luminance only. Preserves colors while adjusting contrast. Lower values make shadows darker. Higher values make shadows brighter. Default: 1.0 [0.7 0.8 0.9 1.0 1.1 1.2 1.3]

#define SATURATION 1.0 // Saturation adjust. Higher values give a more colorful image. Default: 1.0 [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]

#define WHITE_CLIP 0.0 // Higher values will introduce clipping to white on the highlights of the image. [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]

#define BLOOM_ENABLED

#define BLOOM_AMOUNT 1.0 // Amount of bloom to apply to the image. [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define MICRO_BLOOM // Very fine-scale bloom. Very bright areas will have a fine-scale bleed-over to dark areas.

#define TONEMAP_OPERATOR UchimuraTonemap // Each tonemap operator defines a different way to present the raw internal HDR color information to a color range that fits nicely with the limited range of monitors/displays. Each operator gives a different feel to the overall final image. [SEUSTonemap UchimuraTonemap HableTonemap ACESTonemap ACESTonemap2]

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////


uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
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

varying float avgSkyBrightness;

uniform vec3 skyColor;


uniform float nightVision;

#include "Common.inc"

const float overlap = 0.2;

const float rgOverlap = 0.1 * overlap;
const float rbOverlap = 0.01 * overlap;
const float gbOverlap = 0.04 * overlap;

const mat3 coneOverlap = mat3(1.0, 			rgOverlap, 	rbOverlap,
							  rgOverlap, 	1.0, 		gbOverlap,
							  rbOverlap, 	rgOverlap, 	1.0);

const mat3 coneOverlapInverse = mat3(	1.0 + (rgOverlap + rbOverlap), 			-rgOverlap, 	-rbOverlap,
									  	-rgOverlap, 		1.0 + (rgOverlap + gbOverlap), 		-gbOverlap,
									  	-rbOverlap, 		-rgOverlap, 	1.0 + (rbOverlap + rgOverlap));











vec3 SEUSTonemap(vec3 color)
{
	color = color * coneOverlap;



	const float p = 5.0;
	color = pow(color, vec3(p));
	color = color / (1.0 + color);
	color = pow(color, vec3(1.0 / p));


	// color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.0));

	//color = pow(color, vec3(1.0 / 2.0));
	//color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.1));
	//color = pow(color, vec3(2.0));

	//color = color * 0.5 + 0.5;
	//color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.8));
	//color = saturate(color * 2.0 - 1.0);

	color = color * coneOverlapInverse;
	color = saturate(color);


	// color.r = almostIdentity(color.r, 0.05, 0.0);
	// color.g = almostIdentity(color.g, 0.05, 0.0);
	// color.b = almostIdentity(color.b, 0.05, 0.0);

	return color;
}

/////////////////////////////////////////////////////////////////////////////////

// Uchimura 2017, "HDR theory and practice"
// Math: https://www.desmos.com/calculator/gslcdxvipg
// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
// Modified by Satellite.
vec3 UchimuraTonemap(vec3 color) {
    const float maxDisplayBrightness = 0.9;   // max display brightness Default:1.2
    const float contrast             = 1.0;   // contrast Default:0.625
    const float linearStart          = 0.175;  // linear section start Default:0.1
    const float linearLength         = 0.25;    // linear section length Default:0.0
    const float black                = 1.25;  // black Default:1.33
    const float pedestal             = 0.0;    // pedestal

    float l0 = ((maxDisplayBrightness - linearStart) * linearLength) / contrast;
    float L0 = linearStart - linearStart / contrast;
    float L1 = linearStart + (1.0 - linearStart) / contrast;
    float S0 = linearStart + l0;
    float S1 = linearStart + contrast * l0;
    float C2 = (contrast * maxDisplayBrightness) / (maxDisplayBrightness - S1);
    float CP = -C2 / maxDisplayBrightness;

    vec3 w0 = 1.0 - smoothstep(0.0, linearStart, color);
    vec3 w2 = step(linearStart + l0, color);
    vec3 w1 = 1.0 - w0 - w2;

	vec3 T = linearStart * pow(color / vec3(linearStart), vec3(black)) + vec3(pedestal);
    vec3 S = maxDisplayBrightness - (maxDisplayBrightness - S1) * exp(CP * (color - S0));
    vec3 L = linearStart + contrast * (color - linearStart);

	color = color * coneOverlap;

    color = T * w0 + L * w1 + S * w2;

	// Clamp to [0, 1]
	color = color * coneOverlapInverse;
    color = saturate(color);

	return color;
}

/////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////
// Tonemapping by John Hable
vec3 HableTonemap(vec3 x)
{

	x = x * coneOverlap;

	x *= 1.5;

	const float A = 0.15;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.00;
	const float F = 0.30;

	x = pow(x, vec3(5.0));

   	vec3 result = pow((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F), vec3(1.0 / 5.0))-E/F;
   	result = saturate(result);


   	result = result * coneOverlapInverse;

   	return result;
}
/////////////////////////////////////////////////////////////////////////////////



/////////////////////////////////////////////////////////////////////////////////
//	ACES Fitting by Stephen Hill
vec3 RRTAndODTFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (1.0f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec3 ACESTonemap2(vec3 color)
{
	color *= 1.5;
	color = color * coneOverlap;

    // Apply RRT and ODT
    color = RRTAndODTFit(color);


    // Clamp to [0, 1]
	color = color * coneOverlapInverse;
    color = saturate(color);

    return color;
}
/////////////////////////////////////////////////////////////////////////////////











vec3 ACESTonemap(vec3 color)
{
	color = color * coneOverlap;

	color = (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);

	color = color * coneOverlapInverse;

	color = saturate(color);


	return color;
}

vec3 Tonemap2(vec3 color)
{
	color *= 1.3;

	const float p = 2.9;
	color = pow(color, vec3(p));
	color = color / (1.0 + color);
	color = pow(color, vec3(1.0 / p));


	color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.0));

	color = pow(color, vec3(1.0 / 2.0));
	color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.1));
	color = pow(color, vec3(2.0));

	//color = color * 0.5 + 0.5;
	//color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.8));
	//color = saturate(color * 2.0 - 1.0);






	return color;
}



vec3 	CalculateNoisePattern1(vec2 offset, float size)
{
	vec2 coord = texcoord.st;

	coord *= resolution;
	coord = mod(coord + offset, vec2(size));
	coord /= 64.0;

	return texture2D(noisetex, coord).xyz;
}

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
	float ifIsInWater = saturate(isEyeInWater);

	float fogDensity = 0.0125 * rainStrength * (1.0 - ifIsInWater);
	fogDensity += ifIsInWater * 0.5;

	float visibility = 1.0 / (pow(exp(linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0 - visibility;
		  fogFactor = saturate(fogFactor);

	fogFactor *= 1.0 + ifIsInWater * (mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f)) - 1.0);

	color = mix(color, bloomData, vec3((0.08 + fogFactor) * BLOOM_AMOUNT));
}

void CalculateExposureEyeBrightness(inout vec3 color)
{
	float exposureMax = 1.55f;
		  //exposureMax *= mix(1.0f, 0.25f, timeSunriseSunset);
		  //exposureMax *= mix(1.0f, 0.0f, timeMidnight);
		  //exposureMax *= mix(1.0f, 0.25f, rainStrength);
		  exposureMax *= avgSkyBrightness * 2.0;
	float exposureMin = 0.07f;
	float exposure = pow(eyeBrightnessSmooth.y / 240.0f, 6.0f) * exposureMax + exposureMin;

	//exposure = 1.0f;

	color.rgb /= vec3(exposure);
	color.rgb *= 350.0;
}

void AverageExposure(inout vec3 color)
{
	float avglod = int(log2(min(resolution.x, resolution.y))) - 0;
	//color /= pow(Luminance(texture2DLod(gaux3, vec2(0.5, 0.5), avglod).rgb), 1.18) * 1.2 + 0.00000005;

	float avgLumPow = 1.1;
	float exposureMax = 0.9;
	float exposureMin = 0.00005;

	color /= pow(Luminance(texture2DLod(gaux3, vec2(0.5, 0.5), avglod).rgb), avgLumPow) * exposureMax + exposureMin;
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

void 	Vignette(inout vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
		  dist /= 1.5142f;

		  //dist = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist * 0.5;

}

void DoNightEye(inout vec3 color)
{
	float lum = Luminance(color * vec3(1.0, 1.0, 1.0));
	float mixSize = 1250000.0;
	float mixFactor = 0.01 / (pow(lum * mixSize, 2.0) + 0.01);


	vec3 nightColor = mix(color, vec3(lum), vec3(0.9)) * vec3(0.25, 0.5, 1.0) * 2.0;

	color = mix(color, nightColor, mixFactor);
}

void Overlay(inout vec3 color, vec3 overlayColor)
{
	vec3 overlay = vec3(0.0);

	for (int i = 0; i < 3; i++)
	{
		if (color[i] > 0.5)
		{
			float valueUnit = (1.0 - color[i]) / 0.5;
			float minValue = color[i] - (1.0 - color[i]);
			overlay[i] = (overlayColor[i] * valueUnit) + minValue;
		}
		else
		{
			float valueUnit = color[i] / 0.5;
			overlay[i] = overlayColor[i] * valueUnit;
		}
	}

	color = overlay;
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {
	vec2 coord = texcoord.st;

	vec3 color = GammaToLinear(texture2DLod(gaux3, coord.st, 0).rgb);


	//color = mix(color, GetBloom(coord.st), vec3(0.16 * BLOOM_AMOUNT + isEyeInWater * 0.7));
#ifdef BLOOM_ENABLED
	vec3 bloomData = GetBloom(texcoord.st);
	FogScatter(color, bloomData);

	#ifdef MICRO_BLOOM
		MicroBloom(color, coord);
	#endif
#endif


	AverageExposure(color);

	// color = pow(color, vec3(0.8));

	color *= 34.0 * EXPOSURE;


	color = TONEMAP_OPERATOR(color);

	color = pow(length(color), 1.0 / LUMA_GAMMA) * normalize(color + 0.00001);

	color = saturate(color * (1.0 + WHITE_CLIP));


	color = pow(color, vec3(1.0 / 2.2));
	color = pow(color, vec3((1.0 / GAMMA)));


	color = mix(color, vec3(Luminance(color)), vec3(1.0 - SATURATION));





	//color += rand(coord.st) * (1.0 / 255.0);



	// color = (floor(color * 16.0)) / 16.0;

	// color = texture2D(shadowcolor0, texcoord.st).rgb;


	gl_FragColor = vec4(color.rgb, 1.0f);

}
