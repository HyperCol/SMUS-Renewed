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



#include "Common.inc"


#define SHADOW_MAP_BIAS 0.9

#define GI_RENDER_RESOLUTION 1 // Render resolution of GI. 0 = High. 1 = Low. Set to 1 for faster but blurrier GI. [0 1]

#define RAYLEIGH_AMOUNT 1.0 // Density of atmospheric scattering. [0.5 1.0 1.5 2.0 3.0 4.0]

#define WATER_REFRACT_IOR 1.2

#define TORCHLIGHT_FILL 1.0 // Amount of fill/ambient light to add to torchlight falloff. Higher values makes torchlight dim less intensely based on distance. [0.5 1.0 2.0 4.0 8.0]

#define TORCHLIGHT_BRIGHTNESS 1.0 // Brightness of torch light. [0.5 1.0 2.0 3.0 4.0]

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.

#define SHADOW_TAA

#define SUNLIGHT_INTENSITY 1.0 // Intensity of sunlight. [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define COLORED_SHADOWS // Colored shadows from stained glass.

#define HELD_TORCHLIGHT // Holding an item with a light value will cast light into the scene when this is enabled. 

const int 		shadowMapResolution 	= 2048;	// Shadowmap resolution [1024 2048 4096]
const float 	shadowDistance 			= 120.0; // Shadow distance. Set lower if you prefer nicer close shadows. Set higher if you prefer nicer distant shadows. [80.0 120.0 180.0 240.0]
const float 	shadowIntervalSize 		= 4.0f;
const bool 		shadowHardwareFiltering = false;
const bool 		shadowHardwareFiltering0 = false;
const bool 		shadowHardwareFiltering1 = false;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = false;
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
const int 		gcolorFormat 			= RGB8;
const int 		gdepthFormat 			= RGBA8;
const int 		gnormalFormat 			= RGB16;
const int 		compositeFormat 		= RGB8;
const int 		gaux1Format 			= RGBA16;
const int 		gaux2Format 			= RGBA8;
const int 		gaux3Format 			= RGBA16;
const int 		gaux4Format 			= RGBA16;


const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;

const int 		noiseTextureResolution  = 64;

const float 	ambientOcclusionLevel 	= 0.0000001f;


const bool gaux3MipmapEnabled = true;
const bool gaux1MipmapEnabled = false;

const bool gaux4Clear = false;

const float wetnessHalflife = 1.0;
const float drynessHalflife = 60.0;

/* DRAWBUFFERS:26 */


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
uniform sampler2D shadowcolor;
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
uniform float shadowAngle;

uniform int frameCounter;

uniform float nightVision;

varying float heldLightBlacklist;

uniform vec2 taaJitter;
uniform float taaStrength;

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
	decoded += pow(decoded, 0.4) * 0.1 * TORCHLIGHT_FILL;

	return decoded;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) 
{
	vec2 coord = texcoord.st;

	coord *= resolution;
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

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
	float water;
	float stainedGlass;
	float stainedGlassP;
	float slimeBlock;
	float ice;
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

	data.mcLightmap = gbuffer1.rg;
	data.mcLightmap.g = CurveBlockLightSky(data.mcLightmap.g);
	data.mcLightmap.r = CurveBlockLightTorch(data.mcLightmap.r);
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
	mask.water 			= GetMaterialMask(6, materialID);
	mask.stainedGlass	= GetMaterialMask(7, materialID);
	mask.ice 			= GetMaterialMask(8, materialID);
	mask.stainedGlassP	= GetMaterialMask(50, materialID);
	mask.slimeBlock 	= GetMaterialMask(51, materialID);

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
	vec3 shadowNorm = normalize((shadowModelView * vec4(worldNormal.xyz, 0.0)).xyz) * vec3(1.0, 1.0, -1.0);

	vec4 shadowPos = shadowModelView * vec4(worldPos, 1.0);
		 shadowPos = shadowProjection * shadowPos;
		 shadowPos /= shadowPos.w;

#ifdef TAA_ENABLED
	#ifdef SHADOW_TAA
		shadowPos.xy += taaJitter / taaStrength;
	#endif
#endif

	dist = length(shadowPos.xy);
	distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	//shadowPos.xyz += shadowNorm * 0.002 * distortFactor;
	shadowPos.xy *= 0.95f / distortFactor;
	shadowPos.z = mix(shadowPos.z, 0.5, 0.8);
	shadowPos = shadowPos * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates

	return shadowPos.xyz;
}

