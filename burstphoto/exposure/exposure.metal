#include <metal_stdlib>
#include "../misc/constants.h"

/**
 * @file exposure.metal
 * @brief Metal shaders for exposure correction in burst photography
 *
 * This file contains Metal shader implementations for various exposure correction algorithms
 * used in computational photography. It includes both tone-mapped and linear correction methods,
 * as well as utility functions for finding maximum pixel values in textures.
 * 
 * The exposure correction is a critical step in the burst photography pipeline,
 * particularly for improving underexposed images while maintaining highlight details.
 */
using namespace metal;

/**
 * Correction of underexposure with reinhard tone mapping operator.
 *
 * This kernel applies a sophisticated exposure correction using the Reinhard tone mapping
 * operator, which preserves highlight details while boosting shadow and midtone regions.
 * The implementation blends two different tone mapping curves based on the amount of
 * correction needed.
 * 
 * Inspired by https://www-old.cs.utah.edu/docs/techreports/2002/pdf/UUCS-02-001.pdf
 */
kernel void correct_exposure(texture2d<float, access::read> final_texture_blurred [[texture(0)]],
                             texture2d<float, access::read_write> final_texture [[texture(1)]],
                             constant int& exposure_bias         [[buffer(0)]],
                             constant int& target_exposure       [[buffer(1)]],
                             constant int& mosaic_pattern_width  [[buffer(2)]],
                             constant float& white_level         [[buffer(3)]],
                             constant float& color_factor_mean   [[buffer(4)]],
                             constant float& black_level_mean    [[buffer(5)]],
                             constant float& black_level_min     [[buffer(6)]],
                             constant float* black_levels_mean_buffer   [[buffer(7)]],
                             constant float* max_texture_buffer         [[buffer(8)]],
                             uint2 gid [[thread_position_in_grid]]) {
    // ISSUE: Buffer access safety
    // There's no validation that black_levels_mean_buffer has sufficient size 
    // (mosaic_pattern_width * mosaic_pattern_width).
    // FIX: Add validation in the Swift code before dispatching this shader to ensure 
    // buffer size is adequate for the given mosaic_pattern_width.
    float const black_level = black_levels_mean_buffer[mosaic_pattern_width*(gid.y % mosaic_pattern_width) + (gid.x % mosaic_pattern_width)];
       
    // calculate gain for intensity correction
    float const correction_stops = float((target_exposure-exposure_bias)/100.0f);
    
    // ISSUE: Division by zero risk
    // If max_texture_buffer[0] equals black_level_min, this will cause division by zero.
    // FIX: Add a check for near-zero denominator:
    // float denominator = max_texture_buffer[0] - black_level_min;
    // float linear_gain = (denominator > 1e-6f) ? ((white_level - black_level_min) / denominator) : 16.0f;
    float linear_gain = (white_level-black_level_min)/(max_texture_buffer[0]-black_level_min);
    linear_gain = clamp(0.9f*linear_gain, 1.0f, 16.0f);
    
    // the gain is limited to 4.0 stops and it is slightly damped for values > 2.0 stops
    float gain_stops = clamp(correction_stops-log2(linear_gain), 0.0f, 4.0f);
    
    // ISSUE: Performance consideration
    // These pow() operations are computationally expensive and performed for each pixel.
    // FIX: Consider precalculating gain0 and gain1 in Swift and passing them as constants.
    float const gain0 = pow(2.0f, gain_stops-0.05f*max(0.0f, gain_stops-1.5f));
    float const gain1 = pow(2.0f, gain_stops/1.4f);
    
    // extract pixel value
    float pixel_value = final_texture.read(gid).r;
    
    // subtract black level and rescale intensity to range from 0 to 1
    float const rescale_factor = (white_level - black_level_min);
    pixel_value = clamp((pixel_value-black_level)/rescale_factor, 0.0f, 1.0f);
   
    // use luminance estimated as the binomial weighted mean pixel value in a 3x3 window around the main pixel
    // apply correction with color factors to reduce clipping of the green color channel
    float luminance_before = final_texture_blurred.read(gid).r;
    
    // Good practice: This includes a clamp with a minimum value of 1e-12 to prevent division by zero
    luminance_before = clamp((luminance_before-black_level_mean)/(rescale_factor*color_factor_mean), 1e-12, 1.0f);
    
    // apply gains
    float luminance_after0 = linear_gain * gain0 * luminance_before;
    float luminance_after1 = linear_gain * gain1 * luminance_before;
    
    // ISSUE: Numerical stability risk
    // If gain0 is very small, this division could lead to numerical instability.
    // FIX: Add a safety check for the denominator:
    // float gain0_squared = max(gain0 * gain0, 1e-6f);
    // luminance_after0 = luminance_after0 * (1.0f + luminance_after0/gain0_squared) / (1.0f + luminance_after0);
    luminance_after0 = luminance_after0 * (1.0f+luminance_after0/(gain0*gain0)) / (1.0f+luminance_after0);
    
    // apply a modified tone mapping operator, which better protects the highlights
    // ISSUE: Similar numerical stability risk with gain1
    // FIX: Add similar protection for gain1 calculations
    float const luminance_max = gain1 * (0.4f+gain1/(gain1*gain1)) / (0.4f+gain1);
    luminance_after1 = luminance_after1 * (0.4f+luminance_after1/(gain1*gain1)) / ((0.4f+luminance_after1)*luminance_max);
    
    // calculate weight for blending the two tone mapping curves dependent on the magnitude of the gain
    float const weight = clamp(gain_stops*0.25f, 0.0f, 1.0f);
        
    // apply scaling derived from luminance values and return to original intensity scale
    // ISSUE: Potential division by very small number
    // FIX: Since luminance_before is already clamped to minimum 1e-12 above, this is likely safe,
    // but consider adding an explicit check if luminance_before could be modified elsewhere.
    pixel_value = pixel_value * ((1.0f-weight)*luminance_after0 + weight*luminance_after1)/luminance_before * rescale_factor + black_level;
    pixel_value = clamp(pixel_value, 0.0f, float(UINT16_MAX_VAL));

    final_texture.write(pixel_value, gid);
}


