#!/bin/bash

echo "Fixing SwiftUICore framework issues (v2)..."

# 1. Create an Xcode config file with the necessary settings (without problematic flag)
cat > disable_swiftuicore.xcconfig << 'EOT'
// Configuration settings file to disable SwiftUICore direct linking
// This file sets build settings to address the SwiftUICore linking issue

// Use SwiftUI instead of SwiftUICore
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) USE_SWIFTUI_NOT_CORE

// Don't link against private frameworks
LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/../Frameworks

// Make sure framework search paths are standard
FRAMEWORK_SEARCH_PATHS = $(inherited) "$(DEVELOPER_FRAMEWORKS_DIR)" "$(PLATFORM_DIR)/Developer/Library/Frameworks"
EOT

echo "Created updated disable_swiftuicore.xcconfig"

# 2. Process the project file
PROJ_FILE="burstphoto.xcodeproj/project.pbxproj"

# Backup the file if it doesn't already have a backup
if [ ! -f "$PROJ_FILE.bak_swiftui_v2" ]; then
    cp "$PROJ_FILE" "$PROJ_FILE.bak_swiftui_v2"
    echo "Created backup of project file"
fi

# Use sed to modify the project file
sed -i '' 's/SwiftUICore\.framework/SwiftUI.framework/g' "$PROJ_FILE"
echo "Updated project file to use SwiftUI instead of SwiftUICore"

# Also need to handle the PBXBuildFile and PBXFileReference sections
sed -i '' 's/name = SwiftUICore\.framework/name = SwiftUI.framework/g' "$PROJ_FILE"
sed -i '' 's/path = SwiftUICore\.framework/path = SwiftUI.framework/g' "$PROJ_FILE"

# 3. Check and modify Swift files containing SwiftUICore references
find . -name "*.swift" -type f -exec grep -l "SwiftUICore" {} \; | while read file; do
    # Backup the file if needed
    if [ ! -f "${file}.bak" ]; then
        cp "$file" "${file}.bak"
        echo "Created backup of $file"
    fi
    
    # Replace any SwiftUICore import with regular SwiftUI
    sed -i '' 's/import SwiftUICore/import SwiftUI/g' "$file"
    echo "Updated $file to use SwiftUI instead of SwiftUICore"
done

echo "Created fix for SwiftUICore issues"
echo "To build with this fix, use:"
echo "xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 -xcconfig disable_swiftuicore.xcconfig build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 