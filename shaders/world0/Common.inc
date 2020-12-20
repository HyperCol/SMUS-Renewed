#define AUTHOR pspupsp
#define DEV_TEAM Hypercol
#define VERSION 0.2.7

float saturate(float x)
{
	return clamp(x, 0.0, 1.0);
}

vec4 saturate(vec4 x)
{
	return clamp(x, vec4(0.0), vec4(1.0));
}

vec3 saturate(vec3 x)
{
	return clamp(x, vec3(0.0), vec3(1.0));
}

vec2 saturate(vec2 x)
{
	return clamp(x, vec2(0.0), vec2(1.0));
}

vec2 EncodeNormal(vec3 normal)
{
	float p = sqrt(normal.z * 8.0 + 8.0);
	return vec2(normal.xy / p + 0.5);
}

vec3 DecodeNormal(vec2 enc)
{
	vec2 fenc = enc * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	vec3 normal;
	normal.xy = fenc * g;
	normal.z = 1.0 - f / 2.0;
	return normal;
}

float LinearToGamma(float c)
{
	return pow(c, float(1.0 / 2.2));
}

float GammaToLinear(float c)
{
	return pow(c, float(2.2));
}

vec2 LinearToGamma(vec2 c)
{
	return pow(c, vec2(1.0 / 2.2));
}

vec2 GammaToLinear(vec2 c)
{
	return pow(c, vec2(2.2));
}

vec3 LinearToGamma(vec3 c)
{
	return pow(c, vec3(1.0 / 2.2));
}

vec3 GammaToLinear(vec3 c)
{
	return pow(c, vec3(2.2));
}

float curve(float x)
{
	return x * x * (3.0 - 2.0 * x);
}

