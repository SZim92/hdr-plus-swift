#!/bin/bash

# Script to fix DNG SDK file structure issues

# Set base directory
BASE_DIR="dng_sdk/dng_sdk"

# Create a backup directory
BACKUP_DIR="dng_sdk_backup"
mkdir -p $BACKUP_DIR

# Function to back up a file
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local backup_path="$BACKUP_DIR/$(basename $file)"
    cp "$file" "$backup_path"
    echo "Backed up $file to $backup_path"
  fi
}

# Back up key files
backup_file "$BASE_DIR/dng_flags.h"
backup_file "$BASE_DIR/RawEnvironment.h"

# Create a custom setup file
cat > "$BASE_DIR/dng_sdk_compiler_setup.h" << EOF
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

# Update dng_flags.h to include our setup file
TMP_FILE=$(mktemp)

# Define platform for macOS (needed for platform detection)
cat > "$TMP_FILE" << EOF
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

echo "Setup completed. Please rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 