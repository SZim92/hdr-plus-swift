# HDR+ Swift

![Build Status](https://github.com/SZim92/hdr-plus-swift/actions/workflows/main.yml/badge.svg)

[![Apple Platform Compatibility](https://github.com/SZim92/hdr-plus-swift/actions/workflows/cross-platform.yml/badge.svg)](https://github.com/SZim92/hdr-plus-swift/actions/workflows/cross-platform.yml)

## About

HDR+ Swift is a Swift implementation of Google's HDR+ burst photography algorithm, designed for computational photography on macOS. This project aims to bring powerful HDR image processing to Swift developers and photography enthusiasts.

## Features

- Multi-frame burst photography processing
- Automatic alignment of burst frames
- Temporal merging for noise reduction
- HDR tone mapping
- Local and global contrast enhancement

## Installation

Clone this repository and open the Xcode project:

```bash
git clone https://github.com/SZim92/hdr-plus-swift.git
cd hdr-plus-swift
open burstphoto.xcodeproj
```

## Requirements

- macOS 13.0+ (Ventura)
- Xcode 15.0+
- Swift 5.9+

## Development

### CI System

This project uses GitHub Actions for continuous integration. For details on the CI system, see [CI_DOCS.md](CI_DOCS.md).

#### CI Platform Support

- **macOS-only Testing**: Due to Metal API requirements, automated testing is only performed on macOS platforms (currently Sonoma and Ventura).
- **Build Verification**: CI primarily verifies that the code builds successfully and collects Metal environment diagnostics.
- **Local Testing**: For full testing including Metal shaders, use physical devices with proper GPU support.

### Documentation Standards

This project follows consistent markdown formatting standards to ensure documentation readability and accessibility. For details on the standards and how to check your files, see [MARKDOWN_STANDARDS.md](MARKDOWN_STANDARDS.md).

#### Markdown Formatting Tools

We provide tools to help maintain consistent markdown formatting:

- **Automated Fixing**: Run `.\fix-markdown.ps1` (Windows) or `./fix-markdown.sh` (macOS/Linux) to automatically fix common formatting issues
- **CI Linting**: The `markdown-lint.yml` workflow checks documentation formatting on PRs and pushes
- **Editor Integration**: Configure your editor with markdownlint for real-time feedback

Burst Photo is a macOS app written in Swift / SwiftUI / Metal that implements a simplified version of HDR+, the computational photography pipeline in Google Pixel phones. With Burst Photo, this processing can be applied to a burst of images from any camera, increasing dynamic range and reducing noise of the resulting image. You can read more about HDR+ in Google's paper [Burst photography for high dynamic range and low-light imaging on mobile cameras](http://static.googleusercontent.com/media/www.hdrplusdata.org/en//hdrplus.pdf).

If you are a researcher or you prefer Python/PyTorch, you can check out [hdr-plus-pytorch](https://github.com/martin-marek/hdr-plus-pytorch).

In the example, a burst of 51 images was taken at ISO 51,200 on a Sony A7S III camera. Exposure was adjusted to taste with equal settings for both images. Here is a [comparison](docs/assets/images/gallery/monika_stars.jpg) of a single image from the burst versus a merge of all the images.

![Comparison of single image vs merged burst](docs/assets/images/home/monika_stars.jpg)

To test motion-robustness, a burst with strong scene motion is evaluated. Here is a [full comparison](docs/assets/images/gallery/robustness_comparison.jpg) of results. The figure is similar to Figure 6 in Google's original [publication](http://static.googleusercontent.com/media/www.hdrplusdata.org/en//hdrplus.pdf). The input image was taken from Google's [HDR+ dataset](https://hdrplusdata.org/dataset.html) licensed under [CC BY-SA](https://creativecommons.org/licenses/by-sa/4.0/).

![Motion robustness comparison](docs/assets/images/tech/robustness_comparison.jpg)

For more examples, please visit [burst.photo/gallery/](https://burst.photo/gallery/).

To process a burst of RAW images, simply drag-and-drop them into the app. Only DNG files are supported by default - but if you download and install [Adobe DNG Converter](https://helpx.adobe.com/camera-raw/using/adobe-dng-converter.html), Burst Photo will be able to convert most RAW formats in the background. The resulting image will be in the RAW-DNG format and can be further processed with the RAW converter of choice. You can read more at [burst.photo/help/](https://burst.photo/help/).

![App interface showing drag and drop functionality](docs/assets/images/help/drag-and-drop.jpg)

You can download the app from the [Mac App Store](https://burst.photo/download/) or as a [GitHub release](https://github.com/martin-marek/hdr-plus-swift/releases).

- [x] DNG support
- [x] RAW support (requires Adobe DNG Converter to be installed)
- [x] simple temporal averaging
- [x] motion-robust merge in spatial domain (simplified)
- [x] motion-robust merge in frequency domain (similar to original publication)
- [x] Bayer sensor support
- [x] non-Bayer sensor support (beta)
- [x] support for bursts with bracketed exposure
- [x] optional exposure correction to improve tonality in the shadows
- [x] optional output with full 16 bit precision
- [x] preserves lens profiles
- [x] hot pixel suppression
- [x] multi-threaded RAW conversion and image loading
- [x] caching of converted DNGs both on disk and in-memory
- [x] align+merge running in pure Metal
- [x] native Intel, Apple Silicon support

- [ ] add super-resolution algorithm
- [ ] add support for demosaic images (or foveon cameras)
- [ ] fix progressbar getting stuck loading the first image

Please feel free to contribute to any of these features or suggest other features.

This product includes DNG technology under license by Adobe.

## Testing Framework

This repository includes a comprehensive testing framework designed specifically for HDR image processing. The framework provides tools and utilities to ensure proper functionality, performance, and visual consistency in the HDR+ processing pipeline.

### Key Testing Components

- **Visual Testing**: The `VisualTestUtility` provides specialized support for comparing and validating HDR images, including perceptual comparison and HDR-specific tolerance settings.

- **Performance Testing**: The `HDRPerformanceTestHelper` enables detailed performance analysis of HDR processing, including CPU and GPU timing, memory usage tracking, and pipeline stage analysis.

- **Result Visualization**: The `HDRResultVisualizer` generates visual reports of HDR processing, combining input brackets, output image, histograms, and metadata for easy visual inspection.

- **Quarantine System**: A `TestQuarantine` utility manages flaky tests, allowing them to be tracked, analyzed, and temporarily disabled with proper documentation.

### Running Tests

To run the tests locally:

```bash
swift test --filter "HDRVisualTests"
```

For performance tests:

```bash
swift test --filter "HDRPerformanceTests"
```

### CI Integration

The project includes specialized GitHub Actions workflows for testing:

- **HDR Visual Tests**: Runs visual comparison tests on macOS systems with Metal support
- **Test Quarantine**: Automatically analyzes test stability and manages flaky tests
- **Performance Monitoring**: Tracks and reports performance metrics across changes

### Creating Tests

When creating new HDR tests, use the provided utilities:

```swift
// Visual comparison test
func testHDRProcessing() throws {
    // Process your HDR image
    let result = processHDRImages()
    
    // Compare with reference image with HDR-specific settings
    try assertHDRImage(
        result,
        matchesReferenceNamed: "expected_hdr_result"
    )
}

// Performance test
func testPerformance() throws {
    let metrics = measureHDRPipeline(
        name: "HDR Processing Pipeline",
        stages: [
            "Alignment": alignmentOperation,
            "Merging": mergingOperation,
            "ToneMapping": toneMappingOperation
        ]
    )
    
    // Analyze results
    XCTAssertLessThan(metrics.totalTime, 0.5)
}
```

## Contributing

When contributing to the HDR+ Swift project, make sure to:

1. Write tests for any new functionality
2. Run the test suite locally before submitting a PR
3. Document any test quarantines with appropriate ticket references

## License

[Insert your license information here]
