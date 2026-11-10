#version 330 core
// What drifts in the room's air (stage 5 of the winter bar, the author 2026-10-31): the snow
// blown in through the openings, the cigarette's smoke, the breath in the cold - KnoxBarLife's,
// each a small square turned to the camera, lit as the motes are: the sky's light where the
// shadow map lets it reach, the room's dark elsewhere, the ember's warm on the smoke by it.

// (a corner of the square from an array of its own, not gl_VertexID, and not the particle's data
// in attribute 0: the game's context is the compatibility one, QA 2026-10-31)
layout (location = 0) in vec2 aCorner;
layout (location = 1) in vec4 aPlace;   // x y z (scene units), its half size (units)
layout (location = 2) in vec4 aLook;    // alpha, kind (0 a flake, 1 smoke, 2 breath), seed, age to life

out vec2 vCorner;
out vec3 vColor;
out float vAlpha;
flat out int vKind;
out float vSeed;

uniform mat4 uViewProj;
uniform mat4 uLightViewProj;
uniform sampler2D uShadow;
uniform vec3 uRight;
uniform vec3 uUp;
uniform vec2 uScreen;            // the frame's size, pixels
uniform float uPixel;            // the screen's height to 1080
uniform vec3 uLit[3];            // by kind: in the sky's light
uniform vec3 uDark[3];           // by kind: in the room's dark
uniform vec4 uEmber;             // the ember: x y z, its glow (below 0: none)
uniform float uProjY;            // the projection's vertical scale

void main()
{
	int kind = int(aLook.y + 0.5);
	vec2 c = aCorner;
	vec4 centre = uViewProj * vec4(aPlace.xyz, 1.0);
	float size = aPlace.w, alpha = aLook.x;
	// (a pixel and a bit across at least; smaller than that, fainter instead)
	float px = size * uProjY * uScreen.y * 0.5 / max(centre.w, 0.01);
	float least = 1.2 * uPixel;
	if (px < least)
	{
		alpha *= px / least;
		size *= least / max(px, 0.001);
	}
	// (close to the eye, on the walk about the room: gone, not a white ball - the author, 2026-11-04)
	alpha *= clamp((centre.w - 0.25) / 0.9, 0.0, 1.0);
	gl_Position = uViewProj * vec4(aPlace.xyz + (uRight * c.x + uUp * c.y) * size, 1.0);

	vec3 s = (uLightViewProj * vec4(aPlace.xyz, 1.0)).xyz * 0.5 + 0.5;
	float lit = 0.0;
	if (s.x > 0.0 && s.x < 1.0 && s.y > 0.0 && s.y < 1.0 && s.z < 1.0 && textureLod(uShadow, s.xy, 0.0).r >= s.z - 0.0008) lit = 1.0;
	vec3 colour = mix(uDark[kind], uLit[kind], lit);
	if (kind == 1 && uEmber.w >= 0.0)
	{
		// (the smoke just off the ember takes its glow, more on a drag)
		vec3 d = aPlace.xyz - uEmber.xyz;
		colour += vec3(1.0, 0.45, 0.16) * (0.25 + 0.75 * uEmber.w) * 0.0016 / (0.0016 + dot(d, d));
	}
	vColor = colour;
	vAlpha = alpha;
	vKind = kind;
	vSeed = aLook.z;
	vCorner = c;
}
