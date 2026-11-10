#version 330 core
// The depth of field (the author, 2026-11-03: a hero under the mouse in focus, the room before and
// behind him soft; the narrator's own arm before his eyes, the bar behind it soft). How soft a
// point is goes by how far it is from the focus, as a lens has it (|1 - focus / distance|), with a
// band about the focus left sharp (uTol: a hero's own depth; an arm reaching from the elbow to
// the fingers). Gathered over a disc: a point takes in what lies before it as far as that one's
// own blur reaches (a near soft edge spills over the sharp behind it), and what lies behind it
// only as far as its own reaches (a sharp near edge stays sharp - no halo of the wall round it).

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uPicture;
uniform sampler2D uDepth;
uniform sampler2D uFocus;
uniform vec2 uTexel;
uniform float uNear;
uniform float uFar;
uniform float uPower;      // 0..1: how much of it
uniform float uAperture;   // pixels of blur at |1 - focus / distance| of 1 past the band
uniform float uMaxBlur;    // pixels at most
uniform float uTol;        // the band left sharp

const int TAPS = 40;
const float GOLDEN = 2.39996323;

float linearDepth(float d)
{
	return 2.0 * uNear * uFar / (uFar + uNear - (d * 2.0 - 1.0) * (uFar - uNear));
}

float blurOf(float z, float focus)
{
	float off = abs(1.0 - focus / z);
	return uPower * min(uMaxBlur, uAperture * max(0.0, off - uTol));
}

void main()
{
	float focus = 1.0 / max(texture(uFocus, vec2(0.5)).r, 1.0 / uFar);
	float z = linearDepth(texture(uDepth, vUv).r);
	float own = blurOf(z, focus);
	vec3 sum = texture(uPicture, vUv).rgb;
	float weight = 1.0;
	float reach = uPower * uMaxBlur;
	if (reach < 0.5)
	{
		fragColor = vec4(sum, 1.0);
		return;
	}
	for (int i = 0; i < TAPS; i++)
	{
		float r = sqrt((float(i) + 0.5) / float(TAPS)) * reach;
		float a = float(i) * GOLDEN;
		vec2 at = vUv + vec2(cos(a), sin(a)) * r * uTexel;
		float sz = linearDepth(texture(uDepth, at).r);
		float sb = blurOf(sz, focus);
		// (before it: as far as its own blur goes; behind it: no further than ours)
		float b = sz < z ? sb : min(sb, own);
		float w = clamp(b - r + 1.0, 0.0, 1.0);
		sum += texture(uPicture, at).rgb * w;
		weight += w;
	}
	fragColor = vec4(sum / weight, 1.0);
}
