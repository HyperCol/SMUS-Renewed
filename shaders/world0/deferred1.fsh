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



/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////


#define SHADOW_MAP_BIAS 0.9

#define GI_RENDER_RESOLUTION 1 // Render resolution of GI. 0 = High. 1 = Low. Set to 1 for faster but blurrier GI. [0 1]

#define POINTLIGHT_FILL 2.0 // Amount of fill/ambient light to add to point light falloff. Higher values makes point light dim less intensely based on distance. [0.5 1.0 2.0 4.0 8.0]

#define POINTLIGHT_BRIGHTNESS 1.0 // Brightness of point light. [0.5 1.0 2.0 3.0 4.0]

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.

//#define SHADOW_TAA

#define SUNLIGHT_INTENSITY 1.0 // Intensity of sunlight. [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define SHADOW_SAMPLES 4 // Shaodow samples. [4 8 16 24 32 48]
#define SCREEN_SPACE_SAMPLES 8.0  // Screen sapce shadow samples [8.0 12.0 24.0 32.0 48.0 64.0]
#define TRANSLUCENT_SHADOWS // Translucent shadows.

#define HELD_POINTLIGHT // Holding an item with a light value will cast light into the scene when this is enabled.

const int 		shadowMapResolution 	= 2048;	// Shadowmap resolution [1024 2048 4096 6144 8192 16384]
const float 	shadowDistance 			= 120.0; // Shadow distance. Set lower if you prefer nicer close shadows. Set higher if you prefer nicer distant shadows. [80.0 120.0 180.0 240.0 320.0 480.0]
const float 	shadowIntervalSize 		= 1.0f;
const bool 		shadowHardwareFiltering0 = false;
const bool 		shadowHardwareFiltering1 = false;

const bool 		shadowtex0Mipmap = true;
const bool 		shadowtex0Nearest = true;
const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

const float shadowDistanceRenderMul = 1.0f;

const int 		RGB8 					= 0;
const int 		RGBA8 					= 0;
const int 		RGBA16 					= 0;
const int 		RG16 					= 0;
const int 		RGB16 					= 0;
const int 		gcolorFormat 			= RGBA16;
const int 		gdepthFormat 			= RGBA16;
const int 		gnormalFormat 			= RGBA16;
const int 		compositeFormat 		= RGB8;
const int 		gaux1Format 			= RGBA16;
const int 		gaux2Format 			= RGBA16;
const int 		gaux3Format 			= RGBA16;
const int 		gaux4Format 			= RGBA16;


const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;

const int 		noiseTextureResolution  = 64;

const float 	ambientOcclusionLevel 	= 0.0f;


const bool gaux3MipmapEnabled = true;
const bool gaux1MipmapEnabled = false;

const bool gaux4Clear = false;

const float wetnessHalflife = 1.0;
const float drynessHalflife = 60.0;

/* DRAWBUFFERS:6 */


uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D depthtex1;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform sampler2D noisetex;

uniform sampler2D shadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;


varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 sunVector;
varying vec3 upVector;

uniform int worldTime;

uniform float near;
uniform float far;
uniform vec2 resolution;
uniform vec2 texel;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 skyColor;

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
varying vec3 colorTorchlight;

varying vec4 skySHR;
varying vec4 skySHG;
varying vec4 skySHB;

varying vec3 worldLightVector;
varying vec3 worldSunVector;

uniform int heldBlockLightValue;

varying float contextualFogFactor;
uniform float sunAngle;
uniform float shadowAngle;

uniform int frameCounter;

uniform float nightVision;

varying float heldLightBlacklist;

uniform vec2 taaJitter;
uniform float taaStrength;

#include "/Common.inc"

/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

vec4 GetViewPositionRaw(in vec2 coord, in float depth)
{
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;


	return fragposition;
}

vec4 GetViewPosition(in vec2 coord, in float depth)
{
#ifdef TAA_ENABLED
	coord -= taaJitter * 0.5;
#endif

	return GetViewPositionRaw(coord, depth);
}

float 	ExpToLinearDepth(in float depth)
{
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}


float GetMaterialMask(const in int ID, in float matID)
{
	//Catch last part of sky
	if (matID > 254.0f)
	{
		matID = 0.0f;
	}

	if (matID == ID)
	{
		return 1.0f;
	}
	else
	{
		return 0.0f;
	}
}

float CurveBlockLightSky(float blockLight)
{
	//blockLight = pow(blockLight, 3.0);

	//blockLight = InverseSquareCurve(1.0 - blockLight, 0.2);
	blockLight = 1.0 - pow(1.0 - blockLight, 0.45);
	blockLight *= blockLight * blockLight;

	return blockLight;
}

float CurveBlockLightTorch(float blockLight)
{
	float decoded = pow(blockLight, 1.0 / 0.25);

	decoded = pow(decoded, 2.0) * 5.0;
	decoded += pow(decoded, 0.4) * 0.1 * POINTLIGHT_FILL;

	return decoded;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size)
{
	vec2 coord = texcoord.st;

	coord *= resolution;
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

#ifdef TAA_ENABLED
	coord -= taaJitter * 0.5;
#endif

	return texture2D(noisetex, coord).xyz;
}

