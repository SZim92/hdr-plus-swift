/**
 * @file dng_sdk_wrapper.cpp
 * @brief Wrapper functions for Adobe DNG SDK to handle DNG files
 *
 * This file provides functions to read from and write to DNG (Digital Negative) files
 * using Adobe's DNG SDK. It extracts raw sensor data and metadata from DNG files and 
 * enables writing processed image data back to DNG format while preserving the original
 * metadata.
 *
 * The functions handle sensor-specific properties like black levels, white levels,
 * mosaic pattern information, and color correction factors needed for proper
 * raw image processing.
 */
#include "dng_sdk_wrapper.h"
#include "dng_exceptions.h"
#include "dng_file_stream.h"
#include "dng_host.h"
#include "dng_ifd.h"
#include "dng_image_writer.h"
#include "dng_info.h"
#include "dng_negative.h"
#include "dng_simple_image.h"
#include "dng_xmp_sdk.h"


/**
 * Initialize the XMP SDK required for DNG metadata handling
 *
 * This function must be called before any DNG operations that involve
 * metadata, including read_dng_from_disk and write_dng_to_disk.
 */
void initialize_xmp_sdk() {
    dng_xmp_sdk::InitializeSDK();
}


/**
 * Terminate the XMP SDK to free resources
 *
 * This function should be called when the application is done with
 * DNG operations to properly release XMP SDK resources.
 */
void terminate_xmp_sdk() {
    dng_xmp_sdk::TerminateSDK();
}


/**
 * Read a DNG file and extract raw pixel data and metadata
 *
 * This function reads a DNG file and extracts both the raw sensor data and
 * important metadata such as black levels, white level, mosaic pattern information,
 * exposure settings, and color correction factors.
 *
 * @param in_path             Path to the input DNG file
 * @param pixel_bytes_pointer Pointer to receive the raw pixel data
 * @param width               Pointer to receive the image width
 * @param height              Pointer to receive the image height
 * @param mosaic_pattern_width Pointer to receive the width of the color filter array pattern
 * @param white_level         Pointer to receive the white level value
 * @param black_levels        Pointer to receive the black level values for each color in the pattern
 * @param masked_areas        Pointer to receive masked area coordinates
 * @param exposure_bias       Pointer to receive the exposure bias value (in EV*100)
 * @param ISO_exposure_time   Pointer to receive the product of ISO value and exposure time
 * @param color_factor_r      Pointer to receive the red color factor
 * @param color_factor_g      Pointer to receive the green color factor
 * @param color_factor_b      Pointer to receive the blue color factor
 *
 * @return 0 on success, non-zero on failure
 */
