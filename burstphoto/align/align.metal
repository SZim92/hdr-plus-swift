#include <metal_stdlib>
#include "../misc/constants.h"

/**
 * @file align.metal
 * @brief Metal shaders for multi-frame alignment in computational photography
 *
 * This file contains Metal shader implementations for the hierarchical alignment stage
 * of a burst photography pipeline. Alignment is a critical step in multi-frame photography
 * algorithms like HDR+ where multiple frames need to be precisely aligned to be merged.
 *
 * The implementation follows a coarse-to-fine hierarchical approach:
 * 1. Images are downsampled to create a pyramid of lower resolution images
 * 2. Alignment begins at the coarsest level and proceeds to finer levels
 * 3. At each level, alignment vectors from the previous level are upsampled and refined
 * 4. Tile-based alignment is performed by comparing small patches between frames
 * 5. Motion between frames is represented as a field of displacement vectors
 *
 * References:
 * - HDR+: https://graphics.stanford.edu/papers/hdrp/hasinoff-hdrplus-sigasia16.pdf
 * - Alignment: https://www.ipol.im/pub/art/2021/336/
 */
using namespace metal;

/**
 * @brief Downsamples an input texture using average pooling
 *
 * This kernel performs average pooling by taking a square neighborhood of pixels
 * of size scale x scale from the input texture and averaging them to produce a
 * single output pixel. The black level is subtracted from each input pixel.
 *
 * @param in_texture     Input texture to be downsampled
 * @param out_texture    Output texture with reduced dimensions
 * @param scale          The downsampling factor (e.g., 2 = half size in each dimension)
 * @param black_level    The black level to subtract from each pixel
 * @param gid            The output pixel coordinate
 */
kernel void avg_pool(texture2d<float, access::read> in_texture [[texture(0)]],
                     texture2d<float, access::write> out_texture [[texture(1)]],
                     constant int& scale [[buffer(0)]],
                     constant float& black_level [[buffer(1)]],
                     uint2 gid [[thread_position_in_grid]]) {
    
    float out_pixel = 0;
    int x0 = gid.x * scale;
    int y0 = gid.y * scale;
    
    for (int dx = 0; dx < scale; dx++) {
        for (int dy = 0; dy < scale; dy++) {
            int x = x0 + dx;
            int y = y0 + dy;
            out_pixel += (in_texture.read(uint2(x, y)).r - black_level);
        }
    }
    
    out_pixel /= (scale*scale);
    out_texture.write(out_pixel, gid);
}

/**
 * @brief Downsamples an input texture using average pooling with per-pixel normalization
 *
 * Similar to avg_pool, but applies an additional normalization step for color correction.
 * This is particularly useful for Bayer pattern images where different color channels
 * might have different intensities. Each pixel is normalized according to its position
 * in the Bayer pattern using the appropriate color factor.
 *
 * @param in_texture     Input texture to be downsampled
 * @param out_texture    Output texture with reduced dimensions
 * @param scale          The downsampling factor (e.g., 2 = half size in each dimension)
 * @param black_level    The black level to subtract from each pixel
 * @param factor_red     Normalization factor for red pixels in the Bayer pattern
 * @param factor_green   Normalization factor for green pixels in the Bayer pattern
 * @param factor_blue    Normalization factor for blue pixels in the Bayer pattern
 * @param gid            The output pixel coordinate
 */
