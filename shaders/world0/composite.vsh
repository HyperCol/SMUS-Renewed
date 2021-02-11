#version 120

varying vec4 texcoord;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform vec3 skyColor;
uniform float sunAngle;
uniform float shadowAngle;

uniform int worldTime;

varying vec3 lightVector;
varying vec3 upVector;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

varying vec4 skySHR;
varying vec4 skySHG;
varying vec4 skySHB;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec3 worldSunVector;

uniform mat4 shadowModelViewInverse;
uniform float eyeAltitude;

uniform float wetness;

uniform float frameTimeCounter;

uniform sampler2D noisetex;

uniform float nightVision;

#include "Common.inc"

void main()
{
	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	//Calculate ambient light from atmospheric scattering
	vec3 worldLightVector = normalize((shadowModelViewInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	worldSunVector = worldLightVector * -sign(sunAngle * 2.0 - 1.0);

	upVector = normalize((gbufferModelView * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	lightVector = normalize((gbufferModelView * vec4(worldSunVector.xyz, 0.0)).xyz);


	colorSunlight = GetColorSunlight(worldSunVector, rainStrength);
	GetSkylightData(worldSunVector,
		skySHR, skySHG, skySHB,
		colorSkylight/*, colorSkyUp*/);

}
