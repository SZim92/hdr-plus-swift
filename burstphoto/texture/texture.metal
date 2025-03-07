/**
 * Texture Processing Kernels for Burst Photography
 *
 * This file contains Metal compute shaders that handle various texture operations
 * used in the burst photography pipeline. These kernels perform operations like:
 * - Adding and merging multiple frame textures
 * - Blurring and filtering operations
 * - Exposure correction and highlight handling
 * - Format conversion between different representations (Bayer/RGBA)
 * - Hot pixel detection and correction for different sensor types
 * - Various utility operations for texture processing
 *
 * The operations support both Bayer pattern sensors (common in most cameras)
 * and X-Trans sensors (used in Fujifilm cameras).
 */
#include <metal_stdlib>
#include "../misc/constants.h"
using namespace metal;


/**
 * Adds the content of one texture to another with normalization.
 *
 * Divides each pixel value from the input texture by n_textures before adding 
 * to the corresponding pixel in the output texture. This is typically used when
 * merging multiple aligned frames to create an average.
 *
 * Parameters:
 *   - in_texture: Source texture to add from
 *   - out_texture: Destination texture to add to
 *   - n_textures: Number of textures being merged (for normalization)
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void add_texture(texture2d<float, access::read> in_texture [[texture(0)]],
                        texture2d<float, access::read_write> out_texture [[texture(1)]],
                        constant float& n_textures [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    
    float const color_value = out_texture.read(gid).r + in_texture.read(gid).r/n_textures;
    
    out_texture.write(color_value, gid);
}


/**
 * Adds a texture with adaptive weighting based on exposure and highlight characteristics.
 *
 * This kernel implements a sophisticated merging approach that considers:
 * - Exposure differences between frames
 * - Luminance-based weighting (stronger in shadows, weaker in highlights)
 * - Highlight preservation using pre-computed weights
 * 
 * The algorithm applies variable weights to optimize noise reduction while preserving detail
 * in areas with different exposure levels or potential motion.
 *
 * Parameters:
 *   - in_texture: Source texture to be added
 *   - in_texture_blurred: Blurred version of source for luminance calculations
 *   - weight_highlights_texture: Contains weights for highlight regions
 *   - out_texture: Destination texture where values are accumulated
 *   - norm_texture: Texture to track accumulated weights for later normalization
 *   - exposure_bias: Exposure difference in 1/100 stops
 *   - white_level: Maximum possible pixel value
 *   - black_level_mean: Average black level
 *   - color_factor_mean: Average color correction factor
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void add_texture_exposure(texture2d<float, access::read> in_texture [[texture(0)]],
                                 texture2d<float, access::read> in_texture_blurred [[texture(1)]],
                                 texture2d<float, access::read> weight_highlights_texture [[texture(2)]],
                                 texture2d<float, access::read_write> out_texture [[texture(3)]],
                                 texture2d<float, access::read_write> norm_texture [[texture(4)]],
                                 constant int& exposure_bias [[buffer(0)]],
                                 constant float& white_level [[buffer(1)]],
                                 constant float& black_level_mean [[buffer(2)]],
                                 constant float& color_factor_mean [[buffer(3)]],
                                 uint2 gid [[thread_position_in_grid]]) {
       
    // calculate weight based on exposure bias
    float weight_exposure = pow(2.0f, float(exposure_bias/100.0f));
    
    // extract pixel value
    float pixel_value = in_texture.read(gid).r;
    
    // adapt exposure weight based on the luminosity of each pixel relative to the white level
    float luminance = min(white_level, in_texture_blurred.read(gid).r/color_factor_mean);
    luminance = (luminance-black_level_mean)/white_level;
    
    // shadows get the exposure-dependent weight for optimal noise reduction while midtones and highlights have a reduced weight for better motion robustness
    // between 0.25 and 1.00 of the white level (based on pixel values after exposure correction), the weight becomes 1.0    
    weight_exposure = max(sqrt(weight_exposure), weight_exposure * pow(weight_exposure, -0.5f/(0.25f-black_level_mean/white_level)*luminance));
   
    // ensure smooth blending for pixel values between 0.25 and 0.99 of the white level (based on pixel values before exposure correction)
    float const weight_highlights = weight_highlights_texture.read(gid).r;
       
    // apply optimal weight based on exposure of pixel and take into account weight based on the pixel intensity
    pixel_value = weight_exposure*weight_highlights * pixel_value;
    
    out_texture.write(out_texture.read(gid).r + pixel_value, gid);
    
    norm_texture.write(norm_texture.read(gid).r + weight_exposure*weight_highlights, gid);
}


/**
 * Adds a texture with special processing for highlight regions in Bayer pattern sensors.
 *
 * This kernel processes 2x2 Bayer quads (RGGB), identifying bright regions where highlights
 * might be clipped. When potential highlight clipping is detected in green channels, it
 * extrapolates more accurate values using surrounding red and blue pixels to recover detail.
 *
 * The algorithm specifically handles the two green channels in the Bayer pattern separately,
 * applying intelligent blending based on how close the pixel values are to clipping.
 *
 * Parameters:
 *   - in_texture: Source texture to add with highlight processing
 *   - out_texture: Destination texture where values are accumulated
 *   - white_level: Maximum possible pixel value
 *   - black_level_mean: Average black level
 *   - factor_red: Color correction factor for red channel
 *   - factor_blue: Color correction factor for blue channel
 *   - gid: Thread position in grid (each thread processes a 2x2 Bayer quad)
 */
