#version 130

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



////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////

//#define TEXTURE_RESOLUTION 128 // Resolution of current resource pack. This needs to be set properly for POM! [16 32 64 128 256 512]

#define PARALLAX // 3D effect for resource packs with heightmaps. Make sure Texture Resolution is set properly!

#define PARALLAX_SHADOW // Self-shadowing for parallax occlusion mapping.

#define FORCE_WET_EFFECT // Make all surfaces get wet during rain regardless of specular texture values

#define RAIN_SPLASH_EFFECT // Rain ripples/splashes on water and wet blocks.

//#define RAIN_SPLASH_BILATERAL // Bilateral filter for rain splash/ripples. When enabled, ripple texture is smoothed (no hard pixel edges) at the cost of performance.

#define PARALLAX_DEPTH 1.0 // Depth of parallax effect. [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0]

#define PARALLAX_SAMPLES 8 // Parallax Occlusion Mapping samples, higher is better, but costs more performance. [8 16 32 48 64 128 256]

//#define AUTO_NORMAL_SPEC // Enables automatic generation of normal and specular data from base color textures. Only works well for lower resolution resource packs. Make sure to set Surface Options > Texture Resolution properly according to your resource pack!

#define AUTO_NORMAL_STRENGTH 1.0 // Strength of automatically generated normal maps. [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 4.0]

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////



