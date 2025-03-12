#!/bin/bash

echo "Building VisualTests as a standalone target..."

# Create a directory for any test resources if needed
mkdir -p TestResources

# Use a highly specific build command to isolate VisualTests
xcodebuild -project burstphoto.xcodeproj \
  -target VisualTests \
  -configuration Debug \
  -arch arm64 \
  build \
  GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1 USE_SWIFTUI_NOT_CORE=1' \
  ONLY_ACTIVE_ARCH=YES \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  FRAMEWORK_SEARCH_PATHS= \
  PRODUCT_BUNDLE_IDENTIFIER="com.test.visualtests" \
  SWIFT_VERSION=5.0 \
  SWIFT_OPTIMIZATION_LEVEL="-Onone" \
  LD_RUNPATH_SEARCH_PATHS="@loader_path/../Frameworks" \
  MACH_O_TYPE="mh_execute" \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

echo "Build command completed."
