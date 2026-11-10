#version 330 core
// Blur that stays on its own surface: not across a difference in depth. Half size pictures
// of the AO and the air.

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uPicture;
uniform sampler2D uDepth;
uniform vec2 uStep;
uniform float uNear;
uniform float uFar;

float linearDepth(float d)
{
	return 2.0 * uNear * uFar / (uFar + uNear - (d * 2.0 - 1.0) * (uFar - uNear));
}

void main()
{
	float z = linearDepth(texture(uDepth, vUv).r);
	vec4 sum = texture(uPicture, vUv) * 0.25;
	float weight = 0.25;
	for (int i = -3; i <= 3; i++)
	{
		if (i == 0) continue;
		vec2 at = vUv + uStep * float(i);
		float dz = abs(linearDepth(texture(uDepth, at).r) - z);
		float w = exp(-float(i * i) * 0.22) * exp(-dz * dz * 40.0);
		sum += texture(uPicture, at) * w;
		weight += w;
	}
	fragColor = sum / weight;
}
