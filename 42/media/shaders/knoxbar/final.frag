#version 330 core
// The last touch, the mockup's: the glow, a worn-out cold picture, the corners dark, the grain.

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uPicture;
uniform sampler2D uBloom;
uniform float uBloomPower;
uniform vec2 uSize;
uniform float uTime;

float grain(vec2 p)
{
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
	vec3 c = texture(uPicture, vUv).rgb + texture(uBloom, vUv).rgb * uBloomPower;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, 0.8);
	c *= mix(vec3(1.0), vec3(0.84, 0.96, 1.14), 1.0 - smoothstep(0.0, 0.4, l));
	c += vec3(0.007, 0.011, 0.015) * (1.0 - l);
	vec2 q = vUv - 0.5;
	c *= clamp(1.0 - dot(q * vec2(1.2, 1.0), q * vec2(1.2, 1.0)) * 1.5, 0.0, 1.0);
	c += (grain(vUv * uSize + fract(uTime * 7.13) * 91.0) - 0.5) * 0.03;
	fragColor = vec4(c, 1.0);
}
