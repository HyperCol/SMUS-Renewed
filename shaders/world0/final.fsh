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

#define MOTION_BLUR // Motion blur. Makes motion look blurry.
	//#define MOTION_BLUR_PVP_MODE
	#define MOTION_BLUR_SAMPLES 8.0  //Motion blur samples. [4.0 8.0 16.0 24.0 32.0 48.0 64.0 128.0 256.0 512.0 1024.0]
	#define MOTIONBLUR_STRENGTH 1.0		// Default is 1.0. [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0]

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
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

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

#include "/Common.inc"

const mat3 coneOverlap = mat3(1.0, 	 0.02, 0.002,
							  0.02,  1.0,  0.002,
							  0.002, 0.02, 1.0);

const mat3 coneOverlapInverse = mat3( 1.022, -0.02,  -0.002,
									 -0.02,   1.022, -0.002,
									 -0.002, -0.02,   1.022);











vec3 SEUSTonemap(vec3 color)
{
	color = color * coneOverlap;


	color = pow(color, vec3(5.0));
	color = color / (1.0 + color);
	color = pow(color, vec3(0.2));

	color = color * coneOverlapInverse;
	color = saturate(color);

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
    const float linearStart          = 0.5;  // linear section start Default:0.1
    const float linearLength         = 0.0;    // linear section length Default:0.0
    const float black                = 1.0;  // black Default:1.33
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

	//color = color * coneOverlap;

    color = T * w0 + L * w1 + S * w2;

	// Clamp to [0, 1]
	//color = color * coneOverlapInverse;
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
    vec3 a = v * (v + 0.0245786f) - 0.000090537;
    vec3 b = v * (1.0f * v + 0.4329510f) + 0.238081;
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

vec3 	CalculateNoisePattern1(vec2 offset, float size)
{
	vec2 coord = texcoord.st;

	coord *= resolution;
	coord = mod(coord + offset, vec2(size));
	coord /= 64.0;

	return texture2D(noisetex, coord).xyz;
}

void 	MotionBlur(inout vec3 color)
{
	float depth1 = texture2D(depthtex1, texcoord.st).x;
	float depth2 = texture2D(depthtex2, texcoord.st).x;

	if(depth2 > depth1)
	{
		return;
	}

	vec4 currentPosition = vec4(texcoord.st * 2.0 - 1.0, depth2 * 2.0 - 1.0, 1.0);

	vec4 fragposition = gbufferProjectionInverse * currentPosition;
		 fragposition = gbufferModelViewInverse * fragposition;
	fragposition.xyz /= fragposition.w;
	fragposition.xyz += cameraPosition;

	vec4 previousPosition = fragposition;
	previousPosition.xyz -= previousCameraPosition;
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	previousPosition.xyz /= previousPosition.w;

	float intensity = MOTIONBLUR_STRENGTH * 0.125;
	vec2 velocity = currentPosition.xy - previousPosition.xy;

#ifdef MOTION_BLUR_PVP_MODE
	float blurAmount = intensity * 0.08;
	velocity *= clamp(length(velocity), -blurAmount, blurAmount) / length(velocity);
#endif

	if(length(velocity) < 0.00001)
	{
		return;
	}

	float dither = rand(texcoord.st).x;

	float samples = MOTION_BLUR_SAMPLES;
	float count = 1.0;

	while(count < samples) {
		vec2 coord = texcoord.st + velocity * ((count + dither) / samples);

		if(coord != saturate(coord))
		{
			break;
		}

		color += GammaToLinear(texture2DLod(gaux3, coord, 0.0).rgb);
		count++;
	}

	color.rgb /= count;


}

void AverageExposure(inout vec3 color)
{
	float avglod = log2(min(resolution.x, resolution.y) * 0.625);

	float exposureMax = 16.0;
	float exposureMin = 0.0;
	float exposureAvg = 0.375;

	float exposure = Luminance(GammaToLinear(texture2DLod(gaux3, vec2(0.5), avglod).rgb) * 40000.0);
		  exposure = clamp(1.0 / exposure, exposureMin, exposureMax);

	color *= exposure * 40000.0 * exposureAvg;
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
	#ifdef MOTION_BLUR
		MotionBlur(color);
	#endif

	AverageExposure(color);


	color = TONEMAP_OPERATOR(color);

	color = pow(length(color), 1.0 / LUMA_GAMMA) * normalize(color + 0.00001);

	color = saturate(color * (1.0 + WHITE_CLIP));


	color = pow(color, vec3(1.0 / 2.2));
	color = pow(color, vec3((1.0 / GAMMA)));


	color = mix(color, vec3(Luminance(color)), vec3(1.0 - SATURATION));


	gl_FragColor = vec4(color.rgb, 1.0f);

}
