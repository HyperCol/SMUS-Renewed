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


#define VOLUMETRIC_RAYS // Volumetric rays.

#define RAY_TRACE_SAMPLES 1 // Screen sapce ray tracing samples. High performance cost! [1 5 10 15 20 25 30 35 40]
#define FAKE_SKY_TRACE_SAMPLES 1 // Samples of fake sky tracing. High performance cost! [1 5 10 15 20 25 30 35 40]

#define WAVE_SURFACE_SAMPLES 4 // Higher is better. [3 4 5]

const int 		noiseTextureResolution  = 64;


/* DRAWBUFFERS:6 */


const bool gaux3MipmapEnabled = true;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform sampler2D noisetex;

uniform sampler2DShadow shadow;


varying vec4 texcoord;

uniform int worldTime;

uniform float near;
uniform float far;
uniform vec2 resolution;
uniform vec2 texel;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float sunAngle;
uniform float shadowAngle;
uniform float frameTimeCounter;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;

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

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

varying vec3 worldSunVector;
varying vec3 worldLightVector;

uniform float blindness;

uniform float nightVision;

uniform vec2 taaJitter;

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

///*
	float falloff = 10.0;

	blockLight = exp(-(1.0 - blockLight) * falloff);
	blockLight = max(0.0, blockLight - exp(-falloff));
//*/

/*
	float lightmap = blockLight;

	//Apply inverse square law and normalize for natural light falloff
	lightmap 		= clamp(lightmap * 1.22f, 0.0f, 1.0f);
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.6f;
	lightmap 		= 1.0f / pow((lightmap + 0.8f), 2.0f);
	lightmap 		-= 0.02435f;

	// if (lightmap <= 0.0f)
		// lightmap = 1.0f;

	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= 0.008f;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap, 0.9f);


	blockLight = lightmap * 10.0;
*/
	return blockLight;
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


/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

GbufferData GetGbufferData()
{
	GbufferData data;


	vec3 gbuffer0 = texture2D(gcolor, texcoord.st).rgb;
	vec3 gbuffer1 = texture2D(gdepth, texcoord.st).rgb;
	vec2 gbuffer2 = texture2D(gnormal, texcoord.st).rg;
	vec3 gbuffer3 = texture2D(composite, texcoord.st).rgb;
	float depth = texture2D(depthtex0, texcoord.st).x;


	data.albedo = GammaToLinear(gbuffer0);

	data.mcLightmap = gbuffer3.rg;
	data.mcLightmap.g = CurveBlockLightSky(data.mcLightmap.g);
	data.mcLightmap.r = CurveBlockLightTorch(data.mcLightmap.r);
	data.emissive = gbuffer1.b;

	data.normal = DecodeNormal(gbuffer2);

	data.smoothness = gbuffer3.r;
	data.metallic = gbuffer3.g;
	data.materialID = gbuffer3.b;

	data.depth = depth;

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

float GetMaterialIDs(vec2 coord)
{
	return texture2D(composite, coord).b;
}

vec3  	GetWaterNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return DecodeNormal(texture2D(gaux1, coord).xy);
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

vec3 convertScreenSpaceToWorldSpace(vec2 coord) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(coord, texture2DLod(depthtex0, coord, 0).x) * 2.0 - 1.0, 1.0);
		 fragposition /= fragposition.w;

    return fragposition.xyz;
}

vec3 ProjectBack(vec3 cameraSpace)
{
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;

    return screenSpace;
}

