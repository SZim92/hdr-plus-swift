/*
 dng_jxl_dummy.h
 Dummy header to define JxlColorEncoding when JPEG XL support is disabled.
*/
#ifndef DNG_JXL_DUMMY_H
#define DNG_JXL_DUMMY_H

// Dummy enums to match libjxl's color space enums when JXL support is disabled
enum JxlColorSpace {
    JXL_COLOR_SPACE_RGB = 0,
    JXL_COLOR_SPACE_GRAY = 1
};

enum JxlWhitePoint {
    JXL_WHITE_POINT_D65 = 1
};

enum JxlPrimaries {
    JXL_PRIMARIES_2100 = 1
};

enum JxlTransferFunction {
    JXL_TRANSFER_FUNCTION_SRGB = 1
};

// Dummy struct to replace libjxl's JxlColorEncoding when JXL support is disabled
struct JxlColorEncoding {
    JxlColorSpace color_space;
    JxlWhitePoint white_point;
    JxlPrimaries primaries;
    JxlTransferFunction transfer_function;
};

#endif // DNG_JXL_DUMMY_H 