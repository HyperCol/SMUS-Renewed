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



///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////


/* DRAWBUFFERS:0 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform float wetness;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform ivec2 atlasSize;

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

uniform float eyeAltitude;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldNormal;

varying vec2 blockLight;

varying float materialIDs;

varying float distance;

uniform float nightVision;

#include "/Common.inc"

void main()
{

	vec4 albedo = texture2D(texture, texcoord.st);
	albedo *= color;



	//vec2 lightmap;
	// lightmap.x = clamp((lmcoord.x * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	// lightmap.y = clamp((lmcoord.y * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);


	// CurveLightmapSky(lightmap.y);



	vec4 specTex = texture2D(specular, texcoord.st);

	float smoothness = pow(specTex.r, 1.2);
	float metallic = specTex.g;
	float emissive = specTex.b;



	vec4 normalTex = texture2D(normals, texcoord.st) * 2.0 - 1.0;

	vec3 viewNormal = normalize(normalTex.xyz) * tbnMatrix;
	vec2 normalEnc = EncodeNormal(viewNormal.xyz);


	gl_FragData[0] = albedo;
	//gl_FragData[1] = vec4(blockLight.xy, emissive, albedo.a);
	//gl_FragData[2] = vec4(normalEnc.xy, 0.0, 0.0);
	//gl_FragData[3] = vec4(smoothness, metallic, (materialIDs + 0.1) / 255.0, albedo.a);



}
