#!/bin/bash
# setup-test-scheme.sh
# Script to set up a test scheme for HDR+ Swift project
# Run this after installing Xcode to configure testing

set -e

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}HDR+ Swift Test Scheme Setup${NC}"
echo -e "This script will help you configure Xcode for testing."
echo ""

# Check if Xcode is properly installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild command not found.${NC}"
    echo -e "Please install Xcode from the App Store and run 'sudo xcodebuild -license accept'."
    exit 1
fi

# Check if xcode-select is pointing to Xcode.app
XCODE_PATH=$(xcode-select --print-path)
if [[ "$XCODE_PATH" != *"Xcode.app"* ]]; then
    echo -e "${YELLOW}Warning: xcode-select is not pointing to Xcode.app${NC}"
    echo -e "Current path: $XCODE_PATH"
    
    # Check if Xcode.app exists in the Applications folder
    if [ -d "/Applications/Xcode.app" ]; then
        echo -e "Would you like to switch xcode-select to point to /Applications/Xcode.app? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
            echo -e "${GREEN}Successfully switched to /Applications/Xcode.app${NC}"
        fi
    else
        echo -e "${RED}Xcode.app not found in /Applications.${NC}"
        echo -e "Please install Xcode from the App Store."
        exit 1
    fi
fi

# Create HDRPlusTests scheme
echo -e "${BLUE}Creating HDRPlusTests scheme...${NC}"

# First, check if the project exists
if [ ! -d "burstphoto.xcodeproj" ]; then
    echo -e "${RED}Error: burstphoto.xcodeproj not found.${NC}"
    echo -e "Please run this script from the root of the HDR+ Swift project."
    exit 1
fi

# Create a shared xcschemes directory if it doesn't exist
mkdir -p burstphoto.xcodeproj/xcshareddata/xcschemes

# Create the HDRPlusTests.xcscheme file
cat > burstphoto.xcodeproj/xcshareddata/xcschemes/HDRPlusTests.xcscheme << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
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
               BlueprintIdentifier = "REPLACE_WITH_GUI_TARGET_ID"
               BuildableName = "Burst Photo.app"
               BlueprintName = "gui"
               ReferencedContainer = "container:burstphoto.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "REPLACE_WITH_UNIT_TESTS_TARGET_ID"
               BuildableName = "UnitTests.xctest"
               BlueprintName = "UnitTests"
               ReferencedContainer = "container:burstphoto.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "REPLACE_WITH_INTEGRATION_TESTS_TARGET_ID"
               BuildableName = "IntegrationTests.xctest"
               BlueprintName = "IntegrationTests"
               ReferencedContainer = "container:burstphoto.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "REPLACE_WITH_VISUAL_TESTS_TARGET_ID"
               BuildableName = "VisualTests.xctest"
               BlueprintName = "VisualTests"
               ReferencedContainer = "container:burstphoto.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "REPLACE_WITH_PERFORMANCE_TESTS_TARGET_ID"
               BuildableName = "PerformanceTests.xctest"
               BlueprintName = "PerformanceTests"
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
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "REPLACE_WITH_GUI_TARGET_ID"
            BuildableName = "Burst Photo.app"
            BlueprintName = "gui"
            ReferencedContainer = "container:burstphoto.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "REPLACE_WITH_GUI_TARGET_ID"
            BuildableName = "Burst Photo.app"
            BlueprintName = "gui"
            ReferencedContainer = "container:burstphoto.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOF

echo -e "${YELLOW}Note: You will need to open the project in Xcode to complete setup:${NC}"
echo -e "1. Open the project: open burstphoto.xcodeproj"
echo -e "2. Go to Product > Scheme > Edit Scheme..."
echo -e "3. Select HDRPlusTests scheme from the dropdown"
echo -e "4. Update the target IDs in the scheme file to match your project"
echo -e ""
echo -e "${GREEN}Once you've configured the scheme, update the test script:${NC}"
echo -e "Edit Scripts/run-tests.sh and update TEST_SCHEME=\"gui\" to TEST_SCHEME=\"HDRPlusTests\""
echo -e ""

echo -e "${BLUE}Would you like to open the project in Xcode now? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    open burstphoto.xcodeproj
fi

echo -e "${GREEN}Setup script completed.${NC}"
echo -e "You can now run tests with: Scripts/run-tests.sh --unit --verbose" 