float GetDepthLinear(in vec2 coord)
{
	return (near * far) / (texture2D(depthtex1, coord).x * (near - far) + far);
}

vec3 GetNormals(vec2 coord)
{
	return DecodeNormal(texture2D(gnormal, coord).xy);
}

float GetDepth(vec2 coord)
{
	return texture2D(depthtex1, coord).x;
}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct GbufferData
{
	vec3 albedo;
	vec3 normal;
	float depth;
	vec2 mcLightmap;
	float smoothness;
	float metallic;
	float emissive;
	float materialID;
	vec4 transparentAlbedo;
	float parallaxShadow;
};


struct MaterialMask
{
	float sky;
	float land;
	float grass;
	float leaves;
	float hand;
	float entityPlayer;
	float torch;
	float lava;
	float glowstone;
	float fire;
};

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct Plane {
	vec3 normal;
	vec3 origin;
};

struct Intersection {
	vec3 pos;
	float distance;
	float angle;
};

/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


GbufferData GetGbufferData()
{
	GbufferData data;


	vec3 gbuffer0 = texture2D(gcolor, texcoord.st).rgb;
	vec4 gbuffer1 = texture2D(gdepth, texcoord.st).rgba;
	vec2 gbuffer2 = texture2D(gnormal, texcoord.st).rg;
	vec3 gbuffer3 = texture2D(composite, texcoord.st).rgb;
	float depth = texture2D(depthtex1, texcoord.st).x;


	data.albedo = GammaToLinear(gbuffer0);

	data.mcLightmap.g = CurveBlockLightSky(gbuffer1.g);
	data.mcLightmap.r = CurveBlockLightTorch(gbuffer1.r);
	data.emissive = gbuffer1.b;

	data.normal = DecodeNormal(gbuffer2);


	data.smoothness = gbuffer3.r;
	data.metallic = gbuffer3.g;
	data.materialID = gbuffer3.b;

	data.depth = depth;

	data.transparentAlbedo = texture2D(gaux2, texcoord.st);

	data.parallaxShadow = gbuffer1.a;

	return data;
}

MaterialMask CalculateMasks(float materialID)
{
	MaterialMask mask;

	materialID *= 255.0;

	mask.sky = GetMaterialMask(0, materialID);



	mask.land 			= GetMaterialMask(1, materialID);
	mask.grass 			= GetMaterialMask(2, materialID);
	mask.leaves 		= GetMaterialMask(3, materialID);
	mask.hand 			= GetMaterialMask(4, materialID);
	mask.entityPlayer 	= GetMaterialMask(5, materialID);

	mask.torch 			= GetMaterialMask(30, materialID);
	mask.lava 			= GetMaterialMask(31, materialID);
	mask.glowstone 		= GetMaterialMask(32, materialID);
	mask.fire 			= GetMaterialMask(33, materialID);

	return mask;
}

Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.dir * planeRayDist;
		intersectionPos = -intersectionPos;

		intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