kernel void avg_pool_normalization(texture2d<float, access::read> in_texture [[texture(0)]],
                                   texture2d<float, access::write> out_texture [[texture(1)]],
                                   constant int& scale [[buffer(0)]],
                                   constant float& black_level [[buffer(1)]],
                                   constant float& factor_red [[buffer(2)]],
                                   constant float& factor_green [[buffer(3)]],
                                   constant float& factor_blue [[buffer(4)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    
    float out_pixel = 0;
    int x0 = gid.x * scale;
    int y0 = gid.y * scale;
    
    float const norm_factors[4] = {factor_red, factor_green, factor_green, factor_blue};
    // ISSUE: This code assumes scale==2 for norm_factors indexing
    // The array size of 4 only works for a 2×2 pattern (Bayer pattern). For other scale values,
    // accessing norm_factors[dy*scale+dx] will cause out-of-bounds memory access when scale > 2.
    // FIX: Either enforce scale==2 with a static_assert or runtime check, or make the array size
    // dynamic based on scale (e.g., float norm_factors[scale*scale]).
    float const mean_factor = 0.25f*(norm_factors[0]+norm_factors[1]+norm_factors[2]+norm_factors[3]);
     
    for (int dx = 0; dx < scale; dx++) {
        for (int dy = 0; dy < scale; dy++) {
            int x = x0 + dx;
            int y = y0 + dy;
            // ISSUE: This indexing is unsafe for scale > 2
            // FIX: Add bounds checking or restructure to handle different scale values safely
            out_pixel += (mean_factor/norm_factors[dy*scale+dx]*in_texture.read(uint2(x, y)).r - black_level);
        }
    }

    out_pixel /= (scale*scale);
    out_texture.write(out_pixel, gid);
}


/**
 * @brief Generic function for computation of tile differences that works for any search distance
 *
 * This kernel computes differences between corresponding tiles in reference and comparison textures.
 * It is used in the hierarchical alignment process to find the optimal displacement between frames
 * in a burst sequence. This function supports any search distance but is less optimized than the
 * specialized versions.
 *
 * @param ref_texture      Reference texture (usually the "base frame")
 * @param comp_texture     Comparison texture (the frame being aligned to the reference)
 * @param prev_alignment   Previous alignment vectors from coarser scale level
 * @param tile_diff        Output texture storing tile difference metrics
 * @param downscale_factor Scale factor between current and previous alignment level
 * @param tile_size        Size of each tile being compared (in pixels)
 * @param search_dist      Maximum search distance for alignment vectors
 * @param weight_ssd       Weight for SSD (Sum of Squared Differences) vs L1 norm
 * @param gid              3D thread position (x,y,z) where z encodes the displacement candidate
 */
kernel void compute_tile_differences(texture2d<float, access::read> ref_texture [[texture(0)]],
                                     texture2d<float, access::read> comp_texture [[texture(1)]],
                                     texture2d<int, access::read> prev_alignment [[texture(2)]],
                                     texture3d<float, access::write> tile_diff [[texture(3)]],
                                     constant int& downscale_factor [[buffer(0)]],
                                     constant int& tile_size [[buffer(1)]],
                                     constant int& search_dist [[buffer(2)]],
                                     constant int& weight_ssd [[buffer(3)]],
                                     uint3 gid [[thread_position_in_grid]]) {
    
    // load args
    int const texture_width = ref_texture.get_width();
    int const texture_height = ref_texture.get_height();
    int n_pos_1d = 2*search_dist + 1;
    
    float diff_abs;
    
    // compute tile position if previous alignment were 0
    int const x0 = gid.x*tile_size/2;
    int const y0 = gid.y*tile_size/2;
    
    // compute current tile displacement based on thread index
    int dy0 = gid.z / n_pos_1d - search_dist;
    int dx0 = gid.z % n_pos_1d - search_dist;
    
    // factor in previous alignment
    int4 prev_align = prev_alignment.read(uint2(gid.x, gid.y));
    dx0 += downscale_factor * prev_align.x;
    dy0 += downscale_factor * prev_align.y;
    
    // compute tile difference
    float diff = 0;
    for (int dx1 = 0; dx1 < tile_size; dx1++){
        for (int dy1 = 0; dy1 < tile_size; dy1++){
            // compute the indices of the pixels to compare
            int ref_tile_x = x0 + dx1;
            int ref_tile_y = y0 + dy1;
            int comp_tile_x = ref_tile_x + dx0;
            int comp_tile_y = ref_tile_y + dy0;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            // ISSUE: Using 2*FLOAT16_MIN_VAL as penalty value for out-of-bounds pixels
            // This magic constant may not be optimal for all image data and could lead to unexpected behavior.
            // FIX: Consider using a more meaningful constant (e.g., MAX_FLOAT) or make this a parameter
            // that can be tuned based on the specific characteristics of the input data.
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                diff_abs = abs(ref_texture.read(uint2(ref_tile_x, ref_tile_y)).r - 2*FLOAT16_MIN_VAL);
            } else {
                diff_abs = abs(ref_texture.read(uint2(ref_tile_x, ref_tile_y)).r - comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r);
            }
            diff += (1-weight_ssd)*diff_abs + weight_ssd*diff_abs*diff_abs;
        }
    }
    
    // store tile difference
    tile_diff.write(diff, gid);
}


/**
 * @brief Highly-optimized function for computation of tile differences that works only for search_distance == 2 (25 total combinations).
 *
 * The aim of this function is to reduce the number of memory accesses required compared to the more simple function compute_tile_differences() 
 * while providing equal results. As the alignment always checks shifts on a 5x5 pixel grid, a simple implementation would read 25 pixels 
 * in the comparison texture for each pixel in the reference texture. This optimized function however uses a buffer vector covering 5 complete 
 * rows of the texture that slides line by line through the comparison texture and reduces the number of memory reads considerably.
 *
 * @param ref_texture      Reference texture (usually the "base frame")
 * @param comp_texture     Comparison texture (the frame being aligned to the reference)
 * @param prev_alignment   Previous alignment vectors from coarser scale level
 * @param tile_diff        Output texture storing tile difference metrics
 * @param downscale_factor Scale factor between current and previous alignment level
 * @param tile_size        Size of each tile being compared (in pixels)
 * @param search_dist      Maximum search distance for alignment vectors (should be 2)
 * @param weight_ssd       Weight for SSD (Sum of Squared Differences) vs L1 norm
 * @param gid              2D thread position indicating tile coordinates
 */
kernel void compute_tile_differences25(texture2d<half, access::read> ref_texture [[texture(0)]],
                                       texture2d<half, access::read> comp_texture [[texture(1)]],
                                       texture2d<int, access::read> prev_alignment [[texture(2)]],
                                       texture3d<float, access::write> tile_diff [[texture(3)]],
                                       constant int& downscale_factor [[buffer(0)]],
                                       constant int& tile_size [[buffer(1)]],
                                       constant int& search_dist [[buffer(2)]],
                                       constant int& weight_ssd [[buffer(3)]],
                                       uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    int const texture_width = ref_texture.get_width();
    int const texture_height = ref_texture.get_height();
     
    int ref_tile_x, ref_tile_y, comp_tile_x, comp_tile_y, tmp_index, dx_i, dy_i;
    
    // compute tile position if previous alignment were 0
    int const x0 = gid.x*tile_size/2;
    int const y0 = gid.y*tile_size/2;
    
    // factor in previous alignment
    int4 const prev_align = prev_alignment.read(uint2(gid.x, gid.y));
    int const dx0 = downscale_factor * prev_align.x;
    int const dy0 = downscale_factor * prev_align.y;
    
    float diff[25] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    float diff_abs0, diff_abs1;
    half tmp_ref0, tmp_ref1;
    half tmp_comp[5*68];
    // ISSUE: Fixed size buffer assumption
    // The buffer size of 5*68 is insufficient for tile sizes larger than 64.
    // If tile_size exceeds 64, buffer overflow will occur, leading to undefined behavior.
    // FIX: Either enforce a maximum tile size with a static_assert or runtime check,
    // or allocate the buffer dynamically based on the tile size.
    
    // loop over first 4 rows of comp_texture
    for (int dy = -2; dy < +2; dy++) {
        
        // loop over columns of comp_texture to copy first 4 rows of comp_texture into tmp_comp
        for (int dx = -2; dx < tile_size+2; dx++) {
            
            comp_tile_x = x0 + dx0 + dx;
            comp_tile_y = y0 + dy0 + dy;
            
            // index of corresponding pixel value in tmp_comp
            tmp_index = (dy+2)*(tile_size+4) + dx+2;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                tmp_comp[tmp_index] = FLOAT16_MIN_VAL;
            } else {
                tmp_comp[tmp_index] = FLOAT16_05_VAL*comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r;
            }
        }
    }
    
    // loop over rows of ref_texture
    for (int dy = 0; dy < tile_size; dy++) {
        
        // loop over columns of comp_texture to copy 1 additional row of comp_texture into tmp_comp
        for (int dx = -2; dx < tile_size+2; dx++) {
            
            comp_tile_x = x0 + dx0 + dx;
            comp_tile_y = y0 + dy0 + dy+2;
            
            // index of corresponding pixel value in tmp_comp
            tmp_index = ((dy+4)%5)*(tile_size+4) + dx+2;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                tmp_comp[tmp_index] = FLOAT16_MIN_VAL;
            } else {
                tmp_comp[tmp_index] = FLOAT16_05_VAL*comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r;
            }
        }
        
        // loop over columns of ref_texture
        for (int dx = 0; dx < tile_size; dx+=2) {
            
            ref_tile_x = x0 + dx;
            ref_tile_y = y0 + dy;
            
            tmp_ref0 = ref_texture.read(uint2(ref_tile_x+0, ref_tile_y)).r;
            tmp_ref1 = ref_texture.read(uint2(ref_tile_x+1, ref_tile_y)).r;
            
            // loop over 25 test displacements
            for (int i = 0; i < 25; i++) {
                
                dx_i = i % 5;
                dy_i = i / 5;
                
                // index of corresponding pixel value in tmp_comp
                tmp_index = ((dy+dy_i)%5)*(tile_size+4) + dx + dx_i;
                
                diff_abs0 = abs(tmp_ref0 - 2.0f*tmp_comp[tmp_index+0]);
                diff_abs1 = abs(tmp_ref1 - 2.0f*tmp_comp[tmp_index+1]);
                
                // add difference to corresponding combination
                diff[i] += ((1-weight_ssd)*(diff_abs0 + diff_abs1) + weight_ssd*(diff_abs0*diff_abs0 + diff_abs1*diff_abs1));
            }
        }
    }
    
    // store tile differences in texture
    for (int i = 0; i < 25; i++) {
        tile_diff.write(diff[i], uint3(i, gid.x, gid.y));
    }
}