vec3 CalculateSunlightVisibility(vec4 viewPos, MaterialMask mask, vec3 normal) {				//Calculates shadows
	if (rainStrength >= 0.99f)
		return vec3(1.0f);



	//if (shadingStruct.direct > 0.0f) {
		float distance = length(viewPos.xyz); //Get surface distance in meters
		
		float dist;
		float distortFactor;
		vec3 shadowProjPos = (gbufferModelViewInverse * viewPos).xyz;
			 shadowProjPos = WorldPosToShadowProjPosBias(shadowProjPos.xyz, normal, dist, distortFactor);


		float shadowMult = 0.0f;																			//Multiplier used to fade out shadows at distance
		float shading = 0.0f;

		float fademult = 0.15f;
			shadowMult = clamp((shadowDistance * 1.4f * fademult) - (distance * fademult), 0.0f, 1.0f);	//Calculate shadowMult to fade shadows out

	#ifdef COLORED_SHADOWS
		vec3 stainedGlassColorSum = vec3(0.0f);
		float shadowNormalAlphaSum = 0.0f;
	#endif

		if (shadowMult > 0.0) 
		{
			//float vpsSpread = 0.145 / distortFactor;
			float vpsSpread = 0.105 / distortFactor;

			float avgDepth = 0.0;
		#ifdef COLORED_SHADOWS
			float avgDepth2 = 0.0;
		#endif
			int c;

			for (int i = -1; i <= 1; i++)
			{
				for (int j = -1; j <= 1; j++)
				{
					vec2 lookupCoord = shadowProjPos.xy + (vec2(i, j) / shadowMapResolution) * 8.0 * vpsSpread;

					float depthSample = texture2DLod(shadowtex1, lookupCoord, 2).x;
						  depthSample = min(max(0.0, shadowProjPos.z - depthSample) * 1.0, 0.025);
					avgDepth += depthSample * depthSample;

				#ifdef COLORED_SHADOWS
					float shadowNormalAlpha = texture2DLod(shadowcolor1, lookupCoord, 0).a;

					if(shadowNormalAlpha < 0.1)
					{
						float depthSample2 = texture2DLod(shadowtex1, lookupCoord, 2).x;
							  depthSample2 = max(depthSample, depthSample2);
							  depthSample2 = min(max(0.0, shadowProjPos.z - depthSample2) * 1.0, 0.025);
						avgDepth2 += depthSample2 * depthSample2;
					}
				#endif

					c++;
				}
			}

			avgDepth /= c;
			avgDepth = sqrt(avgDepth);
		#ifdef COLORED_SHADOWS
			avgDepth2 /= c;
			avgDepth2 = sqrt(avgDepth2);
		#endif

			int count = 0;
			float spread = avgDepth * 0.625 * vpsSpread + 0.5 / shadowMapResolution;
		#ifdef COLORED_SHADOWS
			float spread2 = avgDepth2 * 1.5 * vpsSpread + 0.5 / shadowMapResolution;
		#endif

			//vec3 noise = CalculateNoisePattern1(vec2(0.0 + sin(frameTimeCounter)), 64.0);
			#ifdef TAA_ENABLED
				vec2 noise = rand(texcoord.st + sin(frameTimeCounter)).xy;
			#else
				vec2 noise = rand(texcoord.st).xy;
			#endif

			float dfs = 0.00022 * dist + (noise.y * 0.00005) + 0.00002 + avgDepth * 0.012;
		#ifdef COLORED_SHADOWS
			float dfs2 = 0.00022 * dist + (noise.y * 0.00005) + 0.00002 + avgDepth2 * 0.012;
		#endif

			for (int i = 0; i < 3; i++)
			{
				float fi = float(i + noise.x) * 0.1;
				float r = float(i + noise.x) * 3.14159265 * 2.0 * 1.61;

				vec2 radialPos = vec2(cos(r), sin(r));
				vec2 coordOffset = radialPos * spread * sqrt(fi) * 2.0;
				vec3 coord = vec3(shadowProjPos.st + coordOffset, shadowProjPos.z - dfs);

				float finalShadow = texture2DLod(shadowtex1, coord.st, 0).x;
				shading += 1.0 - saturate((coord.z - finalShadow) * 5200.0); 
				//shading += shadow2DLod(shadow, coord, 0).x;

			#ifdef COLORED_SHADOWS
				coordOffset = radialPos * spread2 * sqrt(fi) * 2.0;
				coord = vec3(shadowProjPos.st + coordOffset, shadowProjPos.z - dfs2);

				float shadowNormalAlpha = texture2DLod(shadowcolor1, coord.st, 0).a;
				shadowNormalAlphaSum += shadowNormalAlpha;

				if(shadowNormalAlpha < 0.1)
				{
					vec3 stainedGlassColor = texture2DLod(shadowcolor, coord.st, 0).rgb;
					stainedGlassColorSum += stainedGlassColor;
				}
			#endif
				count++;
			}
			shading /= count;
		#ifdef COLORED_SHADOWS
			stainedGlassColorSum /= count;
			shadowNormalAlphaSum /= count;
		#endif

		}

		float clampFactor = max(0.0, dist - 0.1) * 5.0 + 1.0;
		shading = saturate(((shading * 2.0 - 1.0) * clampFactor) * 0.5 + 0.5);

		vec3 result = vec3(shading);
	#ifdef COLORED_SHADOWS
		shadowNormalAlphaSum = saturate(((shadowNormalAlphaSum * 2.0 - 1.0) * clampFactor) * 0.5 + 0.5);

		stainedGlassColorSum *= stainedGlassColorSum;
		stainedGlassColorSum *= shading;
		result = mix(result, stainedGlassColorSum, vec3(1.0 - shadowNormalAlphaSum));
		//result *= stainedGlassColorSum;
	#endif

		result = mix(vec3(1.0), result, shadowMult);


		return result;
}