Intersection 	RayPlaneIntersection(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin - ray.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.origin + ray.dir * planeRayDist;
		// intersectionPos = -intersectionPos;

		// intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}




vec3 WorldPosToShadowProjPosBias(vec3 worldPos, vec3 worldNormal, out float dist, out float distortFactor)
{

	vec3 sn = normalize((shadowModelView * vec4(worldNormal.xyz, 1.0)).xyz);

	vec4 shadowPos = shadowModelView * vec4(worldPos, 1.0);
		 shadowPos = shadowProjection * shadowPos;
		 shadowPos /= shadowPos.w;

	dist = length(shadowPos.xy);
	distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	shadowPos.xyz += sn * 0.008 * distortFactor;
	shadowPos.xy *= 0.95f / distortFactor;
	shadowPos.z = mix(shadowPos.z, 0.5, 0.8);

#ifdef TAA_ENABLED
#ifdef SHADOW_TAA
	shadowPos.st += taaJitter;
#endif
#endif

	shadowPos = shadowPos * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates

	return shadowPos.xyz;
}

vec3 CalculateSunlightVisibility(vec4 viewPos, MaterialMask mask, vec3 normal) {				//Calculates shadows
	if (rainStrength >= 0.99f)
		return vec3(1.0f);

	float distance = length(viewPos.xyz); //Get surface distance in meters

	float dist;
	float distortFactor;
	vec3 shadowProjPos = (gbufferModelViewInverse * viewPos).xyz;
		 shadowProjPos = WorldPosToShadowProjPosBias(shadowProjPos.xyz, normal, dist, distortFactor);


	float shadowMult = 0.0f;																			//Multiplier used to fade out shadows at distance
	float shading = 0.0f;

	float fademult = 0.15f;
		shadowMult = clamp((shadowDistance * 1.4f * fademult) - (distance * fademult), 0.0f, 1.0f);	//Calculate shadowMult to fade shadows out

#ifdef TRANSLUCENT_SHADOWS
	vec3 stainedGlassColorSum = vec3(1.0f);
	float shadowNormalAlphaSum = 0.0f;
#endif





	if (shadowMult > 0.0)
	{
		#ifdef TAA_ENABLED
			vec2 noise = rand(texcoord.st + sin(frameTimeCounter)).xy;
		#else
			vec2 noise = CalculateNoisePattern1(vec2(0.0), 4.0).xy;
		#endif
			noise = pow(noise, vec2(0.125));
			//noise = vec2(1.0);




		float diffthresh = dist + 0.10;
			  diffthresh *= 1.5f / (shadowMapResolution / 2048.0f);

		float shadowMapBlur = log2(float(shadowMapResolution)) * 0.18;

		//float vpsSpread = 0.145 / distortFactor;
		float vpsSpread = 1.05;






		float avgDepth = 0.0;
	#ifdef TRANSLUCENT_SHADOWS
		float avgDepth2 = 0.0;
	#endif

		noise -= 0.5;
		int avgDepthSamp = 0;
		for (int i = -2; i <= 2; i++)
		{
			for (int j = -2; j <= 2; j++)
			{
				vec2 lookupCoord = (shadowProjPos.xy * distortFactor) / 0.95 + ((vec2(i, j) + noise) / shadowDistance) * 0.008 * vpsSpread;
					 lookupCoord *= 0.95 / distortFactor;

				float depthSample = texture2DLod(shadowtex1, lookupCoord, shadowMapBlur).x;
					  depthSample = min(max(0.0, shadowProjPos.z - diffthresh * 0.0008 - depthSample), 0.025);
				avgDepth += depthSample * depthSample;

			#ifdef TRANSLUCENT_SHADOWS
				float shadowNormalAlpha = texture2DLod(shadowcolor1, lookupCoord, 0.0).a;

				if(shadowNormalAlpha <= (40.0 / 255.0))
				{
					float depthSample2 = texture2DLod(shadowtex0, lookupCoord, shadowMapBlur).x;
						  depthSample2 = min(max(0.0, shadowProjPos.z - depthSample2), 0.025);
					avgDepth2 += depthSample2 * depthSample2;
				}
			#endif

				avgDepthSamp++;
			}
		}

		avgDepth /= avgDepthSamp;
		avgDepth = sqrt(avgDepth);
	#ifdef TRANSLUCENT_SHADOWS
		avgDepth2 /= avgDepthSamp;
		avgDepth2 = sqrt(avgDepth2);
	#endif






		float spread = avgDepth * 0.125 * vpsSpread + 0.0375 / shadowDistance;
	#ifdef TRANSLUCENT_SHADOWS
		float spread2 = avgDepth2 * 0.125 * vpsSpread + 0.0375 / shadowDistance;
	#endif
		//diffthresh *= avgDepth * 50.0f + 0.5f;


	#ifdef TAA_ENABLED
	#ifdef SHADOW_TAA
		noise.x = saturate(noise.x) * 2.0 - 1.0;
		shadowProjPos.z += noise.x * sqrt(spread) * 0.075 / distortFactor;
	#endif
	#endif


		noise += 0.5;
		int shadowSamp = SHADOW_SAMPLES;
		for (int i = 0; i < shadowSamp; i++)
		{
			vec2 fi = vec2(float(i) / float(shadowSamp)) + noise;
			vec2 r = vec2(float(i) / float(shadowSamp)) + noise;
				 r *= 3.14159265 * 2.0 * 1.61;

			vec2 radialPos = vec2(cos((r.x + r.y) * 0.5), sin((r.x + r.y) * 0.5));
			vec2 coordOffset = radialPos * spread * fi * 0.08;
			vec3 coord = vec3((shadowProjPos.st * distortFactor) / 0.95 + (coordOffset * 200.0) / shadowDistance, shadowProjPos.z);
				 coord.st *= 0.95f / distortFactor;

			float finalShadow = texture2DLod(shadowtex1, coord.st, 0).x;
			shading += 1.0 - ((coord.z - diffthresh * 0.0008 > finalShadow) ? 1.0 : 0.0);
			//shading += shadow2DLod(shadow, coord, 0).x;

		#ifdef TRANSLUCENT_SHADOWS
			coordOffset = radialPos * spread2 * fi * 0.08;
			coord = vec3((shadowProjPos.st * distortFactor) / 0.95 + (coordOffset * 200.0) / shadowDistance, shadowProjPos.z);
			coord.st *= 0.95f / distortFactor;


			float shadowNormalAlpha = texture2DLod(shadowcolor1, coord.st, 0.0).a;
			shadowNormalAlphaSum += shadowNormalAlpha;

			vec3 stainedGlassColor = texture2DLod(shadowcolor0, coord.st, 0.0).rgb;
			//stainedGlassColorSum += stainedGlassColor;

			if(shadowNormalAlpha > 0.1 && shadowNormalAlpha <= (40.0 / 255.0))
			{
				float depth = saturate(avgDepth2 * 100.0);
					  depth *= depth;
				vec3 waterShadowColor = mix(vec3(1.0), vec3(0.2, 0.6, 1.0), depth);
				stainedGlassColor = stainedGlassColor * waterShadowColor - 0.5;
				stainedGlassColor++;
			}
			stainedGlassColorSum += stainedGlassColor;
		#endif
		}

		shading /= shadowSamp;
	#ifdef TRANSLUCENT_SHADOWS
		stainedGlassColorSum /= shadowSamp;
		shadowNormalAlphaSum /= shadowSamp;
	#endif

	}





	float clampFactor = max(0.0, dist - 0.1) * 5.0 + 1.0;
	shading = saturate(((shading * 2.0 - 1.0) * clampFactor) * 0.5 + 0.5);

	vec3 result = vec3(shading);
#ifdef TRANSLUCENT_SHADOWS
	stainedGlassColorSum *= stainedGlassColorSum;
	stainedGlassColorSum *= shading;
	result = mix(result, stainedGlassColorSum, vec3(1.0 - shadowNormalAlphaSum));
	//result *= stainedGlassColorSum;
#endif



	result = mix(vec3(1.0), result, shadowMult);
	return result;
}

float RenderSunDisc(vec3 worldDir, vec3 sunDir)
{
	float d = dot(worldDir, sunDir);

	float disc = 0.0;

	float size = 0.00195;
	float hardness = 1000.0;

	disc = pow(curve(saturate((d - (1.0 - size)) * hardness)), 2.0);

	float visibility = curve(saturate(worldDir.y * 30.0));

	disc *= visibility;

	return disc;
}


vec4 BilateralUpsample(const in float scale, in vec2 offset, in float depth, in vec3 normal)
{
	vec2 recipres = texel;

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

	for (float i = -0.5f; i <= 0.5f; i++)
	{
		for (float j = -0.5f; j <= 0.5f; j++)
		{
			vec2 coord = vec2(i, j) * recipres * 2.0f;

			float sampleDepth = GetDepthLinear(texcoord.st + coord * 2.0f * (exp2(scale)));
			vec3 sampleNormal = GetNormals(texcoord.st + coord * 2.0f * (exp2(scale)));
			//float weight = 1.0f / (pow(abs(sampleDepth - depth) * 1000.0f, 2.0f) + 0.001f);
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
				  weight *= max(0.0f, dot(sampleNormal, normal) * 2.0f - 1.0f);
			//weight = 1.0f;

			light += pow(texture2DLod(gaux3, texcoord.st / exp2(scale) + offset + coord, 1.0), vec4(vec3(2.2), 1.0f)) * weight;

			weights += weight;
		}
	}


	light /= max(0.00001f, weights);

	if (weights < 0.01f)
	{
		light =	pow(texture2DLod(gaux3, texcoord.st / exp2(scale) + offset, 1.25), vec4(vec3(2.2), 1.0f));
	}

	return light;
}

vec4 GetGI(vec3 albedo, vec3 normal, float depth, float skylight)
{
	depth = ExpToLinearDepth(depth);
	vec4 indirectLight = BilateralUpsample(GI_RENDER_RESOLUTION, vec2(0.0), depth, normal);

	float value = length(indirectLight.rgb);
	indirectLight.rgb = pow(value, 0.8) * normalize(indirectLight.rgb + 0.0001);
	indirectLight.rgb *= albedo * mix(colorSunlight, vec3(0.4) * Luminance(colorSkylight), rainStrength);
	indirectLight.rgb *= 1.44 * saturate((skylight + 0.01) * 7.0);

	return indirectLight;
}

vec3 ProjectBack(vec3 cameraSpace)
{
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;

    return screenSpace;
}

float ScreenSpaceShadow(vec3 origin, vec3 normal, MaterialMask mask)
{
	if (mask.sky > 0.5 || rainStrength >= 0.999)
	{
		return 1.0;
	}

	vec3 viewDir = normalize(origin.xyz);


	float nearCutoff = 0.50 * (12.0 / SCREEN_SPACE_SAMPLES);
	float traceBias = 0.015;


	//Prevent self-intersection issues
	float viewDirDiff = dot(fwidth(viewDir), vec3(0.333333));


	vec3 rayPos = origin;
	vec3 rayDir = lightVector * 0.01;
	rayDir *= viewDirDiff * 1500.001;
	rayDir *= -origin.z * (12.0 / SCREEN_SPACE_SAMPLES) * 0.28 + nearCutoff;


	//rayPos += rayDir * -origin.z * 0.000037 * traceBias;
	rayPos += rayDir * -origin.z * 0.000017 * traceBias;


#ifdef TAA_ENABLED
	float randomness = rand(texcoord.st + sin(frameTimeCounter)).x;
#else
	float randomness = 0.0;
#endif

	rayPos += rayDir * randomness;



	float zThickness = origin.z * (12.0 / SCREEN_SPACE_SAMPLES) * -0.025;

	float shadow = 1.0;

	float numSamples = SCREEN_SPACE_SAMPLES;


	float shadowStrength = 0.9;

	if (mask.grass > 0.5)
	{
		shadowStrength = 0.6;
		zThickness *= 2.0;
	}
	if (mask.leaves > 0.5)
	{
		shadowStrength = 0.4;
	}


	for (int i = 0; i < numSamples; i++)
	{
		float fi = float(i) / numSamples;

		rayPos += rayDir;

		vec3 rayProjPos = ProjectBack(rayPos);

	#ifdef TAA_ENABLED
		rayProjPos.st += taaJitter * 0.5;
	#endif


		vec3 samplePos = GetViewPositionRaw(rayProjPos.xy, GetDepth(rayProjPos.xy)).xyz;

		float depthDiff = samplePos.z - rayPos.z + 0.02 * origin.z * traceBias;

		if (depthDiff > 0.0 && depthDiff < zThickness)
		{
			shadow *= 1.0 - shadowStrength;
		}
	}

	return shadow;
}

float OrenNayar(vec3 normal, vec3 eyeDir, vec3 lightDir)
{
	const float PI = 3.14159;
	const float roughness = 0.55;

	// calculate intermediary values
	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, eyeDir);

	float angleVN = acos(NdotV);
	float angleLN = acos(NdotL);

	float alpha = max(angleVN, angleLN);
	float beta = min(angleVN, angleLN);
	float gamma = dot(eyeDir - normal * dot(eyeDir, normal), lightDir - normal * dot(lightDir, normal));

	float roughnessSquared = roughness * roughness;

	// calculate A and B
	float A = 1.0 - 0.5 * (roughnessSquared / (roughnessSquared + 0.57));

	float B = 0.45 * (roughnessSquared / (roughnessSquared + 0.09));

	float C = sin(alpha) * tan(beta);

	// put it all together
	float L1 = max(0.0, NdotL) * (A + B * max(0.0, gamma) * C);

	//return max(0.0f, surface.NdotL * 0.99f + 0.01f);
	return clamp(L1, 0.0f, 1.0f);
}