kernel void add_texture_highlights(texture2d<float, access::read> in_texture [[texture(0)]],
                                   texture2d<float, access::read_write> out_texture [[texture(1)]],
                                   constant float& white_level [[buffer(0)]],
                                   constant float& black_level_mean [[buffer(1)]],
                                   constant float& factor_red [[buffer(2)]],
                                   constant float& factor_blue [[buffer(3)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    
    // load args
    int texture_width  = in_texture.get_width();
    int texture_height = in_texture.get_height();
    
    int const x = gid.x*2;
    int const y = gid.y*2;
    
    float pixel_value4, pixel_value5, pixel_ratio4, pixel_ratio5, pixel_count, extrapolated_value, weight;
    
    // extract pixel values of 2x2 super pixel
    float pixel_value0 = in_texture.read(uint2(x  , y)).r;
    float pixel_value1 = in_texture.read(uint2(x+1, y)).r;
    float pixel_value2 = in_texture.read(uint2(x,   y+1)).r;
    float pixel_value3 = in_texture.read(uint2(x+1, y+1)).r;
    
    // calculate ratio of pixel value and white level
    float const pixel_ratio0 = (pixel_value0-black_level_mean)/(white_level-black_level_mean);
    float const pixel_ratio1 = (pixel_value1-black_level_mean)/(white_level-black_level_mean);
    float const pixel_ratio2 = (pixel_value2-black_level_mean)/(white_level-black_level_mean);
    float const pixel_ratio3 = (pixel_value3-black_level_mean)/(white_level-black_level_mean);
    
    // process first green channel if a bright pixel is detected
    if (pixel_ratio1 > 0.8f) {
                       
        pixel_value4 = pixel_value5 = 0.0f;
        pixel_ratio4 = pixel_ratio5 = 0.0f;
        pixel_count = 2.0f;
        
        // extract additional pixel close to the green pixel
        if (x+2 < texture_width) {
            pixel_value4 = in_texture.read(uint2(x+2, y)).r;
            pixel_ratio4 = (pixel_value4-black_level_mean)/(white_level-black_level_mean);
            pixel_count += 1.0f;
        }
        
        // extract additional pixel close to the green pixel
        if (y-1 >= 0) {
            pixel_value5 = in_texture.read(uint2(x+1, y-1)).r;
            pixel_ratio5 = (pixel_value5-black_level_mean)/(white_level-black_level_mean);
            pixel_count += 1.0f;
        }
        
        // if at least one surrounding pixel is above the normalized clipping threshold for the respective color channel
        if (pixel_ratio0 > 0.99f*factor_red || pixel_ratio3 > 0.99f*factor_blue || pixel_ratio4 > 0.99f*factor_red || pixel_ratio5 > 0.99f*factor_blue) {
            
            // extrapolate green pixel from surrounding red and blue pixels
            extrapolated_value = ((pixel_value0+pixel_value4)/factor_red + (pixel_value3+pixel_value5)/factor_blue)/pixel_count;
            
            // calculate weight for blending the extrapolated value and the original pixel value
            weight = 0.9f - 4.5f*clamp(1.0f-pixel_ratio1, 0.0f, 0.2f);
            
            pixel_value1 = weight*max(extrapolated_value, pixel_value1) + (1.0f-weight)*pixel_value1;
        }
    }
    
    // process second green channel if a bright pixel is detected
    if (pixel_ratio2 > 0.8f) {
           
        pixel_value4 = pixel_value5 = 0.0f;
        pixel_ratio4 = pixel_ratio5 = 0.0f;
        pixel_count = 2.0f;
        
        // extract additional pixel close to the green pixel
        if (x-1 >= 0) {
            pixel_value4 = in_texture.read(uint2(x-1, y+1)).r;
            pixel_ratio4 = (pixel_value4-black_level_mean)/(white_level-black_level_mean);
            pixel_count += 1.0f;
        }
        
        // extract additional pixel close to the green pixel
        if (y+2 < texture_height) {
            pixel_value5 = in_texture.read(uint2(x  , y+2)).r;
            pixel_ratio5 = (pixel_value5-black_level_mean)/(white_level-black_level_mean);
            pixel_count += 1.0f;
        }
        
        // if at least one surrounding pixel is above the normalized clipping threshold for the respective color channel
        if (pixel_ratio0 > 0.99f*factor_red || pixel_ratio3 > 0.99f*factor_blue || pixel_ratio5 > 0.99f*factor_red || pixel_ratio4 > 0.99f*factor_blue) {
            
            // extrapolate green pixel from surrounding red and blue pixels
            extrapolated_value = ((pixel_value0+pixel_value5)/factor_red + (pixel_value3+pixel_value4)/factor_blue)/pixel_count;
            
            // calculate weight for blending the extrapolated value and the original pixel value
            weight = 0.9f - 4.5f*clamp(1.0f-pixel_ratio2, 0.0f, 0.2f);
            
            pixel_value2 = weight*max(extrapolated_value, pixel_value2) + (1.0f-weight)*pixel_value2;
        }
    }
    
    pixel_value0 = out_texture.read(uint2(x  , y)).r   + pixel_value0;
    pixel_value1 = out_texture.read(uint2(x+1, y)).r   + pixel_value1;
    pixel_value2 = out_texture.read(uint2(x  , y+1)).r + pixel_value2;
    pixel_value3 = out_texture.read(uint2(x+1, y+1)).r + pixel_value3;
    
    out_texture.write(pixel_value0, uint2(x  , y));
    out_texture.write(pixel_value1, uint2(x+1, y));
    out_texture.write(pixel_value2, uint2(x  , y+1));
    out_texture.write(pixel_value3, uint2(x+1, y+1));
}


/**
 * Adds a uint16 texture to a float texture with normalization.
 *
 * Converts unsigned integer pixel values to float, divides by the total number of textures,
 * and adds the result to the corresponding pixel in the output texture. This is used when
 * working with raw sensor data that may be stored in uint16 format.
 *
 * Parameters:
 *   - in_texture: Source texture in uint format
 *   - out_texture: Destination texture in float format
 *   - n_textures: Number of textures being merged (for normalization)
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void add_texture_uint16(texture2d<uint, access::read> in_texture [[texture(0)]],
                               texture2d<float, access::read_write> out_texture [[texture(1)]],
                               constant float& n_textures [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    
    float const color_value = out_texture.read(gid).r + float(in_texture.read(gid).r)/n_textures;
    
    out_texture.write(color_value, gid);
}


/**
 * Blends two textures using a weight texture to control the blending.
 *
 * For each pixel, performs linear interpolation between texture1 and texture2
 * using the corresponding weight value from the weight_texture. A weight of 0 means
 * use only texture1, a weight of 1 means use only texture2, and values between
 * result in a proportional blend.
 *
 * Parameters:
 *   - texture1: First input texture (base texture)
 *   - texture2: Second input texture (to be blended with texture1)
 *   - weight_texture: Contains weight values [0-1] for each pixel
 *   - out_texture: Output texture for the blended result
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void add_texture_weighted(texture2d<float, access::read> texture1 [[texture(0)]],
                                 texture2d<float, access::read> texture2 [[texture(1)]],
                                 texture2d<float, access::read> weight_texture [[texture(2)]],
                                 texture2d<float, access::write> out_texture [[texture(3)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    
    float const intensity1 = texture1.read(gid).r;
    float const intensity2 = texture2.read(gid).r;
    float const weight = weight_texture.read(gid).r;
    
    float const out_intensity = weight * intensity2 + (1 - weight) * intensity1;
    out_texture.write(out_intensity, gid);
}


/**
 * Applies a 1D binomial blur to a texture in either horizontal or vertical direction.
 *
 * This kernel implements a high-quality, separable blur filter using binomial coefficients
 * that approximates a Gaussian blur. It respects the mosaic pattern of the sensor by
 * stepping over complete pattern blocks instead of individual pixels.
 *
 * The kernel size determines the extent of the blur with precomputed weights for various
 * kernel sizes. For efficiency, the kernel weights are truncated where their contribution
 * becomes negligible (less than 0.25% of total).
 *
 * Parameters:
 *   - in_texture: Input texture to be blurred
 *   - out_texture: Output texture for the blurred result
 *   - kernel_size: Size parameter controlling blur intensity
 *   - mosaic_pattern_width: Width of the sensor's mosaic pattern (e.g., 2 for Bayer)
 *   - texture_size: Size of the texture in the current blur direction
 *   - direction: 0 for horizontal blur, 1 for vertical blur
 *   - gid: Thread position in grid (one thread per output pixel)
 */
kernel void blur_mosaic_texture(texture2d<float, access::read> in_texture [[texture(0)]],
                                texture2d<float, access::write> out_texture [[texture(1)]],
                                constant int& kernel_size [[buffer(0)]],
                                constant int& mosaic_pattern_width [[buffer(1)]],
                                constant int& texture_size [[buffer(2)]],
                                constant int& direction [[buffer(3)]],
                                uint2 gid [[thread_position_in_grid]]) {
    
    // set kernel weights of binomial filter for identity operation
    float bw[9] = {1, 0, 0, 0, 0, 0, 0, 0, 0};
    int kernel_size_trunc = kernel_size;
    
    // to speed up calculations, kernels are truncated in such a way that the total contribution of removed weights is smaller than 0.25%
    if (kernel_size== 1)      {bw[0]=    2; bw[1]=    1;}
    else if (kernel_size== 2) {bw[0]=    6; bw[1]=    4; bw[2]=   1;}
    else if (kernel_size== 3) {bw[0]=   20; bw[1]=   15; bw[2]=   6; bw[3]=   1;}
    else if (kernel_size== 4) {bw[0]=   70; bw[1]=   56; bw[2]=  28; bw[3]=   8; bw[4]=   1;}
    else if (kernel_size== 5) {bw[0]=  252; bw[1]=  210; bw[2]= 120; bw[3]=  45; bw[4]=  10; kernel_size_trunc=4;}
    else if (kernel_size== 6) {bw[0]=  924; bw[1]=  792; bw[2]= 495; bw[3]= 220; bw[4]=  66; bw[5]= 12; kernel_size_trunc=5;}
    else if (kernel_size== 7) {bw[0]= 3432; bw[1]= 3003; bw[2]=2002; bw[3]=1001; bw[4]= 364; bw[5]= 91; kernel_size_trunc=5;}
    else if (kernel_size== 8) {bw[0]=12870; bw[1]=11440; bw[2]=8008; bw[3]=4368; bw[4]=1820; bw[5]=560; bw[6]=120; kernel_size_trunc=6;}
    else if (kernel_size==16) {bw[0]=601080390; bw[1]=565722720; bw[2]=471435600; bw[3]=347373600; bw[4]=225792840; bw[5]=129024480; bw[6]=64512240; bw[7]=28048800; bw[8]=10518300; kernel_size_trunc=8;}
    
    // compute a single output pixel
    float total_intensity = 0.0f;
    float total_weight = 0.0f;
    float weight;
    
    // direction = 0: blurring in x-direction, direction = 1: blurring in y-direction
    uint2 xy;
    xy[1-direction] = gid[1-direction];
    int const i0 = gid[direction];
    
    for (int di = -kernel_size_trunc; di <= kernel_size_trunc; di++) {
        int i = i0 + mosaic_pattern_width*di;
        if (0 <= i && i < texture_size) {
           
            xy[direction] = i;
            weight = bw[abs(di)];
            total_intensity += weight * in_texture.read(xy).r;
            total_weight += weight;
        }
    }
    
    // write output pixel
    float const out_intensity = total_intensity / total_weight;
    out_texture.write(out_intensity, gid);
}


/**
 * Calculates weights for highlight handling based on local maximum pixel values.
 *
 * This kernel examines a neighborhood around each pixel to find the maximum intensity,
 * then calculates a weight that will be used during merging to prevent highlight clipping.
 * As pixel values approach the white level, their weight decreases, allowing better
 * highlight preservation when merging frames with different exposures.
 *
 * Parameters:
 *   - in_texture: Input texture containing the image data
 *   - weight_highlights_texture: Output texture to store the calculated weights
 *   - exposure_bias: Exposure difference between frames in 1/100 stops
 *   - white_level: Maximum possible pixel value
 *   - black_level_mean: Average black level
 *   - kernel_size: Size of neighborhood to examine for maximum finding
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void calculate_weight_highlights(texture2d<float, access::read> in_texture [[texture(0)]],
                                        texture2d<float, access::write> weight_highlights_texture [[texture(1)]],
                                        constant int& exposure_bias [[buffer(0)]],
                                        constant float& white_level [[buffer(1)]],
                                        constant float& black_level_mean [[buffer(2)]],
                                        constant int& kernel_size [[buffer(3)]],
                                        uint2 gid [[thread_position_in_grid]]) {
       
    // load args
    int texture_width  = in_texture.get_width();
    int texture_height = in_texture.get_height();
    
    // calculate weight based on exposure bias
    float const weight_exposure = pow(2.0f, float(exposure_bias/100.0f));
    
    // find the maximum intensity in a 5x5 window around the main pixel
    float pixel_value_max = 0.0f;
      
    for (int dy = -kernel_size; dy <= kernel_size; dy++) {
        int y = gid.y + dy;
        
        if (0 <= y && y < texture_height) {
            for (int dx = -kernel_size; dx <= kernel_size; dx++) {
                int x = gid.x + dx;
                
                if (0 <= x && x < texture_width) {
                    pixel_value_max = max(pixel_value_max, in_texture.read(uint2(x, y)).r);
                }
            }
        }
    }
    
    pixel_value_max = (pixel_value_max-black_level_mean)*weight_exposure + black_level_mean;

    // ensure smooth blending for pixel values between 0.25 and 0.99 of the white level (based on pixel values before exposure correction)
    float const weight_highlights = clamp(0.99f/0.74f-1.0f/0.74f*pixel_value_max/white_level, 0.0f, 1.0f);
      
    weight_highlights_texture.write(weight_highlights, gid);
}


/**
 * Converts floating-point pixel values to 16-bit unsigned integers.
 *
 * This kernel handles the conversion from the internal floating-point representation
 * to 16-bit integer format, applying black level correction, scaling, and clamping
 * to ensure values stay within appropriate bounds. It handles the mosaic pattern
 * of the sensor by using appropriate black levels for each position in the pattern.
 *
 * Parameters:
 *   - in_texture: Input texture with floating-point values
 *   - out_texture: Output texture for 16-bit unsigned integer values
 *   - white_level: Maximum pixel value to clamp against
 *   - factor_16bit: Scaling factor for conversion to 16-bit range
 *   - mosaic_pattern_width: Width of the sensor's mosaic pattern
 *   - black_levels: Array of black level values for each position in the mosaic pattern
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void convert_float_to_uint16(texture2d<float, access::read>  in_texture  [[texture(0)]],
                                    texture2d<uint,  access::write> out_texture [[texture(1)]],
                                    constant int& white_level           [[buffer(0)]],
                                    constant int& factor_16bit          [[buffer(1)]],
                                    constant int& mosaic_pattern_width  [[buffer(2)]],
                                    constant int* black_levels          [[buffer(3)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    // load args
    float const black_level = black_levels[(gid.x % mosaic_pattern_width) + mosaic_pattern_width * (gid.y % mosaic_pattern_width)];

    // apply potential scaling to 16 bit and convert to integer
    int out_value = int(round(factor_16bit*(in_texture.read(gid).r - black_level) + black_level));
    out_value     = clamp(out_value, 0, min(white_level, int(UINT16_MAX_VAL)));
    
    // write back into texture
    out_texture.write(uint(out_value), gid);
}


/**
 * Converts an RGBA texture back to Bayer pattern format.
 *
 * This kernel unpacks a texture where each RGBA pixel contains data for a 2x2 Bayer quad
 * back into the raw Bayer format with one value per pixel. Each component of the RGBA
 * value is written to its corresponding position in the 2x2 grid of the output texture.
 *
 * Parameters:
 *   - in_texture: Input RGBA texture where each pixel represents a 2x2 Bayer quad
 *   - out_texture: Output texture in raw Bayer pattern format
 *   - gid: Thread position in grid (each thread handles one 2x2 block)
 */
kernel void convert_to_bayer(texture2d<float, access::read> in_texture [[texture(0)]],
                             texture2d<float, access::write> out_texture [[texture(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    int const x = gid.x*2;
    int const y = gid.y*2;
    
    float4 const color_value = in_texture.read(uint2(gid.x, gid.y));
     
    out_texture.write(color_value[0], uint2(x,   y));
    out_texture.write(color_value[1], uint2(x+1, y));
    out_texture.write(color_value[2], uint2(x,   y+1));
    out_texture.write(color_value[3], uint2(x+1, y+1));
}


/**
 * Converts a Bayer pattern texture to RGBA format.
 *
 * This kernel packs a 2x2 Bayer quad into a single RGBA pixel, which is more efficient for
 * certain processing operations. Each pixel in the output contains the values from a 2x2
 * block of the input, with optional padding handling to account for borders.
 *
 * Parameters:
 *   - in_texture: Input texture in raw Bayer pattern format
 *   - out_texture: Output RGBA texture where each pixel represents a 2x2 Bayer quad
 *   - pad_left: Left padding offset to adjust sampling position
 *   - pad_top: Top padding offset to adjust sampling position
 *   - gid: Thread position in grid (each thread produces one RGBA pixel)
 */
kernel void convert_to_rgba(texture2d<float, access::read> in_texture [[texture(0)]],
                            texture2d<float, access::write> out_texture [[texture(1)]],
                            constant int& pad_left [[buffer(0)]],
                            constant int& pad_top [[buffer(1)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    int const x = gid.x*2 + pad_left;
    int const y = gid.y*2 + pad_top;
    
    float4 const color_value = float4(in_texture.read(uint2(x, y)).r,   in_texture.read(uint2(x+1, y)).r,
                                      in_texture.read(uint2(x, y+1)).r, in_texture.read(uint2(x+1, y+1)).r);
    
    out_texture.write(color_value, gid);
}


/**
 * Simple utility to copy the contents of one texture to another.
 *
 * This straightforward kernel reads each pixel from the input texture and writes
 * the same value to the corresponding pixel in the output texture.
 *
 * Parameters:
 *   - in_texture: Source texture to copy from
 *   - out_texture: Destination texture to copy to
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void copy_texture(texture2d<float, access::read> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    out_texture.write(in_texture.read(gid), gid);
}


/**
 * Crops a texture by removing padding from the edges.
 *
 * This kernel extracts a region from the input texture by offsetting the read
 * coordinates by the specified padding values. It's used to remove padding that
 * may have been added for alignment or processing purposes.
 *
 * Parameters:
 *   - in_texture: Input texture to crop
 *   - out_texture: Output texture for the cropped result
 *   - pad_left: Left padding to remove
 *   - pad_top: Top padding to remove
 *   - gid: Thread position in grid (corresponding to output pixel coordinates)
 */
kernel void crop_texture(texture2d<float, access::read> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(1)]],
                         constant int& pad_left [[buffer(0)]],
                         constant int& pad_top [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
      
    int x = gid.x + pad_left;
    int y = gid.y + pad_top;
  
    float const color_value = in_texture.read(uint2(x, y)).r;
    out_texture.write(color_value, gid);
}


/**
 * Initializes a texture by filling it with zeros.
 *
 * This simple kernel sets every pixel in the texture to zero. It's typically used
 * to prepare a texture for accumulation operations or to clear previous content.
 *
 * Parameters:
 *   - texture: The texture to be filled with zeros
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void fill_with_zeros(texture2d<float, access::write> texture [[texture(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    texture.write(0, gid);
}


/**
 Hot pixel identification for Bayer images.
 Note: A 2-pixel wide border of the image is NOT analyzed in order to make the algorithm simpler.
 */
kernel void find_hotpixels_bayer(texture2d<float, access::read>  average_texture         [[texture(0)]],
                                 texture2d<float, access::write> hotpixel_weight_texture [[texture(1)]],
                                 constant float* mean_texture_buffer     [[buffer(0)]],
                                 constant float* black_levels            [[buffer(1)]],
                                 constant float& hot_pixel_threshold     [[buffer(2)]],
                                 constant float& hot_pixel_multiplicator [[buffer(3)]],
                                 constant float& correction_strength     [[buffer(4)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    // +2 to offset from top-left edge in order to calculate sum of neighbouring pixels
    int const x = gid.x+2;
    int const y = gid.y+2;
    
    // extract color channel-dependent mean value of the average texture of all images and the black level
    int const ix = x % 2;
    int const iy = y % 2;
    float const black_level  = float(black_levels[ix + 2*iy]);
    float const mean_texture = mean_texture_buffer[ix + 2*iy] - black_level;
        
    // calculate weighted sum of 8 pixels surrounding the potential hot pixel based on the average texture
    float sum =   average_texture.read(uint2(x-2, y-2)).r;
    sum      +=   average_texture.read(uint2(x+2, y-2)).r;
    sum      +=   average_texture.read(uint2(x-2, y+2)).r;
    sum      +=   average_texture.read(uint2(x+2, y+2)).r;
    sum      += 2*average_texture.read(uint2(x-2, y+0)).r;
    sum      += 2*average_texture.read(uint2(x+2, y+0)).r;
    sum      += 2*average_texture.read(uint2(x+0, y-2)).r;
    sum      += 2*average_texture.read(uint2(x+0, y+2)).r;
    
    sum /= 12.0;
    
    // extract value of potential hot pixel from the average texture and divide by sum of surrounding pixels
    float const pixel_value = average_texture.read(uint2(x, y)).r;
    float const pixel_ratio = max(1.0, 
                                  pixel_value - black_level) / max(1.0, sum - black_level);
    
    // if hot pixel is detected
    if (pixel_ratio >= hot_pixel_threshold & pixel_value >= 2.0f*mean_texture) {
        // calculate weight for blending to have a smooth transition for not so obvious hot pixels
        float const weight = 0.5f * correction_strength * min(2.0f,
                                                              hot_pixel_multiplicator * (pixel_ratio - hot_pixel_threshold));
        hotpixel_weight_texture.write(weight, uint2(x, y));
    }
}

/**
 Hot pixel identification for X-Trans images
 Similar idea to Bayer correction except that it requires extra work since the mosaic pattern is so large.
 The same approach used for the Bayer images would make color artifacts in small regions with high contrast (e.g. white lines on a black surface would gain a strong purple color).
 Inspired by : https://github.com/darktable-org/darktable/blob/1aca07c62d1c8de7129c93f653bfbf8b4f6a1874/src/iop/hotpixels.c#L231-L343
 */
kernel void find_hotpixels_xtrans(texture2d<float, access::read>  average_texture         [[texture(0)]],
                                  texture2d<float, access::write> hotpixel_weight_texture [[texture(1)]],
                                  constant float* mean_texture_buffer     [[buffer(0)]],
                                  constant float* black_levels            [[buffer(1)]],
                                  constant float& hot_pixel_threshold     [[buffer(2)]],
                                  constant float& hot_pixel_multiplicator [[buffer(3)]],
                                  constant float& correction_strength     [[buffer(4)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    // A more accurate approach for the R and B would be to average out the two knight positions that have 1 distance between them, but that seems more computationally expensive.
    // Lookup table for the relative positions of the closest 4 sub-pixels of the same color (🐷 approach)
    int offset[6][6][4][2] = {
        { // Row 0
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}, // B
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}  // R
        },
        { // Row 1
            {{-1,  2}, {-2,  0}, {-1, -2}, { 2, -1}}, // B
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // R
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}, // G
            {{ 2, -1}, { 2,  1}, {-1,  2}, {-2,  0}}, // R
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // B
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}  // G
        },
        { // Row 2
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}, // B
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}  // R
        },
        { // Row 3
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}, // R
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}  // B
        },
        { // Row 4
            {{-1,  2}, {-2,  0}, {-1, -2}, { 2, -1}}, // R
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // B
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}, // G
            {{ 2, -1}, { 2,  1}, {-1,  2}, {-2,  0}}, // B
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // R
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}  // G
        },
        { // Row 5
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}, // R
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}  // B
        }
    };
    
    // +2 to offset from top-left edge in order to calculate sum of neighbouring pixels
    int const x = gid.x+2;
    int const y = gid.y+2;
    
    // extract color channel-dependent mean value of the average texture of all images and the black level
    int const ix = x % 6;
    int const iy = y % 6;
    float const black_level  = black_levels[ix + 6*iy];
    float const mean_texture = mean_texture_buffer[ix + 6*iy] - black_level;
    
    // Weighed average of the 4 nearest pixels of the same color based on the average texture
    float sum    = 0.0;
    float total  = 0.0;
    float weight = 0.0;
    int dx       = 0;
    int dy       = 0;
    for (int off = 0; off < 4; off++) {
        dx     = offset[iy][ix][off][0];
        dy     = offset[iy][ix][off][1];
        weight = 1.0/sqrt(pow(float(dx), 2) + pow(float(dy), 2));
        
        total += weight;
        float val = average_texture.read(uint2(x+dx, y+dy)).r;
        sum   += weight * val;
    }
    sum /= total;
    
    // extract value of potential hot pixel from the average texture and divide by sum of surrounding pixels
    float const pixel_value = average_texture.read(uint2(x, y)).r;
    float const pixel_ratio = max(1.0,
                                  pixel_value - black_level) / max(1.0,
                                                                   sum - black_level);
    
    if (pixel_ratio >= hot_pixel_threshold & pixel_value >= 2 * mean_texture) {
        // calculate weight for blending to have a smooth transition for not so obvious hot pixels
        float const weight = 0.5f * correction_strength * min(2.0f,
                                                              hot_pixel_multiplicator * (pixel_ratio - hot_pixel_threshold));
        hotpixel_weight_texture.write(weight, uint2(x, y));
    }
}

