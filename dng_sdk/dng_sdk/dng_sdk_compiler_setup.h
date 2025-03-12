/*****************************************************************************/
// Custom compiler setup for DNG SDK
/*****************************************************************************/

#ifndef __dng_sdk_compiler_setup__
#define __dng_sdk_compiler_setup__

// Include our custom environment settings
#include "RawEnvironment.h"

// Map our flag to the DNG SDK flag for JXL support
#if DISABLE_JXL_SUPPORT
#define qDNGSupportJXL 0
#else
#define qDNGSupportJXL 1
#endif

#endif // __dng_sdk_compiler_setup__
