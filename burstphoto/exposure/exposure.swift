/**
 * @file exposure.swift
 * @brief Swift implementation for exposure correction in burst photography
 *
 * This file provides the Swift interface to the Metal shaders that perform exposure correction
 * on burst images. It handles both non-linear (tone-mapped) and linear exposure correction,
 * and manages the calculation of maximum texture values for dynamic range adjustment.
 * 
 * The implementation works with bracketed bursts (multiple exposures of the same scene)
 * and can handle both uniform and non-uniform exposure settings across the burst sequence.
 */

/// Functions related to handling of exposure differences in bracketed bursts.
import Foundation
import MetalPerformanceShaders

// Metal pipeline states for the exposure correction shaders
// ISSUE: Pipeline states are created at global scope without error handling
// FIX: Consider moving creation into a function with proper error handling
// FIX: Add fallback mechanisms if pipeline creation fails
let correct_exposure_state          = create_pipeline(with_function_name: "correct_exposure",           and_label: "Correct Exposure (Non-linear)")
let correct_exposure_linear_state   = create_pipeline(with_function_name: "correct_exposure_linear",    and_label: "Correct Exposure (Linear)")
let max_x_state                     = create_pipeline(with_function_name: "max_x",                      and_label: "Maximum (X-Direction)")
let max_y_state                     = create_pipeline(with_function_name: "max_y",                      and_label: "Maximum (Y-Direction)")

/**
 * Apply tone mapping if the reference image is underexposed.
 * A curve is applied to lift the shadows and protect the highlights from burning.
 * By lifting the shadows they suffer less from quantization errors, this is especially beneficial as the bit-depth of the image decreases.
 *
 * The function supports multiple exposure correction modes:
 * - "Curve0EV": Non-linear correction targeting 0EV (original exposure)
 * - "Curve1EV": Non-linear correction targeting +1EV (1 stop brighter)
 * - "Linear2X": Linear correction with fixed 2x gain
 * - "LinearFullRange": Linear correction adjusted to use full dynamic range
 *
 * @param final_texture         The texture to apply exposure correction to
 * @param white_level           The maximum valid pixel value
 * @param black_level           Array of black level values for each image and color channel
 * @param exposure_control      The exposure correction mode to apply
 * @param exposure_bias         Array of exposure bias values for each image in the burst
 * @param uniform_exposure      Whether the burst was captured with uniform exposure settings
 * @param color_factors         Color correction factors for each image and channel
 * @param ref_idx               Index of the reference image in the burst
 * @param mosaic_pattern_width  Width of the Bayer or X-Trans mosaic pattern
 *
 * Inspired by https://www-old.cs.utah.edu/docs/techreports/2002/pdf/UUCS-02-001.pdf
 */
