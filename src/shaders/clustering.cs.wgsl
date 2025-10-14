// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

// Clustering compute shader
// This shader determines which lights affect which clusters
@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

const clusterWidth = ${clusterWidth};
const clusterHeight = ${clusterHeight};
const clusterDepth = ${clusterDepth};
const maxLightsPerCluster = ${maxLightsPerCluster};
const lightRadius = ${lightRadius};

const nearPlane = 0.1;
const farPlane = 1000.0;

fn getClusterIndex(clusterCoord: vec3u) -> u32 {
    return clusterCoord.x + 
           clusterCoord.y * clusterWidth + 
           clusterCoord.z * clusterWidth * clusterHeight;
}

fn getClusterOffset(clusterIndex: u32) -> u32 {
    return clusterIndex * (1 + maxLightsPerCluster);
}

fn sphereAABBIntersection(sphereCenter: vec3f, sphereRadius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    let closestPoint = clamp(sphereCenter, aabbMin, aabbMax);
    let distance = length(sphereCenter - closestPoint);
    return distance <= sphereRadius;
}

fn screenToView(screenCoord: vec2f, depth: f32) -> vec3f {
    let ndc = vec3f(
        screenCoord.x / f32(cameraUniforms.screenDimensions.x) * 2.0 - 1.0,
        1.0 - (screenCoord.y / f32(cameraUniforms.screenDimensions.y)) * 2.0,
        depth
    );
    let viewSpace = cameraUniforms.invProjMat * vec4f(ndc, 1.0);
    return viewSpace.xyz / viewSpace.w;
}

@compute @workgroup_size(4, 4, 4)
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterCoord = globalId;
    
    if (clusterCoord.x >= clusterWidth || 
        clusterCoord.y >= clusterHeight || 
        clusterCoord.z >= clusterDepth) {
        return;
    }
    
    // Calculate tile size in pixels
    let tileSize = vec2f(
        f32(cameraUniforms.screenDimensions.x) / f32(clusterWidth),
        f32(cameraUniforms.screenDimensions.y) / f32(clusterHeight)
    );
    
    // Screen space bounds for this cluster
    let minScreen = vec2f(f32(clusterCoord.x), f32(clusterCoord.y)) * tileSize;
    let maxScreen = minScreen + tileSize;
    
    // Depth bounds for this cluster
    let depthSliceSize = (farPlane - nearPlane) / f32(clusterDepth);
    let minDepth = nearPlane + f32(clusterCoord.z) * depthSliceSize;
    let maxDepth = minDepth + depthSliceSize;
    
    // Convert to NDC depth
    let minDepthNDC = (minDepth - nearPlane) / (farPlane - nearPlane) * 2.0 - 1.0;
    let maxDepthNDC = (maxDepth - nearPlane) / (farPlane - nearPlane) * 2.0 - 1.0;
    
    // Get 8 corners of cluster frustum in view space
    let minNear = screenToView(minScreen, minDepthNDC);
    let maxNear = screenToView(maxScreen, minDepthNDC);
    let minFar = screenToView(minScreen, maxDepthNDC);
    let maxFar = screenToView(maxScreen, maxDepthNDC);
    
    // Build AABB from the frustum corners
    var aabbMin = min(min(minNear, maxNear), min(minFar, maxFar));
    var aabbMax = max(max(minNear, maxNear), max(maxFar, maxFar));
    
    let clusterIndex = getClusterIndex(clusterCoord);
    let clusterOffset = getClusterOffset(clusterIndex);
    
    var lightCount = 0u;
    
    // Test each light against this cluster
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        if (lightCount >= maxLightsPerCluster) {
            break;
        }
        
        let light = lightSet.lights[lightIdx];
        
        // Transform light position to view space
        let lightPosView = (cameraUniforms.viewMat * vec4f(light.pos, 1.0)).xyz;
        
        // Test if light sphere intersects cluster AABB
        if (sphereAABBIntersection(lightPosView, lightRadius, aabbMin, aabbMax)) {
            clusterSet.clusters[clusterOffset + 1 + lightCount] = lightIdx;
            lightCount++;
        }
    }
    
    clusterSet.clusters[clusterOffset] = lightCount;
}