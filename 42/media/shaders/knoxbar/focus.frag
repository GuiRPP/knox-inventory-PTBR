#version 330 core
// Where the eye is focused (the depth of field: the author, 2026-11-03): how far the thing looked at
// is when it is known (uWant: a hero, the radio - not the wall the point on the screen may fall on
// beside them), else the depth at the point - the nearest of a few taps round it; eased from the
// last frame's, as an eye takes a moment to focus anew. Kept as 1/distance: the
// focus goes over evenly from near to far. One pixel.

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uDepth;
uniform sampler2D uLast;
uniform vec2 uAt;
uniform vec2 uSpread;
uniform float uBlend;
uniform float uWant;
uniform float uNear;
uniform float uFar;

float linearDepth(float d)
{
	return 2.0 * uNear * uFar / (uFar + uNear - (d * 2.0 - 1.0) * (uFar - uNear));
}

void main()
{
	float z = uFar;
	if (uWant > 0.0) z = uWant;
	else for (int i = -1; i <= 1; i++)
	{
		for (int j = -1; j <= 1; j++)
		{
			vec2 at = clamp(uAt + vec2(float(i), float(j)) * uSpread, vec2(0.0), vec2(1.0));
			z = min(z, linearDepth(texture(uDepth, at).r));
		}
	}
	float last = texture(uLast, vec2(0.5)).r;
	fragColor = vec4(mix(last, 1.0 / max(z, uNear), uBlend), 0.0, 0.0, 1.0);
}
