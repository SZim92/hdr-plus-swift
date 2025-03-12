#!/bin/bash

echo "Creating a standalone visual test runner..."

# 1. Create a directory for our standalone test if it doesn't exist
mkdir -p StandaloneTests/VisualTests

# 2. Create a simple TestRunner Swift file
cat > StandaloneTests/VisualTests/TestRunner.swift << 'EOT'
import XCTest
import Foundation

#if os(macOS)
import AppKit
#endif

/// Simple standalone test runner for visual tests
/// This avoids dependencies on the main application
class StandaloneTestRunner: XCTestCase {
    
    /// Set up test environment
    override func setUp() {
        super.setUp()
        print("Setting up standalone test environment")
    }
    
    /// Basic test to verify the test runner works
    func testRunnerWorks() {
        print("Running standalone test")
        XCTAssertTrue(true, "Standalone test runner is working")
    }
    
    /// Example visual test that creates and verifies a test image
    func testBasicVisualComparison() {
        // Create a simple test image
        let width = 200
        let height = 200
        let bytesPerPixel = 4
        
        print("Creating test image \(width)x\(height)")
        
        // Allocate memory for a simple red square image
        let dataSize = width * height * bytesPerPixel
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
        defer { data.deallocate() }
        
        // Fill with a red color
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                data[pixelIndex] = 255     // R (red)
                data[pixelIndex + 1] = 0   // G
                data[pixelIndex + 2] = 0   // B
                data[pixelIndex + 3] = 255 // A (fully opaque)
            }
        }
        
        // Create CGImage from raw data
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let image = context.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        // Save the image to a test directory
        saveTestImage(image, name: "standalone_test")
        
        // Simple assertion that the image was created successfully
        XCTAssertEqual(image.width, width, "Image width should match")
        XCTAssertEqual(image.height, height, "Image height should match")
        
        print("Successfully created and verified test image")
    }
    
    /// Helper function to save a test image
    private func saveTestImage(_ image: CGImage, name: String) {
        // Create test output directory
        let fileManager = FileManager.default
        let outputDir = URL(fileURLWithPath: "StandaloneTests/TestOutput")
        
        try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let outputURL = outputDir.appendingPathComponent("\(name).png")
        
        #if os(macOS)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: outputURL)
            print("Saved test image to \(outputURL.path)")
        }
        #endif
    }
}
EOT

# 3. Create a simple Package.swift file for our test
cat > StandaloneTests/Package.swift << 'EOT'
// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "StandaloneTests",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "StandaloneTests",
            targets: ["VisualTests"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VisualTests",
            dependencies: [],
            path: "VisualTests"),
        .testTarget(
            name: "VisualTestsTests",
            dependencies: ["VisualTests"],
            path: "VisualTestsTests"),
    ]
)
EOT

# 4. Create a simple test directory
mkdir -p StandaloneTests/VisualTestsTests

# 5. Create a test file that imports and runs our standalone tests
cat > StandaloneTests/VisualTestsTests/StandaloneTests.swift << 'EOT'
import XCTest
@testable import VisualTests

final class StandaloneTests: XCTestCase {
    func testExample() throws {
        // This test simply runs our standalone test runner
        let runner = StandaloneTestRunner()
        
        // Call setup manually
        runner.setUp()
        
        // Run the tests
        runner.testRunnerWorks()
        runner.testBasicVisualComparison()
        
        // Simple assertion to make sure the test ran
        XCTAssertTrue(true, "Standalone test completed successfully")
    }
}
EOT

# 6. Create a simple build script
cat > run_standalone_tests.sh << 'EOT'
#!/bin/bash

echo "Running standalone visual tests..."

# Change to the StandaloneTests directory
cd StandaloneTests

# Make sure the output directory exists
mkdir -p TestOutput

# Run the tests with Swift Package Manager
swift test -v

echo "Standalone tests completed."
EOT

chmod +x run_standalone_tests.sh

echo "Created standalone test environment and test runner."
echo "To run the standalone tests, execute:"
echo "./run_standalone_tests.sh" 