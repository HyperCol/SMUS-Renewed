#version 120


varying vec4 texcoord;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform vec3 skyColor;
uniform float sunAngle;

uniform int worldTime;

varying vec3 lightVector;
varying vec3 upVector;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;


float CubicSmooth(in float x)
{
	return x * x * (3.0f - 2.0f * x);
}

float saturate(float x)
{
	return clamp(x, 0.0, 1.0);
}


void main() {
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;

	vec3 sunVector = normalize(sunPosition);

	if (sunAngle < 0.5f) {
		lightVector = sunVector;
	} else {
		lightVector = normalize(moonPosition);
	}

	upVector = normalize(upPosition);


	float timePow = 6.0f;

	float LdotUp = dot(upVector, sunVector);
	float LdotDown = dot(-upVector, sunVector);

	timeNoon = 1.0 - pow(1.0 - saturate(LdotUp), timePow);
	timeSunriseSunset = 1.0 - timeNoon;
	timeMidnight = CubicSmooth(CubicSmooth(saturate(LdotDown * 20.0f + 0.4)));
	timeMidnight = 1.0 - pow(1.0 - timeMidnight, 2.0);
	timeSunriseSunset *= 1.0 - timeMidnight;
	timeNoon *= 1.0 - timeMidnight;


	float horizonTime = CubicSmooth(saturate((1.0 - abs(LdotUp)) * 7.0f - 6.0f));
	
}
