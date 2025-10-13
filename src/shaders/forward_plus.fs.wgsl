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

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

fn getClusterIndex(fragCoord: vec4f) -> u32 {
    let clusterX = u32(fragCoord.x / (f32(cameraUniforms.screenDimensions.x) / f32(clusterWidth)));
    let clusterY = u32(fragCoord.y / (f32(cameraUniforms.screenDimensions.y) / f32(clusterHeight)));
    let clusterZ = u32(fragCoord.z * f32(clusterDepth));
    
    let clusterXClamped = min(clusterX, clusterWidth - 1);
    let clusterYClamped = min(clusterY, clusterHeight - 1);
    let clusterZClamped = min(clusterZ, clusterDepth - 1);
    
    return clusterXClamped + 
           clusterYClamped * clusterWidth + 
           clusterZClamped * clusterWidth * clusterHeight;
}

fn getClusterOffset(clusterIndex: u32) -> u32 {
    return clusterIndex * (1 + maxLightsPerCluster);
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let clusterIndex = getClusterIndex(in.fragCoord);
    let clusterOffset = getClusterOffset(clusterIndex);
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