#version 330 core
// The winter bar's light (the author, 2026-10-31: as well and as properly lit as can be).
// One light: the blizzard's sky, in one direction, let into the room only through the three
// openings of the back wall - the wall, the boards, the door, whatever stands in the way
// throw real shadows, softer the further they fall. The light bouncing off the lit floor is
// a set of weak lamps without shadows. Linear light; the picture is made later (tone.frag).

in vec3 vWorld;
in vec3 vNormal;
in vec2 vUv;
in vec4 vTint;

out vec4 fragColor;

uniform sampler2D uTexture;
uniform sampler2D uShadow;
uniform mat4 uLightViewProj;
uniform vec3 uLightDir;          // the way the light goes
uniform vec3 uSky;               // its colour
uniform vec2 uSplit;             // where on the wall one opening's light gives way to the next
uniform vec3 uOpenPower;         // the three openings' strength
uniform float uWallZ;            // the back wall's plane
uniform vec3 uShadowScale;       // shadow map's uv per scene unit, x and y; its depth range
uniform vec3 uEye;
uniform vec3 uHemiSky;
uniform vec3 uHemiGround;
uniform vec4 uLampPos[24];       // x y z, reach
uniform vec3 uLampCol[24];
uniform int uLamps;
uniform int uLampsShining;         // the last so many shine on varnish and metal: the garland's
uniform float uEmit;             // what shines by itself: a garland's bulb, lit
uniform int uSearch;             // shadow samples: looking for who's in the way, then softening
uniform int uSoften;

const float GOLDEN = 2.39996323;

float pixelNoise(vec2 p)
{
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// How much of the sky reaches this point: a soft shadow from the one map
float skyVisible(vec3 world, vec3 normal, float cosL)
{
	vec3 p = world + normal * (0.004 + 0.012 * (1.0 - cosL));
	vec3 s = (uLightViewProj * vec4(p, 1.0)).xyz * 0.5 + 0.5;
	// (the map holds exactly what the openings can reach: beyond it there is no light)
	if (s.x <= 0.0 || s.x >= 1.0 || s.y <= 0.0 || s.y >= 1.0 || s.z >= 1.0) return 0.0;
	if (s.z <= 0.0) return 1.0;
	float bias = 0.0005;
	float angle = pixelNoise(gl_FragCoord.xy) * 6.2831853;
	float found = 0.0, sum = 0.0;
	vec2 search = uShadowScale.xy * 0.05;
	for (int i = 0; i < uSearch; i++)
	{
		float a = angle + float(i) * GOLDEN;
		vec2 o = vec2(cos(a), sin(a)) * sqrt((float(i) + 0.5) / float(uSearch)) * search;
		float d = texture(uShadow, s.xy + o).r;
		if (d < s.z - bias)
		{
			sum += d;
			found += 1.0;
		}
	}
	if (found < 0.5) return 1.0;
	// the sky is wide: the further the shadow falls, the softer
	float dist = (s.z - sum / found) * uShadowScale.z;
	vec2 radius = uShadowScale.xy * clamp(dist * 0.016, 0.003, 0.05);
	float lit = 0.0;
	for (int i = 0; i < uSoften; i++)
	{
		float a = angle + float(i) * GOLDEN;
		vec2 o = vec2(cos(a), sin(a)) * sqrt((float(i) + 0.5) / float(uSoften)) * radius;
		if (texture(uShadow, s.xy + o).r >= s.z - bias) lit += 1.0;
	}
	return lit / float(uSoften);
}

// (normalize of nothing is undefined: NaN on some cards, and the glow spreads one pixel of it over the
// picture - overhaul, 2026-11-04)
vec3 unit(vec3 v)
{
	float l = length(v);
	return l > 0.000001 ? v / l : vec3(0.0, 1.0, 0.0);
}

void main()
{
	vec4 tex = texture(uTexture, vUv);
	if (tex.a < 0.5) discard;
	vec3 albedo = tex.rgb * vTint.rgb;

	vec3 toEye = uEye - vWorld;
	vec3 view = unit(toEye);
	vec3 normal = unit(vNormal);
	if (dot(normal, view) < 0.0) normal = -normal;

	vec3 toSky = -uLightDir;
	float cosL = max(dot(normal, toSky), 0.0);
	vec3 light = mix(uHemiGround, uHemiSky, 0.5 * normal.y + 0.5);
	vec3 shine = vec3(0.0);

	if (cosL > 0.0)
	{
		float visible = skyVisible(vWorld, normal, cosL);
		if (visible > 0.0)
		{
			// which opening it came through: where the ray back crosses the wall
			float back = (uWallZ - vWorld.z) / uLightDir.z;
			float x = vWorld.x + uLightDir.x * back;
			float power = x < uSplit.x ? uOpenPower.x : (x < uSplit.y ? uOpenPower.y : uOpenPower.z);
			vec3 sun = uSky * power * visible;
			light += sun * cosL;
			if (vTint.a > 0.0)
			{
				// (varnish, glass, metal: the only things that shine back at the sky)
				vec3 h = unit(toSky + view);
				float power2 = mix(16.0, 180.0, vTint.a);
				shine += sun * cosL * vTint.a * pow(max(dot(normal, h), 0.0), power2) * (power2 + 8.0) / 25.0 * 0.04;
			}
		}
	}

	for (int i = 0; i < uLamps; i++)
	{
		vec3 toLamp = uLampPos[i].xyz - vWorld;
		float d = length(toLamp);
		float fall = 1.0 - d / uLampPos[i].w;
		if (fall <= 0.0) continue;
		float cosLamp = max(dot(normal, toLamp) / max(d, 0.001), 0.0);
		light += uLampCol[i] * fall * fall * cosLamp;
		if (i >= uLamps - uLampsShining && vTint.a > 0.0 && cosLamp > 0.0)
		{
			vec3 h = unit(toLamp / max(d, 0.001) + view);
			float power2 = mix(16.0, 180.0, vTint.a);
			shine += uLampCol[i] * fall * fall * cosLamp * vTint.a * pow(max(dot(normal, h), 0.0), power2) * (power2 + 8.0) / 25.0 * 0.5;
		}
	}

	// (alpha 0: this one is the room's, in linear light. The heroes the game draws into the
	// same frame leave their own 1 and their ready picture colours)
	fragColor = vec4(albedo * (light + uEmit) + shine, 0.0);
}
