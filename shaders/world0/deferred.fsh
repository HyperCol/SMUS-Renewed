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
#define SHADOW_MAP_BIAS 0.90

/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////




#define ENABLE_SSAO	// Screen space ambient occlusion.
#define GI	// Indirect lighting from sunlight.

#define AO_SAMPLES 4  // AO samples. [4 8 16 24 32 48 64 72 100 128 256]

#define GI_QUALITY 1.0 // Number of GI samples. More samples=smoother GI. High performance impact! [0.5 1.0 2.0 4.0 6.0 8.0 16.0 32.0 64.0]
#define GI_RENDER_RESOLUTION 1 // Render resolution of GI. 0 = High. 1 = Low. Set to 1 for faster but blurrier GI. [0 1]
#define GI_RADIUS 1.0 // How far indirect light can spread. Can help to reduce artifacts with low GI samples. [0.5 0.75 1.0 1.5 2.0]
#define GI_BRIGHTNESS 250 // This will increase the GI brightness and Bounce. Default: 500. [100 150 200 250 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000]
//#define GI_SATURATION 1.125f // Default: 1.375f

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.

/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const float 	shadowDistance 			= 120.0; // Shadow distance. Set lower if you prefer nicer close shadows. Set higher if you prefer nicer distant shadows. [80.0 120.0 180.0 240.0 320.0 480.0]

const int 		noiseTextureResolution  = 64;


//END OF INTERNAL VARIABLES//

/* DRAWBUFFERS:6 */

uniform sampler2D gnormal;
uniform sampler2D depthtex1;
uniform sampler2D composite;
uniform sampler2D gdepth;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex1;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

varying vec4 texcoord;
varying vec3 lightVector;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;

uniform float near;
uniform float far;
uniform vec2 resolution;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float shadowAngle;
uniform vec3 skyColor;
uniform vec3 cameraPosition;

uniform float eyeAltitude;

varying vec3 upVector;

uniform vec2 taaJitter;
uniform float taaStrength;

uniform float nightVision;

#include "/Common.inc"

/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return DecodeNormal(texture2D(gnormal, coord).xy);
}

float 	GetDepth(in vec2 coord) {
	return texture2D(depthtex1, coord.st).x;
}

vec4  	GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4  	GetScreenSpacePosition(in vec2 coord, in float depth) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}


vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= resolution;
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}

vec2 DistortShadowSpace(in vec2 pos)
{
	vec2 signedPos = pos * 2.0f - 1.0f;

	float dist = length(signedPos.xy);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	signedPos.xy *= 0.95 / distortFactor;

	pos = signedPos * 0.5f + 0.5f;

	return pos;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(composite, coord).b;
}

float GetSkylight(in vec2 coord)
{
	return texture2DLod(gdepth, coord, 0).g;
}

