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


#define POINTLIGHT_FILL 2.0 // Amount of fill/ambient light to add to torchlight falloff. Higher values makes torchlight dim less intensely based on distance. [0.5 1.0 2.0 4.0 8.0]

#define TAA_ENABLED // Temporal Anti-Aliasing. Utilizes multiple rendered frames to reconstruct an anti-aliased image similar to supersampling. Can cause some artifacts.

#define SHADOW_TAA

#define SHADOW_MAP_BIAS 0.9

#define TRANSLUCENT_SHADOWS // Translucent shadows.

#define VOLUMETRIC_RAYS // Volumetric rays.
	#define RAYS_SAMPLES 16.0  // Ray samples. [8.0 16.0 24.0 32.0 48.0 64.0 72.0 100.0 120.0]
	#define TRANSLUCENT_RAYS // Translucent rays.


const int 		shadowMapResolution 	= 2048;	// Shadowmap resolution [1024 2048 4096 6144 8192 16384]
const float 	shadowDistance 			= 120.0; // Shadow distance. Set lower if you prefer nicer close shadows. Set higher if you prefer nicer distant shadows. [80.0 120.0 180.0 240.0 320.0 480.0]

/* DRAWBUFFERS:0246 */


uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform sampler2D noisetex;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;


varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 worldSunVector;
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

varying vec3 colorSunlight;
varying vec3 colorSkylight;

uniform int heldBlockLightValue;

uniform float shadowAngle;

uniform int frameCounter;

uniform float nightVision;

uniform vec2 taaJitter;
uniform float taaStrength;

#include "Common.inc"

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

void FixNormals(inout vec3 normal, in vec3 viewPosition)
{
	vec3 V = normalize(viewPosition.xyz);
	vec3 N = normal;

	float NdotV = dot(N, V);

	N = normalize(mix(normal, -V, clamp(pow((NdotV * 1.0), 1.0), 0.0, 1.0)));
	N = normalize(N + -V * 0.1 * clamp(NdotV + 0.4, 0.0, 1.0));

	normal = N;
}

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
	float ice;
	float slimeBlock;
};

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

	if (isEyeInWater > 0)
		mask.sky = 0.0f;
	else
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

	return mask;
}

vec3 WorldPosToShadowProjPosBias(vec3 worldPos, vec3 worldNormal, out float dist, out float distortFactor)
{

	vec4 shadowPos = shadowModelView * vec4(worldPos, 1.0);
		 shadowPos = shadowProjection * shadowPos;
		 shadowPos /= shadowPos.w;

	dist = length(shadowPos.xy);
	distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	shadowPos.xy *= 0.95f / distortFactor;
	shadowPos.z = mix(shadowPos.z, 0.5, 0.8);
	shadowPos = shadowPos * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates

	return shadowPos.xyz;
}

/*
 *From Craft Shader
 *Copyright 2018 Cheng Ming
 *Attribution-ShareAlike 4.0 International
 */
vec3 VolumetricRays(vec4 worldPos, vec3 worldNormal, float isSky, float brightness)
{
	if(rainStrength > 0.99f) return vec3(0.0);
	float raySamples = RAYS_SAMPLES;

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
	vec4 lightIncrease = vec4(0.0);
	vec4 prevLight = vec4(0.0);
	for(int i = 0; i < raySamples; i++){
		worldPos.xyz -= rayDir.xyz;

		vec3 rayPos = rayDir.xyz * dither + worldPos.xyz;
			 rayPos = WorldPosToShadowProjPosBias(rayPos, worldNormal, dist, distortFactor);

		//Offsets
		float diffthresh = dist - 0.10f;
			  diffthresh *= 1.5f / (shadowMapResolution / 2048.0f);
		rayPos.z -= diffthresh * 0.0008f;



		float raySample = texture2DLod(shadowtex0, rayPos.st, 0.0).x;
			  raySample = (rayPos.z <= raySample) ? 1.0 : 0.0;

		lightIncrease.a += (raySample + prevLight.a) * raySteps * brightness * 0.5;
		prevLight.a = raySample;

	#ifdef TRANSLUCENT_SHADOWS
	#ifdef TRANSLUCENT_RAYS
		float raySample2 = texture2DLod(shadowtex1, rayPos.st, 0.0).x;
			  raySample2 = (rayPos.z <= raySample2) ? 1.0 : 0.0;

		float rayNormalAlpha = texture2DLod(shadowcolor1, rayPos.st, 0.0).a;

		if(raySample == 0.0 && raySample2 == 1.0)
		{
			float rayNormalAlpha = texture2DLod(shadowcolor1, rayPos.st, 0.0).a;

			if(rayNormalAlpha <= (40.0 / 255.0))
			{
				vec3 colorRaySample = texture2DLod(shadowcolor0, rayPos.st, 0.0).rgb;
					 colorRaySample *= colorRaySample;

				if(rayNormalAlpha > 0.1)
				{
					colorRaySample *= 30.0;
					brightness = (1.0 - rainStrength) * 0.1;
				}

				lightIncrease.rgb += (colorRaySample + prevLight.rgb) * raySteps * brightness * 0.5;
				prevLight.rgb = colorRaySample;
			}
		}
	#endif
	#endif
	}

	lightIncrease.a += max(rayDistance - shadowDistance, 0.0) * brightness;
	lightIncrease.a *= (isSky > 0.5) ? 0.1 : 1.0;

	return lightIncrease.rgb + lightIncrease.a;
}