/**
 This function is intended to convert the source input texture from integer to 32 bit float while correcting hot pixels, equalizing exposure and extending the texture to the size needed for alignment
 */
kernel void prepare_texture_bayer(texture2d<uint, access::read> in_texture                  [[texture(0)]],
                                  texture2d<float, access::read> hotpixel_weight_texture    [[texture(1)]],
                                  texture2d<float, access::write> out_texture               [[texture(2)]],
                                  device   float *black_levels   [[buffer(0)]],
                                  constant int&  pad_left        [[buffer(1)]],
                                  constant int&  pad_top         [[buffer(2)]],
                                  constant int&  exposure_diff   [[buffer(3)]],
                                  uint2 gid [[thread_position_in_grid]]) {
        
    // load args
    int x = gid.x;
    int y = gid.y;
    
    int const texture_width = in_texture.get_width();
    int const texture_height = in_texture.get_height();
 
    float pixel_value = float(in_texture.read(gid).r);
    
    float const hotpixel_weight = hotpixel_weight_texture.read(gid).r;
    
    if (hotpixel_weight > 0.001f && x>=2 && x<texture_width-2 && y>=2 && y<texture_height-2) {
        
        // calculate mean value of 4 surrounding values
        float sum = in_texture.read(uint2(x-2, y+0)).r;
        sum      += in_texture.read(uint2(x+2, y+0)).r;
        sum      += in_texture.read(uint2(x+0, y-2)).r;
        sum      += in_texture.read(uint2(x+0, y+2)).r;
        
        // blend values and replace hot pixel value
        pixel_value = hotpixel_weight*0.25f*sum + (1.0f-hotpixel_weight)*pixel_value;
    }
    
    // calculate exposure correction factor from exposure difference
    float const corr_factor = pow(2.0f, float(exposure_diff/100.0f));        
    float const black_level = black_levels[(gid.y%2)*2 + (gid.x%2)];
    
    // correct exposure
    pixel_value = (pixel_value - black_level)*corr_factor + black_level;
    pixel_value = max(pixel_value, 0.0f);
    
    out_texture.write(pixel_value, uint2(gid.x+pad_left, gid.y+pad_top));
}

