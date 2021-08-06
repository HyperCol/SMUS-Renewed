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

////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////


#define WAVE_HEIGHT 0.5
#define WAVE_PARALLAX_SAMPLES 2 // Higher is better, but costs more performance. [2 3 4 5]
#define WAVE_SURFACE_SAMPLES 4 // Higher is better. [3 4 5]

#define WATER_PARALLAX

#define WATER_PARALLAX_SAMPLES 8 // Water Parallax Occlusion Mapping samples, higher is better, but costs more performance. [8 16 32 48 64 128 256]

#define RAIN_SPLASH_EFFECT // Rain ripples/splashes on water and wet blocks.

//#define RAIN_SPLASH_BILATERAL // Bilateral filter for rain splash/ripples. When enabled, ripple texture is smoothed (no hard pixel edges) at the cost of performance.


///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////



uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D noisetex;
uniform sampler2D gaux1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;
uniform int worldTime;
uniform int frameCounter;

uniform float wetness;
uniform int isEyeInWater;
uniform float rainStrength;
uniform float sunAngle;
uniform float shadowAngle;

varying vec3 normal;
varying vec3 globalNormal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec3 worldNormal;

uniform float eyeAltitude;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;
varying float distance;

varying float iswater;
varying float isice;
varying float isGlass;
varying float isGlassP;
varying float isStainedGlass;
varying float isStainedGlassP;
varying float isSlimeBlock;

uniform float nightVision;

#include "/Common.inc"

#define ANIMATION_SPEED 1.0f


/* DRAWBUFFERS:02345 */

#include "/lib/Waves.glsl"

vec3 GetWaterParallaxCoord(in vec3 position, in vec3 viewVector)
{
	vec3 parallaxCoord = position.xyz;

	vec3 stepSize = vec3(0.6f * WAVE_HEIGHT, 0.6f * WAVE_HEIGHT, 0.6f);

	float waveHeight = GetWaves(position, WAVE_PARALLAX_SAMPLES, 0);

		vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

		vec3 step = viewVector * stepSize;
		float distAngleWeight = ((distance * 0.2f) * (2.1f - viewVector.z)) / 2.0f;
		distAngleWeight = 1.0f;
		step *= distAngleWeight;

		float sampleHeight = waveHeight;

		for (int i = 0; sampleHeight < pCoord.z && i < WATER_PARALLAX_SAMPLES; ++i)
		{
			pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 0.2f * distAngleWeight / (-viewVector.z + 0.05f)), 0.0f, 1.0f));
			pCoord.z += step.z;
			//pCoord += step;
			sampleHeight = GetWaves(position + vec3(pCoord.x, 0.0f, pCoord.y), WAVE_PARALLAX_SAMPLES, 0);
		}

	parallaxCoord = position.xyz + vec3(pCoord.x, 0.0f, pCoord.y);

	return parallaxCoord;
}

vec3 GetWavesNormal(vec3 position, in float scale, in mat3 tbnMatrix) {

	vec4 modelView = (gl_ModelViewMatrix * vertexPos);

	vec3 viewVector = normalize(tbnMatrix * modelView.xyz);

		 viewVector = normalize(viewVector);


	#ifdef WATER_PARALLAX
	position = GetWaterParallaxCoord(position, viewVector);
	#endif


	const float sampleDistance = 1.0f;

	position -= vec3(0.005f, 0.0f, 0.005f) * sampleDistance;

	float wavesCenter = GetWaves(position, WAVE_SURFACE_SAMPLES, 0);
	float wavesLeft = GetWaves(position + vec3(0.01f * sampleDistance, 0.0f, 0.0f), WAVE_SURFACE_SAMPLES, 0);
	float wavesUp   = GetWaves(position + vec3(0.0f, 0.0f, 0.01f * sampleDistance), WAVE_SURFACE_SAMPLES, 0);

	vec3 wavesNormal;
		 wavesNormal.r = wavesCenter - wavesLeft;
		 wavesNormal.g = wavesCenter - wavesUp;

		 wavesNormal.r *= 20.0f * WAVE_HEIGHT / sampleDistance;
		 wavesNormal.g *= 20.0f * WAVE_HEIGHT / sampleDistance;


	//wavesNormal.rg *= saturate(1.0 - length(position.xyz - cameraPosition.xyz) / 20.0);


		//  wavesNormal.b = sqrt(1.0f - wavesNormal.r * wavesNormal.r - wavesNormal.g * wavesNormal.g);
     wavesNormal.b = 1.0;
		 wavesNormal.rgb = normalize(wavesNormal.rgb);


		 //float upAmount = dot(fwidth(position.xyz), vec3(1.0));
		 //float upAmount = 1.0 - saturate(dot(-viewVector, wavesNormal));
		 //upAmount = upAmount / (upAmount + 1.0);

		 //wavesNormal = normalize(wavesNormal + vec3(0.0, -1.0, 0.0) * upAmount * 1.0);



	return wavesNormal.rgb;
}


