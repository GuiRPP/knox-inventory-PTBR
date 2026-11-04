#version 330 core
// A flake: a soft dot. Smoke and breath: a soft cloud, torn a little by a noise of its own.

in vec2 vCorner;
in vec3 vColor;
in float vAlpha;
flat in int vKind;
in float vSeed;
out vec4 fragColor;

float hash(vec2 p)
{
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 p)
{
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void main()
{
	float r = dot(vCorner, vCorner);
	if (r > 1.0) discard;
	float k;
	if (vKind == 0)
	{
		k = (1.0 - r) * (1.0 - r);
	}
	else
	{
		vec2 q = vCorner * 1.7 + vec2(vSeed * 13.7, vSeed * 7.3);
		k = exp(-r * 3.2) * (0.45 + 0.55 * noise(q) * noise(q * 2.1 + 5.0) * 1.6);
	}
	// (onto the picture: light the air scatters, so it adds)
	fragColor = vec4(vColor * k * vAlpha, 0.0);
}
