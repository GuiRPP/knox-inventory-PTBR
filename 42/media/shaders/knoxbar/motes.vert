#version 330 core
// The motes: snow dust hanging in the air. They drift in the whole lit part of the room and
// are seen only where the sky's light reaches them (the same shadow map), each its own
// place, speed and twinkle from its number - no buffers, nothing for the processor to do.

out float vBright;

uniform mat4 uViewProj;
uniform mat4 uLightViewProj;
uniform sampler2D uShadow;
uniform vec3 uBoxMin;
uniform vec3 uBoxSize;
uniform float uTime;
uniform float uWind;             // the wind's clock: how far it has carried them, gusts and all
uniform float uGust;
uniform float uPixel;            // a pixel's size against the 1080 the look was set at

float hash(float n)
{
	return fract(sin(n) * 43758.5453123);
}

void main()
{
	float id = float(gl_VertexID);
	vec3 base = vec3(hash(id * 1.17 + 0.3), hash(id * 2.31 + 1.7), hash(id * 3.73 + 2.9));
	vec3 flow = vec3(0.012, -0.006, 0.03) * (0.5 + hash(id * 4.19));
	vec3 sway = vec3(sin(uTime * (0.21 + base.x * 0.2) + id), sin(uTime * (0.17 + base.y * 0.2) + id * 1.7), sin(uTime * (0.13 + base.z * 0.2) + id * 2.3));
	vec3 uvw = fract(base + flow * uWind + sway * 0.012 * (1.0 + 2.0 * uGust));
	vec3 p = uBoxMin + uvw * uBoxSize;
	gl_Position = uViewProj * vec4(p, 1.0);
	gl_PointSize = (1.2 + 1.4 * hash(id * 5.1)) * uPixel;

	vec3 s = (uLightViewProj * vec4(p, 1.0)).xyz * 0.5 + 0.5;
	float lit = 0.0;
	if (s.x > 0.0 && s.x < 1.0 && s.y > 0.0 && s.y < 1.0 && s.z < 1.0 && textureLod(uShadow, s.xy, 0.0).r >= s.z - 0.0005) lit = 1.0;
	float twinkle = 0.55 + 0.45 * sin(uTime * (0.7 + 2.0 * base.y) + id * 3.0);
	vBright = lit * twinkle;
	if (lit <= 0.0) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}
