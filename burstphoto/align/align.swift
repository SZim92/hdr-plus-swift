/**
 * @file align.swift
 * @brief Swift implementation of the hierarchical alignment algorithm for burst photography
 *
 * This file implements the Swift side of the burst photo alignment pipeline, which uses Metal shaders
 * to perform efficient GPU-based alignment of multiple frames in a burst sequence. The implementation
 * follows a coarse-to-fine hierarchical approach where alignment is refined at each resolution level.
 *
 * The alignment process:
 * 1. Builds image pyramids by downsampling the input images
 * 2. Starts alignment at the coarsest level
 * 3. Propagates and refines alignment vectors to finer levels
 * 4. Corrects alignment at object boundaries
 * 5. Warps the final aligned image
 */
import Foundation
import MetalPerformanceShaders

// Metal compute pipeline states for the various shader functions
let avg_pool_state                              = create_pipeline(with_function_name: "avg_pool",                               and_label: "Avg Pool")
let avg_pool_normalization_state                = create_pipeline(with_function_name: "avg_pool_normalization",                 and_label: "Avg Pool (Normalized)")
let compute_tile_differences_state              = create_pipeline(with_function_name: "compute_tile_differences",               and_label: "Compute Tile Difference")
let compute_tile_differences25_state            = create_pipeline(with_function_name: "compute_tile_differences25",             and_label: "Compute Tile Difference (N=25)")
let compute_tile_differences_exposure25_state   = create_pipeline(with_function_name: "compute_tile_differences_exposure25",    and_label: "Compute Tile Difference (N=25) (Exposure)")
let correct_upsampling_error_state              = create_pipeline(with_function_name: "correct_upsampling_error",               and_label: "Correct Upsampling Error")
let find_best_tile_alignment_state              = create_pipeline(with_function_name: "find_best_tile_alignment",               and_label: "Find Best Tile Alignment")
let warp_texture_bayer_state                    = create_pipeline(with_function_name: "warp_texture_bayer",                     and_label: "Warp Texture (Bayer)")
let warp_texture_xtrans_state                   = create_pipeline(with_function_name: "warp_texture_xtrans",                    and_label: "Warp Texture (XTrans)")

/**
 * Aligns a comparison texture to a reference texture using hierarchical alignment approach
 *
 * @param ref_pyramid           Array of reference textures at different resolutions (coarse to fine)
 * @param comp_texture          Comparison texture to be aligned to the reference
 * @param downscale_factor_array Array of downscale factors for each pyramid level
 * @param tile_size_array       Array of tile sizes for each pyramid level
 * @param search_dist_array     Array of search distances for each pyramid level
 * @param uniform_exposure      Flag indicating whether exposure is uniform between frames
 * @param black_level_mean      Mean black level of the sensor
 * @param color_factors3        Array of color correction factors (R, G, B)
 * @return                      The aligned comparison texture
 */
