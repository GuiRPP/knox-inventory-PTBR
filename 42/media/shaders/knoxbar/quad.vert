#version 330 core
// One triangle over the whole target, no buffers.

out vec2 vUv;

void main()
{
	vec2 p = vec2(float((gl_VertexID & 1) * 4 - 1), float((gl_VertexID & 2) * 2 - 1));
	vUv = p * 0.5 + 0.5;
	gl_Position = vec4(p, 0.0, 1.0);
}