int read_dng_from_disk(const char* in_path, void** pixel_bytes_pointer, int* width, int* height, int* mosaic_pattern_width, int* white_level, int* black_levels, int* masked_areas, int* exposure_bias, float* ISO_exposure_time, float* color_factor_r, float* color_factor_g, float* color_factor_b) {
    
    try {
        
        // read image
        dng_host host;
        dng_info info;
        dng_file_stream stream(in_path);
        AutoPtr<dng_negative> negative; {
            info.Parse(host, stream);
            info.PostParse(host);
            if(!info.IsValidDNG()) {return dng_error_bad_format;}
            negative.Reset(host.Make_dng_negative());
            negative->Parse(host, stream, info);
            negative->PostParse(host, stream, info);
        }
        
        // load pixel buffer
        // - it would be possible to do:
        //   >>> negative->ReadStage1Image(host, stream, info);
        //   however, ReadStage1Image will create a dng_simple_image and convert it to
        //   a dng_image. For our use case, we require a dng_simple_image,
        //   hence I have reimplemented dng_negative::ReadStage1Image here.
        dng_ifd& rawIFD = *info.fIFD [info.fMainIndex];
        AutoPtr<dng_simple_image> image_pointer (new dng_simple_image(rawIFD.Bounds(), rawIFD.fSamplesPerPixel, rawIFD.PixelType(), host.Allocator()));
        dng_simple_image& image = *image_pointer.Get();
        rawIFD.ReadImage(host, stream, image);
        dng_pixel_buffer pixel_buffer;
        image.GetPixelBuffer(pixel_buffer);
        
        // copy data
        *width = image.Width();
        *height = image.Height();
        int image_size = image.Width() * image.Height() * image.PixelSize();
        void* pixel_bytes = malloc(image_size);
        *pixel_bytes_pointer = pixel_bytes;
        memcpy(pixel_bytes, pixel_buffer.DirtyPixel(0, 0), image_size);
        
        // get size of mosaic pattern
        // - this affects how raw pixels are aligned
        // - it is assumed that the pattern is square
        const dng_mosaic_info* mosaic_info = negative->GetMosaicInfo();
        if (mosaic_info == NULL) {
            *mosaic_pattern_width = 1;
            printf("ERROR: MosaicInfo is null.\n");
            return 1;
        } else {
            dng_point mosaic_pattern_size = negative->fMosaicInfo->fCFAPatternSize;
            *mosaic_pattern_width = mosaic_pattern_size.h;
        }
               
        // Get masked area
        if (rawIFD.fMaskedAreaCount > 0) {
            for (int i = 0; i < rawIFD.fMaskedAreaCount; i++) {
                // Add masked areas to the array
                *(masked_areas + i + 0) = rawIFD.fMaskedArea[i].t;
                *(masked_areas + i + 1) = rawIFD.fMaskedArea[i].l;
                *(masked_areas + i + 2) = rawIFD.fMaskedArea[i].b;
                *(masked_areas + i + 3) = rawIFD.fMaskedArea[i].r;
            }
        }
        
        int mosaic_width = *mosaic_pattern_width;
        // Get black level, white level and color factors for exposure correction
        const dng_linearization_info* linearization_info = negative->GetLinearizationInfo();
        if (linearization_info == NULL) {
            printf("ERROR: LinearizationInfo is null.\n");
            return 1;
        } else {
            *white_level = int(linearization_info->fWhiteLevel[0]);
            
            // The following performs basic handling of fBlackDeltaV and fBlackDeltaH
            // It is not fully correct, and will fail if each row and column have significant differences between black levels.
            // The current support is added to allow for certain older canon cameras (e.g. Canon 350D) to work correctly since they rely on it.
            double black_level_delta_adjust[6*6] = { 0 };
            
            if (linearization_info->RowBlackCount() > 0) {
                for (int row = 0; row < linearization_info->RowBlackCount(); row++) {
                    for (int col = 0; col < mosaic_width; col++) {
                        black_level_delta_adjust[(row % mosaic_width) + col * mosaic_width] += linearization_info->fBlackDeltaV->Buffer_real64()[row];
                    }
                }
                for (int i = 0; i < mosaic_width*mosaic_width; i++) {
                    black_level_delta_adjust[i] /= (linearization_info->RowBlackCount() / mosaic_width);
                }
            }
            
            if (linearization_info->ColumnBlackCount() > 0) {
                for (int col = 0; col < linearization_info->ColumnBlackCount(); col++) {
                    for (int row = 0; row < mosaic_width; row++) {
                        black_level_delta_adjust[(row % mosaic_width) + col * mosaic_width] += linearization_info->fBlackDeltaH->Buffer_real64()[col];
                    }
                }
                
                for (int i = 0; i < mosaic_width*mosaic_width; i++) {
                    black_level_delta_adjust[i] /= (linearization_info->ColumnBlackCount() / mosaic_width);
                }
            }
            
            int num_non_zero_black_levels = 0;
            int last_black_level = 0;
            int _black_level;
            for (int row = 0; row < mosaic_width; row++) {
                for (int col = 0; col < mosaic_width; col++) {
                    double black_level = 0.0;
                    // If there are multiple samples, average them out
                    for (int sample_num = 0; sample_num < rawIFD.fSamplesPerPixel; sample_num++) {
                        black_level += linearization_info->fBlackLevel[row][col][sample_num];
                    }
                    black_level /= rawIFD.fSamplesPerPixel;
                    
                    _black_level = (int) (black_level + black_level_delta_adjust[row + col*mosaic_width]);
                    *(black_levels + row + col*mosaic_width) = _black_level;
                    
                    if (_black_level != 0) {
                        num_non_zero_black_levels++;
                        last_black_level = _black_level;
                    }
                }
            }
            
            // Some cameras report a single black value which is supposed to be used for all channels.
            // Catch and handle this case here.
            if (num_non_zero_black_levels == 1) {
                for (int row = 0; row < mosaic_width; row++) {
                    for (int col = 0; col < mosaic_width; col++) {
                        *(black_levels + row + col*mosaic_width) = last_black_level;
                    }
                }
            }
        }
        
        // get color factors for neutral colors in camera color space
        const dng_vector camera_neutral = negative->CameraNeutral();
        if (camera_neutral.IsEmpty()) {
            printf("ERROR: CameraNeutral is null.\n");
            return 1;
        } else {
            *color_factor_r = float(camera_neutral[0]);
            *color_factor_g = float(camera_neutral[1]);
            *color_factor_b = float(camera_neutral[2]);
        }
        
        // Get exposure bias for exposure correction  and product of ISO value and exposure time for control of hot pixel correction
        const dng_exif* exif = negative->GetExif();
        if (exif == NULL) {
            printf("ERROR: Exif is null.\n");
            return 1;
        } else {
            const dng_srational exposure_bias_value = exif->fExposureBiasValue;
            // scale exposure bias value that it is EV * 100
            *exposure_bias = exposure_bias_value.n * 100/exposure_bias_value.d;
            
            const dng_urational exposure_time_value = exif->fExposureTime;
            const uint32 ISO_speed_value = exif->fISOSpeedRatings[0];
            // calculate product of ISO value and exposure time
            *ISO_exposure_time = ISO_speed_value*exposure_time_value.n/float(exposure_time_value.d);
        }
        return 0;
    } catch(...) {
        return 1;
    }
}

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
int write_dng_to_disk(const char *in_path, const char *out_path, void** pixel_bytes_pointer, const int white_level) {
    
    try {
        
        // read image
        dng_host host;
        dng_info info;
        dng_file_stream stream(in_path);
        AutoPtr<dng_negative> negative; {
            info.Parse(host, stream);
            info.PostParse(host);
            if(!info.IsValidDNG()) {return dng_error_bad_format;}
            negative.Reset(host.Make_dng_negative());
            // this line ensures that the maker notes are copied 
            host.SetSaveDNGVersion(dngVersion_SaveDefault);
            negative->Parse(host, stream, info);
            negative->PostParse(host, stream, info);
        }
   
        // load pixel buffer
        dng_ifd& rawIFD = *info.fIFD [info.fMainIndex];
        AutoPtr<dng_simple_image> image_pointer (new dng_simple_image(rawIFD.Bounds(), rawIFD.fSamplesPerPixel, rawIFD.PixelType(), host.Allocator()));
        dng_simple_image& image = *image_pointer.Get();
        // rawIFD.ReadImage(host, stream, image);
         
        
        // read opcode lists (required for lens calibration data)
        negative->ReadOpcodeLists(host, stream, info);
        
        // overwrite pixel buffer
        void* pixel_bytes = *pixel_bytes_pointer;
        int image_size = image.Width() * image.Height() * image.PixelSize();
        memcpy(image.fBuffer.DirtyPixel(0, 0), pixel_bytes, image_size);
                
        // store modified pixel buffer to the negative
        negative->fStage1Image.Reset(image_pointer.Release());
            
        // validate the modified image
        // - this resets some of the image stats like md5 checksums
        // - running this function will print a warning "NewRawImageDigest does not match raw image"
        //   but won't halt the program
        // - without running this function, the output dng file would be considered 'damaged'
        negative->ValidateRawImageDigest(host);
                      
        // read metadata
        // - this doesn't seem to affect my test dng files but maybe it makes
        //   a difference for other files
        // - this is used in the dng_validate script
        negative->SynchronizeMetadata();
            
        if (white_level > 0) {
            negative->SetWhiteLevel(white_level, 0);
        }
        
        // write dng
        host.SetSaveLinearDNG(false);
        host.SetKeepOriginalFile(false);
        dng_file_stream stream2(out_path, true); {
            dng_image_writer writer;
            writer.WriteDNG(host, stream2, *negative.Get());
        }

    }
    catch(...) {
        return 1;
    }
    return 0;
}
