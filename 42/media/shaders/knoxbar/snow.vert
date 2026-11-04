#version 330 core
// The snow driven past the openings (stage 5 of the winter bar, the author 2026-10-31): a field
// of flakes out behind the back wall, carried along by the wind's own clock (KnoxBarFrame:
// wind), each a short streak the way it flies, longer in a gust. The room's depth hides all
// of it but what the three openings show. Its place from its number: no buffers.

out float vAlpha;
out vec2 vAt;
out float vPale;

uniform mat4 uViewProj;
uniform float uWind;             // the wind's clock: wind-seconds it has blown
uniform float uWindNow;          // how hard it blows now, against the calm
uniform float uPixel;            // the screen's height to 1080
uniform vec2 uScreen;            // the frame's size, pixels
uniform float uAlpha;
uniform float uProjY;           // the projection's vertical scale

const float U = 1.0 / 1.22;

float hash(float n)
{
	return fract(sin(n) * 43758.5453123);
}

void main()
{
	float id = float(gl_InstanceID);
	vec3 h = vec3(hash(id * 1.31 + 0.7), hash(id * 2.17 + 3.1), hash(id * 3.91 + 5.3));
	// metres: from the left past the right of the room, the ground to over the roof, from the
	// wall out into the white
	vec3 from = vec3(-6.0, -0.3, -21.0), size = vec3(17.0, 4.6, 12.85);
	float speed = 0.7 + 0.6 * hash(id * 5.7 + 1.1);
	vec3 vel = vec3(4.2, -1.2, 1.1) * speed;
	float wob = sin(uWind * (1.3 + h.y) + id) * 0.35;
	vec3 p = from + fract(h + (vel * uWind + vec3(0.0, wob, wob * 0.5)) / size) * size;
	// (more of them near the wall, where they are big: squared the way out, the wrap unseen far off)
	float out_ = (-8.15 - p.z) / size.z;
	p.z = -8.15 - out_ * out_ * size.z;
	vec3 tail = p - vel * (0.012 + 0.012 * uWindNow);

	vec4 a = uViewProj * vec4(tail * U, 1.0), b = uViewProj * vec4(p * U, 1.0);
	// (one pixel across at least; thinner than that, fainter instead)
	float px = (0.009 + 0.016 * h.x) * U * uProjY * uScreen.y * 0.5 / max(b.w, 0.01);
	float width = max(px, 1.1 * uPixel);
	vAlpha = uAlpha * min(1.0, px / (1.1 * uPixel) + 0.35) * exp((p.z + 8.0) / 6.0);
	vec2 sa = a.xy / a.w * uScreen * 0.5, sb = b.xy / b.w * uScreen * 0.5;
	vec2 d = sb - sa;
	float len = length(d);
	vec2 along = len > 0.001 ? d / len : vec2(1.0, 0.0);
	vec2 side = vec2(-along.y, along.x) * width * 0.5;
	// the corners: the tail's two, then the head's (a strip); round off the ends by half a width
	int i = gl_VertexID;
	vec4 c = i < 2 ? a : b;
	vec2 s = (i < 2 ? sa - along * width * 0.5 : sb + along * width * 0.5) + side * ((i & 1) == 0 ? -1.0 : 1.0);
	vAt = vec2(i < 2 ? -1.0 : 1.0, (i & 1) == 0 ? -1.0 : 1.0);
	vPale = step(0.45, h.z);
	gl_Position = vec4(s / (uScreen * 0.5) * c.w, c.z, c.w);
	if (a.w <= 0.01 || b.w <= 0.01) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}
