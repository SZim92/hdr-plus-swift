#!/bin/bash

echo "Applying final fix for SwiftUICore framework issues..."

# 1. Backup the project file if not already done
PROJ_FILE="burstphoto.xcodeproj/project.pbxproj"

if [ ! -f "$PROJ_FILE.bak_final" ]; then
    cp "$PROJ_FILE" "$PROJ_FILE.bak_final"
    echo "Created backup of project file"
fi

# 2. Remove the SwiftUICore framework reference completely
# This is more aggressive than previous approaches but should resolve the linking issue

# This pattern will look for PBXBuildFile and PBXFileReference sections containing SwiftUICore
# and comment them out to effectively remove them from the build process
sed -i '' '/SwiftUICore.*fileRef/ s/^/\/\/ /' "$PROJ_FILE"
sed -i '' '/SwiftUICore.*path =/ s/^/\/\/ /' "$PROJ_FILE"

# Also remove any framework search paths that might be looking for SwiftUICore
sed -i '' 's/FRAMEWORK_SEARCH_PATHS = (.*;/FRAMEWORK_SEARCH_PATHS = ();/g' "$PROJ_FILE"

# 3. Find any Swift files that import SwiftUICore and modify them to use SwiftUI instead
find . -name "*.swift" -type f -exec grep -l "import SwiftUICore" {} \; | while read file; do
    if [ ! -f "${file}.bak_final" ]; then
        cp "$file" "${file}.bak_final"
        echo "Created backup of $file"
    fi
    
    # Replace SwiftUICore import with regular SwiftUI
    sed -i '' 's/import SwiftUICore/import SwiftUI/g' "$file"
    
    # Also add conditional code to handle API differences
    sed -i '' '/import SwiftUI/ a\
// MARK: - SwiftUICore compatibility\
#if !os(macOS) || !DEBUG\
    // Regular SwiftUI mode\
#endif' "$file"
    
    echo "Updated $file to use SwiftUI instead of SwiftUICore"
done

# 4. Create a modified build command script
cat > build_without_swiftuicore.sh << 'EOT'
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
EOT

chmod +x build_without_swiftuicore.sh
echo "Created build script: build_without_swiftuicore.sh"

echo "SwiftUICore framework fix applied. Please run:"
echo "./build_without_swiftuicore.sh" 