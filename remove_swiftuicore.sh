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