func align_texture(_ ref_pyramid: [MTLTexture], _ comp_texture: MTLTexture, _ downscale_factor_array: Array<Int>, _ tile_size_array: Array<Int>, _ search_dist_array: Array<Int>, _ uniform_exposure: Bool, _ black_level_mean: Double, _ color_factors3: Array<Double>) -> MTLTexture {
    
    // ISSUE: No validation of array lengths
    // The function assumes that downscale_factor_array, tile_size_array, and search_dist_array
    // all have the same length, but doesn't validate this.
    // FIX: Add a check to ensure all arrays have matching lengths before proceeding.
        
    // initialize tile alignments
    let alignment_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Sint, width: 1, height: 1, mipmapped: false)
    alignment_descriptor.usage = [.shaderRead, .shaderWrite]
    alignment_descriptor.storageMode = .private
    
    // ISSUE: Force unwrapping of texture creation
    // If texture creation fails (e.g., due to memory pressure), the application will crash
    // FIX: Use optional binding and proper error handling
    var prev_alignment = device.makeTexture(descriptor: alignment_descriptor)!
    
    var current_alignment = device.makeTexture(descriptor: alignment_descriptor)!
    current_alignment.label = "\(comp_texture.label!.components(separatedBy: ":")[0]): Current alignment Start"
    var tile_info = TileInfo(tile_size: 0, tile_size_merge: 0, search_dist: 0, n_tiles_x: 0, n_tiles_y: 0, n_pos_1d: 0, n_pos_2d: 0)
    
    // build comparison pyramid
    let comp_pyramid = build_pyramid(comp_texture, downscale_factor_array, black_level_mean, color_factors3)
    
    // align tiles - starting from the coarsest level (highest index) and refining to finer levels
    for i in (0 ... downscale_factor_array.count-1).reversed() {
        
        // load layer params
        let tile_size = tile_size_array[i]
        
        // ISSUE: No validation of tile size constraints
        // The Metal shaders use fixed buffer sizes (e.g., tmp_comp[5*68] and tmp_ref[64])
        // which limit the maximum tile size to 64 pixels.
        // FIX: Add validation to ensure tile_size <= 64 or adjust Metal shader to handle larger sizes.
        
        // ISSUE: No validation that tile_size divides 64 evenly
        // Some Metal shaders use loop increments like "dy += 64/tile_size" which assumes
        // tile_size divides 64 evenly.
        // FIX: Validate that 64 % tile_size == 0 when using these shaders, or adjust the loop logic.
        
        let search_dist = search_dist_array[i]
        let ref_layer = ref_pyramid[i]
        let comp_layer = comp_pyramid[i]
        
        // calculate the number of tiles
        let n_tiles_x = ref_layer.width / (tile_size / 2) - 1
        let n_tiles_y = ref_layer.height / (tile_size / 2) - 1
        let n_pos_1d = 2*search_dist + 1
        let n_pos_2d = n_pos_1d * n_pos_1d
        
        // ISSUE: No validation of search_dist == 2 assumption
        // When n_pos_2d == 25 (resulting from search_dist == 2), specialized optimized
        // shader functions are used, but we don't explicitly verify search_dist == 2.
        // FIX: Add explicit check that search_dist == 2 when n_pos_2d == 25.
        
        // store the values together in a struct to make it easier and more readable when passing between functions
        tile_info = TileInfo(tile_size: tile_size, tile_size_merge: 0, search_dist: search_dist, n_tiles_x: n_tiles_x, n_tiles_y: n_tiles_y, n_pos_1d: n_pos_1d, n_pos_2d: n_pos_2d)
        
        // resize previous alignment
        // - 'downscale_factor' has to be loaded from the *previous* layer since that is the layer that generated the current layer
        var downscale_factor: Int
        if (i < downscale_factor_array.count-1){
            downscale_factor = downscale_factor_array[i+1]
        } else {
            downscale_factor = 0
        }
        
        // upsample alignment vectors by a factor of 2
        prev_alignment = upsample(current_alignment, to_width: n_tiles_x, to_height: n_tiles_y, using: .NearestNeighbour)
        prev_alignment.label = "\(comp_texture.label!.components(separatedBy: ":")[0]): Prev alignment \(i)"
        
        // compare three alignment vector candidates, which improves alignment at borders of moving object
        // see https://graphics.stanford.edu/papers/hdrp/hasinoff-hdrplus-sigasia16.pdf for more details
        prev_alignment = correct_upsampling_error(ref_layer, comp_layer, prev_alignment, downscale_factor, uniform_exposure, (i != 0), tile_info)
          
        // The parameter 'use_ssd' employed in correct_upsamling_error() and comute_tile_diff() specifies if the calculated cost term shall be based on the absolute difference (L1 norm -> use_ssd = false) or on the sum of squared difference (L2 norm -> use_ssd = true). The alignment is done differently depending on the pyramid scale: for levels with reduced resolution, the L2 norm is calculated while for the highest resolution level, the L1 norm is calculated. This choice is identical to the original publication.
        // see https://graphics.stanford.edu/papers/hdrp/hasinoff-hdrplus-sigasia16.pdf for more details
        
        // compute tile differences
        let tile_diff = compute_tile_diff(ref_layer, comp_layer, prev_alignment, downscale_factor, uniform_exposure, (i != 0), tile_info)
      
        current_alignment = texture_like(prev_alignment)
        current_alignment.label = "\(comp_texture.label!.components(separatedBy: ":")[0]): Current alignment \(i)"
        
        // find best tile alignment based on tile differences
        find_best_tile_alignment(tile_diff, prev_alignment, current_alignment, downscale_factor, tile_info)
    }

    // warp the aligned layer
    // ISSUE: No safety for division by zero in warp functions
    // The Metal warping shaders divide by total_weight without checking if it's zero,
    // which could lead to undefined behavior.
    // FIX: Modify the Metal shaders to check for zero before division.
    let aligned_texture = warp_texture(comp_texture, current_alignment, tile_info, downscale_factor_array[0])
    
    return aligned_texture
}

/**
 * Performs average pooling on an input texture to downsample it
 *
 * @param input_texture     The texture to downsample
 * @param scale             The scale factor for downsampling
 * @param black_level_mean  Mean black level of the sensor to be subtracted
 * @param normalization     Whether to apply color normalization
 * @param color_factors3    Array of color correction factors (R, G, B)
 * @return                  The downsampled texture
 */
