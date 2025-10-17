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
@group(0) @binding(0) var<uniform> camUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

const clusterWidth = ${clusterWidth};
const clusterHeight = ${clusterHeight};
const clusterDepth = ${clusterDepth};
const maxLightsPerCluster = ${maxLightsPerCluster};
const lightRadius = ${lightRadius};

const nearPlane = 0.1;
const farPlane = 1000.0;

struct Plane {
    n: vec3f,
    d: f32
}

fn rayFromNdcXY(ndcXY: vec2f) -> vec3f {
    let p4 = camUniforms.invProjMat * vec4f(ndcXY, 1.0, 1.0);
    let pv = p4.xyz / p4.w;
    return normalize(pv);
}

fn sphereIntersectsCluster(planes: array<Plane, 6>, center: vec3f, radius: f32) -> bool {
    for (var p = 0u; p < 6; p++) {
        var dist = dot(planes[p].n, center) + planes[p].d;
        if (dist > radius) {
            return false;
        }
    }
    return true;
}

fn zBounds(index: u32) -> vec2f {
    let numClustersZ = f32(clusterDepth);
    let dn = nearPlane;
    let df = farPlane;
    let t0 = f32(index) / numClustersZ;
    let t1 = f32(index + 1u) / numClustersZ;
    let d0 = mix(dn, df, t0);
    let d1 = mix(dn, df, t1);
    return vec2f(d0, d1);
}

@compute @workgroup_size(4, 4, 4)
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterCoord = globalId;
    
    if (clusterCoord.x >= clusterWidth || 
        clusterCoord.y >= clusterHeight || 
        clusterCoord.z >= clusterDepth) {
        return;
    }
    
    let clusterIdX = clusterCoord.x;
    let clusterIdY = clusterCoord.y;
    let clusterIdZ = clusterCoord.z;
    
    // Calculate NDC bounds
    let x0 = (f32(clusterIdX) / f32(clusterWidth)) * 2.0 - 1.0;
    let x1 = (f32(clusterIdX + 1u) / f32(clusterWidth)) * 2.0 - 1.0;
    let y1 = 1.0 - (f32(clusterIdY) / f32(clusterHeight)) * 2.0;
    let y0 = 1.0 - (f32(clusterIdY + 1u) / f32(clusterHeight)) * 2.0;
    
    // Get rays for the 4 corners
    let r00 = rayFromNdcXY(vec2f(x0, y0));
    let r10 = rayFromNdcXY(vec2f(x1, y0));
    let r01 = rayFromNdcXY(vec2f(x0, y1));
    let r11 = rayFromNdcXY(vec2f(x1, y1));
    
    // Calculate frustum planes
    var nL = normalize(cross(r01, r00));
    var nR = normalize(cross(r10, r11));
    var nB = normalize(cross(r00, r10));
    var nT = normalize(cross(r11, r01));
    
    // Depth bounds
    let dz = zBounds(clusterIdZ);
    let dNearSlice = dz.x;
    let dFarSlice = dz.y;
    
    let nNear = vec3f(0.0, 0.0, 1.0);
    let dNear = dNearSlice;
    let nFar = vec3f(0.0, 0.0, -1.0);
    let dFar = -dFarSlice;
    
    let planes = array<Plane, 6>(
        Plane(nL, 0.0),
        Plane(nR, 0.0),
        Plane(nB, 0.0),
        Plane(nT, 0.0),
        Plane(nNear, dNear),
        Plane(nFar, dFar)
    );
    
    // Calculate cluster index in array
    let clusterIndex = clusterIdX + clusterIdY * clusterWidth + clusterIdZ * clusterWidth * clusterHeight;
    
    var numLights = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        if (numLights >= maxLightsPerCluster) {
            break;
        }
        
        let light = lightSet.lights[lightIdx];
        let lightPos = (camUniforms.viewMat * vec4f(light.pos, 1.0)).xyz;
        
        if (sphereIntersectsCluster(planes, lightPos, lightRadius)) {
            clusterSet.clusters[clusterIndex].lightIndices[numLights] = lightIdx;
            numLights++;
        }
    }
    
    clusterSet.clusters[clusterIndex].numLights = numLights;
}