/**
 Same as the Bayer version, but accounting for the peculiarities of the XTrans sensor
 */
kernel void prepare_texture_xtrans(texture2d<uint, access::read> in_texture                  [[texture(0)]],
                                   texture2d<float, access::read> hotpixel_weight_texture    [[texture(1)]],
                                   texture2d<float, access::write> out_texture               [[texture(2)]],
                                   device   float *black_levels   [[buffer(0)]],
                                   constant int&  pad_left        [[buffer(1)]],
                                   constant int&  pad_top         [[buffer(2)]],
                                   constant int&  exposure_diff   [[buffer(3)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    // A more accurate approach for the R and B would be to average out the two knight positions that have 1 distance between them, but that seems more computationally expensive.
    // Lookup table for the relative positions of the closest 4 sub-pixels of the same color (🐷 approach)
    int offset[6][6][4][2] = {
        { // Row 0
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}, // B
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}  // R
        },
        { // Row 1
            {{-1,  2}, {-2,  0}, {-1, -2}, { 2, -1}}, // B
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // R
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}, // G
            {{ 2, -1}, { 2,  1}, {-1,  2}, {-2,  0}}, // R
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // B
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}  // G
        },
        { // Row 2
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}, // B
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}  // R
        },
        { // Row 3
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}, // R
            {{ 0, -1}, { 1, -1}, { 1,  0}, {-1,  1}}, // G
            {{ 0, -1}, { 1,  1}, {-1,  0}, {-1, -1}}, // G
            {{ 1, -2}, { 2,  1}, { 0,  2}, {-2,  1}}  // B
        },
        { // Row 4
            {{-1,  2}, {-2,  0}, {-1, -2}, { 2, -1}}, // R
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // B
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}, // G
            {{ 2, -1}, { 2,  1}, {-1,  2}, {-2,  0}}, // B
            {{ 1, -2}, { 2,  0}, { 1,  2}, {-2,  1}}, // R
            {{ 1, -1}, { 1,  1}, {-1,  1}, {-1, -1}}  // G
        },
        { // Row 5
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}, // R
            {{ 1,  0}, { 1,  1}, { 0,  1}, {-1,  1}}, // G
            {{ 1, -1}, { 0,  1}, {-1,  1}, {-1,  0}}, // G
            {{-2, -1}, { 0, -2}, { 2, -1}, { 1, -2}}  // B
        }
    };
    
    // load args
    int x = gid.x;
    int y = gid.y;
    int const ix = x % 6;
    int const iy = y % 6;
    
    int const texture_width = in_texture.get_width();
    int const texture_height = in_texture.get_height();
    
    float pixel_value = float(in_texture.read(gid).r);
    
    float const hotpixel_weight = hotpixel_weight_texture.read(gid).r;
    
    if (hotpixel_weight > 0.001f && x>=2 && x<texture_width-2 && y>=2 && y<texture_height-2) {
        float sum    = 0.0;
        float total  = 0.0;
        float weight = 0.0;
        int dx       = 0;
        int dy       = 0;
        for (int off = 0; off < 4; off++) {
            dx     = offset[iy][ix][off][0];
            dy     = offset[iy][ix][off][1];
            weight = 1.0/sqrt(pow(float(dx), 2) + pow(float(dy), 2));
            
            total += weight;
            float val = in_texture.read(uint2(x+dx, y+dy)).r;
            sum   += weight * val;
        }
        sum /= total;
        
        // blend values and replace hot pixel value
        pixel_value = hotpixel_weight*0.25f*sum + (1.0f-hotpixel_weight)*pixel_value;
    }
    
    float const corr_factor = pow(2.0f, float(exposure_diff/100.0f));
    float const black_level = black_levels[ix + 6*iy];
    
    pixel_value = (pixel_value - black_level)*corr_factor + black_level;
    pixel_value = max(pixel_value, 0.0f);
    
    out_texture.write(pixel_value, uint2(gid.x+pad_left, gid.y+pad_top));
}

