# Slime mold simulation with Godot 4 and compute shaders

This is a small project inspired by the following blog posts:
- [Sage Jensen - Physarum](https://cargocollective.com/sagejenson/physarum)
- [Michael Fogleman - Physarum Simulation](https://www.michaelfogleman.com/projects/physarum/)

The algorithm is based on [Jeff Jones' paper](https://uwe-repository.worktribe.com/preview/980585/artl.2010.16.2.pdf) on simulating *Physarum* transport networks and is implemented in Godot 4. 

The simulation is agent-based, where each agent is a particle tracked in an *agent map* and rendered as a pixel. Each agent can sense its environment using three forward-facing sensors to assess the concentration of chemical stimuli in the *trail map*. Each agent will move in the direction of the highest concentration and deposit chemicals onto the *trail map* when moving. The *trail map* is then subject to a kernel-based diffusion (box blur) and decay.

Based on multiple tunable parameters such as the number of agents, sensor distance, sensor angle, turn angle, step size, deposit size, diffusion kernel size and decay factor, many types of complex patterning behavior can be simulated. The different types of emergent patterns are described in the paper.


## Files
| File | Description |
|-------------|------------------------------------|
| physarum.gd | Original implementation running on the CPU. Tried to achieve better performance by optimizing the diffusion step and by running four threads for the different processing steps, but real-time processing is not possible with images larger than 250 pixels with several thousand agents |
| physarum_gpu.gd | Implementation using parallel computing on the GPU by using compute shaders |
| physarum_ui.gd | Separate script for handling UI logic |
| physarum_compute_shader.glsl | GLSL compute shader implementing the actual algorithm |
| agent_map.gdshader | Custom shader for visualizing the agent map |
| trail_map.gdshader | Custom shader for visualizing the trail map |
| physarum.tscn | Godot scene |

## Issues
I'm pretty certain that my compute shader implementation is prone to race conditions on the GPU where one thread tries to write a pixel in the image buffer while another thread reads or writes the same pixel. This is because each thread is computing the movement of each agent (not for each pixel), and agents are allowed to occupy the same cell in space. This could probably be resolved by reimplementing the compute shader using barriers and atomic operations, but the imageAtomicAdd operation only supports 32 bit integer images, which I couldn't find any equivalent of in the [Godot Image class](https://docs.godotengine.org/en/latest/classes/class_image.html).