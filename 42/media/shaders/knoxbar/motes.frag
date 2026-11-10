#version 330 core

in float vBright;
out vec4 fragColor;

uniform vec3 uColor;

void main()
{
	vec2 q = gl_PointCoord * 2.0 - 1.0;
	float soft = clamp(1.0 - dot(q, q), 0.0, 1.0);
	fragColor = vec4(uColor * soft * vBright, 1.0);
}
