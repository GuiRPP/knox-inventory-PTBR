#version 330 core
// The glow: what's brightest in the picture, halved step by step. uThreshold on the first
// step only (the mockup's 0.86, on picture values).

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uPicture;
uniform vec2 uTexel;
uniform float uThreshold;

void main()
{
	vec3 a = texture(uPicture, vUv + uTexel * vec2(-1.0, -1.0)).rgb;
	vec3 b = texture(uPicture, vUv + uTexel * vec2(1.0, -1.0)).rgb;
	vec3 c = texture(uPicture, vUv + uTexel * vec2(-1.0, 1.0)).rgb;
	vec3 d = texture(uPicture, vUv + uTexel * vec2(1.0, 1.0)).rgb;
	vec3 e = texture(uPicture, vUv).rgb;
	vec3 col = (a + b + c + d) * 0.125 + e * 0.5;
	if (uThreshold > 0.0)
	{
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		col *= smoothstep(uThreshold, uThreshold + 0.06, l);
	}
	fragColor = vec4(col, 1.0);
}
