#!/bin/bash

# Create a directory for the scheme
SCHEME_DIR="burstphoto.xcodeproj/xcshareddata/xcschemes"
mkdir -p "$SCHEME_DIR"

# Create the VisualTests scheme XML file
cat > "$SCHEME_DIR/VisualTests.xcscheme" << 'EOT'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1340"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "97CFEA522BB20FA300C06AF5"
               BuildableName = "VisualTests.xctest"
               BlueprintName = "VisualTests"
               ReferencedContainer = "container:burstphoto.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "97CFEA522BB20FA300C06AF5"
               BuildableName = "VisualTests.xctest"
               BlueprintName = "VisualTests"
               ReferencedContainer = "container:burstphoto.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97CFEA522BB20FA300C06AF5"
            BuildableName = "VisualTests.xctest"
            BlueprintName = "VisualTests"
            ReferencedContainer = "container:burstphoto.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOT

echo "Created VisualTests scheme"

# Now try to build using the scheme
echo "Building with the VisualTests scheme..."

xcodebuild -project burstphoto.xcodeproj \
  -scheme VisualTests \
  -configuration Debug \
  -arch arm64 \
  build \
  GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1' \
  ONLY_ACTIVE_ARCH=YES \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

echo "Build command completed." 