func avg_pool(_ input_texture: MTLTexture, _ scale: Int, _ black_level_mean: Double, _ normalization: Bool, _ color_factors3: Array<Double>) -> MTLTexture {

    // ISSUE: No validation of scale for avg_pool_normalization
    // When normalization is true, avg_pool_normalization shader is used, which assumes scale==2
    // for its norm_factors array indexing. Other scale values will cause out-of-bounds access.
    // FIX: Add a check to ensure scale==2 when normalization is true, or adjust the Metal shader.

    // always set pixel format to float16 with reduced bit depth to make alignment as fast as possible
    let output_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: input_texture.width/scale, height: input_texture.height/scale, mipmapped: false)
    output_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    output_texture_descriptor.storageMode = .private
    let output_texture = device.makeTexture(descriptor: output_texture_descriptor)!
    output_texture.label = "\(input_texture.label!.components(separatedBy: ":")[0]): pool w/ scale \(scale)"
    
    // ISSUE: Inefficient Command Buffer Management
    // Each function creates and commits its own command buffer rather than batching operations.
    // This prevents opportunities for the GPU to optimize across operations.
    // FIX: Consider a design where command buffers can be shared across operations.
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Avg Pool"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = normalization ? "Average Pool Normalized" : "Average Pool"
    let state = (normalization ? avg_pool_normalization_state : avg_pool_state)
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: output_texture.width, height: output_texture.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(input_texture, index: 0)
    command_encoder.setTexture(output_texture, index: 1)
    command_encoder.setBytes([Int32(scale)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Float32(black_level_mean)], length: MemoryLayout<Float32>.stride, index: 1)
    
    if normalization {
        command_encoder.setBytes([Float32(color_factors3[0])], length: MemoryLayout<Float32>.stride, index: 2)
        command_encoder.setBytes([Float32(color_factors3[1])], length: MemoryLayout<Float32>.stride, index: 3)
        command_encoder.setBytes([Float32(color_factors3[2])], length: MemoryLayout<Float32>.stride, index: 4)
    }
    
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()

    return output_texture
}

/**
 * Builds a pyramid of downsampled textures for multi-scale alignment
 *
 * @param input_texture       The highest resolution input texture
 * @param downscale_factor_list Array of scale factors for each pyramid level
 * @param black_level_mean    Mean black level of the sensor
 * @param color_factors3      Array of color correction factors (R, G, B)
 * @return                    Array of textures at different resolution levels (finest to coarsest)
 */
func build_pyramid(_ input_texture: MTLTexture, _ downscale_factor_list: Array<Int>, _ black_level_mean: Double, _ color_factors3: Array<Double>) -> Array<MTLTexture> {
    
    // iteratively resize the current layer in the pyramid
    var pyramid: Array<MTLTexture> = []
    for (i, downscale_factor) in downscale_factor_list.enumerated() {
        if i == 0 {
            // If color_factor is NOT available, a negative value will be set and normalization is deactivated.
            // ISSUE: Scale factor not validated for avg_pool_normalization
            // When color_factors3[0] > 0, normalization is enabled, but we don't check if downscale_factor==2,
            // which is required by the avg_pool_normalization shader.
            // FIX: Add a validation check to ensure downscale_factor==2 when color_factors3[0] > 0.
            pyramid.append(avg_pool(input_texture, downscale_factor, max(0.0, black_level_mean), (color_factors3[0] > 0), color_factors3))
        } else {
            pyramid.append(avg_pool(blur(pyramid.last!, with_pattern_width: 1, using_kernel_size: 2), downscale_factor, 0.0, false, color_factors3))
        }
    }
    return pyramid
}

/**
 * Computes the differences between tiles in reference and comparison textures
 *
 * @param ref_layer         Reference texture
 * @param comp_layer        Comparison texture
 * @param prev_alignment    Previous alignment vectors
 * @param downscale_factor  Scale factor between current and previous level
 * @param uniform_exposure  Flag indicating whether exposure is uniform between frames
 * @param use_ssd           Whether to use Sum of Squared Differences (L2 norm) instead of L1 norm
 * @param tile_info         Structure containing tile parameters
 * @return                  Texture containing tile differences
 */