//Optimize by not needing to do a dot product every time
float MiePhase(float g, vec3 dir, vec3 lightDir)
{
	float VdotL = dot(dir, lightDir);

	float g2 = g * g;
	float theta = VdotL * 0.5f + 0.5f;
	float anisoFactor = 1.5 * ((1.0 - g2) / (2.0 + g2)) * ((theta * theta + 1.0f) / (1.0 + g2 - 2.0 * g * theta)) + g * theta;

	return anisoFactor;
}

/*
 *From Craft Shader
 *Copyright 2018 Cheng Ming
 *Attribution-ShareAlike 4.0 International
 */
float VolumetricRays(vec4 worldPos, vec3 worldNormal, float depth){
	if(rainStrength > 0.99f) return 0.0;
	float raySamples = 24.0;

	float rayDistance = length(worldPos.xyz); //Get surface distance in meters
	float raySteps = min(shadowDistance, rayDistance) / raySamples;

	vec3 camPosCentre = (gbufferModelViewInverse * vec4(vec3(0.0), 1.0)).xyz;
	vec3 rayDir = normalize(worldPos.xyz - camPosCentre) * raySteps;

#ifdef TAA_ENABLED
	float dither = rand(texcoord.st + sin(frameTimeCounter)).x;
#else
	float dither = rand(texcoord.st).x;
#endif

	float dist, distortFactor;
	float lightIncrease = 0.0;
	float prevLight = 0.0;
	for(int i = 0; i < raySamples; i++){
		worldPos.xyz -= rayDir.xyz;

		vec3 rayPos = rayDir.xyz * dither + worldPos.xyz;
			 rayPos = WorldPosToShadowProjPosBias(rayPos, worldNormal, dist, distortFactor);

		//Offsets
		float diffthresh = dist - 0.10f;
			  diffthresh *= 1.5f / (shadowMapResolution / 2048.0f);
		rayPos.z -= diffthresh * 0.0008f;

		float raySample = texture2D(shadowtex1, rayPos.st).x;
			  raySample = (rayPos.z <= raySample) ? 1.0 : 0.0;

		lightIncrease += (raySample + prevLight) * raySteps * 0.5;
		prevLight = raySample;
	}

	lightIncrease += max(rayDistance - shadowDistance, 0.0);
	lightIncrease *= (depth > 0.9999f) ? 0.005f : 1.0f;

	return lightIncrease;
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

	for (float i = -0.5f; i <= 0.5f; i += 1.0f)
	{
		for (float j = -0.5f; j <= 0.5f; j += 1.0f)
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
	indirectLight.rgb *= 1.44 * saturate(skylight * 7.0);

	return indirectLight;
}

vec3 GetWavesNormal(vec3 position) {

	vec2 coord = position.xz / 50.0;
	coord.xy -= position.y / 50.0;
	//coord -= floor(coord);

	coord = mod(coord, vec2(1.0));


	float texelScale = 4.0;

	//to fix color error with GL_CLAMP
	coord *= (resolution - texelScale * 0.5) * texel;


	vec3 normal;
	normal.xyz = DecodeNormal(texture2DLod(gaux1, coord, 2).zw);

	return normal;
}

vec3 FakeRefract(vec3 vector, vec3 normal, float ior)
{
	return refract(vector, normal, ior);
	//return vector + normal * 0.5;
}

float CalculateWaterCaustics(vec4 screenSpacePosition, MaterialMask mask)
{
	//if (shading.direct <= 0.0)
	//{
	//	return 0.0;
	//}
	if (isEyeInWater == 1)
	{
		if (mask.water > 0.5)
		{
			return 1.0;
		}
	}
	vec4 worldPos = gbufferModelViewInverse * screenSpacePosition;
	worldPos.xyz += cameraPosition.xyz;

	vec2 dither = CalculateNoisePattern1(vec2(0.0), 2.0).xy;
	// float waterPlaneHeight = worldPos.y + 8.0;
	float waterPlaneHeight = 63.0;

	// vec4 wlv = shadowModelViewInverse * vec4(0.0, 0.0, 1.0, 0.0);
	vec4 wlv = gbufferModelViewInverse * vec4(lightVector.xyz, 0.0);
	vec3 worldLightVector = -normalize(wlv.xyz);
	// worldLightVector = normalize(vec3(-1.0, 1.0, 0.0));

	float pointToWaterVerticalLength = min(abs(worldPos.y - waterPlaneHeight), 2.0);
	vec3 flatRefractVector = FakeRefract(worldLightVector, vec3(0.0, 1.0, 0.0), 1.0 / 1.3333);
	float pointToWaterLength = pointToWaterVerticalLength / -flatRefractVector.y;
	vec3 lookupCenter = worldPos.xyz - flatRefractVector * pointToWaterLength;


	const float distanceThreshold = 0.15;

	const int numSamples = 1;
	int c = 0;

	float caustics = 0.0;

	for (int i = -numSamples; i <= numSamples; i++)
	{
		for (int j = -numSamples; j <= numSamples; j++)
		{
			vec2 offset = vec2(i + dither.x, j + dither.y) * 0.2;
			vec3 lookupPoint = lookupCenter + vec3(offset.x, 0.0, offset.y);
			// vec3 wavesNormal = normalize(GetWavesNormal(lookupPoint).xzy + vec3(0.0, 1.0, 0.0) * 100.0);
			vec3 wavesNormal = GetWavesNormal(lookupPoint).xzy;
			vec3 refractVector = FakeRefract(worldLightVector.xyz, wavesNormal.xyz, 1.0 / 1.3333);
			float rayLength = pointToWaterVerticalLength / refractVector.y;
			vec3 collisionPoint = lookupPoint - refractVector * rayLength;

			//float dist = distance(collisionPoint, worldPos.xyz);
			float dist = dot(collisionPoint - worldPos.xyz, collisionPoint - worldPos.xyz) * 7.1;

			caustics += 1.0 - saturate(dist / distanceThreshold);

			c++;
		}
	}

	caustics /= c;

	caustics /= distanceThreshold;


	return pow(caustics, 2.0) * 3.0;
}

vec3  	GetWaterNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return DecodeNormal(texture2D(gaux1, coord).xy);
}


