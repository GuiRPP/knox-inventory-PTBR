#version 330 core
// The shafts of light in the air (the mockup's look, made real): walk along the eye's ray
// through the room and gather the light wherever the sky reaches that point - by the same
// shadow map as the room's, so the boards cut the shafts, the door moves them, and heroes
// walk through them. The air is uneven: snow dust, carried by the wind.

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uDepth;
uniform sampler2D uShadow;
uniform mat4 uInvViewProj;
uniform mat4 uLightViewProj;
uniform vec3 uEye;
uniform vec3 uLightDir;
uniform vec2 uSplit;
uniform vec3 uAirPower;          // the three openings' air, as the mockup's strengths
uniform float uWallZ;
uniform float uTime;
uniform float uGust;
uniform vec3 uAirColor;
uniform int uSteps;

float pixelNoise(vec2 p)
{
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float hash(vec3 p)
{
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x)
{
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void main()
{
	float depth = texture(uDepth, vUv).r;
	vec4 w = uInvViewProj * vec4(vUv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	vec3 end = w.xyz / w.w;
	vec3 ray = end - uEye;
	float len = length(ray);
	vec3 dir = ray / len;

	// (only the room's part of the ray can hold light: from the back wall to where it dies)
	float tEnd = len;
	if (dir.z < 0.0) tEnd = min(tEnd, (uWallZ - uEye.z) / dir.z);
	float reach = uWallZ + 7.0;
	float tStart = dir.z < 0.0 ? max(0.0, (reach - uEye.z) / dir.z) : 0.0;
	if (tEnd <= tStart)
	{
		fragColor = vec4(0.0);
		return;
	}
	float stride = (tEnd - tStart) / float(uSteps);
	float t = tStart + stride * pixelNoise(gl_FragCoord.xy);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < uSteps; i++, t += stride)
	{
		vec3 p = uEye + dir * t;
		vec3 s = (uLightViewProj * vec4(p, 1.0)).xyz * 0.5 + 0.5;
		if (s.x <= 0.0 || s.x >= 1.0 || s.y <= 0.0 || s.y >= 1.0 || s.z >= 1.0) continue;
		if (texture(uShadow, s.xy).r < s.z - 0.0005) continue;
		float along = (p.z - uWallZ) / uLightDir.z;
		float x = p.x - uLightDir.x * along;
		float power = x < uSplit.x ? uAirPower.x : (x < uSplit.y ? uAirPower.y : uAirPower.z);
		vec3 q = p * 3.2 + vec3(-uTime * 0.13, uTime * 0.05, -uTime * 0.28);
		float n = noise(q);
		sum += power * exp(-along * 0.42) * (0.35 + 1.1 * n * n);
	}
	fragColor = vec4(sum * stride * uAirColor * (1.0 + 0.45 * uGust), 1.0);
}
