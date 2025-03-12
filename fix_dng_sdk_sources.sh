#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"
SOURCE_DIR="$BASE_DIR/source"

echo "Starting DNG SDK source file fixes..."

# 1. Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR doesn't exist"
    exit 1
fi

# 2. Create backup directory
BACKUP_DIR="dng_sdk_backup"
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# 3. Backup key files if not already backed up
for file in "dng_flags.h" "dng_image_writer.cpp" "dng_image_writer.h" "RawEnvironment.h"; do
    if [ -f "$BASE_DIR/$file" ]; then
        if [ ! -f "$BACKUP_DIR/$(basename $file)" ]; then
            cp "$BASE_DIR/$file" "$BACKUP_DIR/$(basename $file)"
            echo "Backed up $BASE_DIR/$file to $BACKUP_DIR/$(basename $file)"
        else
            echo "Backup for $file already exists"
        fi
    fi
done

# 4. Copy source file versions of key implementation files
echo "Copying source implementation files..."
if [ -f "$SOURCE_DIR/dng_image_writer.cpp" ]; then
    cp "$SOURCE_DIR/dng_image_writer.cpp" "$BASE_DIR/dng_image_writer.cpp"
    echo "Copied dng_image_writer.cpp from source directory"
fi

# 5. Ensure our custom compiler setup is in place
echo "Setting up custom compiler configuration..."

# 5.1 Create or update RawEnvironment.h
cat > "$BASE_DIR/RawEnvironment.h" << 'EOF'
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
EOF
echo "Created/updated RawEnvironment.h"

# 5.2 Create dng_sdk_compiler_setup.h
cat > "$BASE_DIR/dng_sdk_compiler_setup.h" << 'EOF'
/*****************************************************************************/
// Custom compiler setup for DNG SDK
/*****************************************************************************/

#ifndef __dng_sdk_compiler_setup__
#define __dng_sdk_compiler_setup__

// Include our custom environment settings
#include "RawEnvironment.h"

// Map our flag to the DNG SDK flag for JXL support
#if DISABLE_JXL_SUPPORT
#define qDNGSupportJXL 0
#else
#define qDNGSupportJXL 1
#endif

#endif // __dng_sdk_compiler_setup__
EOF
echo "Created/updated dng_sdk_compiler_setup.h"

# 5.3 Update dng_flags.h to include our setup file and fix platform detection
TMP_FILE=$(mktemp)

cat > "$TMP_FILE" << 'EOF'
/*****************************************************************************/
// Copyright 2006-2019 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

/** \file
 * Conditional compilation flags for DNG SDK.
 *
 * All conditional compilation macros for the DNG SDK begin with a lowercase 'q'.
 */

/*****************************************************************************/

#ifndef __dng_flags__
#define __dng_flags__

// Include our custom compiler setup
#include "dng_sdk_compiler_setup.h"

/*****************************************************************************/

/// \def qMacOS 
/// 1 if compiling for Mac OS X.

/// \def qWinOS 
/// 1 if compiling for Windows.

// Define platform for macOS
#if defined(__APPLE__) && defined(__MACH__)
#define qMacOS 1
#endif

// Make sure a platform is defined
#if !(defined(qMacOS) || defined(qWinOS) || defined(qAndroid) || defined(qiPhone) || defined(qLinux) || defined(qWeb))
#include "RawEnvironment.h"
#endif

// This requires a force include or compiler define.  These are the unique platforms.

#if !(defined(qMacOS) || defined(qWinOS) || defined(qAndroid) || defined(qiPhone) || defined(qLinux) || defined(qWeb))
#error Unable to figure out platform
#endif
EOF

# Append the rest of the original file, starting after the platform detection section
sed -n '/^\/\/ Platforms\./,$p' "$BASE_DIR/dng_flags.h" >> "$TMP_FILE"

# Replace the original
mv "$TMP_FILE" "$BASE_DIR/dng_flags.h"
echo "Updated dng_flags.h with platform detection and compiler setup"

# 6. Fix deprecated_flags.h to avoid redefinition of qDNGSupportJXL
if [ -f "$BASE_DIR/dng_deprecated_flags.h" ]; then
    TMP_FILE=$(mktemp)
    
    # Replace the redefinition of qDNGSupportJXL with a check
    sed 's/^#define qDNGSupportJXL 1/#ifndef qDNGSupportJXL\n#define qDNGSupportJXL 1\n#endif/' "$BASE_DIR/dng_deprecated_flags.h" > "$TMP_FILE"
    
    # Replace the original
    mv "$TMP_FILE" "$BASE_DIR/dng_deprecated_flags.h"
    echo "Updated dng_deprecated_flags.h to avoid qDNGSupportJXL redefinition"
fi

echo "Setup completed. Please rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 