/**
 * Swift Metal Wrapper for Texture Processing in Burst Photography
 *
 * This file provides a Swift interface to the Metal compute shaders defined in texture.metal.
 * It handles various texture operations needed for burst photography processing, including:
 * - Texture merging and blending from multiple frames
 * - Exposure correction and highlight handling
 * - Format conversions (Bayer/RGBA, float/uint16)
 * - Blurring, cropping, and scaling operations
 * - Hot pixel detection and correction
 * - Statistical operations like summing and normalization
 *
 * The implementation supports both Bayer pattern (common in most digital cameras) 
 * and X-Trans pattern (used in Fujifilm cameras) sensor arrangements.
 */

import Foundation
import MetalPerformanceShaders

// Pipeline state objects for each Metal kernel function
// These are created once and reused for efficiency
let add_texture_state                   = create_pipeline(with_function_name: "add_texture",                    and_label: "Add Texture")
let add_texture_exposure_state          = create_pipeline(with_function_name: "add_texture_exposure",           and_label: "Add Texture (Exposure)")
let add_texture_highlights_state        = create_pipeline(with_function_name: "add_texture_highlights",         and_label: "Add Texture (Highlights)")
let add_texture_uint16_state            = create_pipeline(with_function_name: "add_texture_uint16",             and_label: "Add Texture (UInt16")
let add_texture_weighted_state          = create_pipeline(with_function_name: "add_texture_weighted",           and_label: "Add Texture (Weighted)")
let blur_mosaic_texture_state           = create_pipeline(with_function_name: "blur_mosaic_texture",            and_label: "Blur Mosaic Texture")
let calculate_weight_highlights_state   = create_pipeline(with_function_name: "calculate_weight_highlights",    and_label: "Calculate Highlight Weights")
let convert_float_to_uint16_state       = create_pipeline(with_function_name: "convert_float_to_uint16",        and_label: "Convert Float to UInt16")
let convert_to_bayer_state              = create_pipeline(with_function_name: "convert_to_bayer",               and_label: "Convert RGBA to Bayer")
let convert_to_rgba_state               = create_pipeline(with_function_name: "convert_to_rgba",                and_label: "Covert Bayer to RGBA")
let copy_texture_state                  = create_pipeline(with_function_name: "copy_texture",                   and_label: "Copy Texture")
let crop_texture_state                  = create_pipeline(with_function_name: "crop_texture",                   and_label: "Crop Texture")
let divide_buffer_state                 = create_pipeline(with_function_name: "divide_buffer",                  and_label: "Divide Buffer Per Sub Pixel")
let sum_divide_buffer_state             = create_pipeline(with_function_name: "sum_divide_buffer",              and_label: "Sum and Divide Buffer Total")
let fill_with_zeros_state               = create_pipeline(with_function_name: "fill_with_zeros",                and_label: "Fill With Zeros")
let find_hotpixels_bayer_state          = create_pipeline(with_function_name: "find_hotpixels_bayer",           and_label: "Find Hotpixels (Bayer)")
let find_hotpixels_xtrans_state         = create_pipeline(with_function_name: "find_hotpixels_xtrans",          and_label: "Find Hotpixels (XTrans)")
let normalize_texture_state             = create_pipeline(with_function_name: "normalize_texture",              and_label: "Normalize Texture")
let prepare_texture_bayer_state         = create_pipeline(with_function_name: "prepare_texture_bayer",          and_label: "Prepare Texture (Bayer)")
let sum_rect_columns_float_state        = create_pipeline(with_function_name: "sum_rect_columns_float",         and_label: "Sum Along Columns Inside A Rect (Float)")
let sum_rect_columns_uint_state         = create_pipeline(with_function_name: "sum_rect_columns_uint",          and_label: "Sum Along Columns Inside A Rect (UInt)")
let sum_row_state                       = create_pipeline(with_function_name: "sum_row",                        and_label: "Sum Along Rows")
let upsample_bilinear_float_state       = create_pipeline(with_function_name: "upsample_bilinear_float",        and_label: "Upsample (Bilinear) (Float)")
let upsample_nearest_int_state          = create_pipeline(with_function_name: "upsample_nearest_int",           and_label: "Upsample (Nearest Neighbour) (Int)")

/**
 * Enumeration of upsampling methods available for texture scaling
 */
enum UpsampleType {
    case Bilinear            // Higher quality interpolation suitable for photographic content
    case NearestNeighbour    // Faster, simpler scaling suitable for masks or integer data
}

/**
 * Adds pixel values from one texture to another with normalization.
 *
 * This function divides each pixel value from the input texture by the total number
 * of textures being merged before adding it to the output texture. This creates an
 * average or blend of multiple textures.
 *
 * Parameters:
 *   - in_texture: The source texture to read values from
 *   - out_texture: The destination texture to add values to
 *   - n_textures: Number of textures being merged, used for normalization
 */
func add_texture(_ in_texture: MTLTexture, _ out_texture: MTLTexture, _ n_textures: Int) {
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Add Texture"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = (in_texture.pixelFormat == .r16Uint ? add_texture_uint16_state : add_texture_state)
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.setBytes([Float32(n_textures)], length: MemoryLayout<Float32>.stride, index: 0)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
}


