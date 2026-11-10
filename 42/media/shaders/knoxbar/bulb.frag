#version 330 core

in vec3 vCol;
out vec4 fragColor;

void main()
{
	vec2 d = gl_PointCoord * 2.0 - 1.0;
	float r = dot(d, d);
	if (r > 1.0) discard;
	fragColor = vec4(vCol * (exp(-r * 16.0) * 1.1 + exp(-r * 4.0) * 0.16) * (1.0 - r), 0.0);
}
