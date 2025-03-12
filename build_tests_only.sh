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
