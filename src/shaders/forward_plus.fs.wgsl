// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

const clusterWidth = ${clusterWidth};
const clusterHeight = ${clusterHeight};
const clusterDepth = ${clusterDepth};
const maxLightsPerCluster = ${maxLightsPerCluster};
const nearPlane = 0.1;
const farPlane = 1000.0;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Calculate cluster index
    let clusterX = u32(in.fragCoord.x / (f32(cameraUniforms.screenDimensions.x) / f32(clusterWidth)));
    let clusterY = u32(in.fragCoord.y / (f32(cameraUniforms.screenDimensions.y) / f32(clusterHeight)));
    
    // Calculate view space depth
    let viewPos = (cameraUniforms.viewMat * vec4f(in.pos, 1.0)).xyz;
    let viewDepth = -viewPos.z;
    
    // Map to cluster Z
    let depthNorm = clamp((viewDepth - nearPlane) / (farPlane - nearPlane), 0.0, 1.0);
    let clusterZ = u32(floor(depthNorm * f32(clusterDepth)));
    
    let cx = min(clusterX, clusterWidth - 1);
    let cy = min(clusterY, clusterHeight - 1);
    let cz = min(clusterZ, clusterDepth - 1);
    
    let clusterIndex = cx + cy * clusterWidth + cz * clusterWidth * clusterHeight;
    let clusterOffset = clusterIndex * (1 + maxLightsPerCluster);
    let lightCount = clusterSet.clusters[clusterOffset];
    
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < lightCount; i++) {
        let lightIdx = clusterSet.clusters[clusterOffset + 1 + i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
}