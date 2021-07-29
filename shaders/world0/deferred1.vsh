#version 120

#define POINTLIGHT_COLOR_TEMPERATURE 4000 // Color temperature of point light in Kelvin. [1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 2100 2200 2300 2400 2500 2600 2700 2800 2900 3000 3100 3200 3300 3400 3500 3600 3700 3800 3900 4000 4100 4200 4300 4400 4500 4600 4700 4800 4900 5000 5100 5200 5300 5400 5500 5600 5700 5800 5900 6000 6100 6200 6300 6400 6500 6600 6700 6800 6900 7000 7100 7200 7300 7400 7500 7600 7700 7800 7900 8000 8100 8200 8300 8400 8500 8600 8700 8800 8900 9000]


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
varying vec3 sunVector;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorSunglow;
varying vec3 colorBouncedSunlight;
varying vec3 colorScatteredSunlight;
varying vec3 colorTorchlight;
varying vec3 colorSkyTint;

uniform float eyeAltitude;

varying vec4 skySHR;
varying vec4 skySHG;
varying vec4 skySHB;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec3 worldLightVector;
varying vec3 worldSunVector;

uniform mat4 shadowModelViewInverse;

uniform float wetness;

uniform float frameTimeCounter;

uniform sampler2D noisetex;


varying float heldLightBlacklist;

uniform int heldItemId;    

uniform float nightVision;

#include "/Common.inc"

float CubicSmooth(in float x)
{
	return x * x * (3.0f - 2.0f * x);
}

void main() 
{
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;

	heldLightBlacklist = 1.0;

	if (
		heldItemId == 344
		|| heldItemId == 423
		|| heldItemId == 413
		|| heldItemId == 411
		)
	{
		heldLightBlacklist = 0.0;
	}



	//Calculate ambient light from atmospheric scattering
	worldLightVector = normalize((shadowModelViewInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	worldSunVector   = worldLightVector * -sign(sunAngle * 2.0 - 1.0);

	upVector = normalize((gbufferModelView * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	sunVector = normalize((gbufferModelView * vec4(worldSunVector.xyz, 0.0)).xyz) * -sign(sunAngle * 2.0 - 1.0);
	lightVector = sunVector;



	float timePow = 6.0f;

	float LdotUp = dot(upVector, sunVector);
	float LdotDown = dot(-upVector, sunVector);

	timeNoon = 1.0 - pow(1.0 - saturate(LdotUp), timePow);
	timeSunriseSunset = 1.0 - timeNoon;
	timeMidnight = CubicSmooth(CubicSmooth(saturate(LdotDown * 20.0f + 0.4)));
	timeMidnight = 1.0 - pow(1.0 - timeMidnight, 2.0);
	timeSunriseSunset *= 1.0 - timeMidnight;
	timeNoon *= 1.0 - timeMidnight;



	colorSunlight = GetColorSunlight(worldSunVector, rainStrength);
	GetSkylightData(worldSunVector,
		skySHR, skySHG, skySHB,
		colorSkylight/*, colorSkyUp*/);


	//Torchlight color
	colorTorchlight = KelvinToRGB(float(POINTLIGHT_COLOR_TEMPERATURE));
	
}
