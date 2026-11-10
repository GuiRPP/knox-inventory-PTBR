#version 330 core
// The winter bar's room in its own frame (KnoxBarFrame.java; the author, 2026-10-31).
// The still room is baked into world space (uModel is 1); what moves has its own matrix.

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUv;
layout (location = 3) in vec4 aTint;

uniform mat4 uViewProj;
uniform mat4 uModel;
uniform mat3 uNormalMat;
uniform vec3 uFlutter;           // a loose sheet (stage 5): how high, the ripple's phase, its length; 0: not one
uniform vec3 uPage;              // a journal's page: its angle at the fold, how far the free edge lags, its width; 0: not one
uniform vec4 uSwag;              // the garland in the draught: each swag's angle out from the wall
uniform vec4 uSwagSide;          // and how far its middle goes along the wall, metres
uniform vec3 uTail;              // its torn end's: out from the wall, along it; z 1: the garland, 0: not it

out vec3 vWorld;

// The garland in the draught (the author, 2026-11-02): its mesh in metres (MenuGen's bar_garland),
// its swags from hooks 2 m apart on x -5.8 .. 2.2 at y 2.95, z 0 its wire, out from the wall. A
// swag swings out about its hooks' line, the most at its middle; the torn end from the last hook,
// a pendulum stiff at the top. KnoxBarFrame.sway does the same for the halos and the lights.
vec3 sway(vec3 p, inout vec3 n)
{
	const vec2 HOOK = vec2(2.2, 2.95);
	float a, b = 0.0;
	// (the bulb on the last hook goes with the end it hangs from)
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
	n.yz = vec2(n.y * c + n.z * s, -n.y * s + n.z * c);
	if (b != 0.0)
	{
		c = cos(b);
		s = sin(b);
		vec2 e = p.xy - HOOK;
		p.xy = HOOK + vec2(e.x * c - e.y * s, e.x * s + e.y * c);
		n.xy = vec2(n.x * c - n.y * s, n.x * s + n.y * c);
	}
	return p;
}
out vec3 vNormal;
out vec2 vUv;
out vec4 vTint;

void main()
{
	vec3 p = aPos;
	vec3 n = aNormal;
	if (uTail.z > 0.0) p = sway(p, n);
	// a sheet the draft lifts: held at x 0, higher and rippling towards its free edge
	if (uFlutter.x > 0.0)
	{
		float s = clamp(p.x / uFlutter.z, 0.0, 1.0);
		float wave = sin(uFlutter.y - s * 4.0);
		p.y += uFlutter.x * s * s * (0.7 + 0.3 * wave);
		float slope = uFlutter.x * (2.0 * s * (0.7 + 0.3 * wave) - 1.2 * s * s * cos(uFlutter.y - s * 4.0)) / uFlutter.z;
		n = normalize(vec3(-slope, 1.0, 0.0));
	}
	// over the fold from the right to the left, the free edge behind; on the height the pages have there.
	// (Its two sides lie apart: nothing culls the back.)
	if (uPage.z > 0.0)
	{
		float a = uPage.x - uPage.y * p.x / uPage.z;
		float side = aNormal.y > 0.0 ? 1.0 : -1.0;
		n = side * vec3(-sin(a), cos(a), 0.0);
		p = vec3(p.x * cos(a), p.x * sin(a) + p.y, p.z) + n * 0.0006;
	}
	vec4 w = uModel * vec4(p, 1.0);
	vWorld = w.xyz;
	vNormal = uNormalMat * n;
	vUv = aUv;
	vTint = aTint;
	gl_Position = uViewProj * w;
}
