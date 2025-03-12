#!/bin/bash

echo "Fixing VisualTests target dependencies..."

# 1. Backup the project file if not already done
PROJ_FILE="burstphoto.xcodeproj/project.pbxproj"

if [ ! -f "$PROJ_FILE.bak_deps" ]; then
    cp "$PROJ_FILE" "$PROJ_FILE.bak_deps"
    echo "Created backup of project file"
fi

# 2. Extract the VisualTests target ID for reference
VISUALTESTS_ID=$(grep -A 2 "VisualTests.xctest" "$PROJ_FILE" | grep "BuildableName" | head -1 | 
                 sed -n 's/.*BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "\([^"]*\)".*/\1/p')

if [ -z "$VISUALTESTS_ID" ]; then
    # Try alternate approach to find the target ID
    VISUALTESTS_ID=$(grep -A 10 "VisualTests =" "$PROJ_FILE" | grep -E "isa = PBXNativeTarget|name = VisualTests" -A 3 | 
                    grep -o "[A-Z0-9]\{24\}" | head -1)
fi

echo "Found VisualTests target ID: $VISUALTESTS_ID"

# 3. Modify the dependencies section to remove any dependency on the gui target
# Use awk for better handling of multi-line modifications in the complex pbxproj format
awk -v vtid="$VISUALTESTS_ID" '
# Flag to track when we are in the dependencies section for VisualTests
/dependencies = \(/ { in_deps = 1; }
/\);/            { in_deps = 0; }

# If we are in a VisualTests target definition, track that
$0 ~ vtid && /PBXNativeTarget/ { in_vt = 1; }

# Inside the VisualTests target, look for the dependencies section
in_vt && /dependencies = \(/ { 
    in_vt_deps = 1; 
    # Print the line, and then the replacement dependencies array
    print; 
    print "\t\t\t\t/* Modified: Empty dependencies */";
    # Skip lines until we reach the end of the dependencies section
    skip_until_deps_end = 1;
    next;
}

# End of dependencies section in VisualTests target
in_vt_deps && /\);/ { 
    in_vt_deps = 0; 
    skip_until_deps_end = 0;
    # Print the closing bracket
    print; 
    next;
}

# If we are skipping the middle of the dependencies array, do not print those lines
skip_until_deps_end { next; }

# Print all other lines as is
{ print; }
' "$PROJ_FILE" > "${PROJ_FILE}.tmp"

# 4. Also modify build phases to remove any explicit dependencies
awk '
# Identify build phases for VisualTests 
/buildPhases = \(/ { in_build_phases = 1; }
/\);/            { in_build_phases = 0; }

# Inside build phases, look for any framework references to SwiftUICore
in_build_phases && /SwiftUICore/ {
    # Comment out this line
    print "/* Disabled: " $0 " */";
    next;
}

# Print all other lines as is
{ print; }
' "${PROJ_FILE}.tmp" > "${PROJ_FILE}.tmp2"

# 5. Final pass to clean up any remaining reference issues
awk '
# Special handling for target_dependencies sections
/TargetDependencies/ { in_target_deps = 1; }
/\);/                { in_target_deps = 0; }

# Find any references to SwiftUICore and comment them out
/SwiftUICore/ {
    print "/* Disabled SwiftUICore reference: " $0 " */";
    next;
}

# Find any references to the gui target in the VisualTests dependencies and comment them out
in_target_deps && /"gui"/ {
    print "/* Disabled gui dependency: " $0 " */";
    next;
}

# Print all other lines as is
{ print; }
' "${PROJ_FILE}.tmp2" > "${PROJ_FILE}.tmp3"

# 6. Replace the original with our modified version
mv "${PROJ_FILE}.tmp3" "$PROJ_FILE"
rm -f "${PROJ_FILE}.tmp" "${PROJ_FILE}.tmp2"

echo "Modified target dependencies in project file"

# 7. Create a standalone build command script
cat > build_standalone_visualtests.sh << 'EOT'
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
EOT

chmod +x build_standalone_visualtests.sh
echo "Created standalone build script: build_standalone_visualtests.sh"

echo "Dependencies fix applied. Please run:"
echo "./build_standalone_visualtests.sh" 