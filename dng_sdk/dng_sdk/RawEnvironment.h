#ifndef __RawEnvironment_h__
#define __RawEnvironment_h__

// This file contains environment-specific settings for the DNG SDK

// Check if DISABLE_JXL_SUPPORT is defined from the build system
#ifndef DISABLE_JXL_SUPPORT
// Default to enabling JXL support if not explicitly disabled
#define DISABLE_JXL_SUPPORT 0
#endif

// No need to redefine qDNGSupportJXL here as it's now handled in dng_sdk_compiler_setup.h

#endif // __RawEnvironment_h__
