/**
 * @file dng_sdk_wrapper.h
 * @brief C interface wrapper for Adobe DNG SDK functions
 *
 * This header provides C-compatible function declarations for working with DNG (Digital Negative)
 * files using Adobe's DNG SDK. It enables reading raw sensor data and metadata from DNG files,
 * as well as writing processed image data back to DNG format.
 *
 * The wrapper functions handle critical camera-specific properties like black levels, white levels,
 * mosaic (Bayer/X-Trans) pattern information, and color correction factors needed for proper
 * raw image processing in computational photography applications.
 */
#ifndef __dng_sdk_wrapper__
#define __dng_sdk_wrapper__

// use a c wrapper around c++ code
// https://stackoverflow.com/q/35229149/6495494
#ifdef __cplusplus
extern "C" {
#endif

    /**
     * Initialize the XMP SDK required for DNG metadata handling
     *
     * This function must be called before any DNG operations that involve
     * metadata, including read_dng_from_disk and write_dng_to_disk.
     */
    void initialize_xmp_sdk();
    
    /**
     * Terminate the XMP SDK to free resources
     *
     * This function should be called when the application is done with
     * DNG operations to properly release XMP SDK resources.
     */
    void terminate_xmp_sdk();

    /**
     * Read a DNG file and extract raw pixel data and metadata
     *
     * @param in_path             Path to the input DNG file
     * @param pixel_bytes_pointer Pointer to receive the raw pixel data
     * @param width               Pointer to receive the image width
     * @param height              Pointer to receive the image height
     * @param mosaic_pattern_width Pointer to receive the width of the color filter array pattern
     * @param white_level         Pointer to receive the white level value
     * @param black_level         Pointer to receive the black level values for each color in the pattern
     * @param masked_areas        Pointer to receive masked area coordinates
     * @param exposure_bias       Pointer to receive the exposure bias value (in EV*100)
     * @param ISO_exposure_time   Pointer to receive the product of ISO value and exposure time
     * @param color_factor_r      Pointer to receive the red color factor
     * @param color_factor_g      Pointer to receive the green color factor
     * @param color_factor_b      Pointer to receive the blue color factor
     *
     * @return 0 on success, non-zero on failure
     */
    int read_dng_from_disk(const char* in_path, void** pixel_bytes_pointer, int* width, int* height, int* mosaic_pattern_width, int* white_level, int* black_level, int* masked_areas, int* exposure_bias, float* ISO_exposure_time, float* color_factor_r, float* color_factor_g, float* color_factor_b);

    /**
     * Write processed image data to a DNG file
     *
     * This function takes an existing DNG file as a template, replaces its
     * pixel data with the provided processed image data, and writes it to a new DNG file.
     * It preserves all the original metadata including lens calibration data and maker notes.
     *
     * @param in_path             Path to the input template DNG file
     * @param out_path            Path where the output DNG file will be written
     * @param pixel_bytes_pointer Pointer to the processed pixel data to write
     * @param white_level         New white level to set in the output DNG file (if > 0)
     *
     * @return 0 on success, non-zero on failure
     */
    int write_dng_to_disk(const char *in_path, const char *out_path, void** pixel_bytes_pointer, const int white_level);

#ifdef __cplusplus
}
#endif

#endif
