#version 120


uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;

uniform sampler2D gaux3;
uniform vec2 resolution;

/* DRAWBUFFERS:6 */

float Luminance(in vec3 color)
{
	//return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
	return dot(color, vec3(0.3333));
}

void main() {
	//discard;

	vec4 rain = texture2D(texture, texcoord.st) * color;
	vec3 screen  = vec3(0.0);
	int count = 0;

	for(float i = 0.0; i <= 1.0; i += 0.125)
	{
		for(float j = 0.0; j <= 1.0; j += 0.125)
		{
			screen += texture2D(gaux3, vec2(i, j)).rgb;
			count++;
		}
	}

	screen /= float(count);

	float brightness = Luminance(screen);

	rain.rgb = normalize(pow(rain.rgb, vec3(0.25))) * brightness;
	
	gl_FragData[0] = rain;
		
}