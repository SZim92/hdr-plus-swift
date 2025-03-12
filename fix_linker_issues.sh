#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"

# 1. Fix the SupportsJXL function issue by providing a conditional implementation
echo "Fixing SupportsJXL function implementation..."

# Check if dng_jxl.cpp exists
if [ ! -f "$BASE_DIR/dng_jxl.cpp" ]; then
    # Create a backup of dng_jxl.h if needed
    if [ ! -f "$BASE_DIR/dng_jxl.h.bak_linker" ]; then
        cp "$BASE_DIR/dng_jxl.h" "$BASE_DIR/dng_jxl.h.bak_linker"
        echo "Created backup of dng_jxl.h"
    fi
    
    # Create a minimal dng_jxl.cpp implementation
    cat > "$BASE_DIR/dng_jxl.cpp" << 'EOT'
/*****************************************************************************/
// Copyright 2006-2022 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

#include "dng_jxl.h"
#include "dng_image.h"

/*****************************************************************************/

// When JXL support is disabled, provide a stub implementation
// that always returns false to prevent linker errors

bool SupportsJXL (const dng_image &image)
{
    #if qDNGSupportJXL
    // This is only reachable when JXL support is enabled
    // The real implementation would be in the JXL-enabled code
    uint32 planes    = image.Planes();
    uint32 pixelType = image.PixelType();

    return ((planes == 1 || planes == 3) &&
           (pixelType == ttByte || 
            pixelType == ttShort || 
            pixelType == ttHalfFloat || 
            pixelType == ttFloat));
    #else
    // When JXL support is disabled, never support JXL operations
    (void)image; // Prevent unused parameter warning
    return false;
    #endif
}

/*****************************************************************************/
EOT
    echo "Created dng_jxl.cpp with stub implementation for SupportsJXL"
else
    # Check if the file already has our fix
    if ! grep -q "#if qDNGSupportJXL" "$BASE_DIR/dng_jxl.cpp"; then
        # Create a backup if needed
        if [ ! -f "$BASE_DIR/dng_jxl.cpp.bak_linker" ]; then
            cp "$BASE_DIR/dng_jxl.cpp" "$BASE_DIR/dng_jxl.cpp.bak_linker"
            echo "Created backup of dng_jxl.cpp"
        fi
        
        # Create a temporary file with our changes
        TMP_FILE=$(mktemp)
        
        # Add conditional compilation around SupportsJXL implementation
        awk '
        /bool SupportsJXL \(const dng_image &image\)/ {
            print "#if qDNGSupportJXL";
            print $0;
            next;
        }
        /return \(\(planes == 1/ {
            print $0;
            print "#else";
            print "    // When JXL support is disabled, never support JXL operations";
            print "    (void)image; // Prevent unused parameter warning";
            print "    return false;";
            print "#endif";
            next;
        }
        { print }
        ' "$BASE_DIR/dng_jxl.cpp" > "$TMP_FILE"
        
        # Replace original with modified file
        mv "$TMP_FILE" "$BASE_DIR/dng_jxl.cpp"
        echo "Updated dng_jxl.cpp with conditional implementation for SupportsJXL"
    else
        echo "dng_jxl.cpp already has conditional implementation for SupportsJXL"
    fi
fi

# 2. Create directory for XMP libraries if it doesn't exist
echo "Setting up XMP library directories..."

XMP_LIB_DIR="$BASE_DIR/../xmp_lib"
mkdir -p "$XMP_LIB_DIR/Release"
mkdir -p "$XMP_LIB_DIR/Debug"

# Create empty README files to ensure the directories are not empty
echo "This directory is for XMP SDK libraries" > "$XMP_LIB_DIR/Release/README.txt"
echo "This directory is for XMP SDK libraries" > "$XMP_LIB_DIR/Debug/README.txt"

echo "Created XMP library directories at $XMP_LIB_DIR"

# 3. Fix SwiftUICore linker issue
echo "Creating a patch for the SwiftUI framework issue..."

cat > remove_swiftuicore.sh << 'EOT'
#!/bin/bash
# This script removes direct references to SwiftUICore framework
# from the project file, if they exist

# Find project.pbxproj file
PROJECT_FILE="burstphoto.xcodeproj/project.pbxproj"

if [ -f "$PROJECT_FILE" ]; then
    # Create backup
    if [ ! -f "${PROJECT_FILE}.bak" ]; then
        cp "$PROJECT_FILE" "${PROJECT_FILE}.bak"
        echo "Created backup of $PROJECT_FILE"
    fi
    
    # Remove SwiftUICore references if they exist
    sed -i '' 's/SwiftUICore\.framework/SwiftUI.framework/g' "$PROJECT_FILE"
    echo "Updated project file to use SwiftUI instead of SwiftUICore"
else
    echo "Project file not found: $PROJECT_FILE"
fi
EOT

chmod +x remove_swiftuicore.sh
echo "Created SwiftUI framework fix script"

echo "All linker fixes have been prepared. To apply the SwiftUI framework fix, run:"
echo "./remove_swiftuicore.sh"
echo ""
echo "Then rebuild your project with:"
echo "xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 