vec4 	ComputeScreenSpaceRaytrace(vec3 normal, float roughness, bool edgeClamping, float rayType)
{
	float depth = texture2D(depthtex0, texcoord.st).x;
    vec3 camPos = GetViewPosition(texcoord.st, depth).xyz;

    vec3 cameraSpaceViewDir = normalize(camPos);
	vec3 camVecOrig = vec3(0.0);
	float angle = 0.0;
	if (rayType > 0.0)
	{
		camVecOrig = normalize(refract(cameraSpaceViewDir, normal, 1.0 / rayType));
		angle = 1.0 - dot(camVecOrig, normal);
	}
	else
	{
		camVecOrig = normalize(reflect(cameraSpaceViewDir, normal));
		angle = dot(camVecOrig, normal);
	}

	int samp = RAY_TRACE_SAMPLES;

	float roughnessCheck = step(roughness + angle, 0.0);
	samp = int(roughnessCheck) + (1 - int(roughnessCheck)) * samp;

    const int maxRefinements = 5;
	int numRefinements = 0;
    int count = 0;
	vec2 finalSampPos = vec2(0.0f);

	vec4 color = vec4(0.0);

	for(int i = 1; i <= samp; i++)
	{
		float alpha = float(i) * 3.14159265358 * 3.22;
		vec3 offs = vec3(cos(alpha), sin(alpha), 1.0 - cos(alpha)) * (float(i) / float(samp));
			 offs *= rand(texcoord.st + sin(frameTimeCounter)) * angle * roughness * 0.1;
		vec3 camVec = normalize(camVecOrig + offs);

		vec3 camVecPos = camPos + camVec;
		vec3 currPos = ProjectBack(camVecPos);

		int numSteps = 0;

		for (int j = 0; j < 40; j++)
		{
			if(/*-camVecPos.z > far * 1.4f || */-camVecPos.z < 0.0f)
			{
				break;
			}

			vec2 sampPos = currPos.xy;

			depth = texture2D(depthtex1, sampPos.st).x;
			float sampDepth = GetViewPosition(sampPos.st, depth).z;
			float currDepth = camVecPos.z;

			float diff = sampDepth - currDepth;
			float error = length(camVec / pow(2.0f, numRefinements));


			//If a collision was detected, refine raymarch
			if(diff >= 0 && diff <= error * 2.00f && numRefinements <= maxRefinements)
			{
				//Step back
				camVecPos -= camVec / pow(2.0f, numRefinements);
				++numRefinements;
		//If refinements run out
			}
			else if (diff >= 0 && diff <= error * 4.0f && numRefinements > maxRefinements)
			{
				finalSampPos = sampPos;
				break;
			}



			camVecPos += camVec / pow(2.0f, numRefinements);

			if (numSteps > 1)
			camVec *= 1.375f;	//Each step gets bigger

			currPos = ProjectBack(camVecPos);

			if (edgeClamping)
			{
				currPos = clamp(currPos, vec3(0.001), vec3(0.999));
			}
			else
			{
				if (currPos.x < 0 || currPos.x > 1 ||
					currPos.y < 0 || currPos.y > 1 /*||
					currPos.z < 0 || currPos.z > 1*/)
				{
					break;
				}
			}



        count++;
        numSteps++;
		}

		if (finalSampPos.x * finalSampPos.y != 0.0f) {
			color += vec4(GammaToLinear(texture2D(gaux3, finalSampPos).rgb), 1.0);
/*
		#ifdef VOLUMETRIC_RAYS
			vec3 raysData = vec3(texture2D(gaux1, finalSampPos).ba, texture2D(gaux3, finalSampPos).a);
				 raysData = GammaToLinear(raysData);

			color.rgb += raysData;
		#endif
*/
		}
	}

	color /= float(samp);

    return color;
}

float RenderSunDisc(vec3 worldDir, vec3 sunDir)
{
	float d = dot(worldDir, sunDir);

	float disc = 0.0;

	//if (d > 0.99)
	//	disc = 1.0;

	float size = 0.00195;
	float hardness = 1000.0;

	disc = pow(curve(saturate((d - (1.0 - size)) * hardness)), 2.0);

	float visibility = curve(saturate(worldDir.y * 30.0));

	disc *= visibility;

	return disc;
}

