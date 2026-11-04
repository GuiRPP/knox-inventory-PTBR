#version 330 core
// The whiteout behind the openings, as the mockup's: a gradient on a far plane, gust clouds
// drifting across it, the dark line of trees, layers of haze before it. Linear light.

in vec2 vUv;
out vec4 fragColor;

uniform mat4 uInvViewProj;
uniform vec3 uEye;
uniform float uTime;
uniform float uGust;

const float U = 1.0 / 1.22;

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

float fbm(vec2 p)
{
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++)
	{
		s += a * noise(p);
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return s;
}

vec3 linear(vec3 c)
{
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void main()
{
	vec4 far = uInvViewProj * vec4(vUv * 2.0 - 1.0, 1.0, 1.0);
	vec3 ray = far.xyz / far.w - uEye;
	// the far plane at 24 metres behind the room
	float t = (-24.0 * U - uEye.z) / ray.z;
	vec3 p = uEye + ray * t;
	vec2 m = p.xy / U;                        // metres on that plane
	float y = clamp((11.0 - m.y) / 16.0, 0.0, 1.0);
	vec3 a = vec3(0.357, 0.455, 0.502), b = vec3(0.616, 0.706, 0.737), c = vec3(0.812, 0.867, 0.878);
	vec3 col = y < 0.55 ? mix(a, b, y / 0.55) : mix(b, c, (y - 0.55) / 0.45);

	// the gusts: clouds of snow driven across, light and dark
	vec2 w = vec2(m.x * 0.16 + uTime * 0.17, m.y * 0.22 - uTime * 0.03);
	float cloud = fbm(w) - 0.5;
	col += (cloud > 0.0 ? vec3(0.92, 0.96, 0.965) - col : vec3(0.235, 0.33, 0.376) - col) * abs(cloud) * (0.62 + 0.3 * uGust);

	// the trees, barely there
	float ridge = 0.8 * sin(m.x * 0.83 + 1.3) + 0.55 * sin(m.x * 1.97) + 0.35 * sin(m.x * 3.7 + 0.6);
	float line = 1.0 - smoothstep(-0.45, 0.55, m.y + 3.05 - 0.55 * ridge - 2.2);
	col = mix(col, vec3(0.227, 0.314, 0.353), line * 0.35);

	col = linear(col) * linear(vec3(0.62, 0.69, 0.722));

	// the haze before it, thicker with a gust
	vec3 haze = linear(vec3(0.706, 0.776, 0.808));
	float thick = 1.0 - (1.0 - 0.18) * (1.0 - 0.30) * (1.0 - 0.35);
	col = mix(col, haze, clamp(thick + 0.14 * uGust, 0.0, 0.92));
	fragColor = vec4(col * 1.12, 0.0);
}
