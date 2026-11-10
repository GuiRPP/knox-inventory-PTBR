#version 330 core
// The dead walking out in the whiteout (stage 4 of the winter bar, the author 2026-10-31): grey
// shapes in the snow, fainter further out and in a gust, seen only through the openings.

in vec3 vWorld;
in vec3 vNormal;
in vec2 vUv;
in vec4 vTint;
out vec4 fragColor;

uniform vec3 uColor;
uniform float uAlpha;
uniform float uGust;

void main()
{
	// (a little lighter from above: the sky's)
	float shade = 0.8 + 0.2 * normalize(vNormal).y;
	fragColor = vec4(uColor * shade, uAlpha * (1.0 - 0.4 * uGust));
}
