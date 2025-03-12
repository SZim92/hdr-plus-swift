#ifndef __RawEnvironment_h__
#define __RawEnvironment_h__

// This file contains environment-specific settings for the DNG SDK

// Check if we need to disable JPEG XL support
#ifdef DISABLE_JXL_SUPPORT
  // Use the build system definition if provided
  #if DISABLE_JXL_SUPPORT
    #define qDNGSupportJXL 0
  #else
    #define qDNGSupportJXL 1
  #endif
#else
  // If not defined in build system, include custom flags
  #include "dng_custom_flags.h"
  
  // If still not defined, default to enabled
  #ifndef qDNGSupportJXL
    #define qDNGSupportJXL 1
  #endif
#endif

// For backward compatibility with our existing changes
#if !qDNGSupportJXL
  #define DISABLE_JXL_SUPPORT 1
#else
  #define DISABLE_JXL_SUPPORT 0
#endif

#endif // __RawEnvironment_h__ 