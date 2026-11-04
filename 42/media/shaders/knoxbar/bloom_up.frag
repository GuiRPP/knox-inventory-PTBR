#version 330 core
// The glow growing back: each step blurred with a tent onto the step above (blended by the
// frame: one, one).

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uPicture;
uniform vec2 uTexel;
uniform float uStrength;

void main()
{
	vec3 s = texture(uPicture, vUv).rgb * 4.0;
	s += texture(uPicture, vUv + uTexel * vec2(-1.0, 0.0)).rgb * 2.0;
	s += texture(uPicture, vUv + uTexel * vec2(1.0, 0.0)).rgb * 2.0;
	s += texture(uPicture, vUv + uTexel * vec2(0.0, -1.0)).rgb * 2.0;
	s += texture(uPicture, vUv + uTexel * vec2(0.0, 1.0)).rgb * 2.0;
	s += texture(uPicture, vUv + uTexel * vec2(-1.0, -1.0)).rgb;
	s += texture(uPicture, vUv + uTexel * vec2(1.0, -1.0)).rgb;
	s += texture(uPicture, vUv + uTexel * vec2(-1.0, 1.0)).rgb;
	s += texture(uPicture, vUv + uTexel * vec2(1.0, 1.0)).rgb;
	fragColor = vec4(s / 16.0 * uStrength, 1.0);
}