vec4 ComputeFakeSky(vec3 dir, vec3 normal, MaterialMask mask, float roughness, float rayType)
{
	vec4 color = vec4(0.0);
	vec3 dirOrig = dir;
	float angle = dot(dirOrig, normal);
	if (rayType > 0.0)
	{
		angle = 1.0 - angle;
	}

	int samp = FAKE_SKY_TRACE_SAMPLES;

	float roughnessCheck = step(roughness + angle, 0.0);
	samp = int(roughnessCheck) + (1 - int(roughnessCheck)) * samp;

	for(int i = 1; i <= samp; i++)
	{
		float alpha = float(i) * 3.14159265358 * 3.22;
		vec3 offs = vec3(cos(alpha), sin(alpha), 1.0 - cos(alpha)) * (float(i) / float(samp));
			 offs *= rand(texcoord.st + sin(frameTimeCounter)) * angle * roughness * 0.1;

		dir = normalize(dirOrig + offs);
		vec3 worldDir = normalize((gbufferModelViewInverse * vec4(dir.xyz, 1.0)).xyz);
		float fresnel = pow(saturate(dot(-dir, normal) + 1.0), 5.0) * 0.98 + 0.02;

		vec3 sky = SkyShading(worldDir.xyz, worldSunVector);


		vec3 sunDisc = vec3(RenderSunDisc(worldDir, worldSunVector));
		//sunDisc *= normalize(sky + 0.001);
		sunDisc *= colorSunlight;
		sunDisc *= pow(saturate(worldSunVector.y + 0.1), 0.9);
		sunDisc *= 5000.0 * pow(1.0 - rainStrength, 5.0);

		//if (mask.water > 0.5)

		sunDisc *= saturate(mask.water + roughness);
		sky += sunDisc;



		color += vec4(sky * 0.8 * 0.0001, fresnel);
	}

	return color / float(samp);
}