float Get2DNoise(in vec3 pos)
{
	pos.xy = pos.xz;
	pos.xy += 0.5f;

	vec2 p = floor(pos.xy);
	vec2 f = fract(pos.xy);

	f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	f.y = f.y * f.y * (3.0f - 2.0f * f.y);

	vec2 uv =  p.xy + f.xy;

	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	return xy1;
}

float Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;

	pos.xyz += 0.5f;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	f.y = f.y * f.y * (3.0f - 2.0f * f.y);
	f.z = f.z * f.z * (3.0f - 2.0f * f.z);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;

	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

float GetCoverage(in float coverage, in float density, in float clouds)
{
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
		clouds = max(0.0f, clouds * 1.1f - 0.1f);
	 clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
	 // clouds = pow(clouds, 1.0f);
	return clouds;
}

float   CalculateSunglow(vec3 npos, vec3 lightVector) {

	float curve = 4.0f;

	vec3 halfVector2 = normalize(-lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness, const bool isShadowPass)
{

	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	//worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 5000.0f);

	vec3 p = worldPosition.xyz / 150.0f;



	float t = frameTimeCounter * 1.0f;
		  t *= 0.5;


	 p += (Get2DNoise(p * 2.0f + vec3(0.0f, t * 0.00f, 0.0f)) * 2.0f - 1.0f) * 0.10f;
	 p.z -= (Get2DNoise(p * 0.25f + vec3(0.0f, t * 0.00f, 0.0f)) * 2.0f - 1.0f) * 0.45f;
	 p.x -= (Get2DNoise(p * 0.125f + vec3(0.0f, t * 0.00f, 0.0f)) * 2.0f - 1.0f) * 2.2f;
	p.xz -= (Get2DNoise(p * 0.0525f + vec3(0.0f, t * 0.00f, 0.0f)) * 2.0f - 1.0f) * 2.7f;


	p.x *= 0.5f;
	p.x -= t * 0.01f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get2DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.057f;	vec3 p2 = p;
		  noise += (2.0f - abs(Get2DNoise(p) * 2.0f - 0.0f)) * (0.15f);						p *= 3.0f;	p.xz -= t * 0.035f;	p.x *= 2.0f;	vec3 p3 = p;
		  noise += (3.0f - abs(Get2DNoise(p) * 3.0f - 0.0f)) * (0.050f);						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p4 = p;
		  noise += (3.0f - abs(Get2DNoise(p) * 3.0f - 0.0f)) * (0.015f);						p *= 3.0f;	p.xz -= t * 0.035f;
		  if (!isShadowPass)
		  {
		 		noise += ((Get2DNoise(p))) * (0.022f);												p *= 3.0f;
		  		noise += ((Get2DNoise(p))) * (0.009f);
		  }
		  noise /= 1.475f;

	//cloud edge
	float coverage = 0.701f;
		  coverage = mix(coverage, 0.97f, rainStrength);

		  float dist = length(worldPosition.xz - cameraPosition.xz * 0.5);
		  coverage *= max(0.0f, 1.0f - dist / 14000.0f);
	float density = 0.1f + rainStrength * 0.3;

	if (isShadowPass)
	{
		return vec4(GetCoverage(0.4f, 0.4f, noise));
	}

	noise = GetCoverage(coverage, density, noise);

	const float lightOffset = 0.4f;



	float sundiff = Get2DNoise(p1 + worldLightVector.xyz * lightOffset);
		  sundiff += (2.0f - abs(Get2DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 2.0f - 0.0f)) * (0.55f);
		  				float largeSundiff = sundiff;
		  				      largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
		  sundiff += (3.0f - abs(Get2DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 3.0f - 0.0f)) * (0.045f);
		  sundiff += (3.0f - abs(Get2DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 3.0f - 0.0f)) * (0.015f);
		  sundiff /= 1.5f;

		  sundiff *= max(0.0f, 1.0f - dist / 14000.0f);

		  sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
	float secondOrder 	= pow(clamp(sundiff * 1.1f + 1.45f, 0.0f, 1.0f), 4.0f);
	float firstOrder 	= pow(clamp(largeSundiff * 1.1f + 1.66f, 0.0f, 1.0f), 3.0f);



	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
	float directLightFalloff  = firstOrder * secondOrder;
		  directLightFalloff *= anisoBackFactor;
	 	  directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));


	vec3 colorDirect = colorSunlight * 11.215f;
		 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), timeMidnight);
		 colorDirect *= 1.0f + pow(sunglow, 2.0f) * 120.0f * pow(directLightFalloff, 1.1f) * (1.0 - rainStrength * 0.8);


	vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(0.15f)) * 0.93f;
		 colorAmbient = mix(colorAmbient, vec3(0.4) * Luminance(colorSkylight), vec3(rainStrength));
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
		 colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));




	directLightFalloff *= 1.0 - rainStrength * 0.915;

	vec3 color  = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));
		 color *= 1.0 - rainStrength * 0.1;


	vec4 result = vec4(color.rgb, noise);

	return result;

}

