/***************************************************************************************
	"Seascape" by Alexander Alekseev aka TDM - 2014
	License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
	Contact: tdmaav@gmail.com
	Website: https://www.shadertoy.com/view/4lKSzh
***************************************************************************************/

const float WAVES_CHOPPY = 2.5;
const float WAVES_SPEED = 0.865;
const float WAVES_FREQ = 0.21;

float noise(vec2 p)
{
	vec2 noiseCoord = p / 64.0;
		 noiseCoord = (floor(noiseCoord * 64.0) + 0.5) / 64.0;

	return texture2D(noisetex, noiseCoord.st).x;
}

float GetWavesNoise(in vec2 coord)
{
	vec2 i = floor(coord);
	vec2 f = coord - i;
	vec2 u = f * f * (3.0 - f * 2.0);
	return mix(mix(noise(i + vec2(0.0, 0.0)), noise(i + vec2(1.0, 0.0)), u.x),
			   mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), u.x),
			   u.y) * 2.0 - 1.0;
}

float WavesOctave(in vec2 coord, in float wavesChoppy)
{
    coord += GetWavesNoise(coord);
    vec2 wv = 0.5 + sin(coord * 2.0) * 0.5;
    vec2 swv = 0.5 + cos(coord * 2.0) * 0.5;
    wv = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), wavesChoppy);
}

float GetWaves(in vec3 pos, in int samp, in int isCaustics)
{
	float freq = WAVES_FREQ;
	float wavesHeight = 0.9 + wetness * 0.1;
	float wavesChoppy = WAVES_CHOPPY;
	vec2 coord = pos.xz - pos.y;

	float wavesTime = frameTimeCounter * WAVES_SPEED;
	const mat2 coordOffs = mat2(1.5, 1.1, -1.6, 1.5);
	const float wavesIteration[5] = float[5](0.320775, 0.250275, 0.201724, 0.175075, 0.170375);
	const float heightAmount[5] = float[5](1.000000, 0.627441, 0.548630, 0.519964, 0.506092);

	float d, h = 0.0f;
	for(int i = 0; i < samp; i++){
		d = WavesOctave((coord + wavesTime) * freq, wavesChoppy);
		d += WavesOctave((coord - wavesTime) * freq, wavesChoppy);
		h += d * wavesHeight;

		coord *= coordOffs;
		freq *= 2.05;

		wavesHeight *= wavesIteration[i];
		wavesTime *= 1.375f;

		wavesChoppy *= 0.8;
	}

	float ifIsInWater = saturate(float(isEyeInWater * (1 - isCaustics)));
	h *= 1.0 - ifIsInWater * 2.0;

	return h * 0.6;
}
