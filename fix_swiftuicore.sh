#!/bin/bash

echo "Fixing SwiftUICore framework issues..."

# Create a final solution that modifies the project settings to avoid linking SwiftUICore directly

# 1. Create an Xcode config file with the necessary settings
cat > disable_swiftuicore.xcconfig << 'EOT'
// Configuration settings file to disable SwiftUICore direct linking
// This file sets build settings to address the SwiftUICore linking issue

// Use modern Swift concurrency
OTHER_SWIFT_FLAGS = $(inherited) -enable-experimental-concurrency

// Use SwiftUI instead of SwiftUICore
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) USE_SWIFTUI_NOT_CORE

// Don't link against private frameworks
LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/../Frameworks

// Make sure framework search paths are standard
FRAMEWORK_SEARCH_PATHS = $(inherited) "$(DEVELOPER_FRAMEWORKS_DIR)" "$(PLATFORM_DIR)/Developer/Library/Frameworks"
EOT

echo "Created disable_swiftuicore.xcconfig"

# 2. Create an App.swift file modification that doesn't directly use SwiftUICore
cat > swiftui_app_patch.txt << 'EOT'
import SwiftUI
import AppKit
EOT

# 3. Now create a patch for the project file to include our config file
PROJ_FILE="burstphoto.xcodeproj/project.pbxproj"

# Backup the file if it doesn't already have a backup
if [ ! -f "$PROJ_FILE.bak_swiftui" ]; then
    cp "$PROJ_FILE" "$PROJ_FILE.bak_swiftui"
    echo "Created backup of project file"
fi

# Use sed to modify the project file
sed -i '' 's/SwiftUICore\.framework/SwiftUI.framework/g' "$PROJ_FILE"
echo "Updated project file to use SwiftUI instead of SwiftUICore"

# 4. Apply the changes to App.swift if it contains SwiftUICore reference
if [ -f "burstphoto/App.swift" ]; then
    # Backup the file if needed
    if [ ! -f "burstphoto/App.swift.bak" ]; then
        cp "burstphoto/App.swift" "burstphoto/App.swift.bak"
        echo "Created backup of App.swift"
    fi
    
    # Replace any SwiftUICore import with regular SwiftUI
    sed -i '' 's/import SwiftUICore/import SwiftUI/g' "burstphoto/App.swift"
    echo "Updated App.swift to use SwiftUI instead of SwiftUICore"
else
    echo "Warning: App.swift not found"
fi

echo "Created fix for SwiftUICore issues"
echo "To build with this fix, use:"
echo "xcodebuild -project burstphoto.xcodeproj -scheme VisualTests -configuration Debug -arch arm64 -xcconfig disable_swiftuicore.xcconfig build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 