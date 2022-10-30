#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer AgentsX {
    float data[];
} agents_x;

layout(set = 0, binding = 1, std430) restrict buffer AgentsY {
    float data[];
} agents_y;

layout(set = 0, binding = 2, std430) restrict buffer AgentsRot {
    float data[];
} agents_rot;

layout(set = 0, binding = 3, std430) restrict buffer Params {
    float stage;
    float img_width;
    float img_height;
    float n_agents;
    float sensor_distance;
    float sensor_angle;
    float rotation_angle;
    float step_size;
    float deposit_size;
    float decay_factor;
    float kernel_size;
} params;

layout(r32f, binding = 4) uniform image2D agent_map;

layout(r32f, binding = 5) uniform image2D agent_map_out;

layout(r32f, binding = 6) uniform image2D trail_map;

layout(r32f, binding = 7) uniform image2D trail_map_out;

layout(set = 0, binding = 8, std430) restrict buffer Debug {
    float data[];
} debug;

float rand(float n) {
    return fract(sin(n) * 43758.5453123);
}

// The code we want to execute in each invocation
void main() {
    // Global invocation ID
    int gid = int(gl_GlobalInvocationID.x);

    float width = params.img_width;
    float height = params.img_height;

    // Motor sensory stage
    if (params.stage == 0) {

        if (gid >= params.n_agents) {
            return;
        }

        // Read agent buffers
        vec2 pos = vec2(agents_x.data[gid], agents_y.data[gid]);
        ivec2 pos_i = ivec2(int(pos.x), int(pos.y));
        float rot = agents_rot.data[gid];

        // Sensor positions
        vec2 sensor_front = vec2(
            mod(pos.x + params.sensor_distance * cos(rot), width), 
            mod(pos.y + params.sensor_distance * sin(rot), height)
        );
        vec2 sensor_left = vec2(
            mod(pos.x + params.sensor_distance * cos(rot + params.sensor_angle), width), 
            mod(pos.y + params.sensor_distance * sin(rot + params.sensor_angle), height)
        );
        vec2 sensor_right = vec2(
            mod(pos.x + params.sensor_distance * cos(rot - params.sensor_angle), width), 
            mod(pos.y + params.sensor_distance * sin(rot - params.sensor_angle), height)
        );

        ivec2 sensor_front_i = ivec2(int(sensor_front.x), int(sensor_front.y));
        ivec2 sensor_left_i = ivec2(int(sensor_left.x), int(sensor_left.y));
        ivec2 sensor_right_i = ivec2(int(sensor_right.x), int(sensor_right.y));

        // Read trail map values at sensor positions
        float sensor_front_v = imageLoad(trail_map, sensor_front_i).r;
        float sensor_left_v = imageLoad(trail_map, sensor_left_i).r;
        float sensor_right_v = imageLoad(trail_map, sensor_right_i).r;

        if ((sensor_front_v < sensor_left_v) && (sensor_front_v < sensor_right_v)) {
            if (rand(rot) < 0.5) {
                rot += params.rotation_angle;
            } else {
                rot -= params.rotation_angle;
            }  
        } else if (sensor_left_v < sensor_right_v) {
            rot -= params.rotation_angle;
        } else if (sensor_right_v < sensor_left_v) {
            rot += params.rotation_angle;
        }
        
        // New position
        vec2 pos_new = vec2(
            mod(pos.x + params.step_size * cos(rot), width), 
            mod(pos.y + params.step_size * sin(rot), height)
        );
        ivec2 pos_new_i = ivec2(int(pos_new.x), int(pos_new.y));

        // Read maps
        float agent_map_v = imageLoad(agent_map, pos_i).r;
        float agent_map_new_v = imageLoad(agent_map, pos_new_i).r;
        float trail_map_new_v = imageLoad(trail_map, pos_new_i).r;

        // Update maps
        //imageStore(agent_map_out, pos_i, vec4(agent_map_v - 1.0));
        imageStore(agent_map_out, pos_new_i, vec4(agent_map_new_v + 1.0));
        imageStore(trail_map_out, pos_new_i, vec4(trail_map_new_v + params.deposit_size));

        // Write to agent buffers
        agents_x.data[gid] = pos_new.x;
        agents_y.data[gid] = pos_new.y;
        agents_rot.data[gid] = rot;

    } 
    
    // Diffusion decay stage
    else if (params.stage == 1) {
        if (gid >= width * height) {
            return;
        }

        // Diffusion kernel (box filter)
        int y = int(gid / params.img_width);
        int x = int(mod(float(gid), width));
        int k = int(params.kernel_size / 2);
        float n = pow(params.kernel_size, 2);
        float v_sum = 0.0;
        for (int i = -k; i < k + 1; i++) {
            for (int j = -k; j < k + 1; j++) {
                ivec2 pos_k = ivec2(int(mod(float(x + i), width)), int(mod(float(y + j), height)));
                v_sum += imageLoad(trail_map, pos_k).r;
            }
        }
        float v = v_sum / n;
        imageStore(trail_map_out, ivec2(x, y), vec4(v * params.decay_factor));
    }
}