void WaterRefraction(inout vec3 color, MaterialMask mask, vec4 viewPos, vec4 viewPos1, float depth0, float depth1, vec3 normal, float skylight, out float totalInternalReflectionMask)
{

	if (mask.water > 0.5 || mask.ice > 0.5 || mask.stainedGlass > 0.5 || mask.stainedGlassP > 0.5 || mask.slimeBlock > 0.5)
	{
		vec3 wavesNormal = (gbufferModelView * vec4(normal, 1.0)).xyz;
		if (mask.water > 0.5)
		{
			wavesNormal = normalize(wavesNormal * 4.0);
		}
		//wavesNormal = (gbufferModelViewInverse * vec4(wavesNormal, 1.0)).xyz;
/*
		float waterDeep = length(viewPos1.xyz) - length(viewPos.xyz);

		float refractAmount = saturate(waterDeep) * 0.125;

		float aberration = 0.025;
		float refractionAmount = 1.0;

		float blurLevel = 1.0;

		if (mask.water > 0.5)
		{
			blurLevel = 2.5;

			if(isEyeInWater > 0.5)
			{
				refractionAmount = -1.3333;
			}
			else
			{
				refractionAmount = 1.3333;
			}
		}
		else if (mask.stainedGlass > 0.5)
		{
			blurLevel = 0.75;
			refractionAmount = 1.5000;
		}
		else if (mask.stainedGlassP > 0.5)
		{
			blurLevel = 0.25;
			refractionAmount = 0.1875;
		}
		else if (mask.ice > 0.5)
		{
			blurLevel = 25.0;
			refractionAmount = 1.3090;
		}
		else if (mask.slimeBlock > 0.5)
		{
			aberration = 0.0;
			blurLevel = 48.0;
			refractionAmount = 0.5;
		}

		vec2 refractCoord0 = texcoord.st;
		vec2 refractCoord1 = texcoord.st;
		vec2 refractCoord2 = texcoord.st;

		if(depth0 < depth1)
		{
			vec2 offsets = wavesNormal.xy / (length(viewPos.xyz) + 1.05) * refractAmount;

			refractCoord0 -= offsets * refractionAmount;
			refractCoord1 -= offsets * (refractionAmount + aberration);
			refractCoord2 -= offsets * (refractionAmount + aberration * 2.0);
		}

		float fogDensity = 0.40;
		float visibility = 1.0f / exp(waterDeep * fogDensity) * refractionAmount;


		vec4 blendWeights = vec4(1.0, 0.0001, 0.00005, 0.00001);
		blendWeights = pow(blendWeights, vec4(visibility));

		float blendWeightsTotal = dot(blendWeights, vec4(1.0));
		vec4 blur = log2(min(resolution.x, resolution.y)) * vec4(0.10, 0.50, 2.25, 4.00) * blurLevel * 0.125;

		color.r = (GammaToLinear(texture2DLod(gaux3, refractCoord0.xy, blur.x).r) * blendWeights.x
				 + GammaToLinear(texture2DLod(gaux3, refractCoord0.xy, blur.y).r) * blendWeights.y
				 + GammaToLinear(texture2DLod(gaux3, refractCoord0.xy, blur.z).r) * blendWeights.z
				 + GammaToLinear(texture2DLod(gaux3, refractCoord0.xy, blur.w).r) * blendWeights.w
				  ) / blendWeightsTotal;

		color.g = (GammaToLinear(texture2DLod(gaux3, refractCoord1.xy, blur.x).g) * blendWeights.x
				 + GammaToLinear(texture2DLod(gaux3, refractCoord1.xy, blur.y).g) * blendWeights.y
				 + GammaToLinear(texture2DLod(gaux3, refractCoord1.xy, blur.z).g) * blendWeights.z
				 + GammaToLinear(texture2DLod(gaux3, refractCoord1.xy, blur.w).g) * blendWeights.w
				  ) / blendWeightsTotal;

		color.b = (GammaToLinear(texture2DLod(gaux3, refractCoord2.xy, blur.x).b) * blendWeights.x
				 + GammaToLinear(texture2DLod(gaux3, refractCoord2.xy, blur.y).b) * blendWeights.y
				 + GammaToLinear(texture2DLod(gaux3, refractCoord2.xy, blur.z).b) * blendWeights.z
				 + GammaToLinear(texture2DLod(gaux3, refractCoord2.xy, blur.w).b) * blendWeights.w
				  ) / blendWeightsTotal;
*/

		float ior = 0.0;

		float roughness = 0.0;

		if (mask.water > 0.5)
		{
			roughness = 0.0375;

			if(isEyeInWater > 0.5)
			{
				ior = -0.3;
			}
			else
			{
				ior = 0.3;
			}
		}
		else if (mask.stainedGlass > 0.5)
		{
			roughness = 0.025;
			ior = 0.275;
		}
		else if (mask.stainedGlassP > 0.5)
		{
			roughness = 0.0;
			ior = 0.05;
		}
		else if (mask.ice > 0.5)
		{
			roughness = 0.125;
			ior = 0.3090;
		}
		else if (mask.slimeBlock > 0.5)
		{
			roughness = 1.0;
			ior = 0.2000;
		}
		ior = ior * 0.25 + 1.0;


		vec3 noDataToRefract = GammaToLinear(texture2D(gaux3, texcoord.st + rand(texcoord.st + sin(frameTimeCounter)).xy * roughness * 0.04, 0.0).rgb);
		vec4 refraction = vec4(noDataToRefract, 1.0);
		if(isEyeInWater > 0)
		{
			refraction = ComputeScreenSpaceRaytrace(normal, roughness, true, ior);
		}
		else
		{
			refraction = ComputeScreenSpaceRaytrace(normal, roughness, false, ior);
		}

		color.rgb = mix(noDataToRefract, refraction.rgb, vec3(refraction.a));
		totalInternalReflectionMask = 1.0 - refraction.a;

	}
}