float Luminance(in vec3 color)
{
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

vec3 rand(vec2 coord)
{
	float noiseX = saturate(fract(sin(dot(coord, vec2(12.9898, 78.223))) * 43758.5453));
	float noiseY = saturate(fract(sin(dot(coord, vec2(12.9898, 78.223)*2.0)) * 43758.5453));
	float noiseZ = saturate(fract(sin(dot(coord, vec2(12.9898, 78.223)*3.0)) * 43758.5453));

	return vec3(noiseX, noiseY, noiseZ);
}

vec3 KelvinToRGB(float k)
{
	const vec3 c = pow(vec3(0.1, 0.4, 0.98), vec3(0.9));

	float x = k - 6500.0;
	float xc = pow(abs(x), 1.1) * sign(x);

	return normalize(exp(xc * (c * 0.00045 - 0.00017)));
}

vec4 ToSH(float value, vec3 dir)
{
	const float PI = 3.14159265359;
	const float N1 = sqrt(4 * PI / 3);
	const float transferl1 = (sqrt(PI) / 3.0) * N1;
	const float transferl0 = PI;

	const float sqrt1OverPI = sqrt(1.0 / PI);
	const float sqrt3OverPI = sqrt(3.0 / PI);

	vec4 coeffs;

	coeffs.x = 0.5 * sqrt1OverPI * value * transferl0;
	coeffs.y = -0.5 * sqrt3OverPI * dir.y * value * transferl1;
	coeffs.z = 0.5 * sqrt3OverPI * dir.z * value * transferl1;
	coeffs.w = -0.5 * sqrt3OverPI * dir.x * value * transferl1; //TODO: Vectorize the math so it's faster

	return coeffs;
}


vec3 FromSH(vec4 cR, vec4 cG, vec4 cB, vec3 lightDir)
{
	const float PI = 3.14159265;

	const float N1 = sqrt(4 * PI / 3);
	const float transferl1 = (sqrt(PI) / 3.0) * N1;
	const float transferl0 = PI;

	const float sqrt1OverPI = sqrt(1.0 / PI);
	const float sqrt3OverPI = sqrt(3.0 / PI);

	vec4 sh;

	sh.x = 0.5 * sqrt1OverPI;
	sh.y = -0.5 * sqrt3OverPI * lightDir.y;
	sh.z = 0.5 * sqrt3OverPI * lightDir.z;
	sh.w = -0.5 * sqrt3OverPI * lightDir.x;

	vec3 result;
	result.r = sh.x * cR.x;
	result.r += sh.y * cR.y;
	result.r += sh.z * cR.z;
	result.r += sh.w * cR.w;

	result.g = sh.x * cG.x;
	result.g += sh.y * cG.y;
	result.g += sh.z * cG.z;
	result.g += sh.w * cG.w;

	result.b = sh.x * cB.x;
	result.b += sh.y * cB.y;
	result.b += sh.z * cB.z;
	result.b += sh.w * cB.w;

	return result.rgb;
}



#define HORIZON_THING
#define SUNLIGHT_BRIGHTNESS 1.0 // Adjusts the relative brightness of sunlight versus sky/ambient light. [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

const vec3 Rayleigh = vec3(0.1, 0.25, 1.0);
float NightBrightness = mix(0.00025, 0.002, nightVision);

const float AtmosphereMie = 0.05;
const float AtmosphereDensity = 0.25;
const float AtmosphereDensityFalloff = 0.625;
const float AtmosphereExtent = 100.0;

// polynomial smooth min (k = 0.1); https://www.iquilezles.org/www/articles/smin/smin.htm
float SmoothMin(float a, float b, float k)
{
    float h = saturate(0.5 + 0.5 * (b-a) / k);
    return mix( b, a, h ) - k*h*(1.0-h);
}

float SmoothMax(float a, float b, float k)
{
    return -SmoothMin(-a, -b, k);
}

// https://pubs.rsc.org/en/content/articlehtml/2019/nr/c9nr01707k
//
// Mie
// g : ( -0.75, -0.999 )
//      3 * ( 1 - g^2 )               1 + c^2
// F = ----------------- * -------------------------------
//      2 * ( 2 + g^2 )     ( 1 + g^2 - 2 * g * c )^(3/2)
float PhaseMie(float g, float LdotV, float LdotV2)
{
	float gg = g * g;

	float a = (1.0 - gg) * (1.0 + LdotV2);

	float b = 1.0 + gg - 2.0 * g * LdotV;
	b *= sqrt(b);
	b *= 2.0 + gg;

	return 1.5 * a / b;
}

float TotalAtmosphereDensity(float dirY, const bool considerLand)
{
	if (!considerLand || (considerLand && dirY > 0.0))
	{
		return 1.0 / (max(0.0, dirY) * 6.0 + 0.03);
	}
	else
	{
		return 1.0 / (max(0.0, -dirY) * 50.0 + 0.4);
	}
}

vec3 AtmosphereAbsorption(vec3 dir, float depth)
{
	float M = AtmosphereMie + wetness * 0.5;
	float rDFv = AtmosphereDensityFalloff * dir.y;

	vec3 absorption = exp((-M - Rayleigh) * AtmosphereDensity * (1.0 / rDFv - 1.0 / (exp(rDFv * depth) * rDFv)));

	if (dir.y < 0.0 && depth > 10.0)
	{
		return vec3(0.0);
	}

	return absorption;
}

vec3 SunlightColorFromSunVector(vec3 worldSunVector)
{
	vec3 color  = AtmosphereAbsorption(worldSunVector, AtmosphereExtent);
		 color *= saturate(worldSunVector.y * 40.0);
	return color * exp2(-Rayleigh * 0.2);
}

vec3 Atmosphere(vec3 worldViewVector, vec3 worldSunVector, float mieAmount, float depthFactor)
{
	float LdotV = dot(worldViewVector, worldSunVector);
	float LdotV2 = LdotV * LdotV;



	vec3 color = vec3(0.0);

	float x = depthFactor;
	float v = worldViewVector.y;
	float s = worldSunVector.y;

	// Fix sunset
	s = SmoothMax(0.01, s, 0.07);
	v = pow(abs(v), 1.0 + saturate(-LdotV * 0.5 + 0.5) * 0.0005 / (s + 0.0005)) * sign(v);
	float energyFade = exp(min(0.0, worldSunVector.y) * 100.0);



	vec3 R = Rayleigh;
	float M = AtmosphereMie;
	float rD = AtmosphereDensity;
	float rDF = AtmosphereDensityFalloff - (-LdotV * 0.5 + 0.5) * max(0.0, -worldSunVector.y + 0.01) * 4.0;

	M += wetness * 0.5;


	#ifdef HORIZON_THING
	float floorDist = min(x, 0.4 / (-worldViewVector.y + 0.0118));
	if (worldViewVector.y < 0.0)
	{
		x = floorDist;
	}
	M += 0.005 / (saturate(worldViewVector.y) + 0.05);
	#endif

	float t1 = s + (-1.0 + exp(-250.0 * rDF * s)) * v;
	vec3 MpR = M + R;
	float t3 = rDF * v;
	float t3rcp = 1.0 / t3;
	vec3 t4 = MpR * t1;
	vec3 t4rcp = vec3(1.0) / t4;
	vec3 t5 = MpR * rD;

	vec3 atmos = s * t4rcp * (exp(t5 * (-1.0 + t1 / s) * t3rcp) - exp(t5 * (-1.0 + t1 / (exp(t3 * x) * s)) * t3rcp));

	atmos *= energyFade;
	atmos *= pow(Rayleigh, vec3(0.005 / (saturate(worldSunVector.y) + 0.009))); 	// Blue tint at twilight

	float rainEnergyLoss = mix(1.0, 0.25, wetness * wetness);

	atmos *= rainEnergyLoss;

	color = max(vec3(0.0),
		  atmos * Rayleigh * PhaseMie(0.0, LdotV, LdotV2)
		+ atmos * M * 0.25 * PhaseMie(0.9 - wetness * 0.5, LdotV, LdotV2) * mieAmount
		+ atmos * M * 0.75 * PhaseMie(0.6 - wetness * 0.5, LdotV, LdotV2) * mieAmount
		);


	float t = x;

	{
		vec3 ms = 1.0 / MpR - 1.0 / (exp(((-1.0 + exp(t3 * x)) * MpR * rD) / (exp(t3 * x) * t3)) * MpR);
		ms *= rainEnergyLoss;
		color += max(vec3(0.0), ms * Rayleigh + ms * M) * exp(SmoothMin(0.0, worldSunVector.y, 0.03) * 200.0) * 0.05;
	}




	color *= 6.6 / SUNLIGHT_BRIGHTNESS;


	#ifdef HORIZON_THING
	if (worldViewVector.y < 0.0 && depthFactor > 5.0) {
		color += vec3(0.1, 0.275, 1.0) * exp(-MpR * floorDist * 0.1) * 0.5 * exp(-MpR * (0.2 / (saturate(worldSunVector.y) + 0.001)));
	}
	#endif

	return color;
}

vec3 Atmosphere(vec3 worldViewVector, vec3 worldSunVector, float mieAmount)
{
	return Atmosphere(worldViewVector, worldSunVector, mieAmount, AtmosphereExtent);
}

vec3 AtmosphericScattering(vec3 rayDir, vec3 lightVector, float mieAmount)
{
	return Atmosphere(rayDir, lightVector, mieAmount);
}

vec3 AtmosphericScatteringSingle(vec3 rayDir, vec3 lightVector, float mieAmount)
{
	return Atmosphere(rayDir, lightVector, mieAmount);
}

vec3 AtmosphericScattering(vec3 rayDir, vec3 lightVector, float mieAmount, float depth)
{
	float LdotV = dot(lightVector, rayDir);
	float LdotV2 = LdotV * LdotV;

	rayDir.y = rayDir.y * 0.5 + 0.5;
	rayDir = normalize(rayDir);

	vec3 atmosphere  = Rayleigh * 1.268 * exp(-TotalAtmosphereDensity(lightVector.y + 0.02, false) * 0.4);
		 atmosphere += PhaseMie(0.78, LdotV, LdotV2) * SunlightColorFromSunVector(lightVector) * mieAmount;

	atmosphere *= 1.0 - exp(-depth * 500.0);

	atmosphere *= saturate(lightVector.y * 10.0);

	return atmosphere;
}

// Main sky shading function
vec3 SkyShading(vec3 worldViewVector, vec3 worldSunVector)
{
	vec3 atmosphere  = Atmosphere(worldViewVector, worldSunVector, 1.0);
		 atmosphere += Atmosphere(worldViewVector, -worldSunVector, 1.0) * NightBrightness;

	return atmosphere;
}

// Lighting colors and data
vec3 GetColorSunlight(vec3 worldSunVector, float rainStrength)
{
	vec3 color  = SunlightColorFromSunVector(worldSunVector);
		 color += SunlightColorFromSunVector(-worldSunVector) * NightBrightness;

	return color;
}

void GetSkylightData(vec3 worldSunVector,
	out vec4 skySHR, out vec4 skySHG, out vec4 skySHB,
	out vec3 colorSkylight/*, out vec3 colorSkyUp*/)
{
	colorSkylight = vec3(0.0);

	const int latSamples = 5;
	const int lonSamples = 5;

	skySHR = vec4(0.0);
	skySHG = vec4(0.0);
	skySHB = vec4(0.0);

	for (int i = 0; i < latSamples; i++)
	{
		float latitude = (float(i) / float(latSamples)) * 3.14159265;
			  latitude = latitude;
		for (int j = 0; j < lonSamples; j++)
		{
			float longitude = (float(j) / float(lonSamples)) * 3.14159265 * 2.0;

			vec3 rayDir;
			rayDir.x = cos(latitude) * cos(longitude);
			rayDir.z = cos(latitude) * sin(longitude);
			rayDir.y = sin(latitude);

			vec3 skyCol = SkyShading(rayDir, worldSunVector);
			colorSkylight += skyCol;

			skySHR += ToSH(skyCol.r, rayDir);
			skySHG += ToSH(skyCol.g, rayDir);
			skySHB += ToSH(skyCol.b, rayDir);
		}
	}

	skySHR /= latSamples * lonSamples;
	skySHG /= latSamples * lonSamples;
	skySHB /= latSamples * lonSamples;

	colorSkylight /= latSamples * lonSamples;
	//colorSkyUp = SkyShading(vec3(0.0, 1.0, 0.0), worldSunVector);
}
