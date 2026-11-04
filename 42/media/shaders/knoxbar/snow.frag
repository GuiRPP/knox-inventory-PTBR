#version 330 core
// A driven flake, soft all round: some paler than the white behind it, some darker (in a
// whiteout the eye only finds them by the difference).

in float vAlpha;
in vec2 vAt;
in float vPale;
out vec4 fragColor;

uniform vec3 uColor;
uniform vec3 uPale;

void main()
{
	float edge = (1.0 - vAt.x * vAt.x) * (1.0 - vAt.y * vAt.y);
	fragColor = vec4(mix(uColor, uPale, vPale), vAlpha * edge);
}