void 	CalculateSpecularReflections(inout vec3 color, vec3 normal, MaterialMask mask, vec3 albedo, float smoothness, float metallic, float skylight, vec3 viewVector, float totalInternalReflectionMask)
{
	float specularity = smoothness * smoothness * smoothness;
	      specularity = max(0.0f, specularity * 1.15f - 0.15f);
	float roughness = 1.0 - smoothness;
		  roughness = sqrt(roughness);
	vec3 specularColor = vec3(1.0f);

	//metallic = pow(metallic, 2.2);
	metallic = metallic * 0.98 + 0.02;
	//metallic = pow(metallic, 2.2);

	bool defaultItself = true;

	//if (mask.sky > 0.5)
		//specularity = 0.0f;


	if (mask.water > 0.5)
	{
		defaultItself = false;
		specularity = 1.0f;
		metallic = 0.0;
		roughness = 0.0;

	}
	else if(mask.stainedGlass > 0.5 || mask.stainedGlassP > 0.5)
	{
		defaultItself = false;
		specularity = 0.875f;
		metallic = 0.0;
		roughness = 0.0;
	}
	else if(mask.ice > 0.5)
	{
		defaultItself = false;
		specularity = 0.5f;
		metallic = 0.0;
	}
	else
	{
		skylight = CurveBlockLightSky(texture2D(gdepth, texcoord.st).g);
	}

	if (mask.slimeBlock > 0.5)
	{
		specularity = 0.0;
		roughness = 1.0;
	}


	vec3 original = color.rgb;

	if (specularity > 0.00f)
	{
		if (isEyeInWater > 0 && mask.water > 0.5)
		{
			vec4 reflection = ComputeScreenSpaceRaytrace(normal, roughness, true, 0.0);
			vec3 colorData = vec3(texture2D(gcolor, texcoord.st).a, texture2D(gnormal, texcoord.st).ba);
				 colorData = color.rgb * (1.0 - totalInternalReflectionMask)
				 		   + GammaToLinear(colorData) * (1.0 - reflection.a) * totalInternalReflectionMask;

			reflection.a *= totalInternalReflectionMask;

			color.rgb = mix(colorData, reflection.rgb, vec3(reflection.a));

		}
		else
		{
			vec4 reflection = ComputeScreenSpaceRaytrace(normal, roughness, false, 0.0);
			//vec4 reflection = RayTraceReflection(normal, false);
			//vec4 reflection = vec4(0.0f);

			vec3 reflectVector = reflect(viewVector, normal);

			vec4 fakeSkyReflection = ComputeFakeSky(reflectVector, normal, mask, roughness, 0.0);

			vec3 noSkyToReflect = vec3(0.0f);

			if (defaultItself)
			{
				noSkyToReflect = color.rgb;
			}

			fakeSkyReflection.rgb = mix(noSkyToReflect, fakeSkyReflection.rgb, clamp(skylight * 16 - 5, 0.0f, 1.0f));
			reflection.rgb = mix(reflection.rgb, fakeSkyReflection.rgb, pow(vec3(1.0f - reflection.a), vec3(10.1f)));
			reflection.a = fakeSkyReflection.a * specularity;


			//reflection.rgb *= specularColor;
			reflection.a = mix(reflection.a, 1.0, metallic);
			reflection.rgb *= mix(vec3(1.0), albedo.rgb, vec3(metallic));

			color.rgb = mix(color.rgb, reflection.rgb, vec3(reflection.a));
		}
	}

	//color.rgb = mix(color.rgb, original, vec3(surface.cloudAlpha));
}

void TransparentAbsorption(inout vec3 color, MaterialMask mask, vec4 worldSpacePosition, float waterDepth, float opaqueDepth)
{
	if (mask.stainedGlass > 0.5 || mask.stainedGlassP > 0.5 || mask.slimeBlock > 0.5)
	{
		vec4 transparentAlbedo = texture2D(gaux2, texcoord.st);
			 transparentAlbedo.rgb = GammaToLinear(transparentAlbedo.rgb);

		if(mask.slimeBlock > 0.5)
		{
			transparentAlbedo.rgb = mix(vec3(1.0), transparentAlbedo.rgb, vec3(0.875));
		}

		transparentAlbedo.rgb = sqrt(length(transparentAlbedo.rgb)) * normalize(transparentAlbedo.rgb + 0.00001);

		color *= transparentAlbedo.rgb * 2.0;
	}

}