/**
 * @brief Highly-optimized function for computation of tile differences that works only for search_distance == 2 (25 total combinations).
 *
 * The aim of this function is to reduce the number of memory accesses required compared to the more simple function compute_tile_differences()
 * while extending it with a scaling of pixel intensities by the ratio of mean values of both tiles. This helps compensate for exposure
 * differences between frames.
 *
 * The algorithm has two main passes:
 * 1. First pass: Calculate the average intensities of corresponding tiles to determine exposure ratios
 * 2. Second pass: Compute the actual tile differences, normalizing for exposure differences
 *
 * This approach is more robust to variable exposure between frames compared to simple pixel differences.
 *
 * @param ref_texture      Reference texture (usually the "base frame")
 * @param comp_texture     Comparison texture (the frame being aligned to the reference)
 * @param prev_alignment   Previous alignment vectors from coarser scale level
 * @param tile_diff        Output texture storing tile difference metrics
 * @param downscale_factor Scale factor between current and previous alignment level
 * @param tile_size        Size of each tile being compared (in pixels)
 * @param search_dist      Maximum search distance for alignment vectors (should be 2)
 * @param weight_ssd       Weight for SSD (Sum of Squared Differences) vs L1 norm
 * @param gid              2D thread position indicating tile coordinates
 */