void CloudPlane(inout vec3 color, vec3 viewDir, vec3 worldVector, float linearDepth, MaterialMask mask, vec3 worldLightVector, vec3 lightVector, float gbufferdepth)
{
	//Initialize view ray
	// vec4 worldPos = gbufferModelViewInverse * (vec4(-GetViewPosition(texcoord.st, gbufferdepth).xyz, 1.0));
	// worldVector = normalize(worldPos.xyz);


	Ray viewRay;

	viewRay.dir = normalize(worldVector.xyz);
	// viewRay.origin = (gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	viewRay.origin = vec3(0.0);

	float sunglow = CalculateSunglow(viewDir, lightVector);



	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 1.0f;

	float planeHeight = cloudsUpperLimit;
	float stepSize = 25.5f;
	planeHeight -= cloudsThickness * 0.85f;


	Plane pl;
	pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	Intersection intersection = RayPlaneIntersectionWorld(viewRay, pl);

	vec3 original = color.rgb;

	if (intersection.angle < 0.0f)
	{
		if (intersection.distance < linearDepth || mask.sky > 0.5 || linearDepth >= far - 0.1)
		{
			vec4 cloudSample = CloudColor(vec4(intersection.pos.xyz * 0.5f + vec3(30.0f) + vec3(1000.0, 0.0, 0.0), 1.0f), sunglow, worldLightVector, cloudsAltitude, cloudsThickness, false);
			 	 cloudSample.a = min(1.0f, cloudSample.a * density);


			float cloudDist = length(intersection.pos.xyz - cameraPosition.xyz);

			const vec3 absorption = vec3(0.2, 0.4, 1.0);

			cloudSample.rgb *= exp(-cloudDist * absorption * 0.0001 * saturate(1.0 - sunglow * 2.0) * (1.0 - rainStrength));

			cloudSample.a *= exp(-cloudDist * (0.0002 + rainStrength * 0.0029));


			//cloudSample.rgb *= sin(cloudDist * 0.3) * 0.5 + 0.5;

			color.rgb = mix(color.rgb, cloudSample.rgb * 1.0f, cloudSample.a);

		}
	}
}