func correct_exposure(_ final_texture: MTLTexture, _ white_level: Int, _ black_level: [[Int]], _ exposure_control: String, _ exposure_bias: [Int], _ uniform_exposure: Bool, _ color_factors: [[Double]], _ ref_idx: Int, _ mosaic_pattern_width: Int) {
    
    // ISSUE: No validation for input parameters before using them
    // FIX: Add validation for all parameters, particularly:
    // - Check if ref_idx is within bounds of exposure_bias and color_factors arrays
    // - Validate that mosaic_pattern_width is a valid value (typically 2 for Bayer, 6 for X-Trans)
    // - Ensure that exposure_control is one of the expected values
              
    // only apply exposure correction if reference image has an exposure, which is lower than the target exposure
    if (exposure_control != "Off" && white_level != -1 && black_level[0][0] != -1) {
          
        var final_texture_blurred = blur(final_texture, with_pattern_width: 2, using_kernel_size: 2)
        // ISSUE: No error handling if blur function fails or returns nil
        // FIX: Add proper error handling for the blur function result
        
        let max_texture_buffer = texture_max(final_texture_blurred)
        // ISSUE: No validation that max_texture_buffer contains valid data
        // FIX: Check if max_texture_buffer contains at least one element before proceeding
        
        // find index of image with longest exposure to use the most robust black level value
        var exp_idx = 0
        for comp_idx in 0..<exposure_bias.count {
             // ISSUE: No bounds checking for array access
             // FIX: Verify that comp_idx and exp_idx are valid indices before accessing the array
             if (exposure_bias[comp_idx] > exposure_bias[exp_idx]) {
                exp_idx = comp_idx
            }
        }
        
        var black_levels_mean: [Double]

        // if exposure levels are uniform, calculate mean value of all exposures
        if uniform_exposure {
            // ISSUE: No verification that black_level[exp_idx] exists or has elements
            // FIX: Add a guard statement to check array bounds before accessing
            black_levels_mean = Array(repeating: 0.0, count: black_level[exp_idx].count)
            for img_idx in 0..<black_level.count {
                for channel_idx in 0..<black_levels_mean.count {
                    // ISSUE: Multiple nested array accesses without bounds checking
                    // FIX: Add bounds checking for all array accesses to prevent crashes
                    black_levels_mean[channel_idx] += Double(black_level[img_idx][channel_idx])
                }
            }
            
            let count = Double(black_level.count)
            for channel_idx in 0..<black_levels_mean.count {
                // ISSUE: Potential division by zero if black_level.count is 0
                // FIX: Add a check that count != 0 before division
                black_levels_mean[channel_idx] /= count
            }
        } else {
            // ISSUE: Force unwrapping map operation could fail if elements can't be converted
            // FIX: Use a safer approach with error handling
            black_levels_mean = Array(black_level[exp_idx].map{Double($0)})
        }
        
        // ISSUE: Force unwrapping min() could crash if array is empty
        // FIX: Add a nil check or provide a default value
        let black_level_min = black_levels_mean.min()!
        
        // ISSUE: Force unwrapping buffer creation without error handling
        // FIX: Use guard statement with proper error handling
        let black_levels_mean_buffer = device.makeBuffer(bytes: black_levels_mean.map{Float32($0)},
                                                         length: MemoryLayout<Float32>.size * black_levels_mean.count)!
        
        // ISSUE: No validation that buffer size matches what shader expects based on mosaic_pattern_width
        // FIX: Verify that black_levels_mean.count >= mosaic_pattern_width * mosaic_pattern_width
        
        // ISSUE: Force unwrapping command buffer creation
        // FIX: Add proper error handling
        let command_buffer = command_queue.makeCommandBuffer()!
        command_buffer.label = "Correct Exposure"
        
        // ISSUE: Force unwrapping command encoder creation
        // FIX: Add proper error handling
        let command_encoder = command_buffer.makeComputeCommandEncoder()!
        command_encoder.label = command_buffer.label
        let state: MTLComputePipelineState
       
        if (exposure_control=="Curve0EV" || exposure_control=="Curve1EV") {
            // Use non-linear tone-mapped exposure correction
            state = correct_exposure_state
            
            // ISSUE: Potential division by zero if black_levels_mean is empty
            // FIX: Add a check that black_levels_mean.count != 0 before division
            let black_level_mean = Double(black_levels_mean.reduce(0, +)) / Double(black_levels_mean.count)
            
            let color_factor_mean: Double
            let kernel_size: Int
            
            // ISSUE: No validation that ref_idx is within bounds of color_factors
            // FIX: Add bounds checking before accessing color_factors[ref_idx]
            
            // Determine color factor mean and kernel size based on mosaic pattern width
            if (mosaic_pattern_width == 6) {
                // For X-Trans sensors (6x6 pattern)
                color_factor_mean = (8.0*color_factors[ref_idx][0] + 20.0*color_factors[ref_idx][1] + 8.0*color_factors[ref_idx][2]) / 36.0
                kernel_size       = 2
            } else if (mosaic_pattern_width == 2) {
                // For Bayer sensors (2x2 pattern)
                color_factor_mean = (    color_factors[ref_idx][0] +  2.0*color_factors[ref_idx][1] +     color_factors[ref_idx][2]) /  4.0
                kernel_size       = 1
            } else {
                // ISSUE: No handling for invalid mosaic_pattern_width values
                // FIX: Add validation or logging for unexpected pattern widths
                
                // Default case
                color_factor_mean = (    color_factors[ref_idx][0] +      color_factors[ref_idx][1] +     color_factors[ref_idx][2]) /  3.0
                kernel_size       = 1
            }
            
            // the blurred texture serves as an approximation of local luminance
            final_texture_blurred = blur(final_texture, with_pattern_width: 1, using_kernel_size: kernel_size)
            
            // ISSUE: No error handling if blur returns nil or fails
            // FIX: Add proper error handling
            
            command_encoder.setTexture(final_texture_blurred, index: 0)
            command_encoder.setTexture(final_texture, index: 1)
            
            // ISSUE: No bounds check for exposure_bias[ref_idx]
            // FIX: Validate ref_idx is within bounds of exposure_bias array
            command_encoder.setBytes([Int32(exposure_bias[ref_idx])], length: MemoryLayout<Int32>.stride, index: 0)
            command_encoder.setBytes([Int32(exposure_control=="Curve0EV" ? 0 : 100)], length: MemoryLayout<Int32>.stride, index: 1)
            command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride,   index: 2)
            command_encoder.setBytes([Float32(white_level)],        length: MemoryLayout<Float32>.stride, index: 3)
            command_encoder.setBytes([Float32(color_factor_mean)],  length: MemoryLayout<Float32>.stride, index: 4)
            command_encoder.setBytes([Float32(black_level_mean)],   length: MemoryLayout<Float32>.stride, index: 5)
            command_encoder.setBytes([Float32(black_level_min)],    length: MemoryLayout<Float32>.stride, index: 6)
            
            command_encoder.setBuffer(black_levels_mean_buffer, offset: 0, index: 7)
            command_encoder.setBuffer(max_texture_buffer, offset: 0, index: 8)
            
            // ISSUE: The Metal shader has a division by zero risk:
            // float linear_gain = (white_level-black_level_min)/(max_texture_buffer[0]-black_level_min);
            // FIX: Add a validation check that max_texture_buffer value - black_level_min != 0
            // Either in Swift or modify the Metal shader to handle this case
        } else {
            // Use linear exposure correction
            state = correct_exposure_linear_state
            
            command_encoder.setTexture(final_texture, index: 0)
            
            command_encoder.setBytes([Float32(white_level)], length: MemoryLayout<Float32>.stride, index: 0)
            // Use specified linear gain (-1.0 for dynamic full range, 2.0 for fixed 2x gain)
            command_encoder.setBytes([Float32(exposure_control=="LinearFullRange" ? -1.0 : 2.0)], length: MemoryLayout<Float32>.stride, index: 1)
            command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 2)
            command_encoder.setBytes([Float32(black_level_min)],    length: MemoryLayout<Float32>.stride, index: 3)
            
            command_encoder.setBuffer(black_levels_mean_buffer, offset: 0, index: 4)
            command_encoder.setBuffer(max_texture_buffer, offset: 0, index: 5)
            
            // ISSUE: Similar division by zero risk in correct_exposure_linear shader:
            // float corr_factor = (white_level - black_level_min)/(max_texture_buffer[0] - black_level_min);
            // FIX: Add validation or modify the shader to handle division by zero
        }
        let threads_per_grid = MTLSize(width: final_texture.width, height: final_texture.height, depth: 1)
        let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
        command_encoder.setComputePipelineState(state)
        
        command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
        command_encoder.endEncoding()
        
        // ISSUE: No completion handler or error handling for command buffer
        // FIX: Add completion handler to detect and handle errors
        command_buffer.commit()
        
        // ISSUE: No waiting for completion, which could lead to resource conflicts
        // FIX: Consider adding a waiting mechanism for critical operations
    }
}