float 	GetMaterialMask(in vec2 coord, const in int ID) {
	float matID = (GetMaterialIDs(coord) * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}

bool 	GetSkyMask(in vec2 coord)
{
	float matID = GetMaterialIDs(coord);
	matID = floor(matID * 255.0f);

	if (matID < 1.0f || matID > 254.0f)
	{
		return true;
	} else {
		return false;
	}
}

vec3 ProjectBack(vec3 cameraSpace)
{
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
		 //screenSpace.z = 0.1f;
    return screenSpace;
}

float 	ExpToLinearDepth(in float depth)
{
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

float GetAO(vec2 coord, vec3 normal, float dither)
{
	const int numRays = AO_SAMPLES;

	const float phi = 1.618033988;
	const float gAngle = phi * 3.14159265 * 1.0003;

	float depth = GetDepth(coord);
	float linDepth = ExpToLinearDepth(depth);
	vec3 origin = GetScreenSpacePosition(coord, depth).xyz;

	float aoAccum = 0.0;

	//float radius = 0.15 * -origin.z;
	float radius = 0.8 * -origin.z;
		  radius = mix(radius, 0.8, 0.5);
	//float zThickness = 0.15 * -origin.z;
	float zThickness = 0.2 * -origin.z;
		  zThickness = mix(zThickness, 1.0, 0.5);

	float aoMul = 1.0;

	for (int i = 0; i < numRays; i++)
	{
		float fi = float(i) + dither;
		float fiN = fi / float(numRays);
		float lon = gAngle * fi * 6.0;
		float lat = asin(fiN * 2.0 - 1.0) * 1.0;

		vec3 kernel;
		kernel.x = cos(lat) * cos(lon);
		kernel.z = cos(lat) * sin(lon);
		kernel.y = sin(lat);

		kernel.xyz = normalize(kernel.xyz + normal.xyz);

		//float sampleLength = radius * mod(fiN, 0.07) / 0.07;
		float sampleLength = radius * mod(fiN, 0.02) / 0.02;

		vec3 samplePos = origin + kernel * sampleLength;

		vec3 samplePosProj = ProjectBack(samplePos);

		vec3 actualSamplePos = GetScreenSpacePosition(samplePosProj.xy, GetDepth(samplePosProj.xy)).xyz;

		vec3 sampleVector = normalize(samplePos - origin);

		float depthDiff = actualSamplePos.z - samplePos.z;

		if (depthDiff > 0.0 && depthDiff < zThickness)
		{
			float aow = 1.35 * saturate(dot(sampleVector, normal));
			aoAccum += aow;
		}
	}

	aoAccum /= numRays;

	float ao = 1.0 - aoAccum;
	//ao = pow(ao, 1.5);
	ao = pow(ao, 1.55);

	return ao;
}

vec3 WorldPosToShadowProjPosBias(vec3 worldPos, vec3 worldNormal, out float dist, out float distortFactor)
{
	vec3 shadowNorm = normalize((shadowModelView * vec4(worldNormal.xyz, 0.0)).xyz) * vec3(1.0, 1.0, -1.0);

	vec4 shadowPos = shadowModelView * vec4(worldPos, 1.0);
		 shadowPos = shadowProjection * shadowPos;
		 shadowPos /= shadowPos.w;

	dist = length(shadowPos.xy);
	distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	shadowPos.xyz += shadowNorm * 0.002 * distortFactor;
	//shadowPos.xy *= 0.95f / distortFactor;
	//shadowPos.z = mix(shadowPos.z, 0.5, 0.8);
	shadowPos = shadowPos * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates

	return shadowPos.xyz;
}

vec4 GetLight(in int LOD, in vec2 offset, in float range, in float quality, vec3 noisePattern)
{
	float scale = pow(2.0f, float(LOD));

	float padding = 0.002f;

	if (	texcoord.s - offset.s + padding < 1.0f / scale + (padding * 2.0f)
		&&  texcoord.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)
		&&  texcoord.s - offset.s + padding > 0.0f
		&&  texcoord.t - offset.t + padding > 0.0f)
	{

		vec2 coord = (texcoord.st - offset.st) * scale;

		vec3 normal 				= GetNormals(coord.st);						//Gets the screen-space normals

		vec4 gn = gbufferModelViewInverse * vec4(normal.xyz, 0.0f);
			 gn = shadowModelView * gn;
			 gn.xyz = normalize(gn.xyz);

		vec3 shadowSpaceNormal = gn.xyz;

		vec4 viewPos 	= GetScreenSpacePosition(coord.st); 			//Gets the screen-space position
		vec3 viewVector 			= normalize(viewPos.xyz);


		float distance = length(viewPos.xyz); //Get surface distance in meters

		float materialIDs = texture2D(composite, coord).b * 255.0f;

		vec4 upVectorShadowSpace = shadowModelView * vec4(0.0f, 1.0, 0.0, 0.0);

		float dist;
		float distortFactor;
		vec3 shadowProjPos = (gbufferModelViewInverse * viewPos).xyz;
			 shadowProjPos = WorldPosToShadowProjPosBias(shadowProjPos.xyz, normal, dist, distortFactor);

		float shadowMult = 0.0f;														//Multiplier used to fade out shadows at distance
		float shad = 0.0f;
		vec3 fakeIndirect = vec3(0.0f);


		float mcSkylight = GetSkylight(coord) * 0.8 + 0.2;

		float fademult = 0.15f;

		shadowMult = clamp((shadowDistance * 41.4f * fademult) - (distance * fademult), 0.0f, 1.0f);	//Calculate shadowMult to fade shadows out

		float compare = sin(frameTimeCounter) > -0.2 ? 1.0 : 0.0;

		if (	shadowMult > 0.0)
		{


			//big shadow
			float rad = range;

			int c = 0;
			float s = rad / 1024.0;

			vec2 dither = noisePattern.xy - 0.5f;

			float step = 1.0f / quality;

			for (float i = -2.0f; i <= 2.0f; i += step) {
				for (float j = -2.0f; j <= 2.0f; j += step) {

					vec2 offset = (vec2(i, j) + dither * step) * s;

					//offset *= length(offset) * 15.0;
					offset *= pow(length(offset * 2.0f ) * 0.75f, 2.5) * 25.0
							+ pow(length(offset * 1.25f) * 3.0f , 2.0) * 8.0
							+ pow(length(offset        ) * 10.0f, 2.0) * 1.75;
					offset *= GI_RADIUS * 1.0;

					vec2 coord =  shadowProjPos.st + offset;
					vec2 lookupCoord = DistortShadowSpace(coord);

					float depthSample = texture2DLod(shadowtex1, lookupCoord, 0).x;


					depthSample = -3 + 5.0 * depthSample;
					vec3 samplePos = vec3(coord.x, coord.y, depthSample);


					vec3 lightVector = normalize(samplePos.xyz - shadowProjPos.xyz);

					vec4 normalSample = texture2DLod(shadowcolor1, lookupCoord, 6);
					vec3 surfaceNormal = normalSample.rgb * 2.0f - 1.0f;
						 surfaceNormal.x = -surfaceNormal.x;
						 surfaceNormal.y = -surfaceNormal.y;

					float surfaceSkylight = normalSample.a;

					if (surfaceSkylight < 0.2)
					{
						surfaceSkylight = mcSkylight;
					}

					float NdotL = max(0.0f, dot(shadowSpaceNormal.xyz, lightVector * vec3(1.0, 1.0, -1.0)));
						   NdotL = NdotL * 0.9f + 0.2f;

					if (abs(materialIDs - 3.0f) < 0.1f || abs(materialIDs - 2.0f) < 0.1f || abs(materialIDs - 11.0f) < 0.1f)
					{
						NdotL = 0.5f;
					}

					if (NdotL > 0.0)
					{
						bool isTranslucent = length(surfaceNormal) < 0.5f;

						if (isTranslucent)
						{
							//surfaceNormal.xyz = vec3(0.0f, 0.0f, 1.0f);
						}

						//float leafMix = clamp(-surfaceNormal.b * 10.0f, 0.0f, 1.0f);


						float weight = dot(lightVector, surfaceNormal);
						float rawdot = weight;

						//weight = mix(weight, 1.0f, leafMix);
						if (isTranslucent)
						{
							weight = abs(weight) * 0.85f;
						}

						if (normalSample.a < 0.2)
						{
							weight = 0.5;
						}

						weight = max(weight, 0.0f);

						float dist = length(samplePos.xyz - shadowProjPos.xyz);
						if (dist < 0.0005f)
						{
							dist = 10000000.0f;
						}

						const float falloffPower = 1.9f;
						float distanceWeight = (1.0f / (pow(dist * (62260.0f / rad), falloffPower) + 100.1f));
							  distanceWeight *= pow(length(offset), 2.0) * 50000.0 + 1.01;


						//Leaves self-occlusion
						if (rawdot < 0.0f)
						{
							distanceWeight = max(distanceWeight * 30.0f - 0.13f, 0.0f);
							distanceWeight *= 0.04f;
						}


						//float skylightWeight = clamp(1.0 - abs(surfaceSkylight - mcSkylight) * 10.0, 0.0, 1.0);
						float skylightWeight = 1.0 / (max(0.0, surfaceSkylight - mcSkylight) * 15.0 + 1.0);


						vec3 colorSample = GammaToLinear(texture2DLod(shadowcolor0, lookupCoord, 6).rgb);

						colorSample /= surfaceSkylight;

						colorSample = normalize(colorSample) * pow(length(colorSample), 1.1f);


						fakeIndirect += colorSample * weight * distanceWeight * NdotL * skylightWeight;
						//fakeIndirect += skylightWeight * weight * distanceWeight * NdotL;
					}
					c += 1;
				}
			}

			fakeIndirect /= c;
		}

		fakeIndirect = mix(vec3(0.0f), fakeIndirect, vec3(shadowMult));

		float ao = 1.0f;
		bool isSky = GetSkyMask(coord.st);
		#ifdef ENABLE_SSAO
		if (!isSky)
		{
			ao *= GetAO(coord.st, normal.xyz, noisePattern.x);
		}
		#endif

		fakeIndirect.rgb *= ao;


		//fakeIndirect.rgb = vec3(mcSkylight / 1150.0);

		//fakeIndirect.rgb = mix(fakeIndirect.rgb, vec3(Luminance(fakeIndirect.rgb)), vec3(1.0 - pow(GI_SATURATION - pow(18.0 / shadowDistance, 0.75f) + (1 / quality) * 0.25, 1.5)));
		float giBrightness = (quality < 1.0f) ? ((GI_BRIGHTNESS * 1.2) / sqrt(quality)) : GI_BRIGHTNESS;
		//float giBrightness = GI_BRIGHTNESS;

		return vec4(fakeIndirect.rgb * giBrightness * GI_RADIUS, ao);
	}
	else {
		return vec4(0.0f);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 noisePattern = CalculateNoisePattern1(vec2(0.0f), 4);
	vec4 viewPos = GetScreenSpacePosition(texcoord.st);
	vec4 worldSpacePosition = gbufferModelViewInverse * viewPos;
	vec4 worldLightVector = shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
	vec3 normal = GetNormals(texcoord.st);

	vec4 light = vec4(0.0, 0.0, 0.0, 1.0);
	#ifdef GI
		 //light = GetLight(GI_RENDER_RESOLUTION, vec2(0.0f), 16.0, GI_QUALITY, noisePattern);
		 light = GetLight(GI_RENDER_RESOLUTION, vec2(0.0f), 22.0, GI_QUALITY, noisePattern);
	#endif


	light.a = mix(light.a, 1.0, GetMaterialMask(texcoord.st * (GI_RENDER_RESOLUTION + 1.0), 4));
	gl_FragData[0] = vec4(pow(light.rgb, vec3(1.0 / 2.2)), light.a);
}
