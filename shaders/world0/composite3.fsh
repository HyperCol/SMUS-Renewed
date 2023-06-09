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

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.
	#define HQ_TAA
	//#define TAA_AGGRESSIVE // Makes Temporal Anti-Aliasing more generously blend previous frames. This results in a more stable and smoother image, but causes more noticeable artifacts with movement.


#define TAA_SOFTNESS 0.0 // Softness of temporal anti-aliasing. Default 0.0 [0.0 0.2 0.4 0.6 0.8 1.0]
#define SHARPENING 0.7 // Sharpening of the image. Default 0.0 [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0]
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////

/* DRAWBUFFERS:67 */



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

uniform float frameTime;

uniform float taaStrength;

uniform float nightVision;

#include "/Common.inc"

float 	ExpToLinearDepth(in float depth)
{
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

vec2 GetNearFragment(vec2 coord, float depth, out float minDepth)
{
	vec4 depthSamples;
	depthSamples.x = texture2D(gdepthtex, coord + texel * vec2(1.0, 1.0)).x;
	depthSamples.y = texture2D(gdepthtex, coord + texel * vec2(1.0, -1.0)).x;
	depthSamples.z = texture2D(gdepthtex, coord + texel * vec2(-1.0, 1.0)).x;
	depthSamples.w = texture2D(gdepthtex, coord + texel * vec2(-1.0, -1.0)).x;

	vec2 targetFragment = vec2(0.0, 0.0);

	if     (depthSamples.w < depth) targetFragment = vec2(-1.0, -1.0);
	else if(depthSamples.z < depth) targetFragment = vec2(-1.0, 1.0);
	else if(depthSamples.y < depth) targetFragment = vec2(1.0, -1.0);
	else if(depthSamples.x < depth) targetFragment = vec2(1.0, 1.0);

	minDepth = min(min(min(depthSamples.x, depthSamples.y), depthSamples.z), depthSamples.w);

	return coord + texel * targetFragment;
}

vec3 RGBToYUV(vec3 color)
{
	mat3 mat = 		mat3( 0.2126,  0.7152,  0.0722,
				 	-0.09991, -0.33609,  0.436,
				 	 0.615, -0.55861, -0.05639);

	return color * mat;
}

vec3 YUVToRGB(vec3 color)
{
	mat3 mat = 		mat3(1.000,  0.000,  1.28033,
				 	1.000, -0.21482, -0.38059,
				 	1.000,  2.12798,  0.000);

	return color * mat;
}

vec3 ClipAABB(vec3 q, vec3 aabbMin, vec3 aabbMax)
{
	vec3 pClip = 0.5 * (aabbMax + aabbMin);
	vec3 eClip = 0.5 * (aabbMax - aabbMin);

	vec3 vClip = q - pClip;
	vec3 vUnit = vClip / eClip;
	vec3 aUnit = abs(vUnit);
	float maxUnit = max(aUnit.x, max(aUnit.y, aUnit.z));

	if (maxUnit > 1.0)
	{
		return pClip + vClip / maxUnit;
	}
	else
	{
		return q;
	}
}

// From "Filmic SMAA Sharp Morphological and Temporal Antialiasing" by Jorge Jimenez
// http://www.klayge.org/material/4_11/Filmic%20SMAA%20v7.pdf
vec4 SMAAFitter(sampler2D prevColorBuf, vec2 coord){
	vec2 pos = coord.st * resolution;
	vec2 centerPos = floor(pos - vec2(0.5f)) + vec2(0.5f);
	vec2 f = pos - centerPos;
	vec2 f2 = f * f;
	vec2 f3 = f * f2;

	float sharpness = SHARPENING; // Pre frame SMAA reprojection sharpness
	vec2 w0 =        -sharpness  * f3 + (      sharpness * 2.0) * f2 - sharpness * f;
	vec2 w1 =  (2.0 - sharpness) * f3 - (3.0 - sharpness      ) * f2 + 1.0;
	vec2 w2 = -(2.0 - sharpness) * f3 + (3.0 - sharpness * 2.0) * f2 + sharpness * f;
	vec2 w3 =         sharpness  * f3 -        sharpness        * f2;

	vec2 w12 = w1 + w2;
	vec2 tc12 = texel * (centerPos + w2 / w12);
	vec4 centerColor = texture2D(prevColorBuf, vec2(tc12.x, tc12.y));

	vec2 tc0 = texel * (centerPos - vec2(1.0));
	vec2 tc3 = texel * (centerPos + vec2(2.0));
	vec4 color = vec4(texture2D(prevColorBuf, vec2(tc12.x, tc0.y )).rgb, 1.0) * (w12.x * w0.y ) +
				 vec4(texture2D(prevColorBuf, vec2(tc0.x , tc12.y)).rgb, 1.0) * (w0.x  * w12.y) +
				 vec4(centerColor.rgb                                  , 1.0) * (w12.x * w12.y) +
				 vec4(texture2D(prevColorBuf, vec2(tc3.x , tc12.y)).rgb, 1.0) * (w3.x  * w12.y) +
				 vec4(texture2D(prevColorBuf, vec2(tc12.x, tc3.y )).rgb, 1.0) * (w12.x * w3.y );

	return vec4(max(vec3(0.0), color.rgb / color.a), centerColor.a);
}

#define COLORPOW 1.0

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	//vec3 color = GammaToLinear(texture2D(gaux3, texcoord.st).rgb);


	//color += rand(texcoord.st) * (1.0 / 255.0);

	//Combine TAA here...
	vec3 color = pow(texture2D(gaux3, texcoord.st).rgb, vec3(COLORPOW));	//Sample color texture
	vec3 origColor = color;


	#ifdef TAA_ENABLED


	float depth = texture2D(gdepthtex, texcoord.st).x;

	float minDepth;

	vec2 nearFragment = GetNearFragment(texcoord.st, depth, minDepth);

	float nearDepth = texture2D(gdepthtex, nearFragment).x;

	vec4 projPos = vec4(texcoord.st * 2.0 - 1.0, nearDepth * 2.0 - 1.0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * projPos;
	viewPos.xyz /= viewPos.w;

	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos.xyz, 1.0);

	vec4 worldPosPrev = worldPos;
	worldPosPrev.xyz += cameraPosition - previousCameraPosition;

	vec4 viewPosPrev = gbufferPreviousModelView * vec4(worldPosPrev.xyz, 1.0);
	vec4 projPosPrev = gbufferPreviousProjection * vec4(viewPosPrev.xyz, 1.0);
	projPosPrev.xyz /= projPosPrev.w;

	vec2 motionVector = projPos.xy - projPosPrev.xy;

	float motionVectorMagnitude = length(motionVector) * 10.0;
	float pixelMotionFactor = clamp(motionVectorMagnitude * 500.0, 0.0, 1.0);

	vec2 reprojCoord = texcoord.st - motionVector.xy * 0.5;
	reprojCoord = depth < 0.7 ? texcoord.st : reprojCoord; 		//Don't reproject hand

	vec2 pixelError = cos((fract(abs(texcoord.st - reprojCoord.xy) * resolution) * 2.0 - 1.0) * 3.14159) * 0.5 + 0.5;
	vec2 pixelErrorFactor = sqrt(pixelError);


	vec4 prevColor = pow(SMAAFitter(gaux4, reprojCoord.st), vec4(COLORPOW, COLORPOW, COLORPOW, 1.0));
	float prevMinDepth = prevColor.a;

	float motionVectorDiff = abs(motionVectorMagnitude - prevColor.a);


	vec3 minColor = vec3(1000000.0);
	vec3 maxColor = vec3(0.0);
	vec3 avgColor = vec3(0.0);
	vec3 avgX = vec3(0.0);
	vec3 avgY = vec3(0.0);

	vec3 m1 = vec3(0.0);
	vec3 m2 = vec3(0.0);

	///*
	for(int count = 0; count < 9; count++)
	{
		float i = mod(float(count), 3.0) - 1.0;
		float j = floor(float(count) / 3.0) - 1.0;

		vec2 offs = vec2(i, j) * texel * taaStrength;
		vec3 samp = pow(texture2D(gaux3, texcoord.xy + offs).rgb, vec3(COLORPOW));
		minColor = min(minColor, samp);
		maxColor = max(maxColor, samp);
		avgColor += samp;

		if (j == 0)
		{
			avgX += samp;
		}

		if (i == 0)
		{
			avgY += samp;
		}

		samp = (RGBToYUV(samp));

		m1 += samp;
		m2 += samp * samp;

	}
	avgColor /= 9.0;
	avgX /= 3.0;
	avgY /= 3.0;

#ifdef HQ_TAA
	#ifdef TAA_AGGRESSIVE
		float colorWindow = 4.0;
		vec3 blendWeight = vec3(0.115);
	#else
		float colorWindow = 1.75;
		vec3 blendWeight = vec3(0.1);
	#endif
#else
	#ifdef TAA_AGGRESSIVE
		float colorWindow = 1.9;
		vec3 blendWeight = vec3(0.015);
	#else
		float colorWindow = 1.5;
		vec3 blendWeight = vec3(0.05);
	#endif
#endif

	vec3 mu = m1 / 9.0;
	vec3 sigma = sqrt(max(vec3(0.0), m2 / 9.0 - mu * mu));
	vec3 minc = mu - colorWindow * sigma;
	vec3 maxc = mu + colorWindow * sigma;


	//adaptive sharpen
	vec3 sharpen = (vec3(1.0) - exp(-(color - avgColor) * 15.0)) * 0.06;
	vec3 sharpenX = (vec3(1.0) - exp(-(color - avgX) * 15.0)) * 0.06;
	vec3 sharpenY = (vec3(1.0) - exp(-(color - avgY) * 15.0)) * 0.06;
	color += sharpenX * (0.1 / blendWeight) * pixelErrorFactor.x;
	color += sharpenY * (0.1 / blendWeight) * pixelErrorFactor.y;



	color += clamp(sharpen, -vec3(0.0005), vec3(0.0005)) * SHARPENING * 4.0;



	color = mix(color, avgColor, vec3(TAA_SOFTNESS));

	prevColor.rgb = YUVToRGB(ClipAABB(RGBToYUV(prevColor.rgb), minc, maxc));




	blendWeight += vec3(pixelMotionFactor * 0.0);


	blendWeight = saturate(blendWeight);



	vec3 taa = mix(prevColor.rgb, color, blendWeight);
		 taa = pow(taa, vec3(1.0 / COLORPOW));

	#else

	vec3 taa = color.rgb;

	#endif

	gl_FragData[0] = vec4(taa, 1.0);
	gl_FragData[1] = vec4(vec3(0.0), 1.0f);

}