/// This function is intended for averaging of frames with uniform exposure or for adding the darkest frame in an exposure bracketed burst: add frame and apply extrapolation of green channels for very bright pixels. All pixels in the frame get the same global weight of 1. Therefore a scalar value for normalization storing the sum of accumulated frames is sufficient.
func add_texture_highlights(_ in_texture: MTLTexture, _ out_texture: MTLTexture, _ white_level: Int, _ black_level: [Int], _ color_factors: [Double]) {
    
    let black_level_mean = Double(black_level.reduce(0, +)) / Double(black_level.count)

    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Add Texture (Highlights)"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = add_texture_highlights_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width/2, height: in_texture.height/2, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.setBytes([Float32(white_level)], length: MemoryLayout<Float32>.stride, index: 0)
    command_encoder.setBytes([Float32(black_level_mean)], length: MemoryLayout<Float32>.stride, index: 1)
    command_encoder.setBytes([Float32(color_factors[0]/color_factors[1])], length: MemoryLayout<Float32>.stride, index: 2)
    command_encoder.setBytes([Float32(color_factors[2]/color_factors[1])], length: MemoryLayout<Float32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
}


/// This function is intended for adding up all frames of a bracketed expsoure besides the darkest frame: add frame with exposure-weighting and exclude regions with clipped highlights. Due to the exposure weighting, frames typically have weights > 1. Inside the function, pixel weights are further adapted based on their brightness: in the shadows, weights are linear with exposure. In the midtones/highlights, this converges towards weights being linear with the square-root of exposure. For clipped highlight pixels, the weight becomes zero. As the weights are pixel-specific, a texture for normalization is employed storing the sum of pixel-specific weights.
func add_texture_exposure(_ in_texture: MTLTexture, _ out_texture: MTLTexture, _ norm_texture: MTLTexture, _ exposure_bias: Int, _ white_level: Int, _ black_level: [Int], _ color_factors: [Double], _ mosaic_pattern_width: Int) {
    
    let black_level_mean = Double(black_level.reduce(0, +)) / Double(black_level.count)
    
    let color_factor_mean: Double
    let kernel_size: Int
    if (mosaic_pattern_width == 6) {
        color_factor_mean = (8.0*color_factors[0] + 20.0*color_factors[1] + 8.0*color_factors[2]) / 36.0
        kernel_size       = 2
    } else if (mosaic_pattern_width == 2) {
        color_factor_mean = (    color_factors[0] +  2.0*color_factors[1] +     color_factors[2]) /  4.0
        kernel_size       = 1
    } else {
        color_factor_mean = (    color_factors[0] +      color_factors[1] +     color_factors[2]) /  3.0
        kernel_size       = 1
    }
    
    // the blurred texture serves as an approximation of local luminance
    let in_texture_blurred = blur(in_texture, with_pattern_width: 1, using_kernel_size: kernel_size)
    // blurring of the weight texture ensures a smooth blending of frames, especially at regions where clipped highlight pixels are excluded
    let weight_highlights_texture_blurred = calculate_weight_highlights(in_texture, exposure_bias, white_level, black_level_mean)
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Add Texture (Exposure)"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = add_texture_exposure_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(in_texture_blurred, index: 1)
    command_encoder.setTexture(weight_highlights_texture_blurred, index: 2)
    command_encoder.setTexture(out_texture, index: 3)
    command_encoder.setTexture(norm_texture, index: 4)
    command_encoder.setBytes([Int32(exposure_bias)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Float32(white_level)], length: MemoryLayout<Float32>.stride, index: 1)
    command_encoder.setBytes([Float32(black_level_mean)], length: MemoryLayout<Float32>.stride, index: 2)
    command_encoder.setBytes([Float32(color_factor_mean)], length: MemoryLayout<Float32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
}


/// Calculate the weighted average of `texture1` and `texture2` using the spatially varying weights specified in `weight_texture`.
/// Larger weights bias towards `texture1`.
func add_texture_weighted(_ texture1: MTLTexture, _ texture2: MTLTexture, _ weight_texture: MTLTexture) -> MTLTexture {
    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture1.pixelFormat, width: texture1.width, height: texture1.height, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = texture1.label
    
    // add textures
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Add Texture (Weighted)"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = add_texture_weighted_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: texture1.width, height: texture1.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(texture1, index: 0)
    command_encoder.setTexture(texture2, index: 1)
    command_encoder.setTexture(weight_texture, index: 2)
    command_encoder.setTexture(out_texture, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return out_texture
}


/**
 * Applies a 2D separable blur to a texture.
 *
 * This function performs a two-pass blur operation - first horizontally, then vertically.
 * The blur uses a binomial filter kernel that approximates a Gaussian blur.
 *
 * Parameters:
 *   - in_texture: The texture to blur
 *   - mosaic_pattern_width: Width of the mosaic pattern (2 for Bayer, 6 for X-Trans)
 *   - kernel_size: Size of the blur kernel, determining blur strength
 *
 * Returns: A new blurred texture
 */
func blur(_ in_texture: MTLTexture, with_pattern_width mosaic_pattern_width: Int, using_kernel_size kernel_size: Int) -> MTLTexture {
    let blurred_in_x_texture  = texture_like(in_texture)
    let blurred_in_xy_texture = texture_like(in_texture)
    blurred_in_x_texture.label  = "\(in_texture.label!.components(separatedBy: ":")[0]): blurred in x by \(kernel_size)"
    blurred_in_xy_texture.label = "\(in_texture.label!.components(separatedBy: ":")[0]): blurred by \(kernel_size)"
    
    let kernel_size_mapped = (kernel_size == 16) ? 16 : max(0, min(8, kernel_size))
    
    // Blur the texture along the x-axis
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Blur"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = blur_mosaic_texture_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(blurred_in_x_texture, index: 1)
    command_encoder.setBytes([Int32(kernel_size_mapped)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(in_texture.width)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(0)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    
    // Blur along the y-axis
    command_encoder.setTexture(blurred_in_x_texture, index: 0)
    command_encoder.setTexture(blurred_in_xy_texture, index: 1)
    command_encoder.setBytes([Int32(in_texture.height)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(1)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return blurred_in_xy_texture
}


/**
 * Calculates black level values for each subpixel position in the mosaic pattern.
 *
 * This function analyzes masked areas in the image that should be black (like optical
 * black regions in camera sensors) to determine the baseline black level for each color
 * channel in the mosaic pattern. These values are essential for proper white balance
 * and exposure correction.
 *
 * Parameters:
 *   - texture: The input texture to analyze
 *   - masked_areas: Pointer to array of rectangles defining black regions (format: [top, left, bottom, right, ...])
 *   - mosaic_pattern_width: Width of the mosaic pattern (2 for Bayer, 6 for X-Trans)
 *
 * Returns: Array of black level values for each subpixel position in the mosaic pattern
 */
func calculate_black_levels(for texture: MTLTexture, from_masked_areas masked_areas: UnsafeMutablePointer<Int32>, mosaic_pattern_width: Int) -> [Int] {
    var num_pixels: Float = 0.0
    var command_buffers: [MTLCommandBuffer] = []
    var black_level_buffers: [MTLBuffer] = []
    var black_level_from_masked_area = [Float](repeating: 0.0, count: Int(mosaic_pattern_width*mosaic_pattern_width))
    
    for i in 0..<4 {
        // Up to 4 masked areas exist, as soon as we reach -1 we know there are no more masked areas after.
        if masked_areas[4*i] == -1 { break }
        let top     = masked_areas[4*i + 0]
        let left    = masked_areas[4*i + 1]
        let bottom  = masked_areas[4*i + 2]
        let right   = masked_areas[4*i + 3]
        
        num_pixels += Float((bottom - top) * (right - left))
        
        // Create output texture from the y-axis blurring
        let texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: Int(right - left), height: mosaic_pattern_width, mipmapped: false)
        texture_descriptor.usage = [.shaderRead, .shaderWrite]
        texture_descriptor.storageMode = .private
        let summed_y = device.makeTexture(descriptor: texture_descriptor)!
        summed_y.label = "\(texture.label!.components(separatedBy: ":")[0]): Summed in y for black level"
        
        // Sum along columns
        let command_buffer = command_queue.makeCommandBuffer()!
        command_buffer.label = "Black Levels \(i) for \(String(describing: texture.label!))"
        let command_encoder = command_buffer.makeComputeCommandEncoder()!
        command_encoder.label = command_buffer.label
        command_encoder.setComputePipelineState(sum_rect_columns_uint_state)
        let thread_groups_per_grid = MTLSize(width: summed_y.width, height: summed_y.height, depth: 1)
        let threads_per_thread_group = get_threads_per_thread_group(sum_rect_columns_uint_state, thread_groups_per_grid)
        
        command_encoder.setTexture(texture, index: 0)
        command_encoder.setTexture(summed_y, index: 1)
        command_encoder.setBytes([top], length: MemoryLayout<Int32>.stride, index: 1)
        command_encoder.setBytes([left], length: MemoryLayout<Int32>.stride, index: 2)
        command_encoder.setBytes([bottom], length: MemoryLayout<Int32>.stride, index: 3)
        command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 4)
        command_encoder.dispatchThreads(thread_groups_per_grid, threadsPerThreadgroup: threads_per_thread_group)
        command_encoder.popDebugGroup()
        
        // Sum along the row
        let sum_buffer = device.makeBuffer(length: (mosaic_pattern_width*mosaic_pattern_width)*MemoryLayout<Float32>.size,
                                           options: .storageModeShared)!
        sum_buffer.label = "\(texture.label!.components(separatedBy: ":")[0]): Black Levels from masked area \(i)"
        command_encoder.setComputePipelineState(sum_row_state)
        command_encoder.setTexture(summed_y, index: 0)
        command_encoder.setBuffer(sum_buffer, offset: 0, index: 0)
        command_encoder.setBytes([Int32(summed_y.width)], length: MemoryLayout<Int32>.stride, index: 1)
        command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 2)
        let threads_per_grid_x = MTLSize(width: mosaic_pattern_width, height: mosaic_pattern_width, depth: 1)
        command_encoder.dispatchThreads(threads_per_grid_x, threadsPerThreadgroup: threads_per_thread_group)
        command_encoder.endEncoding()
        
        command_buffers.append(command_buffer)
        black_level_buffers.append(sum_buffer)
    }
    
    if num_pixels > 0 {
        // E.g. if a masked area is 2x2 and we're using a bayer image (2x2 RGGB mosaic pattern), while there are 4 pixels in the masked area, each subpixel (R, G, G, or B) actually only has 1/4 (1 / mosaic_width^2) that number of pixels.
         num_pixels /= Float(mosaic_pattern_width*mosaic_pattern_width)
        
        for i in 0..<command_buffers.count {
            command_buffers[i].waitUntilCompleted()
            let _this_black_levels = black_level_buffers[i].contents().bindMemory(to: Float32.self, capacity: 1)
            for j in 0..<black_level_from_masked_area.count {
                black_level_from_masked_area[j] += _this_black_levels[j] / num_pixels
            }
        }
    }
    
    return black_level_from_masked_area.map { Int(round($0)) }
}


/**
 * Calculates highlight weights for exposure merging.
 *
 * This function generates a weight map for handling highlights when merging exposures.
 * Pixels that are near or at the saturation point (white level) receive lower weights
 * to prevent clipped highlights in the final merged image.
 *
 * Parameters:
 *   - in_texture: The input texture to analyze
 *   - exposure_bias: Exposure bias in EV stops (powers of 2)
 *   - white_level: Maximum pixel value before clipping
 *   - black_level_mean: Average black level across all channels
 *
 * Returns: A texture containing weights for each pixel
 */
func calculate_weight_highlights(_ in_texture: MTLTexture, _ exposure_bias: Int, _ white_level: Int, _ black_level_mean: Double) -> MTLTexture {
    
    let weight_highlights_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: in_texture.width, height: in_texture.height, mipmapped: false)
    weight_highlights_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    weight_highlights_texture_descriptor.storageMode = .private
    let weight_highlights_texture = device.makeTexture(descriptor: weight_highlights_texture_descriptor)!
    weight_highlights_texture.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Weight Highlights"
  
    let kernel_size = 4
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Calculate highlights weight"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = calculate_weight_highlights_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(weight_highlights_texture, index: 1)
    command_encoder.setBytes([Int32(exposure_bias)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Float32(white_level)], length: MemoryLayout<Float32>.stride, index: 1)
    command_encoder.setBytes([Float32(black_level_mean)], length: MemoryLayout<Float32>.stride, index: 2)
    command_encoder.setBytes([Int32(kernel_size)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    let weight_highlights_texture_blurred = blur(weight_highlights_texture, with_pattern_width: 1, using_kernel_size: 5)
    
    return weight_highlights_texture_blurred
}


/**
 * Converts floating-point pixel values to 16-bit unsigned integers for DNG storage.
 *
 * This function applies black level correction and scaling to convert
 * normalized floating-point pixel values back to the 16-bit integer range
 * required for DNG file storage.
 *
 * Parameters:
 *   - in_texture: Input floating-point texture
 *   - white_level: Maximum value (saturation point) in the output
 *   - black_level: Array of black level values for each subpixel position
 *   - factor_16bit: Scaling factor for 16-bit conversion 
 *   - mosaic_pattern_width: Width of the mosaic pattern (2 for Bayer, 6 for X-Trans)
 *
 * Returns: A new texture with 16-bit unsigned integer format
 */
func convert_float_to_uint16(_ in_texture: MTLTexture, _ white_level: Int, _ black_level: [Int], _ factor_16bit: Int, _ mosaic_pattern_width: Int) -> MTLTexture {
    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Uint, width: in_texture.width, height: in_texture.height, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = "\(in_texture.label!.components(separatedBy: ":")[0]): UInt16"
    
    let black_levels_buffer = device.makeBuffer(bytes: black_level.map{Int32($0)},
                                                length: MemoryLayout<Int32>.size * black_level.count)!
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Float to UInt"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = convert_float_to_uint16_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: out_texture.width, height: out_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.setBytes([Int32(white_level)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(factor_16bit)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBuffer(black_levels_buffer, offset: 0, index: 3)
    
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()

    return out_texture
}


/**
 * Converts a Bayer pattern texture to RGBA format.
 *
 * This function packs a 2x2 Bayer quad (RGGB) into a single RGBA pixel,
 * reducing the spatial resolution but preserving all color channel data.
 * The function also applies cropping around the edges of the image.
 *
 * Parameters:
 *   - in_texture: Input Bayer pattern texture
 *   - crop_x: Number of pixels to crop from left/right edges
 *   - crop_y: Number of pixels to crop from top/bottom edges
 *
 * Returns: A new RGBA texture with half the width and height
 */
func convert_to_rgba(_ in_texture: MTLTexture, _ crop_x: Int, _ crop_y: Int) -> MTLTexture {
    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: (in_texture.pixelFormat == .r16Float ? .rgba16Float : .rgba32Float), width: (in_texture.width-2*crop_x)/2, height: (in_texture.height-2*crop_y)/2, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Bayer to RGBA"
        
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Bayer To RGBA"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = convert_to_rgba_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: out_texture.width, height: out_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.setBytes([Int32(crop_x)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(crop_y)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return out_texture
}


/**
 * Converts an RGBA texture back to Bayer pattern format.
 *
 * This function unpacks each RGBA pixel into a 2x2 Bayer quad (RGGB),
 * increasing the spatial resolution to match the original Bayer pattern.
 * This is essentially the inverse operation of convert_to_rgba.
 *
 * Parameters:
 *   - in_texture: Input RGBA texture
 *
 * Returns: A new Bayer pattern texture with twice the width and height
 */
func convert_to_bayer(_ in_texture: MTLTexture) -> MTLTexture {
    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: (in_texture.pixelFormat == .rgba16Float ? .r16Float : .r32Float), width: in_texture.width*2, height: in_texture.height*2, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = "\(in_texture.label!.components(separatedBy: ":")[0]): RGBA to Bayer"
        
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "RGBA To Bayer"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = convert_to_bayer_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: out_texture.width, height: out_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return out_texture
}


/**
 * Creates a deep copy of a texture.
 *
 * This function makes an exact copy of all pixel data from the input texture
 * to a newly created texture with identical dimensions and format.
 *
 * Parameters:
 *   - in_texture: The source texture to copy
 *
 * Returns: A new texture with identical contents
 */
func copy_texture(_ in_texture: MTLTexture) -> MTLTexture {
    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: in_texture.pixelFormat, width: in_texture.width, height: in_texture.height, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = in_texture.label
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Copy Texture"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = copy_texture_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return out_texture
}


/**
 * Crops a texture by removing padding from the edges.
 *
 * This function creates a new texture that is smaller than the input texture
 * by removing specified amounts of padding from each edge.
 *
 * Parameters:
 *   - in_texture: The texture to crop
 *   - pad_left: Number of pixels to remove from left edge
 *   - pad_right: Number of pixels to remove from right edge
 *   - pad_top: Number of pixels to remove from top edge
 *   - pad_bottom: Number of pixels to remove from bottom edge
 *
 * Returns: A new texture with dimensions reduced by the padding amounts
 */
func crop_texture(_ in_texture: MTLTexture, _ pad_left: Int, _ pad_right: Int, _ pad_top: Int, _ pad_bottom: Int) -> MTLTexture {
    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: in_texture.pixelFormat, width: in_texture.width-pad_left-pad_right, height: in_texture.height-pad_top-pad_bottom, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = in_texture.label
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Crop Texture"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = crop_texture_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: out_texture.width, height: out_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(out_texture, index: 1)
    command_encoder.setBytes([Int32(pad_left)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(pad_top)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()

    return out_texture
}


/**
 * Initializes a texture by filling it with zeros.
 *
 * This function sets all pixel values in the texture to zero,
 * which is typically used to prepare a texture for accumulation operations.
 *
 * Parameters:
 *   - texture: The texture to fill with zeros
 */
func fill_with_zeros(_ texture: MTLTexture) {
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Fill with Zeros"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = fill_with_zeros_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: texture.width, height: texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(texture, index: 0)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
}


/**
 * Detects and corrects hot pixels in sensor data.
 *
 * Hot pixels are defective sensor pixels that consistently appear brighter than
 * their surroundings across multiple frames. This function identifies such pixels
 * by analyzing multiple frames and creates a weight map for correcting them during
 * image processing.
 *
 * Parameters:
 *   - textures: Array of input textures from a burst sequence
 *   - hotpixel_weight_texture: Output texture for storing hot pixel correction weights
 *   - black_level: Array of black level values for each texture and color channel
 *   - ISO_exposure_time: Array of ISO*exposure_time values for determining correction strength
 *   - noise_reduction: Noise reduction strength parameter
 *   - mosaic_pattern_width: Width of the mosaic pattern (2 for Bayer, 6 for X-Trans)
 */
func find_hotpixels(_ textures: [MTLTexture], _ hotpixel_weight_texture: MTLTexture, _ black_level: [[Int]], _ ISO_exposure_time: [Double], _ noise_reduction: Double, _ mosaic_pattern_width: Int) {
    
    if mosaic_pattern_width != 2 && mosaic_pattern_width != 6 {
        return
    }
    
    // calculate hot pixel correction strength based on ISO value, exposure time and number of frames in the burst
    var correction_strength: Double
    if ISO_exposure_time[0] > 0.0 {
        correction_strength = ISO_exposure_time.reduce(0, +)
        
        correction_strength = ( // TODO: This needs an explanation
            min(80,
                max(5.0,
                    correction_strength/sqrt(Double(textures.count)) * (noise_reduction==23.0 ? 0.25 : 1.00)
                )
            ) - 5.0
        ) / 75.0
    } else {
        correction_strength = 1.0
    }
    
    // only apply hot pixel correction if correction strength is larger than 0.001
    if correction_strength > 0.001 {
    
        // generate simple average of all textures
        let average_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: textures[0].width, height: textures[0].height, mipmapped: false)
        average_texture_descriptor.usage = [.shaderRead, .shaderWrite]
        average_texture_descriptor.storageMode = .private
        let average_texture = device.makeTexture(descriptor: average_texture_descriptor)!
        average_texture.label = "Average of all texture"
        fill_with_zeros(average_texture)
        
        // iterate over all images
        for comp_idx in 0..<textures.count {
            add_texture(textures[comp_idx], average_texture, textures.count)
        }
        
        // calculate mean value specific for each color channel
        let mean_texture_buffer = texture_mean(average_texture,
                                               per_sub_pixel: true,
                                               mosaic_pattern_width: mosaic_pattern_width)
        
        // standard parameters if black level is not available / available
        let hot_pixel_multiplicator = (black_level[0][0] == -1) ? 2.0 : 1.0
        var hot_pixel_threshold     = (black_level[0][0] == -1) ? 1.0 : 2.0
        // X-Trans sensor has more spacing between nearest pixels of same color, need a more relaxed threshold.
        if mosaic_pattern_width == 6 {
            hot_pixel_threshold *= 1.4
        }
        
        // Calculate mean black level for each color channel
        var black_levels_mean = Array(repeating: Float32(0), count: mosaic_pattern_width*mosaic_pattern_width)
        if black_level[0][0] != 1 {
            for channel_idx in 0..<mosaic_pattern_width*mosaic_pattern_width {
                for img_idx in 0..<textures.count {
                    black_levels_mean[channel_idx] += Float32(black_level[img_idx][channel_idx])
                }
                black_levels_mean[channel_idx] /= Float32(textures.count)
            }
        }
        let black_levels_buffer = device.makeBuffer(bytes: black_levels_mean, length: MemoryLayout<Float32>.size * black_levels_mean.count)!
             
        let command_buffer = command_queue.makeCommandBuffer()!
        command_buffer.label = "Finding hotpixels"
        let command_encoder = command_buffer.makeComputeCommandEncoder()!
        command_encoder.label = command_buffer.label
        let state: MTLComputePipelineState
        switch mosaic_pattern_width {
            case 2:
                state = find_hotpixels_bayer_state
            case 6:
                state = find_hotpixels_xtrans_state
            default:
                return
        }
        command_encoder.setComputePipelineState(state)
        // -4 in width and height represent that hotpixel correction is not applied on a 2-pixel wide border around the image.
        // This is done so that the algorithm is simpler and comparing neighbours don't have to handle the edge cases.
        let threads_per_grid = MTLSize(width: average_texture.width-4, height: average_texture.height-4, depth: 1)
        let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
        command_encoder.setTexture(average_texture, index: 0)
        command_encoder.setTexture(hotpixel_weight_texture, index: 1)
        command_encoder.setBuffer(mean_texture_buffer, offset: 0, index: 0)
        command_encoder.setBuffer(black_levels_buffer, offset: 0, index: 1)
        command_encoder.setBytes([Float32(hot_pixel_threshold)],     length: MemoryLayout<Float32>.stride, index: 2)
        command_encoder.setBytes([Float32(hot_pixel_multiplicator)], length: MemoryLayout<Float32>.stride, index: 3)
        command_encoder.setBytes([Float32(correction_strength)],     length: MemoryLayout<Float32>.stride, index: 4)
        command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
        command_encoder.endEncoding()
        command_buffer.commit()
    }
}


/**
 * Calculates optimal thread group dimensions for maximum performance.
 *
 * This function determines the best thread group size by analyzing the computation
 * requirements and hardware characteristics. It attempts to find a balance that 
 * maximizes GPU utilization while respecting the grid dimensions.
 *
 * Parameters:
 *   - state: The compute pipeline state that will be executed
 *   - threads_per_grid: The dimensions of the full computation grid
 *
 * Returns: Optimal thread group dimensions for the GPU
 */
func get_threads_per_thread_group(_ state: MTLComputePipelineState, _ threads_per_grid: MTLSize) -> MTLSize {
    var thread_execution_width = state.threadExecutionWidth
    if threads_per_grid.depth >= thread_execution_width {
        return MTLSize(width: 1, height: 1, depth: thread_execution_width)
    } else {
        thread_execution_width /= threads_per_grid.depth
        // set initial values that always work, but may not be optimal
        var best_dim_x = 1
        var best_dim_y = thread_execution_width
        let best_dim_z = threads_per_grid.depth
         
        if threads_per_grid.height <= thread_execution_width {
            thread_execution_width /= threads_per_grid.height
            best_dim_x = thread_execution_width
            best_dim_y = threads_per_grid.height
        }
         
        thread_execution_width = state.threadExecutionWidth        
        var best_runs = Int(1e12)
        // perform additional optimization for 2D grids and try to find a pattern that has the lowest possible overhead (ideally thread grid is exactly a multiple of grid specified by grid_x and grid_y)
        // the divisor is varied from 2 to thread_execution_width/2 and for each combination the total number of runs is calculated
        // the combination with the lowest number of runs is selected, which in addition has a ratio of dim_x/dim_y that is similar to the ratio of the thread grid (e.g. for a thread grid with a ratio of 3:2, dim_x = 8 and dim_y = 4 may be selected assuming thread_execution_width = 32
        for divisor in 1..<thread_execution_width/4+1 {
            let dim_x = thread_execution_width/(2*divisor)
            let dim_y = 2*divisor
             
            if dim_x*dim_y == thread_execution_width && dim_x<=threads_per_grid.width && dim_y<=threads_per_grid.height {
                let runs = Int(ceil(Double(threads_per_grid.width)/Double(dim_x))*ceil(Double(threads_per_grid.height)/Double(dim_y))+0.1)
                 
                if runs < best_runs || (runs==best_runs && dim_x>=dim_y) {
                    best_runs = runs
                    best_dim_x = dim_x
                    best_dim_y = dim_y
                }
            }
        }
        
        return MTLSize(width: best_dim_x, height: best_dim_y, depth: best_dim_z)
    }
}


/**
 * Normalizes a texture by dividing pixel values by corresponding normalization factors.
 *
 * This function is typically used after accumulating weighted pixel values,
 * where each pixel needs to be divided by the sum of weights used in the accumulation.
 *
 * Parameters:
 *   - in_texture: The texture to normalize
 *   - norm_texture: Texture containing normalization factors for each pixel
 *   - norm_scalar: Additional scalar normalization factor applied to all pixels
 */
func normalize_texture(_ in_texture: MTLTexture, _ norm_texture: MTLTexture, _ norm_scalar: Int) {
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Normalize Texture"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = normalize_texture_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(norm_texture, index: 1)
    command_encoder.setBytes([Float32(norm_scalar)], length: MemoryLayout<Float32>.stride, index: 0)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
}

/**
 * Prepares a texture for alignment and merging in the burst pipeline.
 *
 * This function performs several preprocessing steps:
 * 1. Converts the input texture from integer to 32-bit float format
 * 2. Applies hot pixel correction using the provided weight texture
 * 3. Adjusts exposure to make frames with different exposures comparable
 * 4. Extends the texture with padding as needed for alignment
 *
 * Parameters:
 *   - in_texture: The input texture to prepare
 *   - hotpixel_weight_texture: Weight texture for hot pixel correction
 *   - pad_left, pad_right, pad_top, pad_bottom: Padding amounts to add to each edge
 *   - exposure_diff: Exposure difference in EV stops (powers of 2)
 *   - black_level: Array of black level values for each subpixel position
 *   - mosaic_pattern_width: Width of the mosaic pattern (2 for Bayer, 6 for X-Trans)
 *
 * Returns: A prepared texture ready for alignment and merging
 */
func prepare_texture(_ in_texture: MTLTexture, _ hotpixel_weight_texture: MTLTexture, _ pad_left: Int, _ pad_right: Int, _ pad_top: Int, _ pad_bottom: Int, _ exposure_diff: Int, _ black_level: [Int], _ mosaic_pattern_width: Int) -> MTLTexture {

    // always use pixel format float32 with increased precision that merging is performed with best possible precision    
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: in_texture.width+pad_left+pad_right, height: in_texture.height+pad_top+pad_bottom, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = "\(in_texture.label!.components(separatedBy: ":")[0]): Prepared"
    
    fill_with_zeros(out_texture)
    
    let black_levels_buffer = device.makeBuffer(bytes: black_level.map{ $0 == -1 ? Float32(0) : Float32($0)},
                                                length: black_level.count * MemoryLayout<Float32>.size)!
        
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Prepare Texture"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = prepare_texture_bayer_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: in_texture.width, height: in_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(hotpixel_weight_texture, index: 1)
    command_encoder.setTexture(out_texture, index: 2)
    command_encoder.setBuffer(black_levels_buffer, offset: 0, index: 0)
    command_encoder.setBytes([Int32(pad_left)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(pad_top)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(exposure_diff)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return out_texture
}


/**
 * Creates a new texture with the same properties as the input texture.
 *
 * This utility function creates an empty texture that matches the dimensions
 * and format of the provided texture. This is useful when creating intermediate
 * textures for multi-step operations.
 *
 * Parameters:
 *   - in_texture: The texture to use as a template
 *
 * Returns: A new empty texture with the same dimensions and format
 */
func texture_like(_ in_texture: MTLTexture) -> MTLTexture {
    let out_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: in_texture.pixelFormat, width: in_texture.width, height: in_texture.height, mipmapped: false)
    out_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    out_texture_descriptor.storageMode = .private
    let out_texture = device.makeTexture(descriptor: out_texture_descriptor)!
    out_texture.label = in_texture.label
    
    return out_texture
}


/**
 * Calculates the average pixel value across a texture.
 *
 * This function computes either a global average for the entire texture or
 * separate averages for each subpixel position in the mosaic pattern.
 *
 * Parameters:
 *   - in_texture: The texture to analyze
 *   - per_sub_pixel: If true, calculate separate averages for each subpixel in the mosaic pattern
 *   - mosaic_pattern_width: Width of the mosaic pattern (2 for Bayer, 6 for X-Trans)
 *
 * Returns: A Metal buffer containing either a single average value or an array
 *          of averages for each subpixel position in the mosaic pattern
 */
func texture_mean(_ in_texture: MTLTexture, per_sub_pixel: Bool, mosaic_pattern_width: Int) -> MTLBuffer {
    
    // Create output texture from the y-axis blurring
    let texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: in_texture.width, height: mosaic_pattern_width, mipmapped: false)
    texture_descriptor.usage = [.shaderRead, .shaderWrite]
    texture_descriptor.storageMode = .private
    let summed_y = device.makeTexture(descriptor: texture_descriptor)!

    // Sum each subpixel of the mosaic vertically along columns, creating a (width, mosaic_pattern_width) sized image
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Mean for \(String(describing: in_texture.label!))\(per_sub_pixel ? " per_sub_pixel" : "")"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    command_encoder.setComputePipelineState(sum_rect_columns_float_state)
    let thread_per_grid = MTLSize(width: summed_y.width, height: summed_y.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(sum_rect_columns_float_state, thread_per_grid)
    
    command_encoder.setTexture(in_texture, index: 0)
    command_encoder.setTexture(summed_y, index: 1)
    command_encoder.setBytes([0], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([0], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([in_texture.height], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(thread_per_grid, threadsPerThreadgroup: threads_per_thread_group)

    // Sum along the row
    // If `per_sub_pixel` is true, then the result is per sub pixel, otherwise a single value is calculated
    let sum_buffer = device.makeBuffer(length: (mosaic_pattern_width*mosaic_pattern_width)*MemoryLayout<Float32>.size,
                                       options: .storageModeShared)!
    command_encoder.setComputePipelineState(sum_row_state)
    let threads_per_grid_x = MTLSize(width: mosaic_pattern_width, height: mosaic_pattern_width, depth: 1)
    let threads_per_thread_group_x = get_threads_per_thread_group(sum_row_state, threads_per_grid_x)
    
    command_encoder.setTexture(summed_y, index: 0)
    command_encoder.setBuffer(sum_buffer, offset: 0, index: 0)
    command_encoder.setBytes([Int32(summed_y.width)],       length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(mosaic_pattern_width)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.dispatchThreads(threads_per_grid_x, threadsPerThreadgroup: threads_per_thread_group_x)
    
    // Calculate the average from the sum
    let state       = per_sub_pixel ? divide_buffer_state                       : sum_divide_buffer_state
    let buffer_size = per_sub_pixel ? mosaic_pattern_width*mosaic_pattern_width : 1
    let avg_buffer  = device.makeBuffer(length: buffer_size*MemoryLayout<Float32>.size, options: .storageModeShared)!
    command_encoder.setComputePipelineState(state)
    // If doing per-subpixel, the total number of pixels of each subpixel is 1/(mosaic_pattern_withh)^2 times the total
    let num_pixels_per_value = Float(in_texture.width * in_texture.height) / (per_sub_pixel ? Float(mosaic_pattern_width*mosaic_pattern_width) : 1.0)
    let threads_per_grid_divisor = MTLSize(width: buffer_size, height: 1, depth: 1)
    let threads_per_thread_group_divisor = get_threads_per_thread_group(state, threads_per_grid_divisor)
    
    command_encoder.setBuffer(sum_buffer,                                   offset: 0,                            index: 0)
    command_encoder.setBuffer(avg_buffer,                                   offset: 0,                            index: 1)
    command_encoder.setBytes([num_pixels_per_value],                        length: MemoryLayout<Float32>.stride, index: 2)
    command_encoder.setBytes([mosaic_pattern_width*mosaic_pattern_width],   length: MemoryLayout<Int>.stride,     index: 3)
    command_encoder.dispatchThreads(threads_per_grid_divisor, threadsPerThreadgroup: threads_per_thread_group_divisor)
    
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return avg_buffer
}


/**
 * Upsamples a texture to larger dimensions using specified interpolation method.
 *
 * This function increases the resolution of a texture using either bilinear interpolation
 * (for smooth photographic content) or nearest-neighbor interpolation (for masks or integer data).
 *
 * Parameters:
 *   - input_texture: The texture to upsample
 *   - width: Target width for the upsampled texture
 *   - height: Target height for the upsampled texture
 *   - mode: Interpolation method to use (Bilinear or NearestNeighbour)
 *
 * Returns: A new upsampled texture with the specified dimensions
 */
func upsample(_ input_texture: MTLTexture, to_width width: Int, to_height height: Int, using mode: UpsampleType) -> MTLTexture {
    let scale_x = Double(width)  / Double(input_texture.width)
    let scale_y = Double(height) / Double(input_texture.height)
    
    // create output texture
    let output_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: input_texture.pixelFormat, width: width, height: height, mipmapped: false)
    output_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    output_texture_descriptor.storageMode = .private
    let output_texture = device.makeTexture(descriptor: output_texture_descriptor)!
    output_texture.label = input_texture.label
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Upsample"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = (mode == .Bilinear ? upsample_bilinear_float_state : upsample_nearest_int_state)
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: output_texture.width, height: output_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(input_texture,  index: 0)
    command_encoder.setTexture(output_texture, index: 1)
    command_encoder.setBytes([Float32(scale_x)], length: MemoryLayout<Float32>.stride, index: 0)
    command_encoder.setBytes([Float32(scale_y)], length: MemoryLayout<Float32>.stride, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return output_texture
}