void WaterFog(inout vec3 color, inout vec3 origional, inout vec3 rayColor, MaterialMask mask, float waterSkylight, vec4 viewPos0, vec4 viewPos1, vec3 normal)
{
	if (mask.water > 0.5 || isEyeInWater > 0 || mask.ice > 0.5)
	{
		vec3 viewVector = normalize(viewPos0.xyz);


		float waterDepth = distance(viewPos0.xyz, viewPos1.xyz);
		if (isEyeInWater > 0)
		{
			waterDepth = length(viewPos0.xyz) * 0.5;
		}


		float fogDensity = 0.1;



		vec3 waterNormal = normalize(normal);

		vec3 waterFogColor = vec3(0.2, 0.6, 1.0) * 7.0;
			if (mask.ice > 0.5)
			{
				//waterFogColor = vec3(0.2, 0.6, 1.0) * 7.0;
				fogDensity = 0.025;
			}
			  waterFogColor *= 0.03 * dot(vec3(0.33333), colorSunlight);
			  waterFogColor *= (1.0 - rainStrength * 0.95);


		{
			waterFogColor *= 0.1;
			//waterFogColor *= pow(eyeBrightnessSmooth.y / 240.0f, 6.0f);


			vec3 waterSunlightVector = refract(-lightVector, upVector, 1.0 / 1.3333);

			float scatter = 1.0 / (pow(saturate(dot(waterSunlightVector, viewVector) * 0.5 + 0.5) * 20.0, 1.0) + 0.1);
			vec3 waterSunlightScatter = colorSunlight * scatter * waterFogColor * 4.0;

			float eyeWaterDepth = eyeBrightnessSmooth.y / 240.0;


			waterFogColor *= dot(viewVector, upVector) * 0.5 + 0.5;
			waterFogColor = waterFogColor + waterSunlightScatter;


			//waterFogColor *= pow(vec3(0.4, 0.72, 1.0) * 0.99, vec3(0.2 + (1.0 - eyeWaterDepth)));
			waterFogColor = mix(waterFogColor, waterFogColor * vec3(0.2, 0.4, 1.0), 1.0 - eyeWaterDepth);

			fogDensity *= 0.5;
		}


		float visibility  = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));


		vec3 viewVectorRefracted = refract(viewVector, waterNormal, 1.0 / 1.3333);
		float scatter = 1.0 / (pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5) * 20.0, 2.0) + 0.1);


		color *= pow(vec3(0.4, 0.75, 1.0) * 0.99, vec3(waterDepth * 0.25 + 0.25));
		color = mix(waterFogColor * 40.0, color, saturate(visibility));

		origional = mix(waterFogColor * 40.0, vec3(0.0), saturate(visibility));

		rayColor *= pow(vec3(0.4, 0.75, 1.0) * 0.99, vec3(waterDepth * 0.25 + 0.25));
		rayColor = mix(waterFogColor * 40.0, rayColor, saturate(visibility));
	}
}

