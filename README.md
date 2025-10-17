WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Lijun Qu
  * [LinkedIn](https://www.linkedin.com/in/lijun-qu-398375251/), [personal website](www.lijunqu.com).
* Tested on: Windows 11, i7-14700HX (2.10 GHz) 32GB, Nvidia GeForce RTX 4060 Laptop
### Live Demo

https://lijunqu.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/

### Demo Video/GIF

<video width="640" controls>
  <source src="image/video.mp4" type="video/mp4">
</video>

---

## Overview

In this project, I implemented **Forward+** and **Clustered Deferred Shading** in WebGPU.  
Both approaches perform light culling in a 3D view-space grid to reduce per-fragment lighting cost.  
The project builds upon a Naive Forward Renderer baseline and adds clustering, compute shaders, and efficient light management.



## ✨ Features

### Naive Forward Rendering
**Overview:**  
The simplest baseline implementation — every fragment is shaded against **all lights** in the scene.

**What It Does:**  
1. For each pixel, loops through *every light* and accumulates illumination.  
2. No spatial partitioning or culling — all lights affect all pixels.  
3. Directly performs lighting computations in the fragment shader.  

**Pros:**  
- Easiest to implement.  
- Works with transparency and all material types.  

**Cons:**  
- Extremely slow when number of lights increases (O(n × m), where *n = pixels*, *m = lights*).  
- Every pixel computes lighting for lights that may not affect it.  

**Use Case:**  
Used as a **baseline** to measure improvements from Forward+ and Clustered Deferred.

---

### Forward+ Rendering
**Overview:**  
An optimization of traditional Forward Rendering using **tile-based light culling** on the GPU.  
Instead of shading all lights per pixel, Forward+ computes which lights influence each **screen-space tile or 3D cluster**, then only shades with those lights.

**What It Does:**  
1. A **compute shader** divides the view frustum into clusters (a 3D grid).  
2. Each cluster stores a list of nearby lights (light indices).  
3. In the **render pass**, each fragment identifies which cluster it belongs to and shades only the lights in that cluster.  

**Pros:**  
- Major performance improvement for large light counts (> 100).  
- Avoids redundant light computations for pixels far from most lights.  
- Still supports transparency and forward materials.  

**Cons:**  
- Each fragment still performs lighting computations, though on fewer lights.  
- Requires additional GPU memory for cluster light lists.  

**Use Case:**  
Efficient for real-time engines with **dynamic lights** and **transparent materials**.  
Common in modern game engines (e.g., Unreal Engine 4’s Forward+ pipeline).

---

### Clustered Deferred Rendering
**Overview:**  
A **deferred shading** variant of Forward+, combining clustered light culling with a two-pass G-Buffer pipeline.  
Lighting is computed in screen space, **decoupled from geometry complexity**.

**What It Does:**  
1. **G-Buffer Pass** — Renders geometry once and stores attributes (position, normal, albedo) in screen-space textures.  
2. **Clustering Compute Pass** — Groups lights into clusters, same as Forward+.  
3. **Deferred Lighting Pass** — For each pixel, reads G-Buffer data and shades only the lights affecting that cluster.  

**Pros:**  
- Scales well with thousands of lights.  
- Geometry cost is mostly independent of lighting complexity.  
- Enables screen-space post-processing (e.g., SSAO, Bloom).  

**Cons:**  
- Can’t handle transparency directly.  
- Higher memory bandwidth due to multiple G-Buffer textures.  

**Use Case:**  
Ideal for dense lighting scenes (e.g., Sponza or indoor environments with many overlapping lights).

---



### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
