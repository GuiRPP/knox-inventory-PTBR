#version 330 core
// (holes in a picture let the light through: a note's torn edge, the garland)

in vec2 vUv;
uniform sampler2D uTexture;

void main()
{
	if (texture(uTexture, vUv).a < 0.5) discard;
}
