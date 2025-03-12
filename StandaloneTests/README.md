# Standalone Visual Tests

This is a standalone visual testing framework created to support visual regression testing for the HDR+ Swift project without dependencies on the main application.

## Overview

This independent test environment allows you to:

- Create test images (solid colors, gradients, blurred images)
- Compare images with reference images
- Generate visual diff images to highlight differences
- Run visual tests without depending on SwiftUICore or the main application

## Directory Structure

- **VisualTests/**: Core visual testing utilities and test runner
  - `TestRunner.swift`: Main test runner implementation
  - `VisualTestUtility.swift`: Utilities for image comparison and diff generation
- **VisualTestsTests/**: Tests that use the visual testing framework
  - `StandaloneTests.swift`: Example test suite
- **TestOutput/**: Generated test images
- **ReferenceImages/**: Reference images for comparison
- **DiffImages/**: Visual difference images when tests fail

## Usage

### Running the Tests

To run the tests, execute:

```bash
./run_standalone_tests.sh
```

This will build and run all the visual tests using Swift Package Manager.

### Adding New Tests

1. Add new test methods to `TestRunner.swift`
2. Update the `testVisualTestSuite()` method in `StandaloneTests.swift` to call your new test methods

For example:

```swift
// In TestRunner.swift
func testNewVisualFeature() {
    // Create your test image
    let testImage = createCustomImage()
    
    // Compare with reference image
    let matches = VisualTestUtility.compareImage(
        testImage,
        toReferenceNamed: "new_feature_reference",
        tolerance: 0.01,
        in: self
    )
    
    XCTAssertTrue(matches, "Image should match reference image")
}

// In StandaloneTests.swift, add to testVisualTestSuite():
runner.testNewVisualFeature()
```

### Customizing the Test Environment

You can modify:

- `ComparisonOptions` in `VisualTestUtility.swift` to adjust tolerance levels
- Image creation methods in `TestRunner.swift` to create different test patterns
- Build settings in `Package.swift` if you need to add dependencies

## Extending the Framework

To add more visual testing capabilities:

1. Add new image generation functions to `TestRunner.swift`
2. Add new comparison methods to `VisualTestUtility.swift`
3. Create new test methods that use these capabilities

## Troubleshooting

If tests fail, check:

1. The generated test images in `TestOutput/`
2. The reference images in `ReferenceImages/`
3. The diff images in `DiffImages/` to see what's different

If reference images don't exist, they'll be automatically created on the first run.

## Why Standalone?

This standalone approach was created to address linking issues with private frameworks (SwiftUICore) in the main application. By decoupling the visual tests, we can continue visual regression testing without being blocked by framework linking issues. 