# HDR+ Swift Project Fixes

This document provides instructions for resolving the build issues in the HDR+ Swift project.

## Issues Fixed

1. **JPEG XL (JXL) Support**: Undefined symbols related to JXL functionality in the DNG SDK
2. **SwiftUICore Framework**: Replacing private SwiftUICore framework with standard SwiftUI
3. **HDRPlusCore Module**: Missing module in performance tests

## How to Apply the Fixes

### 1. Add the JXL Stubs File to Your Project

1. Open the project in Xcode
2. Right-click on the `dng_sdk` group or folder
3. Select "Add Files to burstphoto..."
4. Navigate to and select the `dng_sdk/dng_jxl_stubs.cpp` file
5. Make sure the file is added to the `gui` target

### 2. Add the HDRPlusCore Compatibility File

1. In Xcode, right-click on the `PerformanceTests` group
2. Select "Add Files to burstphoto..."
3. Navigate to and select the `PerformanceTests/Compatibility/HDRPlusCore.swift` file
4. Make sure it's added to the `PerformanceTests` target

### 3. Apply the Combined Configuration File

1. In Xcode, select the project in the navigator
2. Select the `gui` target
3. Go to the "Build Settings" tab
4. Find "Based on Configuration File" (you can search for "configuration")
5. Set it to `combined_fixes.xcconfig`

## What the Fixes Do

### JPEG XL Fix
- Adds conditional compilation around JXL-related code
- Provides stub implementations for JXL functions when disabled
- Sets `DISABLE_JXL_SUPPORT=1` preprocessor definition

### SwiftUI Fix
- Replaces SwiftUICore with standard SwiftUI
- Adds conditional compilation for window styling
- Sets `USE_SWIFTUI_NOT_CORE` compilation condition

### HDRPlusCore Fix
- Provides a compatibility layer for HDRPlusCore functionality
- Replaces imports in test files
- Adds the compatibility directory to header search paths

## After Applying Fixes

After applying these fixes, you should be able to build the project successfully. If you encounter any issues:

1. Check the build log for specific errors
2. Ensure all files have been added to the correct targets
3. Verify the configuration file is being applied correctly

## Additional Notes

- The SwiftUI migration may require additional adjustments for window management APIs
- The JXL stubs provide minimal implementations that return false/null values
- The HDRPlusCore compatibility layer provides stub implementations for testing 