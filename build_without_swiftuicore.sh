#!/bin/bash

echo "Building without SwiftUICore framework..."

xcodebuild -project burstphoto.xcodeproj \
  -target VisualTests \
  -configuration Debug \
  -arch arm64 \
  build \
  GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1 USE_SWIFTUI_NOT_CORE=1' \
  ONLY_ACTIVE_ARCH=YES \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  FRAMEWORK_SEARCH_PATHS= \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

echo "Build command completed."
