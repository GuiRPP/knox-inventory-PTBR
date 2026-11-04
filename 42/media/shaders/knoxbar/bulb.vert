#version 330 core
// A lit bulb of the garland's halo, as the ember's: a point the bloom makes more of (the author,
// 2026-11-02). One for each live bulb, its place and colour by gl_VertexID.

uniform mat4 uViewProj;
uniform vec3 uBulb[30];
uniform vec3 uBulbCol[30];
uniform float uPixel;          // the screen's height to 1080
uniform float uShown;          // the garland's light now, 0..1

out vec3 vCol;

void main()
{
	gl_Position = uViewProj * vec4(uBulb[gl_VertexID], 1.0);
	vCol = uBulbCol[gl_VertexID] * uShown;
	gl_PointSize = max(2.0, uPixel * 300.0 / gl_Position.w);
}
