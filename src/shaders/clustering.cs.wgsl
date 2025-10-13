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

// Constants from shaders.ts
const clusterWidth = ${clusterWidth};
const clusterHeight = ${clusterHeight};
const clusterDepth = ${clusterDepth};
const maxLightsPerCluster = ${maxLightsPerCluster};
const lightRadius = ${lightRadius};

// Near and far planes from Camera class
const nearPlane = 0.1;
const farPlane = 1000.0;

// Helper function to convert screen space to view space
fn screenToView(screenPos: vec2f, depth: f32) -> vec3f {
    // Convert screen coordinates to NDC
    let ndc = vec3f(
        screenPos.x / f32(cameraUniforms.screenDimensions.x) * 2.0 - 1.0,
        (1.0 - screenPos.y / f32(cameraUniforms.screenDimensions.y)) * 2.0 - 1.0,
        depth
    );
    
    // Unproject using inverse projection matrix
    let viewPos = cameraUniforms.invProjMat * vec4f(ndc, 1.0);
    return viewPos.xyz / viewPos.w;
}

// Get the index of a cluster from its 3D coordinates
fn getClusterIndex(clusterCoord: vec3u) -> u32 {
    return clusterCoord.x + 
           clusterCoord.y * clusterWidth + 
           clusterCoord.z * clusterWidth * clusterHeight;
}

// Get the offset in the flat cluster buffer for a given cluster
fn getClusterOffset(clusterIndex: u32) -> u32 {
    return clusterIndex * (1 + maxLightsPerCluster);
}

// Check if a sphere (light) intersects with an AABB (cluster bounds)
fn sphereAABBIntersection(sphereCenter: vec3f, sphereRadius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    // Find the closest point on the AABB to the sphere center
    let closestPoint = clamp(sphereCenter, aabbMin, aabbMax);
    
    // Calculate distance from sphere center to closest point
    let distance = length(sphereCenter - closestPoint);
    
    return distance <= sphereRadius;
}

@compute @workgroup_size(4, 4, 4)
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterCoord = globalId;
    
    if (clusterCoord.x >= clusterWidth || 
        clusterCoord.y >= clusterHeight || 
        clusterCoord.z >= clusterDepth) {
        return;
    }
    
    let clusterIndex = getClusterIndex(clusterCoord);
    let clusterOffset = getClusterOffset(clusterIndex);
    
    var lightCount = 0u;
    
    // Simple: Add ALL lights to every cluster (no culling for now)
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        if (lightCount >= maxLightsPerCluster) {
            break;
        }
        clusterSet.clusters[clusterOffset + 1 + lightCount] = lightIdx;
        lightCount++;
    }
    
    clusterSet.clusters[clusterOffset] = lightCount;
}