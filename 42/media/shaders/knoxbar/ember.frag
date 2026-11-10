#version 330 core

in float vGlow;
out vec4 fragColor;

void main()
{
	vec2 d = gl_PointCoord * 2.0 - 1.0;
	float r = dot(d, d);
	if (r > 1.0) discard;
	fragColor = vec4(vec3(1.0, 0.42, 0.12) * exp(-r * 5.0) * vGlow * 1.6, 0.0);
}
