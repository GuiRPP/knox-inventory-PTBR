#version 330 core
// The bar seen from the sky's light (room.frag: uShadow).

layout (location = 0) in vec3 aPos;
layout (location = 2) in vec2 aUv;

uniform mat4 uLightViewProj;
uniform mat4 uModel;
uniform vec3 uFlutter;           // (room.vert)
uniform vec3 uPage;              // (room.vert)
uniform vec4 uSwag;              // (room.vert)
uniform vec4 uSwagSide;          // (room.vert)
uniform vec3 uTail;              // (room.vert)

out vec2 vUv;

// the garland in the draught: room.vert's, without the normal
vec3 sway(vec3 p)
{
	const vec2 HOOK = vec2(2.2, 2.95);
	float a, b = 0.0;
	if (p.x > HOOK.x || (p.x > 2.165 && p.y < 2.92))
	{
		float k = smoothstep(0.0, 0.15, length(p.xy - HOOK));
		a = uTail.x * k;
		b = uTail.y * k;
	}
	else
	{
		float t = clamp((p.x + 5.8) / 2.0, 0.0, 3.999);
		float m = sin(fract(t) * 3.14159265);
		a = uSwag[int(t)] * m;
		p.x += uSwagSide[int(t)] * m;
	}
	float c = cos(a), s = sin(a);
	float dy = p.y - HOOK.y;
	p.yz = vec2(HOOK.y + dy * c + p.z * s, -dy * s + p.z * c);
	if (b != 0.0)
	{
		c = cos(b);
		s = sin(b);
		vec2 e = p.xy - HOOK;
		p.xy = HOOK + vec2(e.x * c - e.y * s, e.x * s + e.y * c);
	}
	return p;
}

void main()
{
	vUv = aUv;
	vec3 p = aPos;
	if (uTail.z > 0.0) p = sway(p);
	// a sheet the draft lifts: held at x 0, higher and rippling towards its free edge
	if (uFlutter.x > 0.0)
	{
		float s = clamp(p.x / uFlutter.z, 0.0, 1.0);
		float wave = sin(uFlutter.y - s * 4.0);
		p.y += uFlutter.x * s * s * (0.7 + 0.3 * wave);
	}
	if (uPage.z > 0.0)
	{
		float a = uPage.x - uPage.y * p.x / uPage.z;
		p = vec3(p.x * cos(a), p.x * sin(a) + p.y, p.z);
	}
	gl_Position = uLightViewProj * uModel * vec4(p, 1.0);
}
