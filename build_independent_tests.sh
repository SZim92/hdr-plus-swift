#!/bin/bash

echo "Creating a specialized build for independent tests..."

# Create a summary of our fixes so far
cat > jxl_swiftui_fixes_summary.md << 'EOT'
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
EOT

echo "Created build fixes summary"

# Create a build script that tries to build ONLY the test components, not the full app
cat > build_tests_only.sh << 'EOT'
#!/bin/bash

echo "Building test components only..."

# Replace this with the path to your project directory if different
PROJECT_DIR=$(pwd)

# Create a test-only build configuration
cat > test_only.xcconfig << 'INNER_EOT'
// Configuration settings for test-only build
// This removes dependencies on SwiftUICore and other problematic frameworks

// Use SwiftUI instead of SwiftUICore
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) USE_SWIFTUI_NOT_CORE DISABLE_JXL_SUPPORT

// Don't link against problematic frameworks
FRAMEWORK_SEARCH_PATHS = $(inherited)
EXCLUDED_SOURCE_FILE_NAMES = *SwiftUICore*

// Build settings optimization
ONLY_ACTIVE_ARCH = YES
BUILD_LIBRARY_FOR_DISTRIBUTION = NO
INNER_EOT

# Run xcodebuild with carefully selected options
xcodebuild -project burstphoto.xcodeproj \
  -target VisualTests \
  -configuration Debug \
  -arch arm64 \
  -xcconfig test_only.xcconfig \
  build \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  OTHER_LDFLAGS="-Wl,-undefined,dynamic_lookup" \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

echo "Test-only build completed."
EOT

chmod +x build_tests_only.sh
echo "Created script: build_tests_only.sh"

echo "Build script created. Please run:"
echo "./build_tests_only.sh" 