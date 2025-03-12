// Stub implementations for JXL functions when JXL support is disabled
#include "dng_stream.h"
#include "dng_host.h"
#include "dng_info.h"
#include "dng_image.h"
#include "dng_pixel_buffer.h"

#ifdef DISABLE_JXL_SUPPORT

// Stub class for dng_jxl_decoder
class dng_jxl_decoder
{
public:
    dng_jxl_decoder() {}
    ~dng_jxl_decoder() {}
    
    static bool Decode(dng_host &host, dng_stream &stream)
    {
        // JXL support disabled
        return false;
    }
};

// Stub function for SupportsJXL
bool SupportsJXL(const dng_image &image)
{
    // JXL support disabled
    return false;
}

// Stub function for EncodeJXL_Tile
bool EncodeJXL_Tile(dng_host &host, dng_stream &stream, dng_pixel_buffer &buffer)
{
    // JXL support disabled
    return false;
}

// Stub function for EncodeJXL_Container
bool EncodeJXL_Container(dng_host &host, dng_stream &stream, dng_image &image)
{
    // JXL support disabled
    return false;
}

// Stub function for ParseJXL
bool ParseJXL(dng_host &host, dng_stream &stream, dng_info &info)
{
    // JXL support disabled
    return false;
}

#endif // DISABLE_JXL_SUPPORT