void LandAtmosphericScattering(inout vec3 color, in vec3 viewPos, in vec3 viewDir, vec3 worldDir)
{
	float dist = length(viewPos);

	dist *= pow(saturate((eyeBrightnessSmooth.y / 240.0)), 6.0);

	color *= AtmosphereAbsorption(worldDir, dist * 0.005);

	color += Atmosphere(normalize(worldDir), worldSunVector, wetness, dist * mix(0.005, 0.015, wetness)) * 0.1
		* pow(1.0 - exp2(-dist * 0.02), 2.0);
}

void BlindnessFog(inout vec3 color, in vec3 viewPos, in vec3 viewDir)
{
	if (blindness < 0.001)
	{
		return;
	}
	float dist = length(viewPos);

	float fogDensity = 1.0 * blindness;

	float fogFactor = 1.0 - exp(-dist * fogDensity);
		  fogFactor *= fogFactor;

	vec3 fogColor = vec3(0.0);

	color = mix(color, fogColor, vec3(fogFactor));
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main()
{

	GbufferData gbuffer 			= GetGbufferData();



	MaterialMask materialMask 		= CalculateMasks(gbuffer.materialID);
	vec4 viewPos 					= GetViewPosition(texcoord.st, gbuffer.depth);
	vec4 viewPos1 					= GetViewPosition(texcoord.st, texture2D(depthtex1, texcoord.st).x);
	vec4 worldPos					= gbufferModelViewInverse * viewPos;
	vec3 viewDir 					= normalize(viewPos.xyz);

	vec3 worldDir 					= normalize(worldPos.xyz);


	//gbuffer.normal = normalize(gbuffer.normal - viewDir.xyz * (1.0 / (saturate(dot(gbuffer.normal, -viewDir.xyz)) + 0.01) ) * 0.0025);


	vec3 color = GammaToLinear(texture2D(gaux3, texcoord.st).rgb);

	if (materialMask.water > 0.5 || materialMask.ice > 0.5 || materialMask.stainedGlass > 0.5 || materialMask.stainedGlassP > 0.5 || materialMask.slimeBlock > 0.5)
	{
		gbuffer.normal = GetWaterNormals(texcoord.st);
	}

	float depth0 = ExpToLinearDepth(gbuffer.depth);
	float depth1 = ExpToLinearDepth(texture2D(depthtex1, texcoord.st).x);

	float totalInternalReflectionMask = 0.0;
	WaterRefraction(color, materialMask, viewPos, viewPos1, depth0, depth1, gbuffer.normal, gbuffer.mcLightmap.g, totalInternalReflectionMask);

	TransparentAbsorption(color, materialMask, worldPos, depth0, depth1);

	//if (isEyeInWater == 0)
	{
		CalculateSpecularReflections(color, gbuffer.normal, materialMask, gbuffer.albedo, gbuffer.smoothness, gbuffer.metallic, gbuffer.mcLightmap.g, viewDir, totalInternalReflectionMask);
	}

#ifdef VOLUMETRIC_RAYS
	if (materialMask.water > 0.5 || materialMask.ice > 0.5 || materialMask.stainedGlass > 0.5 || materialMask.stainedGlassP > 0.5 || materialMask.slimeBlock > 0.5 || gbuffer.smoothness >= 0.507144)
	{
		vec3 raysData = vec3(texture2D(gaux1, texcoord.st).ba, texture2D(gaux3, texcoord.st).a);
			 raysData = GammaToLinear(raysData);

		color += raysData;
	}
#endif

	color /= 0.0001;

	BlindnessFog(color, viewPos.xyz, viewDir);

	color *= 0.0001;

	//color += saturate(dot(viewDir, gbuffer.normal) + 1.0) * 0.0001;


	//color = texture2D(gaux2, texcoord.st).aaa * 0.0001;

	color = LinearToGamma(color);



	gl_FragData[0] = vec4(color.rgb, 1.0);
}