void RainFog(inout vec3 color, inout vec3 origional, inout vec3 rayColor, MaterialMask mask, in vec3 viewPos, in vec3 worldPos, in vec3 worldDir)
{
	float dist = length(worldPos.xyz);

	float fogDensity = 0.01;
		  fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));
		  fogDensity *= rainStrength;

	float fogFactor = 1.0 - exp(-fogDensity * dist);
		  fogFactor *= fogFactor;

	vec3 fogColor = colorSkylight * vec3(fogFactor * rainStrength * 0.725);
		 fogColor *= 1.0 - clamp(mask.water + mask.ice + isEyeInWater, 0.0, 1.0) * 0.5;

	color += fogColor;
	origional += fogColor;
	rayColor += fogColor;
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main()
{
    GbufferData gbuffer 			= GetGbufferData();
	MaterialMask materialMask 		= CalculateMasks(gbuffer.materialID);

	vec4 viewPos0 					= GetViewPosition(texcoord.st, texture2D(depthtex0, texcoord.st).x);
	vec4 viewPos1 					= GetViewPosition(texcoord.st, gbuffer.depth);

	vec2 gaux1Data = texture2D(gaux1, texcoord.st).rg;

	if (materialMask.water > 0.5 || materialMask.ice > 0.5 || materialMask.stainedGlass > 0.5 || materialMask.stainedGlassP > 0.5 || materialMask.slimeBlock > 0.5)
	{
		gbuffer.normal = DecodeNormal(gaux1Data.xy);
		FixNormals(gbuffer.normal, viewPos0.xyz);

		gaux1Data.xy = EncodeNormal(gbuffer.normal);
	}

	vec4 worldPos0					= gbufferModelViewInverse * vec4(viewPos0.xyz, 1.0);
	vec4 worldPos1					= gbufferModelViewInverse * vec4(viewPos1.xyz, 1.0);
	vec3 worldDir 					= normalize(worldPos0.xyz);



	vec3 finalComposite = GammaToLinear(texture2D(gaux3, texcoord.st).rgb) * 10000.0;

	vec3 vRays = vec3(0.0);
	vec3 waterFog = vec3(0.0);

	#ifdef VOLUMETRIC_RAYS
		float rayStrength = 1.0;
		//vec3 skyPos = normalize(vec3(worldDir.x, worldDir.y + log(eyeAltitude * 0.00001 + 1.0), worldDir.z));

		float dist = length(viewPos1.xyz) * 0.004;
		vec3 getAtmosphericColor = AtmosphericScattering(worldDir, worldSunVector, 1.0, dist) * normalize(AtmosphereAbsorption(worldDir, dist) * sqrt(colorSunlight));
			 //getAtmosphericColor = mix(getAtmosphericColor, getAtmosphericColor * colorSunlight, 0.5);

		vec3 totalLight = getAtmosphericColor * rayStrength * 0.0065;

		float brightness  = pow((1.0 - shadowAngle) * 1.05, 32.0);
			  brightness  = saturate(brightness) * 0.5 + 0.5;
			  brightness *= 1.0 - rainStrength;

		//float fogFactor  = 1.0 - exp(-4.0 * dist);
			  //fogFactor *= fogFactor;

		vRays = VolumetricRays(worldPos0, gbuffer.normal, materialMask.sky, brightness);
		vRays *= totalLight;
	#endif

	WaterFog(finalComposite, waterFog, vRays, materialMask, gbuffer.mcLightmap.g, viewPos0, viewPos1, gbuffer.normal);

	if(materialMask.sky < 0.5)
	{
		RainFog(finalComposite, waterFog, vRays, materialMask, viewPos0.xyz, worldPos0.xyz, worldDir);
	}

	#ifdef VOLUMETRIC_RAYS
		if (materialMask.water < 0.5 && materialMask.ice < 0.5 && materialMask.stainedGlass < 0.5 && materialMask.stainedGlassP < 0.5 && materialMask.slimeBlock < 0.5 && gbuffer.smoothness < 0.507144)
		{
			finalComposite += vRays;
			vRays = vec3(0.0f);
		}
		else
		{
			vRays = LinearToGamma(vRays * 0.0001);
		}
	#endif

	finalComposite = LinearToGamma(finalComposite * 0.0001);
	waterFog = LinearToGamma(waterFog * 0.0001);

	vec4 gcolorData = texture2D(gcolor, texcoord.st);
	vec4 gnormalData = texture2D(gnormal, texcoord.st);
	gl_FragData[0] = vec4(gcolorData.rgb, waterFog.r);
	gl_FragData[1] = vec4(gnormalData.rg, waterFog.gb);
	gl_FragData[2] = vec4(gaux1Data, vRays.rg);
	gl_FragData[3] = vec4(finalComposite.rgb, vRays.b);
}
