// Clustered Deferred fullscreen vertex shader (simple fullscreen triangle)

struct VertOut {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f
}

@vertex
fn main(@builtin(vertex_index) vi: u32) -> VertOut {
    var verts = array<vec2f, 3>(vec2f(-1.0, -1.0), vec2f(3.0, -1.0), vec2f(-1.0, 3.0));
    var uvs = array<vec2f, 3>(vec2f(0.0, 0.0), vec2f(2.0, 0.0), vec2f(0.0, 2.0));
    var out: VertOut;
    out.pos = vec4f(verts[vi], 0.0, 1.0);
    out.uv = uvs[vi];
    return out;
}