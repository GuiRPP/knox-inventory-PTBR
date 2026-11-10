#version 330 core
// The cigarette's ember (stage 4 of the winter bar): one point the bloom makes a glow of, pulled
// a little towards the eye so the fingers holding it don't hide it. A drag makes it brighter.

uniform mat4 uViewProj;
uniform vec3 uPos;
uniform vec3 uEye;
uniform float uPixel;          // the screen's height to 1080
uniform float uGlow;           // 0 resting .. 1 a drag
uniform float uTime;
uniform float uShown;          // as far as the smoker has come out of the dark
// (it stood over the cigarette's end: the author's screenshot, 2026-11-01)
const float DOWN = 0.012;

out float vGlow;

void main()
{
	vec3 p = uPos + normalize(uEye - uPos) * 0.03;
	p.y -= DOWN;
	gl_Position = uViewProj * vec4(p, 1.0);
	float flicker = 0.9 + 0.1 * sin(uTime * 23.0) * sin(uTime * 7.1);
	vGlow = (0.35 + 0.65 * uGlow) * flicker * uShown;
	gl_PointSize = max(2.0, uPixel * (18.0 + 16.0 * uGlow) / gl_Position.w);
}
