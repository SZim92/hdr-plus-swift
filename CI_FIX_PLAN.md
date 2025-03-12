# CI and Test Fix Plan for HDR+ Swift

## Issues Found

1. **Xcode Installation Issues**:
   - Only Command Line Tools were installed (`/Library/Developer/CommandLineTools`)
   - Full Xcode.app is required for running `xcodebuild` tests
   - `xcode-select --print-path` was pointing to CommandLineTools
   - ✅ FIXED: Xcode 16.2 is now installed and properly configured

2. **Test Script Configuration Issues**:
   - `Scripts/run-tests.sh` was looking for "HDRPlus" scheme which doesn't exist
   - ✅ FIXED: Updated the script to use "gui" scheme
   - ❌ ISSUE: The "gui" scheme is not configured for testing (error: "Scheme gui is not currently configured for the test action")

3. **CI Configuration**:
   - GitHub Actions workflows are extensive and well-structured
   - Local execution environment requires proper configuration

## Next Steps and Detailed Fix Plan

### 1. Configure Xcode Schemes for Testing

The key issue is that the Xcode schemes in the project aren't properly configured for testing. To fix this:

1. Open the project in Xcode:
   ```bash
   open burstphoto.xcodeproj
   ```

2. Edit the "gui" scheme:
   - In Xcode, go to Product > Scheme > Edit Scheme
   - Select the "Test" action from the left sidebar
   - Click the "+" button under "Tests" to add test targets
   - Add all test targets from the Tests directory
   - Save the scheme and make sure "Shared" is checked

3. Alternative: Create a dedicated test scheme:
   ```bash
   # In Xcode:
   # Product > Scheme > New Scheme...
   # Name it "HDRPlusTests"
   # Configure to include all test targets
   # Save as shared scheme
   ```

### 2. Set Up Test Targets

If test targets don't exist in the project:

1. In Xcode, add proper test targets:
   - File > New > Target
   - Select "Unit Testing Bundle"
   - Create separate targets for UnitTests, IntegrationTests, VisualTests, and PerformanceTests
   - Configure each target to include the appropriate test files
   - Update the test scripts to use the correct target names

### 3. Update Test Scripts

After configuring the schemes:

1. Update test script configuration:
   ```bash
   # Already fixed:
   # - Changed TEST_SCHEME="HDRPlus" to TEST_SCHEME="gui" in Scripts/run-tests.sh
   
   # Further updates needed:
   # - Update test target specifications in Scripts/run-tests.sh
   # - Fix scheme configuration as described above
   ```

### 4. Update CI Workflow

1. Review GitHub Actions workflow files:
   - Update `.github/workflows/main.yml` to use correct scheme names
   - Ensure test matrix is properly configured 
   - Update the preflight check to use correct test targets

### 5. Documentation Update

1. Update CI documentation:
   - Document the need for full Xcode installation
   - Add specific instructions for configuring test schemes
   - Update any references to "HDRPlus" scheme to use the correct names

### 6. Testing Verification

After completing these changes:

1. Test locally:
   ```bash
   Scripts/run-tests.sh --unit --verbose
   Scripts/run-tests.sh --integration --verbose
   Scripts/run-tests.sh --visual --verbose
   Scripts/run-tests.sh --performance --verbose
   ```

2. Commit changes and push to trigger CI workflows
3. Verify CI builds pass in GitHub Actions
4. Update status badge in README.md when CI is working

## Summary

The key issue is a mismatch between the expected test configuration in the CI scripts and the actual Xcode project setup. By properly configuring the Xcode schemes for testing and updating the CI scripts to match the actual project structure, we can get the tests running both locally and in CI.