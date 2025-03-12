# HDR+ Swift Build Fixes

## JXL Support Issues

The JPEG XL (JXL) support in the DNG SDK had issues that prevented building. We applied the following fixes:

1. Created conditional compilation guards around JXL-specific code in `dng_image_writer.cpp`
2. Added proper `#if qDNGSupportJXL` checks around:
   - `WriteJPEGXL` method
   - `WriteJPEGXLTile` method
   - References to `fJxlColorEncoding`
   - Functions that depend on `JxlColorEncoding` type

## SwiftUICore Framework Issues

The project referenced a private framework `SwiftUICore` which is not available for direct linking in all environments. We applied the following fixes:

1. Created a xcconfig file to modify build settings
2. Modified the project file to remove direct references to the SwiftUICore framework
3. Updated Swift imports to use standard SwiftUI instead
4. Added compatibility code for API differences

## Remaining Issues

There are still some unresolved issues:

1. The gui target still attempts to link against SwiftUICore
2. There are search path warnings for XMP libraries
3. There are various documentation and deprecation warnings in the DNG SDK code
