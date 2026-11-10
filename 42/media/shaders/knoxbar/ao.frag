#version 330 core
// How much the corners, the undersides and the contacts see of the room's air (half size).

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uDepth;
uniform mat4 uProj;
uniform mat4 uInvProj;
uniform vec2 uTexel;

const int SAMPLES = 14;
const float RADIUS = 0.28;
const float GOLDEN = 2.39996323;

vec3 viewAt(vec2 uv)
{
	float d = texture(uDepth, uv).r;
	vec4 v = uInvProj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return v.xyz / v.w;
}

float pixelNoise(vec2 p)
{
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main()
{
	float depth = texture(uDepth, vUv).r;
	if (depth >= 1.0)
	{
		fragColor = vec4(1.0);
		return;
	}
	vec3 p = viewAt(vUv);
	vec3 dx1 = viewAt(vUv + vec2(uTexel.x, 0.0)) - p, dx2 = p - viewAt(vUv - vec2(uTexel.x, 0.0));
	vec3 dy1 = viewAt(vUv + vec2(0.0, uTexel.y)) - p, dy2 = p - viewAt(vUv - vec2(0.0, uTexel.y));
	vec3 dx = abs(dx1.z) < abs(dx2.z) ? dx1 : dx2;
	vec3 dy = abs(dy1.z) < abs(dy2.z) ? dy1 : dy2;
	// (nothing to normalize where the depth stands still: NaN on some cards - overhaul, 2026-11-04)
	vec3 n = cross(dx, dy);
	float nLen = length(n);
	n = nLen > 0.0000001 ? n / nLen : vec3(0.0, 0.0, 1.0);

	float screen = RADIUS * uProj[1][1] * 0.5 / max(-p.z, 0.5);   // the radius in uv height
	vec2 scale = vec2(screen * uTexel.x / uTexel.y, screen);
	float angle = pixelNoise(gl_FragCoord.xy) * 6.2831853;
	float occluded = 0.0;
	for (int i = 0; i < SAMPLES; i++)
	{
		float a = angle + float(i) * GOLDEN;
		float r = sqrt((float(i) + 0.5) / float(SAMPLES));
		vec3 q = viewAt(vUv + vec2(cos(a), sin(a)) * r * scale);
		vec3 d = q - p;
		float l2 = dot(d, d);
		float h = dot(d, n) - 0.012;
		if (h <= 0.0 || l2 <= 0.0) continue;
		float near = clamp(1.0 - l2 / (RADIUS * RADIUS * 2.0), 0.0, 1.0);
		occluded += near * h / sqrt(l2);
	}
	float ao = clamp(1.0 - occluded * 2.0 / float(SAMPLES), 0.0, 1.0);
	fragColor = vec4(ao * ao);
}