void WaterFog(inout vec3 color, in MaterialMask mask, float waterSkylight, vec4 viewSpacePositionSolid, vec4 viewSpacePosition)
{
	// return;
	if (mask.water > 0.5 || isEyeInWater > 0 || mask.ice > 0.5)
	{
		//float depth = texture2D(depthtex1, texcoord.st).x;
		//float depthSolid = texture2D(gdepthtex, texcoord.st).x;

		//vec4 viewSpacePosition = GetScreenSpacePosition(texcoord.st, depth);
		//vec4 viewSpacePositionSolid = GetScreenSpacePosition(texcoord.st, depthSolid);

		vec3 viewVector = normalize(viewSpacePosition.xyz);


		float waterDepth = distance(viewSpacePosition.xyz, viewSpacePositionSolid.xyz);
		if (isEyeInWater > 0)
		{
			waterDepth = length(viewSpacePosition.xyz) * 0.5;		
			if (mask.water > 0.5 || mask.ice > 0.5)
			{
				waterDepth = length(viewSpacePosition.xyz) * 0.5;		
			}	
		}


		float fogDensity = 0.1;



		vec3 waterNormal = normalize(GetWaterNormals(texcoord.st));

		// vec3 waterFogColor = vec3(1.0, 1.0, 0.1);	//murky water
		// vec3 waterFogColor = vec3(0.2, 0.95, 0.0) * 1.0; //green water
		// vec3 waterFogColor = vec3(0.4, 0.95, 0.05) * 2.0; //green water
		// vec3 waterFogColor = vec3(0.7, 0.95, 0.00) * 0.75; //green water
		// vec3 waterFogColor = vec3(0.2, 0.95, 0.4) * 5.0; //green water
		// vec3 waterFogColor = vec3(0.2, 0.95, 1.0) * 1.0; //clear water
		//vec3 waterFogColor = vec3(0.05, 0.8, 1.0) * 2.0; //clear water
		vec3 waterFogColor = vec3(0.2, 0.6, 1.0) * 7.0;
			if (mask.ice > 0.5)
			{
				waterFogColor = vec3(0.2, 0.6, 1.0) * 7.0;
				fogDensity = 0.025;
			}
			  waterFogColor *= 0.01 * dot(vec3(0.33333), colorSunlight);
			  waterFogColor *= (1.0 - rainStrength * 0.95);
			  waterFogColor *= isEyeInWater * 2.0 + 1.0;



		if (isEyeInWater == 0)
		{
			waterFogColor *= waterSkylight;
		}
		else
		{
			waterFogColor *= 0.5;
			//waterFogColor *= pow(eyeBrightnessSmooth.y / 240.0f, 6.0f);


			vec3 waterSunlightVector = refract(-lightVector, upVector, 1.0 / WATER_REFRACT_IOR);

			//waterFogColor *= (dot(lightVector, viewVector) * 0.5 + 0.5) * 2.0 + 1.0;
			float scatter = 1.0 / (pow(saturate(dot(waterSunlightVector, viewVector) * 0.5 + 0.5) * 20.0, 1.0) + 0.1);
			vec3 waterSunlightScatter = colorSunlight * scatter * 1.0 * waterFogColor * 16.0;

			float eyeWaterDepth = eyeBrightnessSmooth.y / 240.0;


			waterFogColor *= dot(viewVector, upVector) * 0.5 + 0.5;
			waterFogColor = waterFogColor * pow(eyeWaterDepth, 1.0f) + waterSunlightScatter * pow(eyeWaterDepth, 1.0);
			//waterFogColor = waterFogColor + waterSunlightScatter;
		

			waterFogColor *= pow(vec3(0.4, 0.72, 1.0) * 0.99, vec3(0.2 + (1.0 - eyeWaterDepth)));

			fogDensity *= 0.5;
		}


		float visibility = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));
		float visibility2 = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));


		// float scatter = CalculateSunglow(surface);

		vec3 viewVectorRefracted = refract(viewVector, waterNormal, 1.0 / 1.3333);
		float scatter = 1.0 / (pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5) * 20.0, 2.0) + 0.1);
		//vec3 reflectedLightVector = reflect(lightVector, upVector);
			  //scatter += (1.0 / (pow(saturate(dot(-reflectedLightVector, viewVectorRefracted) * 0.5 + 0.5) * 30.0, 2.0) + 0.1)) * saturate(1.0 - dot(lightVector, upVector) * 1.4);

		// scatter += pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5), 3.0) * 0.02;
		if (isEyeInWater < 1)
		{
			waterFogColor = mix(waterFogColor, colorSunlight * 21.0 * waterFogColor, vec3(scatter * (1.0 - rainStrength)));
		}



		// color *= pow(vec3(0.7, 0.88, 1.0) * 0.99, vec3(waterDepth * 0.45 + 0.2));
		// color *= pow(vec3(0.7, 0.88, 1.0) * 0.99, vec3(waterDepth * 0.45 + 1.0));
		color *= pow(vec3(0.4, 0.75, 1.0) * 0.99, vec3(waterDepth * 0.25 + 0.25));
		// color *= pow(vec3(0.7, 1.0, 0.2) * 0.8, vec3(waterDepth * 0.15 + 0.1));
		color = mix(waterFogColor * 40.0, color, saturate(visibility));





	}
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

	if (isEyeInWater > 0.5)
	{
		origin.xy /= 0.82;
	}

	vec3 viewDir = normalize(origin.xyz);


	float nearCutoff = 0.50;
	float traceBias = 0.015;


	//Prevent self-intersection issues
	float viewDirDiff = dot(fwidth(viewDir), vec3(0.333333));


	vec3 rayPos = origin;
	vec3 rayDir = lightVector * 0.01;
	rayDir *= viewDirDiff * 1500.001;
	rayDir *= -origin.z * 0.28 + nearCutoff;


	//rayPos += rayDir * -origin.z * 0.000037 * traceBias;
	rayPos += rayDir * -origin.z * 0.000017 * traceBias;