kernel void compute_tile_differences_exposure25(texture2d<half, access::read> ref_texture [[texture(0)]],
                                                texture2d<half, access::read> comp_texture [[texture(1)]],
                                                texture2d<int, access::read> prev_alignment [[texture(2)]],
                                                texture3d<float, access::write> tile_diff [[texture(3)]],
                                                constant int& downscale_factor [[buffer(0)]],
                                                constant int& tile_size [[buffer(1)]],
                                                constant int& search_dist [[buffer(2)]],
                                                constant int& weight_ssd [[buffer(3)]],
                                                uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    int const texture_width = ref_texture.get_width();
    int const texture_height = ref_texture.get_height();
     
    int ref_tile_x, ref_tile_y, comp_tile_x, comp_tile_y, tmp_index, dx_i, dy_i;
    
    // compute tile position if previous alignment were 0
    int const x0 = gid.x*tile_size/2;
    int const y0 = gid.y*tile_size/2;
    
    // factor in previous alignment
    int4 const prev_align = prev_alignment.read(uint2(gid.x, gid.y));
    int const dx0 = downscale_factor * prev_align.x;
    int const dy0 = downscale_factor * prev_align.y;
    
    // Arrays to store sums for each of the 25 possible displacements
    float sum_u[25] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // ref texture values
    float sum_v[25] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // comp texture values
    float diff[25]  = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // final difference values
    float ratio[25]; // exposure ratios
    float diff_abs0, diff_abs1;
    half tmp_ref0, tmp_ref1, tmp_comp_val0, tmp_comp_val1;
    half tmp_comp[5*68]; // Buffer to store comparison pixels (5 rows of the texture at a time)
    
    // First pass: load comparison texture and calculate the sums for exposure normalization
    
    // loop over first 4 rows of comp_texture
    for (int dy = -2; dy < +2; dy++) {
        
        // loop over columns of comp_texture to copy first 4 rows of comp_texture into tmp_comp
        for (int dx = -2; dx < tile_size+2; dx++) {
            
            comp_tile_x = x0 + dx0 + dx;
            comp_tile_y = y0 + dy0 + dy;
            
            // index of corresponding pixel value in tmp_comp
            tmp_index = (dy+2)*(tile_size+4) + dx+2;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                tmp_comp[tmp_index] = FLOAT16_MAX_VAL;
            } else {
                tmp_comp[tmp_index] = max(FLOAT16_ZERO_VAL, FLOAT16_05_VAL * comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r);
            }
        }
    }
    
    // loop over rows of ref_texture
    for (int dy = 0; dy < tile_size; dy++) {
        
        // For each row of reference texture, we need to consider 5 rows of comparison texture
        // (current row + 2 rows above and 2 rows below for the 5x5 search area)
        
        // loop over columns of comp_texture to copy 1 additional row of comp_texture into tmp_comp
        for (int dx = -2; dx < tile_size+2; dx++) {
            
            comp_tile_x = x0 + dx0 + dx;
            comp_tile_y = y0 + dy0 + dy+2;
            
            // index of corresponding pixel value in tmp_comp (using a circular buffer technique)
            tmp_index = ((dy+4)%5)*(tile_size+4) + dx+2;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                tmp_comp[tmp_index] = FLOAT16_MAX_VAL;
            } else {
                tmp_comp[tmp_index] = max(FLOAT16_ZERO_VAL, FLOAT16_05_VAL * comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r);
            }
        }
        
        // loop over columns of ref_texture (process 2 pixels at once for better efficiency)
        for (int dx = 0; dx < tile_size; dx+=2) {
            
            ref_tile_x = x0 + dx;
            ref_tile_y = y0 + dy;
            
            tmp_ref0 = max(FLOAT16_ZERO_VAL, ref_texture.read(uint2(ref_tile_x+0, ref_tile_y)).r);
            tmp_ref1 = max(FLOAT16_ZERO_VAL, ref_texture.read(uint2(ref_tile_x+1, ref_tile_y)).r);
              
            // loop over 25 test displacements (5x5 grid)
            for (int i = 0; i < 25; i++) {
                
                dx_i = i % 5; // horizontal displacement (-2 to +2)
                dy_i = i / 5; // vertical displacement (-2 to +2)
                
                // index of corresponding pixel value in tmp_comp
                tmp_index = ((dy+dy_i)%5)*(tile_size+4) + dx + dx_i;
                
                tmp_comp_val0 = tmp_comp[tmp_index+0];
                tmp_comp_val1 = tmp_comp[tmp_index+1];
         
                // Accumulate valid pixel values for mean calculation
                if (tmp_comp_val0 > -1)
                {
                    sum_u[i] += tmp_ref0;
                    sum_v[i] += 2.0f*tmp_comp_val0;
                }
                
                if (tmp_comp_val1 > -1)
                {
                    sum_u[i] += tmp_ref1;
                    sum_v[i] += 2.0f*tmp_comp_val1;
                }
            }
        }
    }
       
    // Calculate exposure ratios for each displacement
    for (int i = 0; i < 25; i++) {
        // calculate ratio of mean values of the tiles, which is used for correction of slight differences in exposure
        // ratio is clamped to reasonable bounds to avoid extreme corrections
        ratio[i] = clamp(sum_u[i]/(sum_v[i]+1e-9), 0.9f, 1.1f);
    }
    
    // Second pass: load comparison texture again and compute the actual differences with exposure correction
        
    // The second pass has the same structure as the first, but now applies the exposure correction
    // and calculates the actual pixel differences
    
    // loop over first 4 rows of comp_texture
    for (int dy = -2; dy < +2; dy++) {
        
        // loop over columns of comp_texture to copy first 4 rows of comp_texture into tmp_comp
        for (int dx = -2; dx < tile_size+2; dx++) {
            
            comp_tile_x = x0 + dx0 + dx;
            comp_tile_y = y0 + dy0 + dy;
            
            // index of corresponding pixel value in tmp_comp
            tmp_index = (dy+2)*(tile_size+4) + dx+2;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                tmp_comp[tmp_index] = FLOAT16_MIN_VAL;
            } else {
                tmp_comp[tmp_index] = max(FLOAT16_ZERO_VAL, FLOAT16_05_VAL * comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r);
            }
        }
    }
    
    // loop over rows of ref_texture
    for (int dy = 0; dy < tile_size; dy++) {
        
        // loop over columns of comp_texture to copy 1 additional row of comp_texture into tmp_comp
        for (int dx = -2; dx < tile_size+2; dx++) {
            
            comp_tile_x = x0 + dx0 + dx;
            comp_tile_y = y0 + dy0 + dy+2;
            
            // index of corresponding pixel value in tmp_comp
            tmp_index = ((dy+4)%5)*(tile_size+4) + dx+2;
            
            // if the comparison pixels are outside of the frame, attach a high loss to them
            if ((comp_tile_x < 0) || (comp_tile_y < 0) || (comp_tile_x >= texture_width) || (comp_tile_y >= texture_height)) {
                tmp_comp[tmp_index] = FLOAT16_MIN_VAL;
            } else {
                tmp_comp[tmp_index] = max(FLOAT16_ZERO_VAL, FLOAT16_05_VAL * comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r);
            }
        }
        
        // loop over columns of ref_texture
        for (int dx = 0; dx < tile_size; dx+=2) {
            
            ref_tile_x = x0 + dx;
            ref_tile_y = y0 + dy;
            
            tmp_ref0 = max(FLOAT16_ZERO_VAL, ref_texture.read(uint2(ref_tile_x+0, ref_tile_y)).r);
            tmp_ref1 = max(FLOAT16_ZERO_VAL, ref_texture.read(uint2(ref_tile_x+1, ref_tile_y)).r);
              
            // loop over 25 test displacements
            for (int i = 0; i < 25; i++) {
                
                dx_i = i % 5;
                dy_i = i / 5;
                
                // index of corresponding pixel value in tmp_comp
                tmp_index = ((dy+dy_i)%5)*(tile_size+4) + dx + dx_i;
                
                // Calculate absolute differences with exposure correction applied
                diff_abs0 = abs(tmp_ref0 - 2.0f*ratio[i]*tmp_comp[tmp_index+0]);
                diff_abs1 = abs(tmp_ref1 - 2.0f*ratio[i]*tmp_comp[tmp_index+1]);
                
                // add difference to corresponding combination
                // the formula uses a weighted combination of L1 norm (abs diff) and L2 norm (squared diff)
                diff[i] += ((1-weight_ssd)*(diff_abs0 + diff_abs1) + weight_ssd*(diff_abs0*diff_abs0 + diff_abs1*diff_abs1));
            }
        }
    }
    
    // store tile differences in texture
    for (int i = 0; i < 25; i++) {
        tile_diff.write(diff[i], uint3(i, gid.x, gid.y));
    }
}