/**
 * Calculate the maximum value of the texture.
 * 
 * This function finds the global maximum value in a texture by:
 * 1. Finding the maximum value along the y-dimension for each x coordinate
 * 2. Finding the maximum of these maxima along the x-dimension
 *
 * The result is used for adjusting the exposure of the final image to prevent 
 * color channels from being clipped while maximizing dynamic range.
 *
 * @param in_texture The input texture to find the maximum value of
 * @return A Metal buffer containing the maximum value
 */
func texture_max(_ in_texture: MTLTexture) -> MTLBuffer {
    
    // create a 1d texture that will contain the maxima of the input texture along the x-axis
    let texture_descriptor = MTLTextureDescriptor()
    texture_descriptor.textureType = .type1D
    texture_descriptor.pixelFormat = in_texture.pixelFormat
    texture_descriptor.width = in_texture.width
    texture_descriptor.usage = [.shaderRead, .shaderWrite]
    texture_descriptor.storageMode = .private
    
    // ISSUE: Force unwrapping texture creation without error handling
    // FIX: Use guard statement with proper error handling
    let max_y = device.makeTexture(descriptor: texture_descriptor)!
    
    // ISSUE: Multiple force unwraps in a single line
    // FIX: Break into multiple statements with proper nil checking
    max_y.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Max y"
    
    // ISSUE: Misleading comment, this finds maximum values not averages
    // FIX: Update comment to correctly describe the operation
    // average the input texture along the y-axis
    
    // ISSUE: Force unwrapping command buffer creation
    // FIX: Add proper error handling
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Texture Max"
    
    // ISSUE: Force unwrapping command encoder creation
    // FIX: Add proper error handling
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = max_y_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: 1, depth: 1)
    let max_threads_per_thread_group = state.threadExecutionWidth
    let threads_per_thread_group = MTLSize(width: max_threads_per_thread_group, height: 1, depth: 1)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(max_y, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    
    // ISSUE: The Metal max_y shader has a concurrency issue:
    // No synchronization between threads when writing to out_texture
    // FIX: Either ensure threads don't overlap or modify the shader to use atomic operations
    
    // ISSUE: Misleading comment, this finds maximum not average
    // FIX: Update comment to correctly describe the operation
    // average the generated 1d texture along the x-axis
    let state2 = max_x_state
    command_encoder.setComputePipelineState(state2)
    
    // ISSUE: Force unwrapping buffer creation without error handling
    // FIX: Use guard statement with proper error handling
    let max_buffer = device.makeBuffer(length: MemoryLayout<Float32>.size, options: .storageModeShared)!
    
    // ISSUE: Multiple force unwraps in a single line
    // FIX: Break into multiple statements with proper nil checking
    max_buffer.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Max"
    
    command_encoder.setTexture(max_y, index: 0)
    command_encoder.setBuffer(max_buffer, offset: 0, index: 0)
    command_encoder.setBytes([Int32(in_texture.width)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    
    // ISSUE: The Metal max_x shader has a concurrency issue:
    // If multiple threads run with the same gid, they'll write to the same buffer location
    // FIX: Ensure the kernel is called with a single thread or modify it to use atomic operations
    
    command_encoder.endEncoding()
    
    // ISSUE: No completion handler or error handling for command buffer
    // FIX: Add completion handler to detect and handle errors
    command_buffer.commit()
    
    // ISSUE: No waiting for completion before returning buffer
    // FIX: Consider adding a waiting mechanism to ensure buffer contains valid data
    
    // ISSUE: Misleading comment, this returns maximum not average
    // FIX: Update comment to correctly describe the operation
    // return the average of all pixels in the input array
    return max_buffer
}
