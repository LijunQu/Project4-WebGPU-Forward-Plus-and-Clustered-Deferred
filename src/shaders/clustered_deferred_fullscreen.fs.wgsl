// Clustered Deferred fullscreen fragment shader
// Reads the G-buffer and uses the precomputed cluster lists to only iterate lights that affect this pixel's cluster.
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var gBufferPosition: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var gBufferNormal: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(5) var gBufferAlbedo: texture_2d<f32>;

const clusterWidth = ${clusterWidth};
const clusterHeight = ${clusterHeight};
const clusterDepth = ${clusterDepth};
const maxLightsPerCluster = ${maxLightsPerCluster};
const nearPlane = 0.1;
const farPlane = 1000.0;

struct FragmentInput {
    @builtin(position) fragCoord: vec4f,
    @location(0) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let pixelCoord = vec2i(in.fragCoord.xy);
    
    let position = textureLoad(gBufferPosition, pixelCoord, 0).xyz;
    let nor = textureLoad(gBufferNormal, pixelCoord, 0).xyz;
    let albedo = textureLoad(gBufferAlbedo, pixelCoord, 0);
    
    // Calculate cluster index
    let clusterX = u32(in.fragCoord.x / (f32(cameraUniforms.screenDimensions.x) / f32(clusterWidth)));
    let clusterY = u32(in.fragCoord.y / (f32(cameraUniforms.screenDimensions.y) / f32(clusterHeight)));
    
    let viewPos = (cameraUniforms.viewMat * vec4f(position, 1.0)).xyz;
    let viewDepth = -viewPos.z;
    let depthNorm = clamp((viewDepth - nearPlane) / (farPlane - nearPlane), 0.0, 1.0);
    let clusterZ = u32(floor(depthNorm * f32(clusterDepth)));
    
    let cx = min(clusterX, clusterWidth - 1);
    let cy = min(clusterY, clusterHeight - 1);
    let cz = min(clusterZ, clusterDepth - 1);
    
    let clusterIndex = cx + cy * clusterWidth + cz * clusterWidth * clusterHeight;
    let clusterOffset = clusterIndex * (1 + maxLightsPerCluster);
    let lightCount = clusterSet.clusters[clusterOffset];
    
    var totalLightContrib = vec3f(0.0);
    
    // Hybrid: Use clustering if available, otherwise fallback
    if (lightCount > 0u) {
        // Use clustered lights
        let safeCount = min(lightCount, maxLightsPerCluster);
        for (var i = 0u; i < safeCount; i++) {
            let lightIdx = clusterSet.clusters[clusterOffset + 1u + i];
            if (lightIdx < lightSet.numLights) {
                totalLightContrib += calculateLightContrib(lightSet.lights[lightIdx], position, nor);
            }
        }
    } else {
        // Fallback: use all lights
        for (var i = 0u; i < lightSet.numLights; i++) {
            totalLightContrib += calculateLightContrib(lightSet.lights[i], position, nor);
        }
    }
    
    return vec4f(albedo.rgb * totalLightContrib, 1.0);
}