func compute_tile_diff(_ ref_layer: MTLTexture, _ comp_layer: MTLTexture, _ prev_alignment: MTLTexture, _ downscale_factor: Int, _ uniform_exposure: Bool, _ use_ssd: Bool, _ tile_info: TileInfo) -> MTLTexture {
    
    // create a 'tile difference' texture
    let texture_descriptor = MTLTextureDescriptor()
    texture_descriptor.textureType = .type3D
    texture_descriptor.pixelFormat = .r32Float
    texture_descriptor.width = tile_info.n_pos_2d
    texture_descriptor.height = tile_info.n_tiles_x
    texture_descriptor.depth = tile_info.n_tiles_y   
    texture_descriptor.usage = [.shaderRead, .shaderWrite]
    texture_descriptor.storageMode = .private
    let tile_diff = device.makeTexture(descriptor: texture_descriptor)!
    tile_diff.label = "\(comp_layer.label!.components(separatedBy: ":")[0]): Tile diff"
    
    // compute tile differences
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Compute Tile Diff"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    
    // ISSUE: Specialized shader functions without explicit validation
    // When tile_info.n_pos_2d==25, we use specialized optimized shaders without explicitly
    // verifying that search_dist == 2 (which would guarantee n_pos_2d == 25).
    // FIX: Add an assertion or validation check that tile_info.search_dist == 2 when n_pos_2d==25.
    
    // either use generic function or highly-optimized function for testing a +/- 2 displacement in both image directions (in total 25 combinations)
    let state = (tile_info.n_pos_2d==25 ? (uniform_exposure ? compute_tile_differences25_state : compute_tile_differences_exposure25_state) : compute_tile_differences_state)
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: tile_info.n_tiles_x, height: tile_info.n_tiles_y, depth: (tile_info.n_pos_2d==25 ? 1 : tile_info.n_pos_2d))
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(ref_layer, index: 0)
    command_encoder.setTexture(comp_layer, index: 1)
    command_encoder.setTexture(prev_alignment, index: 2)
    command_encoder.setTexture(tile_diff, index: 3)
    command_encoder.setBytes([Int32(downscale_factor)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(tile_info.tile_size)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(tile_info.search_dist)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(use_ssd ? 1 : 0)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return tile_diff
}

/**
 * Corrects alignment errors at boundaries between moving objects and static backgrounds
 *
 * This function evaluates three candidate alignment vectors for each tile to improve
 * alignment at motion boundaries: the upsampled vector and vectors from neighboring tiles.
 *
 * @param ref_layer         Reference texture
 * @param comp_layer        Comparison texture
 * @param prev_alignment    Previous alignment vectors
 * @param downscale_factor  Scale factor between current and previous level
 * @param uniform_exposure  Flag indicating whether exposure is uniform between frames
 * @param use_ssd           Whether to use Sum of Squared Differences (L2 norm) instead of L1 norm
 * @param tile_info         Structure containing tile parameters
 * @return                  Texture containing corrected alignment vectors
 */
func correct_upsampling_error(_ ref_layer: MTLTexture, _ comp_layer: MTLTexture, _ prev_alignment: MTLTexture, _ downscale_factor: Int, _ uniform_exposure: Bool, _ use_ssd: Bool, _ tile_info: TileInfo) -> MTLTexture {
    
    // ISSUE: No validation that tile_size <= 64
    // The Metal shader 'correct_upsampling_error' uses a fixed buffer tmp_ref[64],
    // limiting the maximum tile size to 64 pixels.
    // FIX: Add validation to ensure tile_info.tile_size <= 64.
    
    // ISSUE: No validation that 64 % tile_size == 0
    // The Metal shader uses increments like "dy += 64/tile_size" which assumes
    // tile_size divides 64 evenly.
    // FIX: Add validation to ensure 64 % tile_info.tile_size == 0.
    
    // create texture for corrected alignment
    let prev_alignment_corrected_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: prev_alignment.pixelFormat, width: prev_alignment.width, height: prev_alignment.height, mipmapped: false)
    prev_alignment_corrected_descriptor.usage = [.shaderRead, .shaderWrite]
    prev_alignment_corrected_descriptor.storageMode = .private
    let prev_alignment_corrected = device.makeTexture(descriptor: prev_alignment_corrected_descriptor)!
    prev_alignment_corrected.label = "\(prev_alignment.label!.components(separatedBy: ":")[0]): Prev alignment upscaled corrected"
        
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Correct Upsampling Error"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = correct_upsampling_error_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: tile_info.n_tiles_x, height: tile_info.n_tiles_y, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(ref_layer, index: 0)
    command_encoder.setTexture(comp_layer, index: 1)
    command_encoder.setTexture(prev_alignment, index: 2)
    command_encoder.setTexture(prev_alignment_corrected, index: 3)
    command_encoder.setBytes([Int32(downscale_factor)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(tile_info.tile_size)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(tile_info.n_tiles_x)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(tile_info.n_tiles_y)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.setBytes([Int32(uniform_exposure ? 1 : 0)], length: MemoryLayout<Float32>.stride, index: 4)
    command_encoder.setBytes([Int32(use_ssd ? 1 : 0)], length: MemoryLayout<Int32>.stride, index: 5)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return prev_alignment_corrected
}

/**
 * Finds the best alignment vector for each tile by selecting the displacement with minimum difference
 *
 * @param tile_diff         Texture containing tile differences for each displacement
 * @param prev_alignment    Previous alignment vectors
 * @param current_alignment Output texture for storing the best alignment vectors
 * @param downscale_factor  Scale factor between current and previous level
 * @param tile_info         Structure containing tile parameters
 */
func find_best_tile_alignment(_ tile_diff: MTLTexture, _ prev_alignment: MTLTexture, _ current_alignment: MTLTexture, _ downscale_factor: Int, _ tile_info: TileInfo) {
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Find Best Tile Alignment"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = command_buffer.label
    let state = find_best_tile_alignment_state
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: tile_info.n_tiles_x, height: tile_info.n_tiles_y, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(tile_diff, index: 0)
    command_encoder.setTexture(prev_alignment, index: 1)
    command_encoder.setTexture(current_alignment, index: 2)
    command_encoder.setBytes([Int32(downscale_factor)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32(tile_info.search_dist)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
}

/**
 * Warps a texture based on the computed alignment vectors
 *
 * This function applies the computed alignment vectors to transform the input texture,
 * effectively aligning it with the reference frame. It uses either the Bayer-specific
 * warping function or the more general X-Trans function depending on the downscale factor.
 *
 * @param texture_to_warp   The texture to be warped
 * @param alignment         Texture containing alignment vectors
 * @param tile_info         Structure containing tile parameters
 * @param downscale_factor  Scale factor for the alignment vectors
 * @return                  The warped and aligned texture
 */
func warp_texture(_ texture_to_warp: MTLTexture, _ alignment: MTLTexture, _ tile_info: TileInfo, _ downscale_factor: Int) -> MTLTexture {
    
    // ISSUE: Division by zero risk in warp shaders
    // Both warp_texture_bayer and warp_texture_xtrans Metal shaders divide by total_weight
    // without checking if it's zero, which could lead to undefined behavior.
    // FIX: Modify the Metal shaders to add a check before division:
    // float out_intensity = (total_weight > 0.0f) ? (pixel_value / total_weight) : 0.0f;
    
    let warped_texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture_to_warp.pixelFormat, width: texture_to_warp.width, height: texture_to_warp.height, mipmapped: false)
    warped_texture_descriptor.usage = [.shaderRead, .shaderWrite]
    warped_texture_descriptor.storageMode = .private
    let warped_texture = device.makeTexture(descriptor: warped_texture_descriptor)!
    warped_texture.label = "\(texture_to_warp.label!.components(separatedBy: ":")[0]): warped"
    
    let command_buffer = command_queue.makeCommandBuffer()!
    command_buffer.label = "Warp Texture"
    let command_encoder = command_buffer.makeComputeCommandEncoder()!
    command_encoder.label = downscale_factor==2 ? "Warp Texture Bayer" : "Warp Texture XTrans"
    // The function warp_texture_xtrans corresponds to an old version of the warp function and would also work with images with Bayer pattern
    let state = (downscale_factor==2 ? warp_texture_bayer_state : warp_texture_xtrans_state)
    command_encoder.setComputePipelineState(state)
    let threads_per_grid = MTLSize(width: texture_to_warp.width, height: texture_to_warp.height, depth: 1)
    let threads_per_thread_group = get_threads_per_thread_group(state, threads_per_grid)
    command_encoder.setTexture(texture_to_warp, index: 0)
    command_encoder.setTexture(warped_texture, index: 1)
    command_encoder.setTexture(alignment, index: 2)
    command_encoder.setBytes([Int32(downscale_factor)], length: MemoryLayout<Int32>.stride, index: 0)
    command_encoder.setBytes([Int32((downscale_factor==2 ? 1 : downscale_factor)*tile_info.tile_size)], length: MemoryLayout<Int32>.stride, index: 1)
    command_encoder.setBytes([Int32(tile_info.n_tiles_x)], length: MemoryLayout<Int32>.stride, index: 2)
    command_encoder.setBytes([Int32(tile_info.n_tiles_y)], length: MemoryLayout<Int32>.stride, index: 3)
    command_encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_thread_group)
    command_encoder.endEncoding()
    command_buffer.commit()
    
    return warped_texture
}