/**
 * Divides values in a buffer by a specified divisor.
 *
 * This utility kernel performs element-wise division of the input buffer by a constant divisor,
 * storing the results in an output buffer. A separate output buffer is used instead of in-place
 * modification to maintain a consistent interface with sum_divide_buffer.
 *
 * Parameters:
 *   - in_buffer: Input buffer containing values to be divided
 *   - out_buffer: Output buffer to store the divided values
 *   - divisor: Value to divide each element by
 *   - buffer_size: Unused parameter (included for signature consistency with sum_divide_buffer)
 *   - gid: Thread position in grid (corresponding to buffer element index)
 */
kernel void divide_buffer(device   float  *in_buffer   [[buffer(0)]],
                          device   float  *out_buffer  [[buffer(1)]],
                          constant float& divisor      [[buffer(2)]],
                          constant int&   buffer_size  [[buffer(3)]],  // Unused. Here to keep signature consistent with sum_divide_buffer
                          uint2 gid [[thread_position_in_grid]]) {
    out_buffer[gid.x] = in_buffer[gid.x] / divisor;
}

/**
 * Calculates the sum of all elements in a buffer and divides by a specified divisor.
 *
 * This kernel accumulates all values in the input buffer, then divides the total by
 * a constant divisor. The result is stored in the first element of the output buffer.
 * This is useful for computing means and other statistical operations across the buffer.
 *
 * Parameters:
 *   - in_buffer: Input buffer containing values to be summed
 *   - out_buffer: Output buffer to store the sum/divisor (only index 0 is used)
 *   - divisor: Value to divide the sum by
 *   - buffer_size: Number of elements in the input buffer to include in the sum
 *   - gid: Thread position in grid (only one thread actually performs the operation)
 */
