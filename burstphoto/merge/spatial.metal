/**
 * Spatial Domain Merging Kernels
 *
 * This file defines Metal compute kernels for spatial domain calculations used in the burst photography pipeline.
 * It includes:
 *   - color_difference: Computes the absolute difference between two textures over a mosaic block.
 *   - compute_merge_weight: Computes a merging weight based on the texture difference and noise estimation.
 *
 * All code and existing comments are preserved.
 */
#include <metal_stdlib>
using namespace metal;

/**
 * Kernel: color_difference
 *
 * Computes the sum of absolute differences between corresponding pixels of two input textures over a mosaic block.
 *
 * Parameters:
 *   - texture1: The first input texture (read access).
 *   - texture2: The second input texture (read access).
 *   - out_texture: The output texture where the computed sum of absolute differences is stored (write access).
 *   - mosaic_pattern_width: The width of the mosaic block provided as a constant.
 *   - gid: The thread position in the grid representing the mosaic block's index.
 */
kernel void color_difference(texture2d<float, access::read> texture1 [[texture(0)]],
                             texture2d<float, access::read> texture2 [[texture(1)]],
                             texture2d<float, access::write> out_texture [[texture(2)]],
                             constant int& mosaic_pattern_width [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    float total_diff = 0;
    int x0 = gid.x * mosaic_pattern_width;
    int y0 = gid.y * mosaic_pattern_width;
    
    for (int dx = 0; dx < mosaic_pattern_width; dx++) {
        for (int dy = 0; dy < mosaic_pattern_width; dy++) {
            int x = x0 + dx;
            int y = y0 + dy;
            float i1 = texture1.read(uint2(x, y)).r;
            float i2 = texture2.read(uint2(x, y)).r;
            total_diff += abs(i1 - i2);
        }
    }
    
    out_texture.write(total_diff, gid);
}

/**
 * Kernel: compute_merge_weight
 *
 * Computes the merge weight for the comparison frame based on the texture difference and noise statistics.
 *
 * Parameters:
 *   - texture_diff: The input texture containing the absolute difference computed by the color_difference kernel.
 *   - weight_texture: The output texture where the computed weight is written.
 *   - noise_sd_buffer: A constant buffer containing the estimated noise standard deviation.
 *   - robustness: A constant representing the robustness parameter for merging.
 *   - gid: The thread position in the grid.
 *
 * The kernel computes a weight value that decreases linearly from 1 to 0 as the difference increases relative to the noise level.
 */
kernel void compute_merge_weight(texture2d<float, access::read> texture_diff [[texture(0)]],
                                 texture2d<float, access::write> weight_texture [[texture(1)]],
                                 constant float* noise_sd_buffer [[buffer(0)]],
                                 constant float& robustness [[buffer(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    float noise_sd = noise_sd_buffer[0];
    
    // load texture difference
    float diff = texture_diff.read(gid).r;
    
    // compute the weight to assign to the comparison frame
    // weight == 0 means that the aligned image is ignored
    // weight == 1 means that the aligned image has full weight
    float weight;
    if (robustness == 0) {
        // robustness == 0 means that robust merge is turned off
        weight = 1;
    } else {
        // compare the difference to image noise
        // as diff increases, the weight of the aligned image will continuously decrease from 1.0 to 0.0
        // the two extreme cases are:
        // diff == 0                   --> aligned image will have weight 1.0
        // diff >= noise_sd/robustness --> aligned image will have weight 0.0
        float max_diff = noise_sd / robustness;
        weight =  1 - diff / max_diff;
        weight = clamp(weight, 0.0, 1.0);
    }
    
    // write weight
    weight_texture.write(weight, gid);
}
