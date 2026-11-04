#version 330 core
// From light to a picture, as the approved mockup makes it (sRGB, then the fog in the
// picture's values; its tone curve never reached its frame - measured against its shot) - for
// each of a pixel's samples on its own, so a thin board against the white sky keeps a clean edge. The heroes come from the game in ready
// picture colours (alpha above 0.5). The AO lies on it all, the air is added on top.

in vec2 vUv;
out vec4 fragColor;

uniform sampler2DMS uHdr;
uniform sampler2DMS uDepth;
uniform sampler2D uAo;
uniform sampler2D uAir;
uniform int uSamples;
uniform float uNear;
uniform float uFar;
uniform mat4 uInvViewProj;
uniform vec3 uHomeEye;           // the menu's camera: the dead's depth is as from there
uniform vec3 uHomeDir;

vec3 picture(vec3 c)
{
	// (a soft shoulder only at the very top; the darks stay as they are)
	vec3 v = clamp(c, 0.0, 8.0);
	vec3 over = max(v - 0.8, 0.0);
	v = min(v, 0.8) + 0.2 * over / (over + 0.2);
	return mix(v * 12.92, 1.055 * pow(v, vec3(0.41666)) - 0.055, step(0.0031308, v));
}

void main()
{
	ivec2 at = ivec2(gl_FragCoord.xy);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < uSamples; i++)
	{
		vec4 h = texelFetch(uHdr, at, i);
		// (the heroes in their picture colours as they came; in the room's air all the same - stage 4)
		vec3 c = h.a > 0.5 ? h.rgb : picture(h.rgb);
		float d = texelFetch(uDepth, at, i).r;
		if (d < 1.0)
		{
			float z = 2.0 * uNear * uFar / (uFar + uNear - (d * 2.0 - 1.0) * (uFar - uNear));
			// (the dead out beyond the wall, the game's models: a little lost in the white of the
			// storm with the distance, their clothes still reading - the author, 2026-11-01:
			// at 40% and more they looked untextured)
			// (their depth as from the menu's camera wherever the eye is: walking about the room, the
			// author 2026-11-04, one by the door isn't one of them, nor one outside is near)
			float outside = 0.0;
			if (h.a > 0.5)
			{
				vec4 w = uInvViewProj * vec4(vUv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
				outside = dot(w.xyz / w.w - uHomeEye, uHomeDir);
			}
			if (outside > 11.0) c = mix(c, vec3(0.75, 0.80, 0.82), 1.0 - 0.9 * exp(-(outside - 12.2) / 14.0));
			else c = mix(c, vec3(0.051, 0.090, 0.110), 1.0 - exp(-0.002025 * z * z));
		}
		sum += c;
	}
	vec3 col = sum / float(uSamples);
	col *= texture(uAo, vUv).r;
	// (over the pale sky the air only lifts it, never burns it out)
	vec3 air = texture(uAir, vUv).rgb;
	col += air * (1.0 - clamp(col, 0.0, 1.0));
	fragColor = vec4(col, 1.0);
}