/**
 * @brief Corrects alignment errors that can occur at boundaries between moving objects and static backgrounds
 *
 * At transitions between moving objects and non-moving background, the alignment vectors from downsampled images 
 * may be inaccurate. Therefore, after upsampling to the next resolution level, three candidate alignment vectors 
 * are evaluated for each tile. In addition to the vector obtained from upsampling, two vectors from neighboring 
 * tiles are checked. As a consequence, alignment at the transition regions described above is more accurate.
 * 
 * See section on "Hierarchical alignment" in https://graphics.stanford.edu/papers/hdrp/hasinoff-hdrplus-sigasia16.pdf 
 * and section "Multi-scale Pyramid Alignment" in https://www.ipol.im/pub/art/2021/336/
 *
 * @param ref_texture                Reference texture (usually the "base frame")
 * @param comp_texture               Comparison texture (the frame being aligned to the reference)
 * @param prev_alignment             Previous alignment vectors from coarser scale level
 * @param prev_alignment_corrected   Output texture with corrected alignment vectors
 * @param downscale_factor           Scale factor between current and previous alignment level
 * @param tile_size                  Size of each tile being compared (in pixels)
 * @param n_tiles_x                  Number of tiles in x direction
 * @param n_tiles_y                  Number of tiles in y direction
 * @param uniform_exposure           Flag indicating whether to apply exposure correction (1=no, 0=yes)
 * @param weight_ssd                 Weight for SSD (Sum of Squared Differences) vs L1 norm
 * @param gid                        2D thread position indicating tile coordinates
 */