float CloudShadow(vec3 lightVector, vec4 screenSpacePosition)
{
	lightVector = upVector;

	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float planeHeight = cloudsUpperLimit;

	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	//Cloud shadow
	Ray surfaceToSun;
	vec4 sunDir = gbufferModelViewInverse * vec4(lightVector, 0.0f);
	surfaceToSun.dir = normalize(sunDir.xyz);
	vec4 surfacePos = gbufferModelViewInverse * screenSpacePosition;
	surfaceToSun.origin = surfacePos.xyz + cameraPosition.xyz;

	Intersection i = RayPlaneIntersection(surfaceToSun, pl);

	//float cloudShadow = CloudColor(vec4(i.pos.xyz * 30.5f + vec3(30.0f) + vec3(1000.0, 0.0, 0.0), 1.0f), 0.0, worldLightVector, cloudsAltitude, cloudsThickness, false).x;
		  //cloudShadow += CloudColor(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;

	i.pos *= 0.015;
	i.pos.x -= frameTimeCounter * 0.42;

	float noise = Get2DNoise(i.pos.xzx);
	noise += Get2DNoise(i.pos.xzx * 0.5);

	noise *= 0.5;

	noise = mix(saturate(noise * 1.0 - 0.3), 1.0, rainStrength);
	noise = pow(noise, 0.5);
	//noise = mix(saturate(noise * 2.6 - 1.0), 1.0, rainStrength);

	noise = noise * noise * (3.0 - 2.0 * noise);

	//noise = GetCoverage(0.6, 0.2, noise);

	float cloudShadow = noise;

		  cloudShadow = min(cloudShadow, 1.0f);
		  cloudShadow = 1.0f - cloudShadow;

	return cloudShadow;
	// return 1.0f;
}