/* DRAWBUFFERS:0123 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform float wetness;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform ivec2 atlasSize;

uniform vec3 cameraPosition;
uniform int frameCounter;
uniform int isEyeInWater;

uniform mat4 gbufferProjection;

uniform float near;
uniform float far;
uniform float aspectRatio;
uniform float sunAngle;
uniform float shadowAngle;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;
varying mat3 tbnMatrix;
varying vec3 viewPos;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldNormal;

uniform float eyeAltitude;

varying vec2 blockLight;

varying vec4 autoMaterialProperties;

varying float materialIDs;

varying float distance;

uniform float rainStrength;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform float nightVision;

#include "Common.inc"

float CurveBlockLightTorch(float blockLight)
{
	float falloff = 10.0;

	blockLight = exp(-(1.0 - blockLight) * falloff);
	blockLight = max(0.0, blockLight - exp(-falloff));

	return blockLight;
}

vec4 GetTexture(in sampler2D tex, in vec2 coord)
{
	#ifdef PARALLAX
		vec4 t = vec4(0.0f);
		if (distance < 60.0f)
		{
			t = texture2DLod(tex, coord, 0);
		}
		else
		{
			t = texture2D(tex, coord);
		}
		return t;
	#else
		return texture2D(tex, coord);
	#endif
}

vec2 OffsetCoord(in vec2 coord, in vec2 offset, in int level, in ivec2 atlasResolution, in int tileResolution)
{
	//int tileResolution = TEXTURE_RESOLUTION;
	//ivec2 atlasResolution = textureSize(texture, 0);
	//ivec2 atlasTiles = atlasResolution / tileResolution;

	coord *= atlasResolution;

	vec2 offsetCoord = coord + mod(offset.xy * atlasResolution, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x) {
		offsetCoord.x -= tileResolution;
	} else if (offsetCoord.x < minCoord.x) {
		offsetCoord.x += tileResolution;
	}

	if (offsetCoord.y > maxCoord.y) {
		offsetCoord.y -= tileResolution;
	} else if (offsetCoord.y < minCoord.y) {
		offsetCoord.y += tileResolution;
	}

	offsetCoord /= atlasResolution;

	return offsetCoord;
}

vec2 CalculateParallaxCoord(in vec2 coord, in vec3 viewVector, out vec3 rayOffset, in vec2 texGradX, in vec2 texGradY, in ivec2 atlasResolution, in int tileResolution)
{
	vec2 parallaxCoord = coord.st;
	const int maxSteps = 112;
	vec3 stepSize = vec3(0.001f, 0.001f, 0.15f);

	float parallaxDepth = PARALLAX_DEPTH;




	const float gradThreshold = 0.004;
	float absoluteTexGrad = dot(abs(texGradX) + abs(texGradY), vec2(1.0));

	parallaxDepth *= saturate((1.0 - saturate(absoluteTexGrad / gradThreshold)) * 1.0);
	if (absoluteTexGrad > gradThreshold)
	{
		// parallaxDepth *= 0.1;
		//pCoord = vec3(0.2, 0.0, 1.0);
		return texcoord.st;
	}

	float parallaxStepSize = 0.5;

	stepSize.xy *= parallaxDepth;
	stepSize *= parallaxStepSize;

	float heightmap = textureGrad(normals, coord.st, texGradX, texGradY).a;

	vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);



	int numRefinements = 0;
	const int maxRefinements = 4;

	if (heightmap < 1.0f)
	{
		vec3 step = viewVector * stepSize * (128.0 / PARALLAX_SAMPLES);
		//step *= rand(texcoord.st + frameTimeCounter);

		float distAngleWeight = ((distance * 0.6) * (2.1 - viewVector.z)) / 16.0;
		step *= distAngleWeight;

		float sampleHeight = heightmap;

		for (int i = 0; i < PARALLAX_SAMPLES; i++)
		{
			vec3 prevPCoord = pCoord;
			pCoord += step;

	 		sampleHeight = textureGrad(normals, OffsetCoord(coord.st, pCoord.st, 0, atlasResolution, tileResolution), texGradX, texGradY).a;

	 		if (sampleHeight > pCoord.z)
	 		{
	 			if (numRefinements < maxRefinements)
	 			{
	 				//pCoord -= step;

	 				pCoord = prevPCoord;

	 				step *= 0.5;
	 				numRefinements++;
	 			}
	 			else
	 			{
	 				break;
	 			}
	 		}
		}

		parallaxCoord.xy = OffsetCoord(coord.st, pCoord.st, 0, atlasResolution, tileResolution);
	}






	rayOffset = pCoord;


	return parallaxCoord;
}

float GetParallaxShadow(in vec2 texcoord, in vec3 lightVector, float baseHeight, in vec2 texGradX, in vec2 texGradY, in ivec2 atlasResolution, in int tileResolution)
{
	float sunVis = 1.0;



	//lightVector = normalize(tbnMatrix * lightVector);


	// lightVector.z *= TEXTURE_RESOLUTION * 0.5;
	lightVector.z *= 64.0;
	lightVector.z /= PARALLAX_DEPTH * 0.5;




	float shadowStrength = 1.0;

	const float gradThreshold = 0.003;
	float absoluteTexGrad = dot(abs(texGradX) + abs(texGradY), vec2(1.0));

	shadowStrength *= saturate((1.0 - saturate(absoluteTexGrad / gradThreshold)) * 1.0);
	if (absoluteTexGrad > gradThreshold)
	{
		// parallaxDepth *= 0.1;
		//pCoord = vec3(0.2, 0.0, 1.0);
		return 1.0;
	}




	// lightVector = normalize(vec3(1.0, 1.0, 0.5));

	vec3 currCoord = vec3(texcoord, baseHeight);

	float stepSize = 0.0005;

	ivec2 texSize = textureSize(texture, 0);
	currCoord.xy = (floor(currCoord.xy * texSize) + 0.5) / texSize;


	float allTexGrad = dot(abs(texGradX), vec2(1.0)) + dot(abs(texGradY), vec2(1.0));


	// stepSize *= allTexGrad * 500.0 + 1.0;

	for (int i = 0; i < 12; i++)
	{
		currCoord = vec3(OffsetCoord(currCoord.xy, lightVector.xy * stepSize, 0, atlasResolution, tileResolution), currCoord.z + lightVector.z * stepSize);
		//float heightSample = GetTexture(normals, currCoord.xy).a;
		float heightSample = textureGrad(normals, currCoord.xy, texGradX, texGradY).a;



		// if (sin(frameTimeCounter) > 0.0)
		// {
		// 	if (heightSample > currCoord.z + 0.015)
		// 	{
		// 		sunVis *= 0.05;
		// 	}
		// }
		// else
		// {
			//float shadowBias = 0.0015 + allTexGrad * 7.0 * (sin(frameTimeCounter) > 0.0 ? 1.0 : 0.0);
			float shadowBias = 0.0015;
			sunVis *= mix(1.0, saturate((currCoord.z - heightSample + shadowBias) / 0.01), shadowStrength);
			// sunVis *= saturate((currCoord.z - heightSample + shadowBias + 0.04) / 0.08);
		// }

	}

	// sunVis = mix(1.0, sunVis, shadowStrength);

	return sunVis;
}

vec3 Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
		 f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f, 37.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f, 37.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / 64.0f;
	vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	vec3 xy1 = texture2D(noisetex, coord).xyz;
	vec3 xy2 = texture2D(noisetex, coord2).xyz;
	return mix(xy1, xy2, vec3(f.z));
}

vec3 Get3DNoiseNormal(in vec3 pos)
{
	float center = Get3DNoise(pos + vec3( 0.0f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float left 	 = Get3DNoise(pos + vec3( 0.1f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float up     = Get3DNoise(pos + vec3( 0.0f, 0.1f, 0.0f)).x * 2.0f - 1.0f;

	vec3 noiseNormal;
		 noiseNormal.x = center - left;
		 noiseNormal.y = center - up;

		 noiseNormal.x *= 0.2f;
		 noiseNormal.y *= 0.2f;

		 noiseNormal.b = sqrt(1.0f - noiseNormal.x * noiseNormal.x - noiseNormal.g * noiseNormal.g);
		 noiseNormal.b = 0.0f;

	return noiseNormal.xyz;
}

float GetModulatedRainSpecular(in vec3 pos)
{
	if (rainStrength < 0.01)
	{
		return 0.0;
	}

	pos.xyz += frameTimeCounter * vec3(0.125f, 3.0f, 0.0625f);
	pos.xz *= 1.0f;
	pos.y *= 0.2f;

	// pos.y += Get3DNoise(pos.xyz * vec3(1.0f, 0.0f, 1.0f)).x * 2.0f;

	vec3 p = pos;

	float n = Get3DNoise(p).y;
		  n += Get3DNoise(p / 2.0f).x * 2.0f;
		  n += Get3DNoise(p / 4.0f).x * 4.0f;

		  n /= 7.0f;


	n = saturate(n * 0.8 + 0.5) * 0.97;


	return n;
}


vec3 GetRainAnimationTex(sampler2D tex, vec2 uv, float wet)
{
	float frame = mod(floor(frameTimeCounter * 60.0), 60.0);
	vec2 coord = vec2(uv.x, mod(uv.y / 60.0, 1.0) - frame / 60.0);

	vec3 n = texture2D(tex, coord).rgb * 2.0 - 1.0;
	n.y *= -1.0;

	n.xy = pow(abs(n.xy) * 1.0, vec2(2.0 - wet * wet * wet * 1.2)) * sign(n.xy);

	return n;
}

vec3 BilateralRainTex(sampler2D tex, vec2 uv, float wet)
{
	vec3 n   = GetRainAnimationTex(tex, uv.xy                         , wet);
	vec3 nR  = GetRainAnimationTex(tex, uv.xy + vec2(1.0, 0.0) / 128.0, wet);
	vec3 nU  = GetRainAnimationTex(tex, uv.xy + vec2(0.0, 1.0) / 128.0, wet);
	vec3 nUR = GetRainAnimationTex(tex, uv.xy + vec2(1.0, 1.0) / 128.0, wet);

	vec2 fractCoord = fract(uv.xy * 128.0);

	vec3 lerpX  = mix(n , nR , fractCoord.x);
	vec3 lerpX2 = mix(nU, nUR, fractCoord.x);
	vec3 lerpY  = mix(lerpX, lerpX2, fractCoord.y);

	return lerpY;
}

vec3 GetRainSplashNormal(vec3 worldPos, vec3 worldNorm, inout float wet)
{
	if (wetness < 0.01)
	{
		return vec3(0.0, 0.0, 1.0);
	}

	vec3 pos = worldPos * 0.5;
	vec3 flowPos = pos;


	#ifdef RAIN_SPLASH_BILATERAL
	vec3 n = BilateralRainTex(gaux1, pos.xz, wet);
	#else
	vec3 n = GetRainAnimationTex(gaux1, pos.xz, wet);
	#endif

	pos.x -= frameTimeCounter * 1.5;
	float downfall = texture2D(noisetex, pos.xz * 0.0025).x;
	downfall = saturate(downfall * 1.5 - 0.25);

	wet = saturate(wet * 1.0 + downfall * (1.0 - wet) * 0.95);

	float lod = dot(abs(fwidth(pos.xyz)), vec3(1.0));
	n.xy *= rainStrength / (1.0 + lod * 5.0);

	return n;
}

float NormalWeight(vec4 color)
{
	float weight = Luminance(color.rgb);
	weight += color.a * 0.0;

	return weight;
}

void AutoNormalSpec(vec2 textureCoordinate, vec2 texGradX, vec2 texGradY, out vec3 normalTex, out vec3 specTex)
{
	float normalStrength = autoMaterialProperties.z;
	float smoothnessStrength = autoMaterialProperties.x;
	float smoothnessVariance = autoMaterialProperties.y;
	float metalness = autoMaterialProperties.w;

	ivec2 atlasResolution = atlasSize;
	int tileResolution = atlasResolution.y / 32;
	ivec2 atlasTiles = atlasResolution / tileResolution;


	normalStrength *= AUTO_NORMAL_STRENGTH;


	/*
	vec2 coordC = OffsetCoord(textureCoordinate, vec2(0.0, 0.0) / atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coordU = OffsetCoord(textureCoordinate, vec2(0.0, -1.0) / atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coordR = OffsetCoord(textureCoordinate, vec2(1.0, 0.0) / atlasResolution, 0, atlasResolution, tileResolution);

	float lumC = Luminance(texture2D(texture, coordC).rgb);
	float lumU = Luminance(texture2D(texture, coordU).rgb);
	float lumR = Luminance(texture2D(texture, coordR).rgb);


	vec3 n = vec3(0.0);
	n.x = lumC - lumR;
	n.y = -lumC + lumU;
	n.z = 0.3 / (normalStrength + 0.00001);

	n = normalize(n);

	normalTex = n * 0.5 + 0.5;
	*/

	float s = 1.0;

	vec2 coordC = textureCoordinate;
	vec2 coord1 = OffsetCoord(textureCoordinate, (vec2(1.0, 1.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord2 = OffsetCoord(textureCoordinate, (vec2(1.0, -1.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord3 = OffsetCoord(textureCoordinate, (vec2(-1.0, 1.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord4 = OffsetCoord(textureCoordinate, (vec2(-1.0, -1.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord5 = OffsetCoord(textureCoordinate, (vec2(1.0, 0.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord6 = OffsetCoord(textureCoordinate, (vec2(-1.0, 0.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord7 = OffsetCoord(textureCoordinate, (vec2(0.0, 1.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);
	vec2 coord8 = OffsetCoord(textureCoordinate, (vec2(0.0, -1.0) 	* s)	/ atlasResolution, 0, atlasResolution, tileResolution);

	float lumC = NormalWeight(textureGrad(texture, coordC, texGradX, texGradY));
	float lum1 = NormalWeight(textureGrad(texture, coord1, texGradX, texGradY));
	float lum2 = NormalWeight(textureGrad(texture, coord2, texGradX, texGradY));
	float lum3 = NormalWeight(textureGrad(texture, coord3, texGradX, texGradY));
	float lum4 = NormalWeight(textureGrad(texture, coord4, texGradX, texGradY));
	float lum5 = NormalWeight(textureGrad(texture, coord5, texGradX, texGradY));
	float lum6 = NormalWeight(textureGrad(texture, coord6, texGradX, texGradY));
	float lum7 = NormalWeight(textureGrad(texture, coord7, texGradX, texGradY));
	float lum8 = NormalWeight(textureGrad(texture, coord8, texGradX, texGradY));

	vec2 nSpace = vec2(1.0, 1.0);
	vec3 n = vec3(0.0);
	n.xy += (lumC - lum1) * vec2(1.0, 1.0)		* nSpace;
	n.xy += (lumC - lum2) * vec2(1.0, -1.0)		* nSpace;
	n.xy += (lumC - lum3) * vec2(-1.0, 1.0)		* nSpace;
	n.xy += (lumC - lum4) * vec2(-1.0, -1.0)	* nSpace;
	n.xy += (lumC - lum5) * vec2(1.0, 0.0)		* nSpace;
	n.xy += (lumC - lum6) * vec2(-1.0, 0.0)		* nSpace;
	n.xy += (lumC - lum7) * vec2(0.0, 1.0)		* nSpace;
	n.xy += (lumC - lum8) * vec2(0.0, -1.0)		* nSpace;


	//Fine
	//Flip fine x direction to better match sun angle
	if (sunAngle > 0.25 && sunAngle < 0.5
		|| sunAngle > 0.75 && sunAngle < 1.0)
	{
		n.xy += (lumC - lum6) * vec2(-1.0, 0.0) * nSpace * 2.0;
	}
	else
	{
		n.xy += (lumC - lum5) * vec2(1.0, 0.0) * nSpace * 2.0;
	}
	n.xy += (lumC - lum8) * vec2(0.0, -1.0) * nSpace * 2.0;



	n.z = 1.5 / (normalStrength + 0.00001);

	n = normalize(n);

	normalTex = n * 0.5 + 0.5;





	float lumBlur = NormalWeight(texture2DLod(texture, coordC, 2));
	float highpassLum = (lumC - lumBlur) * 1.0;


	float smoothness = saturate((highpassLum * 4.0) * 0.5 + 0.5) * 0.9 + 0.05;


	smoothness = pow(smoothness, smoothnessVariance);
	smoothness *= smoothnessStrength;




	// smoothness = 0.8;


	specTex = vec3(smoothness, metalness, 0.0);

}

void main()
{

	vec2 texGradX = dFdx(texcoord.st);
	vec2 texGradY = dFdy(texcoord.st);



	vec2 textureCoordinate = texcoord.st;


	#ifdef PARALLAX

		vec3 viewVector = normalize(tbnMatrix * viewPos.xyz);
			 //viewVector.x /= 2.0f;
		//int tileResolution = TEXTURE_RESOLUTION;
	 	//ivec2 atlasResolution = textureSize(texture, 0);
	 	//ivec2 atlasTiles = atlasResolution / tileResolution;
		ivec2 atlasResolution = atlasSize;
		int tileResolution = atlasResolution.y / 32;
		ivec2 atlasTiles = atlasResolution / tileResolution;
		float atlasAspectRatio = atlasTiles.x / atlasTiles.y;
			viewVector.y *= atlasAspectRatio;


			 viewVector = normalize(viewVector);
		vec3 rayOffset;
		 textureCoordinate = CalculateParallaxCoord(texcoord.st, viewVector, rayOffset, texGradX, texGradY, atlasResolution, tileResolution);
	#endif


	//vec4 albedo = texture2D(texture, textureCoordinate.st);
	vec4 albedo = textureGrad(texture, textureCoordinate.st, texGradX, texGradY);
	albedo *= color;


	//vec2 lightmap;
	// lightmap.x = clamp((lmcoord.x * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	// lightmap.y = clamp((lmcoord.y * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);


	// CurveLightmapSky(lightmap.y);

	vec4 specTex = vec4(0.0, 0.0, 0.0, 0.0);
	vec4 normalTex = vec4(0.0, 1.0, 0.0, 1.0);
	vec3 viewNormal = normal;

		//specTex = texture2D(specular, textureCoordinate.st);
		specTex = textureGrad(specular, textureCoordinate.st, texGradX, texGradY);
		//normalTex = texture2D(normals, textureCoordinate.st);
		normalTex = textureGrad(normals, textureCoordinate.st, texGradX, texGradY);

	#ifdef AUTO_NORMAL_SPEC
		AutoNormalSpec(textureCoordinate.st, texGradX, texGradY, normalTex.xyz, specTex.xyz);
	#endif


	float smoothness = pow(specTex.r, 1.0);
	float metallic = specTex.g;
	float emissive = 0.0;



	float wetnessModulator = GetModulatedRainSpecular(worldPosition.xyz + cameraPosition.xyz);
	#ifdef RAIN_SPLASH_EFFECT
		//vec3 rainNormal = GetRainNormal(worldPosition.xyz + cameraPosition.xyz, wetnessModulator);
		vec3 rainNormal = GetRainSplashNormal(worldPosition.xyz + cameraPosition.xyz, worldNormal, wetnessModulator);
	#else
		vec3 rainNormal = vec3(0.0, 0.0, 1.0);
	#endif
	/*
	wetnessModulator *= saturate(worldNormal.y * 0.5 + 0.5);
	wetnessModulator *= clamp(blockLight.y * 1.05 - 0.9, 0.0, 0.1) / 0.1;
	wetnessModulator *= wetness;
	*/

	wetnessModulator *= saturate(worldNormal.y * 10.5 + 0.7);
	wetnessModulator *= saturate(abs(2.0 - materialIDs));
	wetnessModulator *= clamp(blockLight.y * 1.05 - 0.7, 0.0, 0.3) / 0.3;
	wetnessModulator *= saturate(wetness * 1.1 - 0.1);

	#ifdef FORCE_WET_EFFECT
		//metallic *= 1.0 - rainStrength * wetnessModulator;
	#else
		wetnessModulator *= specTex.b;
	#endif

	// Darker albedo when wet
/*
	float darkFactor = clamp(wetnessModulator, 0.0f, 0.2f) / 0.2f;
	albedo.rgb = pow(albedo.rgb, vec3(mix(1.0f, 1.15f, darkFactor)));
*/
	albedo.rgb = pow(albedo.rgb, vec3(1.0 + wetnessModulator * (1.0 - metallic) * 0.3));


	#ifdef FORCE_WET_EFFECT
	if (isEyeInWater < 1)
	{
		smoothness = mix(smoothness, 1.0, saturate(wetnessModulator * 1.0 * saturate(1.0 - metallic)));
	}
	#endif



	vec3 normalMap = normalize(normalTex.xyz * 2.0 - 1.0);
	normalMap = mix(normalMap, vec3(0.0, 0.0, 1.0), vec3(wetnessModulator * wetnessModulator));

	#ifdef RAIN_SPLASH_EFFECT
		normalMap = normalize(normalMap + rainNormal * wetnessModulator * saturate(worldNormal.y) * vec3(1.0, 1.0, 0.0));
	#endif

	viewNormal = normalize(normalMap) * tbnMatrix;


	vec2 normalEnc = EncodeNormal(viewNormal.xyz);







	float parallaxShadow = 1.0;

	#ifdef PARALLAX
		#ifdef PARALLAX_SHADOW

			float baseHeight = GetTexture(normals, textureCoordinate.st).a;

			if (dot(normalize(sunPosition), viewNormal) > 0.0 && baseHeight < 1.0)
			{
				vec3 lightVector = normalize(sunPosition.xyz);
				lightVector = normalize(tbnMatrix * lightVector);
				lightVector.y *= atlasAspectRatio;
				lightVector = normalize(lightVector);
				parallaxShadow = GetParallaxShadow(textureCoordinate.st, lightVector, baseHeight, texGradX, texGradY, atlasResolution, tileResolution);
			}
		#endif
	#endif





	//Calculate torchlight average direction
	vec3 Q1 = dFdx(viewPos.xyz);
	vec3 Q2 = dFdy(viewPos.xyz);
	float st1 = dFdx(blockLight.x);
	float st2 = dFdy(blockLight.x);

	st1 /= dot(fwidth(viewPos.xyz), vec3(0.333333));
	st2 /= dot(fwidth(viewPos.xyz), vec3(0.333333));
	vec3 T = (Q1*st2 - Q2*st1);
	T = normalize(T + normal.xyz * 0.0002);
	T = -cross(T, normal.xyz);

	T = normalize(T + normal * 0.01);
	T = normalize(T + normal * 0.85 * (blockLight.x));


	float torchLambert = pow(saturate(dot(T, viewNormal.xyz) * 1.0 + 0.0), 1.0);
	torchLambert += pow(saturate(dot(T, viewNormal.xyz) * 0.4 + 0.6), 1.0) * 0.5;

	if (dot(T, normal.xyz) > 0.99)
	{
		torchLambert = pow(torchLambert, 2.0) * 0.45;
	}

	// albedo.rgb = texture2DLod(gaux1, worldPosition.xz, 0).rgb;


	vec2 mcLightmap = blockLight;
	mcLightmap.x = CurveBlockLightTorch(mcLightmap.x);
	mcLightmap.x = mcLightmap.x * torchLambert * 1.0;
	mcLightmap.x = pow(mcLightmap.x, 0.25);
	mcLightmap.x += rand(vertexPos.xy + sin(frameTimeCounter)).x * (1.5 / 255.0);


	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(mcLightmap.xy, emissive, parallaxShadow);
	gl_FragData[2] = vec4(normalEnc.xy, blockLight.x, albedo.a);
	gl_FragData[3] = vec4(smoothness, metallic, (materialIDs + 0.1) / 255.0, albedo.a);



}
