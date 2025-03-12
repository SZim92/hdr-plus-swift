#!/bin/bash

# This script attempts to build only the VisualTests target without the main app
echo "Building only the VisualTests target..."

xcodebuild -project burstphoto.xcodeproj \
  -target VisualTests \
  -configuration Debug \
  -arch arm64 \
  -scheme VisualTests \
  GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1' \
  VALID_ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

echo "Build command completed." 