float G1V(float dotNV, float k)
{
	return 1.0 / (dotNV * (1.0 - k) + k);
}

vec3 SpecularGGX(vec3 N, vec3 V, vec3 L, float roughness, float F0)
{
	//N:world normal
	//V:world vector
	//L:world light vector
	float alpha = roughness * roughness;

	vec3 H = normalize(V + L);

	float dotNL = saturate(dot(N, L));
	float dotNV = saturate(dot(N, V));
	float dotNH = saturate(dot(N, H));
	float dotLH = saturate(dot(L, H));

	float F, D, vis;

	float alphaSqr = alpha * alpha;
	float pi = 3.14159265359;
	float denom = dotNH * dotNH * (alphaSqr - 1.0) + 1.0;
	D = alphaSqr / (pi * denom * denom);

	float dotLH5 = pow(1.0f - dotLH, 5.0);
	F = F0 + (1.0 - F0) * dotLH5;

	float k = alpha * 0.5;
	vis = G1V(dotNL, k) * G1V(dotNV, k);

	vec3 specular  = vec3(dotNL * D * F * vis) * colorSunlight;
		 specular *= saturate(pow(1.0 - roughness, 0.7) * 2.0);

	return specular;
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main()
{



	GbufferData gbuffer 			= GetGbufferData();
	MaterialMask materialMask 		= CalculateMasks(gbuffer.materialID);




	vec4 viewPos 					= GetViewPosition(texcoord.st, gbuffer.depth);

	vec4 worldPos					= gbufferModelViewInverse * viewPos;
	vec3 viewDir 					= normalize(viewPos.xyz);
	vec3 worldDir 					= normalize(worldPos.xyz);
	//vec3 worldLightVector 			= normalize((gbufferModelViewInverse * vec4(lightVector, 0.0)).xyz);
	//vec3 worldSunVector 			= normalize((gbufferModelViewInverse * vec4(sunVector, 0.0)).xyz);
	vec3 worldNormal 				= normalize((gbufferModelViewInverse * vec4(gbuffer.normal, 0.0)).xyz);
	float linearDepth 				= length(viewPos.xyz);

	vec3 finalComposite = vec3(0.0);
	bool skyChecker = materialMask.sky > 0.5 || isEyeInWater > 0 && gbuffer.depth > 0.9999999;


	if(skyChecker)
	{
		gbuffer.albedo *= 1.0 - saturate((dot(worldDir, vec3(0.0, -1.0, 0.0)) - 0.85) * 50.0);
	}

	//GI
	vec4 gi = GetGI(gbuffer.albedo, gbuffer.normal, gbuffer.depth, gbuffer.mcLightmap.g);

	vec3 fakeGI = normalize(gbuffer.albedo + 0.0001) * pow(length(gbuffer.albedo), 1.0) * colorSunlight * 0.08 * gbuffer.mcLightmap.g;
	float fakeGIFade = saturate((shadowDistance * 0.1 * 1.0) - length(viewPos) * 0.1);

	gi.rgb = mix(fakeGI, gi.rgb, vec3(fakeGIFade));

	float ao = gi.a;





	//grass points up
	if (materialMask.grass > 0.5)
		worldNormal = vec3(0.0, 1.0, 0.0);








	//shading from sky
	vec3 skylight = vec3(1.0);
	if (!skyChecker)
	{
		skylight *= FromSH(skySHR, skySHG, skySHB, worldNormal);
		skylight *= gbuffer.mcLightmap.g;
		skylight *= dot(worldNormal, vec3(0.0, 1.0, 0.0)) * 0.2 + 0.8;
		finalComposite += skylight * gbuffer.albedo * 2.0 * ao;
	}





	//Pointlight
	const float torchlightBrightness = 3.7 * POINTLIGHT_BRIGHTNESS;


	finalComposite += gbuffer.mcLightmap.r * colorTorchlight * gbuffer.albedo * 0.5 * ao * torchlightBrightness;

	#ifdef HELD_POINTLIGHT
	//held point light
	float heldLightFalloff = 1.0 / (pow(length(worldPos.xyz), 2.0) + 0.5);
	finalComposite += gbuffer.albedo * heldLightFalloff * heldBlockLightValue * colorTorchlight * 0.025 * torchlightBrightness * ao * heldLightBlacklist;
	#endif

	if (materialMask.glowstone > 0.5)
	{
		finalComposite += gbuffer.albedo * colorTorchlight * 5.0 * pow(length(gbuffer.albedo.rgb), 2.0);
	}
	if (materialMask.lava > 0.5)
	{
		finalComposite += gbuffer.albedo * colorTorchlight * 5.0 * pow(length(gbuffer.albedo.rgb), 1.0);
	}
	if (materialMask.torch > 0.5)
	{
		finalComposite += gbuffer.albedo * colorTorchlight * 5.0 * saturate(pow(length(gbuffer.albedo.rgb) - 0.5, 1.0));
	}




	//sunlight
	float sunlightMult = 14.0 * (1.0 - rainStrength) * SUNLIGHT_INTENSITY;

	float NdotL = dot(worldNormal, worldLightVector);
	//float sunlight = saturate(NdotL);
	float sunlight = OrenNayar(worldNormal, -worldDir, worldLightVector);
	if (materialMask.leaves > 0.5)
	{
		sunlight = 0.5;
	}
	if (materialMask.grass > 0.5)
	{
		gbuffer.metallic = 0.0;
	}

	sunlight *= pow(gbuffer.mcLightmap.g + 0.001, 0.1 + isEyeInWater * 0.4);

	vec3 shadow  = CalculateSunlightVisibility(viewPos, materialMask, gbuffer.normal);
		 shadow *= ScreenSpaceShadow(viewPos.xyz, gbuffer.normal.xyz, materialMask);

	//float cloudShadow = CloudShadow(lightVector, viewPos);
	float cloudShadow = 1.0;
	shadow *= cloudShadow;
	shadow *= gbuffer.parallaxShadow;
	gi.rgb *= cloudShadow * 0.88 + 0.12;

	finalComposite += sunlight * gbuffer.albedo * shadow * sunlightMult * colorSunlight;



	//Sunlight specular
	if (isEyeInWater < 0.5)
	{
		vec3 specularGGX  = SpecularGGX(worldNormal, -worldDir, worldLightVector, 1.0 - gbuffer.smoothness, gbuffer.metallic * 0.98 + 0.02) * sunlightMult * shadow;
			 specularGGX *= pow(gbuffer.mcLightmap.g, 0.1);
		finalComposite += specularGGX;
	}









	//GI
	finalComposite += gi.rgb * 1.0 * sunlightMult;
	//vec3 skyPos = normalize(vec3(worldDir.x, worldDir.y + log(eyeAltitude * 0.00001 + 1.0), worldDir.z));
	vec3 atmosphere = SkyShading(worldDir, worldSunVector);

	//sky
	if (skyChecker)
	{

		//float albedoCheck = sign(Luminance(gbuffer.albedo));
		//vec3 albedoForSky = 1.0 + albedoCheck * (gbuffer.albedo - 1.0);
		finalComposite += atmosphere * 0.8;
		//finalComposite += mix(atmosphere, atmosphere * albedoForSky, albedoCheck * 0.5);
		//finalComposite += atmosphere + albedoCheck;


		vec3 sunDisc = vec3(RenderSunDisc(worldDir, worldSunVector));
		//finalComposite.rgb *= 1.0 + sunDisc * 950.0;

		//sunDisc *= normalize(atmosphere + 0.0001);
		sunDisc *= colorSunlight;
		sunDisc *= pow(saturate(worldSunVector.y + 0.1), 0.9);

		finalComposite += sunDisc * 5000.0 * pow(1.0 - rainStrength, 5.0);


		CloudPlane(finalComposite, viewDir, -worldDir, linearDepth, materialMask, worldLightVector, lightVector, gbuffer.depth);

		//worldPos.xyz = worldDir.xyz * 2670.0;
	}

	//finalComposite = vec3(saturate(dot(gbuffer.normal, viewDir)));
	//finalComposite = gbuffer.normal;



	//finalComposite = GetWavesNormal(worldPos.xyz + cameraPosition) * 0.5 + 0.5;


	finalComposite *= 0.0001;


	//finalComposite.rgb *= 2.5;













	finalComposite = LinearToGamma(finalComposite);



	finalComposite += rand(texcoord.st + sin(frameTimeCounter)) * (1.0 / 65535.0);
	gl_FragData[0] = vec4(finalComposite.rgb, 1.0);
}
