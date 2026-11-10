#version 330 core
// The panes left in the smashed window: nothing lights them, the whiteout shows through.

in vec3 vWorld;
in vec2 vUv;
in vec4 vTint;

out vec4 fragColor;

uniform sampler2D uTexture;

void main()
{
	vec4 tex = texture(uTexture, vUv);
	if (tex.a < 0.02) discard;
	// (blended over linear light; alpha stays the room's 0 where it is written with blend
	// factors for colour only)
	fragColor = vec4(tex.rgb * vTint.rgb, tex.a);
}