kernel void sum_divide_buffer(device   float  *in_buffer   [[buffer(0)]],
                              device   float  *out_buffer  [[buffer(1)]],
                              constant float& divisor      [[buffer(2)]],
                              constant int&   buffer_size  [[buffer(3)]],
                              uint2 gid [[thread_position_in_grid]]) {
    for (int i = 0; i < buffer_size; i++) {
        out_buffer[0] += in_buffer[i];
    }
    out_buffer[0] /= divisor;
}


/**
 * Normalizes a texture by dividing its values by corresponding normalization factors.
 *
 * This kernel performs pixel-wise division of the input texture by values from the normalization
 * texture, with an additional scalar added to prevent division by zero. This is typically used
 * as a final step in merging operations where weighted contributions need to be normalized.
 *
 * Parameters:
 *   - in_texture: Texture to be normalized (modified in-place)
 *   - norm_texture: Texture containing normalization factors
 *   - norm_scalar: Small value added to normalization factors to prevent division by zero
 *   - gid: Thread position in grid (corresponding to pixel coordinates)
 */
kernel void normalize_texture(texture2d<float, access::read_write> in_texture [[texture(0)]],
                              texture2d<float, access::read> norm_texture [[texture(1)]],
                              constant float& norm_scalar [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
    
    in_texture.write(in_texture.read(gid).r/(norm_texture.read(gid).r + norm_scalar), gid);
}

/**
 * Used for calculating texture_mean. Can't use the UInt version since the images at this point are stored as floats.
 *
 * Sums pixel values in columns within a rectangular region of a float texture. The summation
 * respects the mosaic pattern by stepping by the pattern width when scanning vertically.
 * This is part of the process for computing averages over regions of an image.
 *
 * Parameters:
 *   - in_texture: Input texture to sum from
 *   - out_texture: Output texture to store column sums
 *   - top: Top coordinate of the rectangular region
 *   - left: Left coordinate of the rectangular region
 *   - bottom: Bottom coordinate of the rectangular region
 *   - mosaic_pattern_width: Width of the sensor's mosaic pattern
 *   - gid: Thread position in grid (each thread handles one column)
 */
kernel void sum_rect_columns_float(texture2d<float, access::read> in_texture [[texture(0)]],
                                   texture2d<float, access::write> out_texture [[texture(1)]],
                                   constant int& top [[buffer(0)]],
                                   constant int& left [[buffer(1)]],
                                   constant int& bottom [[buffer(2)]],
                                   constant int& mosaic_pattern_width [[buffer(3)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    uint x = left + gid.x;
    
    float total = 0;
    for (int y = top + gid.y; y < bottom; y += mosaic_pattern_width) {
        total += in_texture.read(uint2(x, y)).r;
    }

    out_texture.write(total, gid);
}

/**
 * Used for calculating a black level from masked areas of the DNG.
 * DNG data is storred as UInt, thus need a seperate version from the float one above.
 *
 * Similar to sum_rect_columns_float, but works with unsigned integer textures. It sums
 * pixel values in columns within a rectangular region and stores the result as floats.
 * This is used for calculating black levels from the optical black regions in DNG files.
 *
 * Parameters:
 *   - in_texture: Input uint texture to sum from
 *   - out_texture: Output float texture to store column sums
 *   - top: Top coordinate of the rectangular region
 *   - left: Left coordinate of the rectangular region
 *   - bottom: Bottom coordinate of the rectangular region
 *   - mosaic_pattern_width: Width of the sensor's mosaic pattern
 *   - gid: Thread position in grid (each thread handles one column)
 */
kernel void sum_rect_columns_uint(texture2d<uint, access::read> in_texture [[texture(0)]],
                                  texture2d<float, access::write> out_texture [[texture(1)]],
                                  constant int& top [[buffer(0)]],
                                  constant int& left [[buffer(1)]],
                                  constant int& bottom [[buffer(2)]],
                                  constant int& mosaic_pattern_width [[buffer(3)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    uint x = left + gid.x;
    
    float total = 0;
    for (int y = top + gid.y; y < bottom; y += mosaic_pattern_width) {
        total += in_texture.read(uint2(x, y)).r;
    }

    out_texture.write(total, gid);
}


/**
 * Sums pixel values across rows in a texture, considering the mosaic pattern.
 *
 * This kernel computes the sum of pixel values in each row, respecting the mosaic pattern
 * by stepping horizontally by the pattern width. The result is stored in a buffer rather
 * than a texture, with positions calculated to maintain the pattern structure.
 *
 * Parameters:
 *   - in_texture: Input texture to sum from
 *   - out_buffer: Output buffer to store row sums
 *   - width: Width of the region to sum
 *   - mosaic_pattern_width: Width of the sensor's mosaic pattern
 *   - gid: Thread position in grid (each thread handles one row)
 */
kernel void sum_row(texture2d<float, access::read> in_texture [[texture(0)]],
                    device float *out_buffer [[buffer(0)]],
                    constant int& width [[buffer(1)]],
                    constant int& mosaic_pattern_width [[buffer(2)]],
                    uint2 gid [[thread_position_in_grid]]) {
    float total = 0.0;
    
    for (int x = gid.x; x < width; x+= mosaic_pattern_width) {
        total += in_texture.read(uint2(x, gid.y)).r;
    }
    
    out_buffer[gid.x + mosaic_pattern_width*gid.y] = total;
}


/**
 * Naming based on https://en.wikipedia.org/wiki/Bilinear_interpolation#/media/File:BilinearInterpolation.svg
 *
 * Upsamples a float texture using bilinear interpolation for high-quality results.
 * This kernel implements full bilinear interpolation with special handling for exact pixel
 * alignments that don't require interpolation. It's used to increase the resolution of
 * textures like weight maps before applying them to full-resolution images.
 *
 * Parameters:
 *   - in_texture: Input texture to upsample
 *   - out_texture: Output texture with increased resolution
 *   - scale_x: Horizontal scaling factor
 *   - scale_y: Vertical scaling factor
 *   - gid: Thread position in grid (corresponding to output pixel coordinates)
 */
kernel void upsample_bilinear_float(texture2d<float, access::read> in_texture [[texture(0)]],
                                    texture2d<float, access::write> out_texture [[texture(1)]],
                                    constant float& scale_x [[buffer(0)]],
                                    constant float& scale_y [[buffer(1)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    
    // naming based on https://en.wikipedia.org/wiki/Bilinear_interpolation#/media/File:BilinearInterpolation.svg
    float x = float(gid.x) / scale_x;
    float y = float(gid.y) / scale_y;
    float epsilon = 1e-5;
    
    // interpolate over the x-axis
    float4 i1, i2;
    if (abs(x - round(x)) < epsilon) {
        i1 = float4(in_texture.read(uint2(round(x), floor(y))));
        i2 = float4(in_texture.read(uint2(round(x), ceil(y) )));
    } else {
        float4 i11 = float4(in_texture.read(uint2(floor(x), floor(y))));
        float4 i12 = float4(in_texture.read(uint2(floor(x), ceil(y) )));
        float4 i21 = float4(in_texture.read(uint2(ceil(x),  floor(y))));
        float4 i22 = float4(in_texture.read(uint2(ceil(x),  ceil(y) )));
        i1 = (ceil(x) - x) * i11 + (x - floor(x)) * i21;
        i2 = (ceil(x) - x) * i12 + (x - floor(x)) * i22;
    }
    
    // interpolate over the y-axis
    float4 i;
    if (abs(y - round(y)) < epsilon) {
        i = i1;
    } else {
        i = (ceil(y) - y) * i1 + (y - floor(y)) * i2;
    }
    
    out_texture.write(i, gid);
}


/**
 * Upsamples an integer texture using nearest-neighbor interpolation.
 *
 * This kernel increases the resolution of an integer texture using the simplest
 * nearest-neighbor sampling. This approach is appropriate for data where preserving
 * exact integer values is more important than visual smoothness.
 *
 * Parameters:
 *   - in_texture: Input integer texture to upsample
 *   - out_texture: Output integer texture with increased resolution
 *   - scale_x: Horizontal scaling factor
 *   - scale_y: Vertical scaling factor
 *   - gid: Thread position in grid (corresponding to output pixel coordinates)
 */
kernel void upsample_nearest_int(texture2d<int, access::read> in_texture [[texture(0)]],
                                 texture2d<int, access::write> out_texture [[texture(1)]],
                                 constant float& scale_x [[buffer(0)]],
                                 constant float& scale_y [[buffer(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {

    int x = int(round(float(gid.x) / scale_x));
    int y = int(round(float(gid.y) / scale_y));
    
    int4 out_color = in_texture.read(uint2(x, y));
    out_texture.write(out_color, gid);
}