/**
 * Correction of underexposure with simple linear scaling
 *
 * This kernel applies a straightforward linear exposure correction by scaling pixel values 
 * based on the specified gain. Unlike the tone-mapped version, this approach is simpler
 * but may result in highlight clipping for significantly underexposed images.
 *
 * The function calculates a correction factor to bring pixel values close to the full
 * dynamic range, while accounting for black level variations across the sensor pattern.
 */
kernel void correct_exposure_linear(texture2d<float, access::read_write> final_texture [[texture(0)]],
                                    constant float& white_level [[buffer(0)]],
                                    constant float& linear_gain [[buffer(1)]],
                                    constant int& mosaic_pattern_width [[buffer(2)]],
                                    constant float& black_level_min     [[buffer(3)]],
                                    constant float* black_levels_mean_buffer [[buffer(4)]],
                                    constant float* max_texture_buffer       [[buffer(5)]],
                                    
                                    uint2 gid [[thread_position_in_grid]]) {
   
    // ISSUE: Buffer access safety
    // Same issue as in correct_exposure - no validation of buffer size.
    // FIX: Validate buffer size in Swift code before dispatching.
    float const black_level = black_levels_mean_buffer[mosaic_pattern_width*(gid.y % mosaic_pattern_width) + (gid.x % mosaic_pattern_width)];
    
    // ISSUE: Division by zero risk
    // If max_texture_buffer[0] equals black_level_min, this division will fail.
    // FIX: Add a safeguard against zero or near-zero denominator:
    // float denominator = max_texture_buffer[0] - black_level_min;
    // float corr_factor = (denominator > 1e-6f) ? ((white_level - black_level_min) / denominator) : 16.0f;
    float corr_factor = (white_level - black_level_min)/(max_texture_buffer[0] - black_level_min);
    corr_factor = clamp(0.9f*corr_factor, 1.0f, 16.0f);
    // use maximum of specified linear gain and correction factor
    corr_factor = max(linear_gain, corr_factor);
       
    // extract pixel value
    float pixel_value = final_texture.read(gid).r;
    
    // correct exposure
    pixel_value = max(0.0f, pixel_value-black_level)*corr_factor + black_level;
    pixel_value = clamp(pixel_value, 0.0f, float(UINT16_MAX_VAL));

    final_texture.write(pixel_value, gid);
}


/**
 * Finds the maximum value across the x-dimension of a 1D texture
 *
 * This utility kernel is used as part of determining the maximum pixel value
 * in an image texture. It scans across the x-dimension of the input texture
 * and outputs the maximum value found to the output buffer.
 *
 * @param in_texture  Input 1D texture to be scanned
 * @param out_buffer  Output buffer to store the maximum value
 * @param width       Width of the input texture to scan
 * @param gid         Thread position in grid
 */
kernel void max_x(texture1d<float, access::read> in_texture [[texture(0)]],
                  device float *out_buffer [[buffer(0)]],
                  constant int& width [[buffer(1)]],
                  uint gid [[thread_position_in_grid]]) {
    // ISSUE: Validation of width parameter
    // No validation that width matches the actual texture width.
    // FIX: Validate in Swift code or use in_texture.get_width() directly.
    float max_value = 0;
    
    for (int x = 0; x < width; x++) {
        max_value = max(max_value, in_texture.read(uint(x)).r);
    }

    // ISSUE: Concurrency risk
    // If multiple threads run with the same gid, they'll all write to the same out_buffer location.
    // FIX: Ensure this kernel is called with only a single thread, or implement atomic operations.
    out_buffer[0] = max_value;
}


/**
 * Finds the maximum value across the y-dimension of a 2D texture for each x coordinate
 *
 * This utility kernel scans vertically through a 2D texture to find the maximum value
 * for each column (x-coordinate). The results are stored in a 1D output texture where
 * each element represents the maximum value for the corresponding column.
 *
 * @param in_texture   Input 2D texture to be scanned
 * @param out_texture  Output 1D texture to store maximum values
 * @param gid          Thread position in grid (one thread per x-coordinate)
 */
kernel void max_y(texture2d<float, access::read> in_texture [[texture(0)]],
                  texture1d<float, access::write> out_texture [[texture(1)]],
                  uint gid [[thread_position_in_grid]]) {
    uint x = gid;
    
    // ISSUE: Bounds checking
    // No validation that x is within the valid range for the texture.
    // FIX: Validate in Swift that dispatch size matches texture width.
    
    int texture_height = in_texture.get_height();
    float max_value = 0;
    
    for (int y = 0; y < texture_height; y++) {
        max_value = max(max_value, in_texture.read(uint2(x, y)).r);
    }

    out_texture.write(max_value, x);
}
