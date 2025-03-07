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
              
    // only apply exposure correction if reference image has an exposure, which is lower than the target exposure
    if (exposure_control != "Off" && white_level != -1 && black_level[0][0] != -1) {
          
        var final_texture_blurred = blur(final_texture, with_pattern_width: 2, using_kernel_size: 2)
        let max_texture_buffer = texture_max(final_texture_blurred)
        
        // find index of image with longest exposure to use the most robust black level value
        var exp_idx = 0
        for comp_idx in 0..<exposure_bias.count {
             if (exposure_bias[comp_idx] > exposure_bias[exp_idx]) {
                exp_idx = comp_idx
            }
        }
        
        var black_levels_mean: [Double]

        // if exposure levels are uniform, calculate mean value of all exposures
        if uniform_exposure {
            black_levels_mean = Array(repeating: 0.0, count: black_level[exp_idx].count)
            for img_idx in 0..<black_level.count {
                for channel_idx in 0..<black_levels_mean.count {
                    black_levels_mean[channel_idx] += Double(black_level[img_idx][channel_idx])
                }
            }
            
            let count = Double(black_level.count)
            for channel_idx in 0..<black_levels_mean.count {
                black_levels_mean[channel_idx] /= count
            }
        } else {
            black_levels_mean = Array(black_level[exp_idx].map{Double($0)})
        }
        
        let black_level_min = black_levels_mean.min()!
        let black_levels_mean_buffer = device.makeBuffer(bytes: black_levels_mean.map{Float32($0)},
                                                         length: MemoryLayout<Float32>.size * black_levels_mean.count)!
        
        let command_buffer = command_queue.makeCommandBuffer()!
        command_buffer.label = "Correct Exposure"
        let command_encoder = command_buffer.makeComputeCommandEncoder()!
        command_encoder.label = command_buffer.label
        let state: MTLComputePipelineState
       
        if (exposure_control=="Curve0EV" || exposure_control=="Curve1EV") {
            // Use non-linear tone-mapped exposure correction
            state = correct_exposure_state
            
            let black_level_mean = Double(black_levels_mean.reduce(0, +)) / Double(black_levels_mean.count)
            let color_factor_mean: Double
            let kernel_size: Int
            
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
                // Default case
                color_factor_mean = (    color_factors[ref_idx][0] +      color_factors[ref_idx][1] +     color_factors[ref_idx][2]) /  3.0
                kernel_size       = 1
            }
            
            // the blurred texture serves as an approximation of local luminance
            final_texture_blurred = blur(final_texture, with_pattern_width: 1, using_kernel_size: kernel_size)
            
            command_encoder.setTexture(final_texture_blurred, index: 0)
            command_encoder.setTexture(final_texture, index: 1)
            
            command_encoder.setBytes([Int32(exposure_bias[ref_idx])], length: MemoryLayout<Int32>.stride, index: 0)
            command_encoder.setBytes([Int32(exposure_control=="Curve0EV" ? 0 : 100)], length: MemoryLayout<Int32>.stride, index: 1)
            command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride,   index: 2)
            command_encoder.setBytes([Float32(white_level)],        length: MemoryLayout<Float32>.stride, index: 3)
            command_encoder.setBytes([Float32(color_factor_mean)],  length: MemoryLayout<Float32>.stride, index: 4)
            command_encoder.setBytes([Float32(black_level_mean)],   length: MemoryLayout<Float32>.stride, index: 5)
            command_encoder.setBytes([Float32(black_level_min)],    length: MemoryLayout<Float32>.stride, index: 6)
            
            command_encoder.setBuffer(black_levels_mean_buffer, offset: 0, index: 7)
            command_encoder.setBuffer(max_texture_buffer, offset: 0, index: 8)
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
        }
        let threads_per_grid = MTLSize(width: final_texture.width, height: final_texture.height, depth: 1)
        let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
        command_encoder.setComputePipelineState(state)
        
        command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
        command_encoder.endEncoding()
        command_buffer.commit()
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
    let max_y = device.makeTexture(descriptor: texture_descriptor)!
    max_y.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Max y"
    
    // average the input texture along the y-axis
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Texture Max"
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
    
    // average the generated 1d texture along the x-axis
    let state2 = max_x_state
    command_encoder.setComputePipelineState(state2)
    let max_buffer = device.makeBuffer(length: MemoryLayout<Float32>.size, options: .storageModeShared)!
    max_buffer.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Max"
    command_encoder.setTexture(max_y, index: 0)
    command_encoder.setBuffer(max_buffer, offset: 0, index: 0)
    command_encoder.setBytes([Int32(in_texture.width)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    // return the average of all pixels in the input array
    return max_buffer
}