float CurveBlockLightTorch(float blockLight)
{
	float falloff = 10.0;

	blockLight = exp(-(1.0 - blockLight) * falloff);
	blockLight = max(0.0, blockLight - exp(-falloff));

	return blockLight;
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

vec3 GetRainNormal(in vec3 pos, vec2 blockLight, float wet)
{
	if (rainStrength < 0.01)
	{
		return vec3(0.0, 0.0, 1.0);
	}

	pos.xyz *= 0.5;


	#ifdef RAIN_SPLASH_BILATERAL
		vec3 n = BilateralRainTex(gaux1, pos.xz, wet);
	#else
		vec3 n = GetRainAnimationTex(gaux1, pos.xz, wet);
	#endif
	n *= 0.4;

	pos.x -= frameTimeCounter * 1.5;
	float downfall = texture2D(noisetex, pos.xz * 0.0025).x;
		  downfall = saturate(downfall * 1.5 - 0.25);

	float lod = dot(abs(fwidth(pos.xyz)), vec3(1.0));
	n.xy /= (1.0 + lod * 5.0) * (wet + 0.1);

	wet = saturate(wet * 1.0 + downfall * (1.0 - wet) * 0.5);

	n.xy *= rainStrength;

	//vec3 rainFlowNormal = vec3(0.0, 0.0, 1.0);

	//n = mix(rainFlowNormal, n, saturate(worldNormal.y));
	n = mix(vec3(0.0, 0.0, 1.0), n, clamp(blockLight.y * 1.05 - 0.9, 0.0, 0.1) * 10.0);

	return n;
}

void main() {

	vec4 tex = texture2D(texture, texcoord.st);
		 tex.rgb *= tex.a;
		 //tex.a = 0.85f;
		 tex.a = saturate(tex.a) * 0.85;

	vec4 transparentAlbedo = tex;

	float zero = 1.0f;
	float transx = 0.0f;
	float transy = 0.0f;

	//float iswater = 0.0f;

	float texblock = 0.0625f;

	bool backfacing = false;

	if (viewVector.z > 0.0f) {
		//backfacing = true;
	} else {
		//backfacing = false;
	}


	if (iswater > 0.5 || isice > 0.5 || isGlass > 0.5 || isGlassP > 0.5 || isStainedGlass > 0.5 || isStainedGlassP > 0.5 || isSlimeBlock > 0.5)
	{
		tex = vec4(0.0, 0.0, 0.0f, 0.2);
	}

	if(isGlass > 0.5 || isGlassP > 0.5)
	{
		transparentAlbedo.rgb = vec3(transparentAlbedo.a * 0.4 + 0.6) ;
	}

	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.

	//Separate lightmap types
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	//lightmap.b = pow(lightmap.b, 1.0f);
	//lightmap.r = pow(lightmap.r, 3.0f);







	float matID = 1.0f;

	if (iswater > 0.5f)
	{
			matID = 6.0;
	}

	if (isice > 0.5)
	{
		matID = 8.0;
	}

	if (isStainedGlass > 0.5 || isGlass > 0.5)
	{
		matID = 7.0;
	}


	if (isStainedGlassP > 0.5 || isGlassP > 0.5)
	{
		matID = 50.0;
	}

	if (isSlimeBlock > 0.5)
	{
		matID = 51.0;
	}

	matID += 0.1f;

  // gl_FragData[0] = vec4(tex.rgb, 0.2);

	mat3 tbnMatrix = mat3 (tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
					     	tangent.z, binormal.z, normal.z);




	vec3 wavesNormal = GetWavesNormal(worldPosition.xyz, 1.0f, tbnMatrix);
	#ifdef RAIN_SPLASH_EFFECT
		vec3 rainNormal = GetRainNormal(worldPosition.xyz, lightmap.rb, 1.0) * clamp(worldNormal.y, -1.0, 1.0) * vec3(1.0, 1.0, 0.0);
		wavesNormal = normalize(wavesNormal + rainNormal);
	#endif

	vec3 waterNormal = wavesNormal * tbnMatrix;
	vec3 texNormal = texture2D(normals, texcoord.st).rgb * 2.0f - 1.0f;
		 texNormal = texNormal * tbnMatrix;
	#ifdef RAIN_SPLASH_EFFECT
		texNormal = normalize(texNormal + rainNormal);
	#endif


	waterNormal = mix(texNormal, waterNormal, iswater);

	lightmap.r = CurveBlockLightTorch(lightmap.r);
	lightmap.r = pow(lightmap.r, 0.25);

	gl_FragData[0] = tex;
	//gl_FragData[1] = vec4(lightmap.rb, 0.0, 1.0);
	gl_FragData[1] = vec4(EncodeNormal(texNormal), 0.0, tex.a);







	//lightmap.r = 0.0;

	vec2 data3 = vec2(0.0, 0.0);
	if (isice > 0.5 || iswater > 0.5 || isGlass > 0.5 || isGlassP > 0.5 || isStainedGlass > 0.5 || isStainedGlassP > 0.5 || isSlimeBlock > 0.5)
		data3 = vec2(lightmap.r, lightmap.b);

	gl_FragData[2] = vec4(data3, (matID) / 255.0, tex.a * 5.0);

	gl_FragData[3] = vec4(EncodeNormal(waterNormal.xyz).xy, 0.0, 1.0f);
	gl_FragData[4] = vec4(transparentAlbedo);



	//gl_FragData[7] = vec4(globalNormal * 0.5f + 0.5f, 1.0);
}