#ifdef TAA_ENABLED
	float randomness = rand(texcoord.st + sin(frameTimeCounter)).x;
#else
	float randomness = 0.0;
#endif

	rayPos += rayDir * randomness;



	float zThickness = 0.025 * -origin.z;

	float shadow = 1.0;

	float numSamples = 12.0;


	float shadowStrength = 0.9;

/*
	if (mask.grass > 0.5)
	{
		shadowStrength = 0.4;
	}
	if (mask.leaves > 0.5)
	{
		shadowStrength = 0.5;
	}
*/

	if (mask.grass > 0.5)
	{
		shadowStrength = 0.6;
		zThickness *= 2.0;
	}
	if (mask.leaves > 0.5)
	{
		shadowStrength = 0.4;
	}


	// vec3 prevRayProjPos = ProjectBack(rayPos);

	for (int i = 0; i < numSamples; i++)
	{
		float fi = float(i) / numSamples;

		rayPos += rayDir;

		vec3 rayProjPos = ProjectBack(rayPos);

	#ifdef TAA_ENABLED
		rayProjPos.st += taaJitter;
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


void LandAtmosphericScattering(inout vec3 color, in vec3 viewPos, in vec3 viewDir)
{
	float dist = length(viewPos);

	float fogDensity = 0.003 * RAYLEIGH_AMOUNT;
	float fogFactor = pow(1.0 - exp(-dist * fogDensity), 2.0);


	vec3 absorption = vec3(0.2, 0.45, 1.0);

	color *= exp(-dist * absorption * fogDensity * 0.27);
	color += max(vec3(0.0), vec3(1.0) - exp(-fogFactor * absorption)) * mix(colorSunlight, vec3(dot(colorSunlight, vec3(0.33333))), vec3(0.9)) * 2.0;

	float VdotL = dot(viewDir, sunVector);

	float g = 0.72;
				//float g = 0.9;
	float g2 = g * g;
	float theta = VdotL * 0.5 + 0.5;
	float anisoFactor = 1.5 * ((1.0 - g2) / (2.0 + g2)) * ((1.0 + theta * theta) / (1.0 + g2 - 2.0 * g * theta)) + g * theta;

	color += colorSunlight * fogFactor * 0.2 * anisoFactor;

}

void ContextualFog(inout vec3 color, in vec3 viewPos, in vec3 viewDir, float density)
{
	float dist = length(viewPos);

	float fogDensity = density * 0.019;
		  fogDensity *= 1.0 -  saturate(viewDir.y * 0.5 + 0.5) * exp(-density * 0.125);
		  fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

	float fogFactor = pow(1.0 - exp(-dist * fogDensity), 1.6);
		  //fogFactor = 1.0 -  saturate(viewDir.y * 0.5 + 0.5);




	vec3 fogColor = pow(gl_Fog.color.rgb, vec3(2.2));


	float VdotL = dot(viewDir, worldSunVector);

	float g = 0.72;
				//float g = 0.9;
		  //g = exp(-density) * 0.4 + 0.5;

	float g2 = g * g;
	float theta = VdotL * 0.5 + 0.5;
	float anisoFactor = 1.5 * ((1.0 - g2) / (2.0 + g2)) * ((1.0 + theta * theta) / (1.0 + g2 - 2.0 * g * theta)) + g * theta;


	float skyFactor = pow(saturate(viewDir.y * 0.5 + 0.5), 2.0);
		  //skyFactor = skyFactor * (3.0 - 2.0 * skyFactor);

	fogColor = colorSunlight * anisoFactor * (1.0 - rainStrength) + skyFactor * colorSkylight * 2.0;

	fogColor *= exp(-density * 1.5) * 2.0;

	color = mix(color, fogColor, fogFactor);

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



	float directLightFalloff = firstOrder * secondOrder;
	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

		  directLightFalloff *= anisoBackFactor;
	 	  directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));

	//noise *= saturate(1.0 - directLightFalloff);

	vec3 colorDirect = colorSunlight * 11.215f;
		 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), timeMidnight);
		 colorDirect *= 1.0f + pow(sunglow, 2.0f) * 120.0f * pow(directLightFalloff, 1.1f) * (1.0 - rainStrength * 0.8);
		 colorDirect *= 1.0f;


	vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(0.15f)) * 0.93f;
		 colorAmbient = mix(colorAmbient, vec3(0.4) * Luminance(colorSkylight), vec3(rainStrength));
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
		 colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));




	directLightFalloff *= mix(1.0, 0.085, rainStrength);

	//directLightFalloff += (pow(Get3DNoise(p3), 2.0f) * 0.5f + pow(Get3DNoise(p3 * 1.5f), 2.0f) * 0.25f) * 0.02f;
	//directLightFalloff *= Get3DNoise(p2);

	vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

	color *= 1.0f;

	color = mix(color, color * 0.9, rainStrength);


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

	float k = alpha / 2.0;
	vis = G1V(dotNL, k) * G1V(dotNV, k);

	vec3 specular = vec3(dotNL * D * F * vis) * colorSunlight;

	//specular = vec3(0.1);
	specular *= saturate(pow(1.0 - roughness, 0.7) * 2.0);

	return specular;
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() 
{



	GbufferData gbuffer 			= GetGbufferData();
	MaterialMask materialMask 		= CalculateMasks(gbuffer.materialID);

	if (materialMask.stainedGlass > 0.5 || materialMask.stainedGlassP > 0.5 || materialMask.slimeBlock > 0.5)
	{
		if (gbuffer.transparentAlbedo.a >= 0.9)
		{
			gbuffer.depth = texture2D(gdepthtex, texcoord.st).x;
			gbuffer.normal = DecodeNormal(texture2D(gaux1, texcoord.st).xy);
			gbuffer.albedo.rgb = GammaToLinear(gbuffer.transparentAlbedo.rgb);

			vec2 transparentLightmap = texture2D(composite, texcoord.st).rg;
			gbuffer.mcLightmap.x = CurveBlockLightTorch(transparentLightmap.x);
			gbuffer.mcLightmap.y = CurveBlockLightSky(transparentLightmap.y);

			materialMask.sky = 0.0;


		}

		gbuffer.smoothness = 0.0;
		gbuffer.metallic = 0.0;
	}

	// vec4 gnormalData = texture2D(gnormal, texcoord.st);
	// gl_FragData[0] = gnormalData;
	// gl_FragData[1] = vec4(gbuffer.albedo.rgb, 1.0);
	// return;

	if (materialMask.water > 0.5)
	{
		gbuffer.smoothness = 0.0;
		gbuffer.metallic = 0.0;
	}

	vec4 viewPos 					= GetViewPosition(texcoord.st, gbuffer.depth);

	vec4 worldPos					= gbufferModelViewInverse * vec4(viewPos.xyz, 0.0);
	vec3 viewDir 					= normalize(viewPos.xyz);
	vec3 worldDir 					= normalize(worldPos.xyz);
	//vec3 worldLightVector 			= normalize((gbufferModelViewInverse * vec4(lightVector, 0.0)).xyz);
	//vec3 worldSunVector 			= normalize((gbufferModelViewInverse * vec4(sunVector, 0.0)).xyz);
	vec3 worldNormal 				= normalize((gbufferModelViewInverse * vec4(gbuffer.normal, 0.0)).xyz);
	vec3 worldTransparentNormal 	= normalize((gbufferModelViewInverse * vec4(GetWaterNormals(texcoord.st), 0.0)).xyz);
	float linearDepth 				= length(viewPos.xyz);

	vec3 finalComposite = vec3(0.0);

	float multiply = 0.7;
	gbuffer.albedo *= 1.0 + materialMask.water         * multiply;
	gbuffer.albedo *= 1.0 + materialMask.ice           * multiply;
	gbuffer.albedo *= 1.0 + materialMask.stainedGlass  * multiply;
	gbuffer.albedo *= 1.0 + materialMask.stainedGlassP * multiply;
	gbuffer.albedo *= 1.0 + materialMask.slimeBlock    * multiply;

	if (materialMask.water > 0.5 || materialMask.ice > 0.5)
	{
		gbuffer.mcLightmap.g = CurveBlockLightSky(texture2D(composite, texcoord.st).g);
	}






	//GI
	vec4 gi = GetGI(gbuffer.albedo, gbuffer.normal, gbuffer.depth, gbuffer.mcLightmap.g);
	// vec4 gi = vec4(0.0, 0.0, 0.0, 1.0);

	vec3 fakeGI = normalize(gbuffer.albedo + 0.0001) * pow(length(gbuffer.albedo), 1.0) * colorSunlight * 0.08 * gbuffer.mcLightmap.g;
	float fakeGIFade = saturate((shadowDistance * 0.1 * 1.0) - length(viewPos) * 0.1);

	gi.rgb = mix(fakeGI, gi.rgb, vec3(fakeGIFade));

	float ao = gi.a;
	//float ao = 1.0;

	//gi.rgb *= ao;






	//grass points up
	if (materialMask.grass > 0.5)
		worldNormal = vec3(0.0, 1.0, 0.0);







	//shading from sky
	vec3 skylight = FromSH(skySHR, skySHG, skySHB, worldNormal);
	skylight = mix(skylight, vec3(0.3) * (dot(worldNormal, vec3(0.0, 1.0, 0.0)) * 0.35 + 0.65) * Luminance(colorSkylight), vec3(rainStrength));
	skylight *= gbuffer.mcLightmap.g;
	//skylight *= dot(worldNormal, vec3(0.0, 1.0, 0.0)) * 0.2 + 0.8;
	
	finalComposite += skylight * gbuffer.albedo * 2.0 * ao;




	//Torchlight
	const float torchlightBrightness = 3.7 * TORCHLIGHT_BRIGHTNESS;


	finalComposite += gbuffer.mcLightmap.r * colorTorchlight * gbuffer.albedo * 0.5 * ao * torchlightBrightness;

	#ifdef HELD_TORCHLIGHT
	//held torch light
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
	float sunlightMult = 12.0 * exp(-contextualFogFactor * 2.5) * (1.0 - rainStrength) * SUNLIGHT_INTENSITY;

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

	if (materialMask.water > 0.5 || isEyeInWater > 0.5)
	{
		sunlight *= CalculateWaterCaustics(viewPos, materialMask);
	}


	sunlight *= pow(gbuffer.mcLightmap.g, 0.1 + isEyeInWater * 0.4);
 
	vec3 shadow = CalculateSunlightVisibility(viewPos, materialMask, gbuffer.normal);
	//vec3 shadow = vec3(1.0);
	if (isEyeInWater < 1)
	{
		shadow *= ScreenSpaceShadow(viewPos.xyz, gbuffer.normal.xyz, materialMask);
	}
	//float cloudShadow = CloudShadow(lightVector, viewPos);
	float cloudShadow = 1.0;
	shadow *= cloudShadow;
	shadow *= gbuffer.parallaxShadow;
	gi.rgb *= cloudShadow * 0.88 + 0.12;

	finalComposite += sunlight * gbuffer.albedo * shadow * sunlightMult * colorSunlight;



	//Sunlight specular
	vec3 specularGGX = SpecularGGX(worldNormal, -worldDir, worldLightVector, pow(1.0 - pow(gbuffer.smoothness, 1.0), 1.0), gbuffer.metallic * 0.98 + 0.02) * sunlightMult * shadow;
	specularGGX *= pow(gbuffer.mcLightmap.g, 0.1);

	if (isEyeInWater < 0.5)
	{
		finalComposite += specularGGX;
	}









	//GI
	finalComposite += gi.rgb * 1.0 * sunlightMult;

	vec4 viewPosTransparent = GetViewPosition(texcoord.st, texture2D(gdepthtex, texcoord.st).x);


	//Refraction of unterwater surface and total internal reflection detection for water
	if (isEyeInWater > 0)
	{
		if (materialMask.water > 0.5)
		{
			worldDir = refract(worldDir, worldTransparentNormal, WATER_REFRACT_IOR);
		}
	}

	float nightBrightness = 0.00025 * (1.0 + 32.0 * nightVision);

	//sky
	if (materialMask.sky > 0.5 || (isEyeInWater > 0 || materialMask.ice > 0.5 || materialMask.stainedGlass > 0.5 || materialMask.stainedGlassP > 0.5 || materialMask.slimeBlock > 0.5 || materialMask.water > 0.5) && gbuffer.depth > 0.9999999)
	// if (materialMask.sky > 0.5)
	{



		//remove sun texture
		gbuffer.albedo *= 1.0 - saturate((dot(worldDir, worldSunVector) - 0.95) * 50.0);

		//finalComposite.rgb = vec3(1.0);
		vec3 sunDisc = vec3(RenderSunDisc(worldDir, worldSunVector));
		vec3 atmosphere = AtmosphericScattering(vec3(worldDir.x, (worldDir.y), worldDir.z), worldSunVector, 1.0);


		atmosphere = mix(atmosphere, vec3(0.6) * Luminance(colorSkylight), vec3(rainStrength * 0.95));
		//atmosphere = mix(atmosphere, vec3(dot(atmosphere, vec3(0.333333))), vec3(-0.4));
		//atmosphere *= skyTint;

		finalComposite.rgb = atmosphere;
		//finalComposite.rgb *= 1.0 + sunDisc * 950.0;

		//sunDisc *= normalize(atmosphere + 0.0001);
		sunDisc *= colorSunlight;
		sunDisc *= pow(saturate(worldSunVector.y + 0.1), 0.9);

		finalComposite += sunDisc * 5000.0 * pow(1.0 - rainStrength, 5.0);



//void CloudPlane(inout vec3 color, vec3 viewDir, vec3 worldVector, float linearDepth, MaterialMask mask, vec3 worldLightVector, vec3 lightVector)

		CloudPlane(finalComposite, viewDir, -worldDir, linearDepth, materialMask, worldLightVector, lightVector, gbuffer.depth);



		vec3 moonAtmosphere = AtmosphericScattering(vec3(worldDir.x, (worldDir.y), worldDir.z), -worldSunVector, 1.0);
		moonAtmosphere = mix(moonAtmosphere, vec3(0.6) * nightBrightness, vec3(rainStrength * 0.95));

		finalComposite += moonAtmosphere * nightBrightness;

		//if (linearDepth < far - 1.0)
		//{
			finalComposite += gbuffer.albedo * normalize(moonAtmosphere + 0.0000001) * 0.13 * (1.0 - rainStrength * 0.99);
		//}


		worldPos.xyz = worldDir.xyz * 2670.0;
	}
	else
	{
		//finalComposite += AtmosphericScattering(worldDir, worldSunVector, 1.0, ExpToLinearDepth(gbuffer.depth) * 0.000005);
		//LandAtmosphericScattering(finalComposite, viewPos.xyz, viewDir.xyz);

	}

	//If total internal reflection, make black
	float totalInternalReflection = 0.0;
	if (length(worldDir) < 0.5)
	{
		finalComposite *= 0.0;
		totalInternalReflection = 1.0;
	}

	{
		float anisoFactor = MiePhase(0.5, worldDir, worldLightVector) + MiePhase(0.375, worldDir, -worldLightVector) * 0.1;
		vec3 getSkyLight = FromSH(skySHR, skySHG, skySHB, vec3(0.0, 1.0, 0.0)) * 0.05f;
		vec3 totalLight = colorSunlight + getSkyLight * 0.5;

		float brightness = pow(1.05 - shadowAngle * 1.05, 32.0);
			  brightness = saturate(brightness) * 0.9 + 0.1;

		float vRays = VolumetricRays(worldPos, gbuffer.normal, gbuffer.depth);
		finalComposite += vRays * sunlightMult * totalLight * anisoFactor * brightness * 0.0003125;
	}

	//finalComposite = vec3(saturate(dot(gbuffer.normal, viewDir)));
	//finalComposite = gbuffer.normal;

		//ContextualFog(finalComposite, worldPos.xyz * 0.5, worldDir.xyz, contextualFogFactor);

	WaterFog(finalComposite, materialMask, gbuffer.mcLightmap.g, viewPos, viewPosTransparent);



	//finalComposite = GetWavesNormal(worldPos.xyz + cameraPosition) * 0.5 + 0.5;


	finalComposite *= 0.0001;


	//finalComposite.rgb *= 2.5;



	

	







	finalComposite = LinearToGamma(finalComposite);



	finalComposite += rand(texcoord.st + sin(frameTimeCounter)) * (1.0 / 65535.0);


	vec4 gnormalData = texture2D(gnormal, texcoord.st);
	gl_FragData[0] = vec4(gnormalData.xy, totalInternalReflection, 1.0);
	gl_FragData[1] = vec4(finalComposite.rgb, 1.0);
}