kernel void correct_upsampling_error(texture2d<half, access::read> ref_texture [[texture(0)]],
                                     texture2d<half, access::read> comp_texture [[texture(1)]],
                                     texture2d<int, access::read> prev_alignment [[texture(2)]],
                                     texture2d<int, access::write> prev_alignment_corrected [[texture(3)]],
                                     constant int& downscale_factor [[buffer(0)]],
                                     constant int& tile_size [[buffer(1)]],
                                     constant int& n_tiles_x [[buffer(2)]],
                                     constant int& n_tiles_y [[buffer(3)]],
                                     constant int& uniform_exposure [[buffer(4)]],
                                     constant int& weight_ssd [[buffer(5)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    int const texture_width = ref_texture.get_width();
    int const texture_height = ref_texture.get_height();
    
    // initialize some variables
    int comp_tile_x, comp_tile_y, tmp_tile_x, tmp_tile_y, weight_outside;
    float diff_abs;
    half tmp_ref[64];
    // ISSUE: Fixed size buffer assumption
    // The buffer size of 64 limits tile_size to 64 or below. For larger tile sizes,
    // this will cause a buffer overflow.
    // FIX: Either enforce a maximum tile size or make the buffer dynamically sized.
    
    // compute tile position if previous alignment were 0
    int const x0 = gid.x*tile_size/2;
    int const y0 = gid.y*tile_size/2;
    
    // calculate shifts of gid index for 3 candidate alignments to evaluate
    int3 const x_shift = int3(0, ((gid.x%2 == 0) ? -1 : 1), 0);
    int3 const y_shift = int3(0, 0, ((gid.y%2 == 0) ? -1 : 1));
    
    int3 const x = clamp(int3(gid.x+x_shift), 0, n_tiles_x-1);
    int3 const y = clamp(int3(gid.y+y_shift), 0, n_tiles_y-1);
    
    // factor in previous alignment for 3 candidates
    int4 const prev_align0 = prev_alignment.read(uint2(x[0], y[0]));
    int4 const prev_align1 = prev_alignment.read(uint2(x[1], y[1]));
    int4 const prev_align2 = prev_alignment.read(uint2(x[2], y[2]));
    
    int3 const dx0 = downscale_factor * int3(prev_align0.x, prev_align1.x, prev_align2.x);
    int3 const dy0 = downscale_factor * int3(prev_align0.y, prev_align1.y, prev_align2.y);
    
    // compute tile differences for 3 candidates
    float diff[3]  = {0.0f, 0.0f, 0.0f};
    float ratio[3] = {1.0f, 1.0f, 1.0f};
    
    // calculate exposure correction factors for slight scaling of pixel intensities
    if (uniform_exposure != 1) {
        
        float sum_u[3] = {0.0f, 0.0f, 0.0f};
        float sum_v[3] = {0.0f, 0.0f, 0.0f};
        
        // loop over all rows
        // ISSUE: Division by tile_size assumption
        // The increment `64/tile_size` assumes that tile_size divides 64 evenly.
        // If tile_size doesn't divide 64 evenly (e.g., tile_size = 48), some rows may be skipped
        // or the loop may not cover all rows properly.
        // FIX: Use a different loop structure that doesn't make this assumption, or ensure
        // that tile_size always divides 64 evenly through validation.
        for (int dy = 0; dy < tile_size; dy += 64/tile_size) {
            
            // copy 64/tile_size rows into temp vector
            for (int i = 0; i < 64; i++) {
                tmp_ref[i] = max(FLOAT16_ZERO_VAL, ref_texture.read(uint2(x0+(i % tile_size), y0+dy+int(i / tile_size))).r);
            }
            
            // loop over three candidates
            for (int c = 0; c < 3; c++) {
                
                // loop over tmp vector: candidate c of alignment vector
                tmp_tile_x = x0 + dx0[c];
                tmp_tile_y = y0 + dy0[c] + dy;
                for (int i = 0; i < 64; i++) {
                    
                    // compute the indices of the pixels to compare
                    comp_tile_x = tmp_tile_x + (i % tile_size);
                    comp_tile_y = tmp_tile_y + int(i / tile_size);
                    
                    if ((comp_tile_x >= 0) && (comp_tile_y >= 0) && (comp_tile_x < texture_width) && (comp_tile_y < texture_height)) {
                        
                        sum_u[c] += tmp_ref[i];
                        sum_v[c] += max(FLOAT16_ZERO_VAL, comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r);
                    }
                }
            }
        }
        
        for (int c = 0; c < 3; c++) {
            // calculate ratio of mean values of the tiles, which is used for correction of slight differences in exposure
            ratio[c] = clamp(sum_u[c]/(sum_v[c]+1e-9), 0.9f, 1.1f);
        }
    }
    
    // loop over all rows
    for (int dy = 0; dy < tile_size; dy += 64/tile_size) {
        
        // copy 64/tile_size rows into temp vector
        for (int i = 0; i < 64; i++) {
            tmp_ref[i] = ref_texture.read(uint2(x0+(i % tile_size), y0+dy+int(i / tile_size))).r;
        }
        
        // loop over three candidates
        for (int c = 0; c < 3; c++) {
            
            // loop over tmp vector: candidate c of alignment vector
            tmp_tile_x = x0 + dx0[c];
            tmp_tile_y = y0 + dy0[c] + dy;
            for (int i = 0; i < 64; i++) {
                
                // compute the indices of the pixels to compare
                comp_tile_x = tmp_tile_x + (i % tile_size);
                comp_tile_y = tmp_tile_y + int(i / tile_size);
                
                // if (comp_tile_x < 0 || comp_tile_y < 0 || comp_tile_x >= texture_width || comp_tile_y >= texture_height) => set weight_outside = 1, else set weight_outside = 0
                weight_outside = clamp(texture_width-comp_tile_x-1, -1, 0) + clamp(texture_height-comp_tile_y-1, -1, 0) + clamp(comp_tile_x, -1, 0) + clamp(comp_tile_y, -1, 0);
                weight_outside = -max(-1, weight_outside);
                
                diff_abs = abs(tmp_ref[i] - (1-weight_outside)*ratio[c]*(comp_texture.read(uint2(comp_tile_x, comp_tile_y)).r) - weight_outside*2*FLOAT16_MIN_VAL);
                
                // add difference to corresponding combination
                diff[c] += (1-weight_ssd)*diff_abs + weight_ssd*diff_abs*diff_abs;
            }
        }
    }
    
    // store corrected (best) alignment
    // ISSUE: Incorrect logical operator
    // The code uses bitwise AND ('&') instead of logical AND ('&&') which can lead to incorrect results.
    // Bitwise operations work on individual bits rather than evaluating the logical truth of expressions.
    // FIX: Replace '&' with '&&' to ensure proper logical evaluation.
    if(diff[0] < diff[1] && diff[0] < diff[2]) {
        prev_alignment_corrected.write(prev_align0, gid);
        
    } else if(diff[1] < diff[2]) {
        prev_alignment_corrected.write(prev_align1, gid);
        
    } else {
        prev_alignment_corrected.write(prev_align2, gid);
    }
}

/**
 * @brief Finds the alignment vector with the lowest difference value
 *
 * After computing the differences for all possible displacements in the search space,
 * this kernel identifies the displacement that results in the minimum difference, which
 * represents the best alignment between frames for the current tile.
 *
 * @param tile_diff         Input texture containing difference values for each displacement
 * @param prev_alignment    Previous alignment vectors from coarser scale level
 * @param current_alignment Output texture storing the best alignment vectors
 * @param downscale_factor  Scale factor between current and previous alignment level
 * @param search_dist       Maximum search distance for alignment vectors
 * @param gid              2D thread position indicating tile coordinates
 */
kernel void find_best_tile_alignment(texture3d<float, access::read> tile_diff [[texture(0)]],
                                     texture2d<int, access::read> prev_alignment [[texture(1)]],
                                     texture2d<int, access::write> current_alignment [[texture(2)]],
                                     constant int& downscale_factor [[buffer(0)]],
                                     constant int& search_dist [[buffer(1)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    // load args
    int const n_pos_1d = 2*search_dist + 1;
    int const n_pos_2d = n_pos_1d * n_pos_1d;
    
    // find tile displacement with the lowest pixel difference
    float current_diff;
    float min_diff_val = 1e20f;
    int min_diff_idx = 0;
    
    for (int i = 0; i < n_pos_2d; i++) {
        current_diff = tile_diff.read(uint3(i, gid.x, gid.y)).r;
        if (current_diff < min_diff_val) {
            min_diff_val = current_diff;
            min_diff_idx = i;
        }
    }
    
    // compute tile displacement if previous alignment were 0
    int const dx = min_diff_idx % n_pos_1d - search_dist;
    int const dy = min_diff_idx / n_pos_1d - search_dist;
    
    // factor in previous alignment
    int4 const prev_align = downscale_factor * prev_alignment.read(gid);
    
    // store alignment
    int4 const out = int4(prev_align.x+dx, prev_align.y+dy, 0, 0);
    current_alignment.write(out, gid);
}

/**
 * @brief Warps a Bayer pattern texture based on the computed alignment vectors
 *
 * This kernel applies the computed alignment vectors to transform the input texture,
 * effectively aligning it with the reference frame. It uses bilinear interpolation
 * between tile centers to ensure smooth transitions in the alignment field.
 * This version is optimized for Bayer pattern images.
 *
 * @param in_texture       Input texture to be warped
 * @param out_texture      Output texture after warping
 * @param prev_alignment   Alignment vectors to apply
 * @param downscale_factor Scale factor for the alignment vectors
 * @param half_tile_size   Half the size of the alignment tiles
 * @param n_tiles_x        Number of tiles in x direction
 * @param n_tiles_y        Number of tiles in y direction
 * @param gid              2D thread position (output pixel coordinate)
 */
kernel void warp_texture_bayer(texture2d<float, access::read> in_texture [[texture(0)]],
                               texture2d<float, access::write> out_texture [[texture(1)]],
                               texture2d<int, access::read> prev_alignment [[texture(2)]],
                               constant int& downscale_factor [[buffer(0)]],
                               constant int& half_tile_size [[buffer(1)]],
                               constant int& n_tiles_x [[buffer(2)]],
                               constant int& n_tiles_y [[buffer(3)]],
                               uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    int const x = gid.x;
    int const y = gid.y;
    float const half_tile_size_float = float(half_tile_size);
    
    // compute the coordinates of output pixel in tile-grid units
    float const x_grid = (x+0.5f)/half_tile_size_float - 1.0f;
    float const y_grid = (y+0.5f)/half_tile_size_float - 1.0f;
    
    int const x_grid_floor = int(max(0.0f, floor(x_grid)) + 0.1f);
    int const y_grid_floor = int(max(0.0f, floor(y_grid)) + 0.1f);
    int const x_grid_ceil  = int(min(ceil(x_grid), n_tiles_x-1.0f) + 0.1f);
    int const y_grid_ceil  = int(min(ceil(y_grid), n_tiles_y-1.0f) + 0.1f);
    
    // weights calculated for the bilinear interpolation
    float const weight_x = ((x % half_tile_size) + 0.5f)/(2.0f*half_tile_size_float);
    float const weight_y = ((y % half_tile_size) + 0.5f)/(2.0f*half_tile_size_float);
    
    // factor in alignment
    int4 const prev_align0 = downscale_factor * prev_alignment.read(uint2(x_grid_floor, y_grid_floor));
    int4 const prev_align1 = downscale_factor * prev_alignment.read(uint2(x_grid_ceil,  y_grid_floor));
    int4 const prev_align2 = downscale_factor * prev_alignment.read(uint2(x_grid_floor, y_grid_ceil));
    int4 const prev_align3 = downscale_factor * prev_alignment.read(uint2(x_grid_ceil,  y_grid_ceil));
    
    // alignment vector from tile 0
    float pixel_value  = (1.0f-weight_x)*(1.0f-weight_y) * in_texture.read(uint2(x+prev_align0.x, y+prev_align0.y)).r;
    float total_weight = (1.0f-weight_x)*(1.0f-weight_y);
    
    // alignment vector from tile 1
    pixel_value  += weight_x*(1.0f-weight_y) * in_texture.read(uint2(x+prev_align1.x, y+prev_align1.y)).r;
    total_weight += weight_x*(1.0f-weight_y);
    
    // alignment vector from tile 2
    pixel_value  += (1.0f-weight_x)*weight_y * in_texture.read(uint2(x+prev_align2.x, y+prev_align2.y)).r;
    total_weight += (1.0f-weight_x)*weight_y;
    
    // alignment vector from tile 3
    pixel_value  += weight_x*weight_y * in_texture.read(uint2(x+prev_align3.x, y+prev_align3.y)).r;
    total_weight += weight_x*weight_y;
    
    // write output pixel
    // ISSUE: Division by zero risk
    // There's no check for zero total_weight before division, which could lead to undefined behavior
    // if all sampling points are invalid or weights become zero.
    // FIX: Add a check to handle the case where total_weight is zero, such as:
    // float out_intensity = (total_weight > 0.0f) ? (pixel_value / total_weight) : 0.0f;
    float out_intensity = pixel_value / total_weight;
    out_texture.write(out_intensity, gid);
}


/**
 * @brief Warps an X-Trans pattern texture based on the computed alignment vectors
 *
 * This kernel applies the computed alignment vectors to transform the input texture,
 * effectively aligning it with the reference frame. It uses a weighted interpolation
 * scheme that's specialized for X-Trans sensor pattern images (used in Fujifilm cameras).
 * The algorithm considers multiple neighboring tiles and applies weights based on the
 * distance from tile centers.
 *
 * @param in_texture       Input texture to be warped
 * @param out_texture      Output texture after warping
 * @param prev_alignment   Alignment vectors to apply
 * @param downscale_factor Scale factor for the alignment vectors
 * @param tile_size        Size of each tile being compared (in pixels)
 * @param n_tiles_x        Number of tiles in x direction
 * @param n_tiles_y        Number of tiles in y direction
 * @param gid              2D thread position (output pixel coordinate)
 */
kernel void warp_texture_xtrans(texture2d<float, access::read> in_texture [[texture(0)]],
                                texture2d<float, access::read_write> out_texture [[texture(1)]],
                                texture2d<int, access::read> prev_alignment [[texture(2)]],
                                constant int& downscale_factor [[buffer(0)]],
                                constant int& tile_size [[buffer(1)]],
                                constant int& n_tiles_x [[buffer(2)]],
                                constant int& n_tiles_y [[buffer(3)]],
                                uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    int texture_width = in_texture.get_width();
    int texture_height = in_texture.get_height();
    int tile_half_size = tile_size / 2;
    
    // load coordinates of output pixel
    int x1_pix = gid.x;
    int y1_pix = gid.y;
    
    // compute the coordinates of output pixel in tile-grid units
    float x1_grid = float(x1_pix - tile_half_size) / float(texture_width  - tile_size - 1) * (n_tiles_x - 1);
    float y1_grid = float(y1_pix - tile_half_size) / float(texture_height - tile_size - 1) * (n_tiles_y - 1);
    
    // compute the four possible tile-grid indices that the given output pixel might belong to
    // (this handles the case of pixels near tile boundaries)
    int x_grid_list[] = {int(floor(x1_grid)), int(floor(x1_grid)), int(ceil (x1_grid)), int(ceil(x1_grid))};
    int y_grid_list[] = {int(floor(y1_grid)), int(ceil (y1_grid)), int(floor(y1_grid)), int(ceil(y1_grid))};
    
    // loop over the four possible tile-grid indices to apply weighted alignment
    float total_intensity = 0;
    float total_weight = 0;
    for (int i = 0; i < 4; i++){
        
        // load the index of the tile
        int x_grid = x_grid_list[i];
        int y_grid = y_grid_list[i];
        
        // compute the pixel coordinates of the center of the reference tile
        int x0_pix = int(floor( tile_half_size + float(x_grid)/float(n_tiles_x-1) * (texture_width  - tile_size - 1) ));
        int y0_pix = int(floor( tile_half_size + float(y_grid)/float(n_tiles_y-1) * (texture_height - tile_size - 1) ));
        
        // check that the output pixel falls within the reference tile
        if ((abs(x1_pix - x0_pix) <= tile_half_size) && (abs(y1_pix - y0_pix) <= tile_half_size)) {
            
            // compute tile displacement
            int4 prev_align = prev_alignment.read(uint2(x_grid, y_grid));
            int dx = downscale_factor * prev_align.x;
            int dy = downscale_factor * prev_align.y;

            // load coordinates of the corresponding pixel from the comparison tile
            int x2_pix = x1_pix + dx;
            int y2_pix = y1_pix + dy;
            
            // compute the weight of the aligned pixel (based on distance from tile center)
            // pixels closer to the center have higher weight
            int dist_x = abs(x1_pix - x0_pix);
            int dist_y = abs(y1_pix - y0_pix);
            float weight_x = tile_size - dist_x - dist_y;
            float weight_y = tile_size - dist_x - dist_y;
            float curr_weight = weight_x * weight_y;
            total_weight += curr_weight;
            
            // add pixel value to the output
            total_intensity += curr_weight * in_texture.read(uint2(x2_pix, y2_pix)).r;
        }
    }
    
    // write output pixel
    // ISSUE: Division by zero risk
    // There's no check for zero total_weight before division. If no valid pixels are found
    // (e.g., all sampled points are outside the reference tiles), total_weight could be zero,
    // leading to undefined behavior.
    // FIX: Add a check to handle this case, such as:
    // float out_intensity = (total_weight > 0.0f) ? (total_intensity / total_weight) : 0.0f;
    float out_intensity = total_intensity / total_weight;
    out_texture.write(out_intensity, uint2(x1_pix, y1_pix));
}
