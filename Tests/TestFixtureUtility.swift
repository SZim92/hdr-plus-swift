import Foundation
import XCTest

/// TestFixtureUtility provides easy management of test fixtures and mocks.
/// Test fixtures are automatically cleaned up when the test finishes.
public class TestFixtureUtility {
    
    /// A fixture represents a temporary environment for a test.
    /// It automatically cleans up when deallocated.
    public class Fixture {
        /// The fixture's unique identifier
        public let identifier: String
        
        /// The base directory for this fixture
        public let directory: URL
        
        /// Tracks whether this fixture has been cleaned up
        private var isCleanedUp = false
        
        /// Creates a new test fixture
        /// - Parameter identifier: Optional identifier for the fixture. If nil, a UUID will be used.
        public init(identifier: String? = nil) {
            self.identifier = identifier ?? UUID().uuidString
            
            let baseDir = TestConfig.shared.fixturesDirectory
            self.directory = baseDir.appendingPathComponent(self.identifier)
            
            // Create the fixture directory
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                XCTFail("Failed to create fixture directory: \(error)")
            }
        }
        
        deinit {
            cleanup()
        }
        
        /// Manually clean up the fixture
        public func cleanup() {
            if !isCleanedUp {
                do {
                    if FileManager.default.fileExists(atPath: directory.path) {
                        try FileManager.default.removeItem(at: directory)
                    }
                    isCleanedUp = true
                } catch {
                    print("Error cleaning up fixture \(identifier): \(error)")
                }
            }
        }
        
        // MARK: - File Creation Helpers
        
        /// Creates a file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - content: The content of the file as a string
        /// - Returns: The URL of the created file
        @discardableResult
        public func createFile(named: String, content: String) throws -> URL {
            let fileURL = directory.appendingPathComponent(named)
            
            // Create parent directories if needed
            let parentDir = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
        
        /// Creates a text file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - contents: The content of the file as a string
        /// - Returns: The URL of the created file
        @discardableResult
        public func createTextFile(named: String, contents: String) -> URL {
            do {
                return try createFile(named: named, content: contents)
            } catch {
                XCTFail("Failed to create text file \(named): \(error)")
                return directory.appendingPathComponent(named)
            }
        }
        
        /// Creates a binary data file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - data: The binary data to write
        /// - Returns: The URL of the created file
        @discardableResult
        public func createDataFile(named: String, data: Data) -> URL {
            let fileURL = directory.appendingPathComponent(named)
            
            do {
                // Create parent directories if needed
                let parentDir = fileURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parentDir.path) {
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }
                
                try data.write(to: fileURL)
                return fileURL
            } catch {
                XCTFail("Failed to create data file \(named): \(error)")
                return fileURL
            }
        }
        
        /// Creates a JSON file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - object: The object to serialize to JSON
        /// - Returns: The URL of the created file
        @discardableResult
        public func createJSONFile<T: Encodable>(named: String, object: T) -> URL {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            do {
                let data = try encoder.encode(object)
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    XCTFail("Failed to convert JSON data to string for \(named)")
                    return directory.appendingPathComponent(named)
                }
                
                return try createFile(named: named, content: jsonString)
            } catch {
                XCTFail("Failed to create JSON file \(named): \(error)")
                return directory.appendingPathComponent(named)
            }
        }
        
        /// Creates a temporary URL for a file
        /// - Parameter fileName: Optional file name. If nil, a unique name will be generated.
        /// - Returns: A URL that can be used for temporary storage
        public func temporaryURL(fileName: String? = nil) -> URL {
            let name = fileName ?? "\(UUID().uuidString).tmp"
            return directory.appendingPathComponent(name)
        }
        
        /// Returns the URL for a file in the fixture directory
        /// - Parameter fileName: The name of the file
        /// - Returns: The URL of the file
        public func url(for fileName: String) -> URL {
            return directory.appendingPathComponent(fileName)
        }
        
        // MARK: - Directory Helpers
        
        /// Creates a subdirectory in the fixture directory
        /// - Parameter path: The path of the subdirectory
        /// - Returns: The URL of the created directory
        @discardableResult
        public func createDirectory(at path: String) -> URL {
            let dirURL = directory.appendingPathComponent(path)
            
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                return dirURL
            } catch {
                XCTFail("Failed to create directory at \(path): \(error)")
                return dirURL
            }
        }
        
        /// Creates multiple files from a dictionary
        /// - Parameter files: Dictionary of filename to content
        /// - Returns: Dictionary of filename to URL
        @discardableResult
        public func createFiles(_ files: [String: String]) -> [String: URL] {
            var results = [String: URL]()
            
            for (name, content) in files {
                do {
                    let url = try createFile(named: name, content: content)
                    results[name] = url
                } catch {
                    XCTFail("Failed to create file \(name): \(error)")
                }
            }
            
            return results
        }
    }
    
    // MARK: - Mock Creation Helpers
    
    /// Creates a mock camera configuration for testing
    /// - Parameters:
    ///   - fixture: The fixture to create the mock in
    ///   - width: The sensor width in pixels
    ///   - height: The sensor height in pixels
    ///   - hasRawSupport: Whether the camera supports RAW capture
    /// - Returns: The URL of the created configuration file
    public static func createMockCameraConfig(
        in fixture: Fixture,
        width: Int = 4032,
        height: Int = 3024,
        hasRawSupport: Bool = true
    ) -> URL {
        let config: [String: Any] = [
            "camera": [
                "sensorWidth": width,
                "sensorHeight": height,
                "pixelSize": 1.4,
                "hasRawSupport": hasRawSupport,
                "maxISO": 3200,
                "defaultShutterSpeed": 0.016666 // 1/60
            ],
            "processing": [
                "defaultNoiseReduction": "medium",
                "defaultSharpening": 0.5,
                "colorProfile": "sRGB"
            ],
            "features": [
                "supportsBurst": true,
                "supportsHDR": true,
                "supportsNightMode": hasRawSupport,
                "maxBurstLength": 10
            ]
        ]
        
        // Convert to JSON data
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
        } catch {
            XCTFail("Failed to serialize mock camera config: \(error)")
            return fixture.url(for: "camera_config.json")
        }
        
        // Write to file
        return fixture.createDataFile(named: "camera_config.json", data: jsonData)
    }
    
    /// Creates mock burst frame files for testing
    /// - Parameters:
    ///   - fixture: The fixture to create the mocks in
    ///   - count: Number of frames to create
    ///   - width: Width of each frame
    ///   - height: Height of each frame
    /// - Returns: Array of URLs to the created frame files
    public static func createMockBurstFrames(
        in fixture: Fixture,
        count: Int = 8,
        width: Int = 1024,
        height: Int = 768
    ) -> [URL] {
        // Create a burst directory
        let burstDir = fixture.createDirectory(at: "burst")
        var frameURLs = [URL]()
        
        // Create mock frame data (just random bytes for testing)
        let bytesPerPixel = 2 // 16-bit grayscale
        let dataSize = width * height * bytesPerPixel
        
        for i in 0..<count {
            // Generate random data to simulate an image
            var data = Data(count: dataSize)
            data.withUnsafeMutableBytes { bufferPtr in
                if let addr = bufferPtr.baseAddress {
                    for j in 0..<dataSize {
                        let value = UInt8.random(in: 0...255)
                        addr.advanced(by: j).storeBytes(of: value, as: UInt8.self)
                    }
                }
            }
            
            // Create the frame file
            let frameURL = fixture.createDataFile(
                named: "burst/frame_\(i).raw",
                data: data
            )
            frameURLs.append(frameURL)
            
            // Create metadata JSON
            let metadata: [String: Any] = [
                "index": i,
                "exposure": 1.0 / Double(30 + i),
                "iso": 100 * (i + 1),
                "timestamp": Date().timeIntervalSince1970 + Double(i) * 0.1,
                "width": width,
                "height": height,
                "format": "RAW16",
                "isBaseFrame": (i == 0)
            ]
            
            // Convert to JSON and write
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted])
                _ = fixture.createDataFile(
                    named: "burst/frame_\(i).json",
                    data: jsonData
                )
            } catch {
                XCTFail("Failed to create metadata for frame \(i): \(error)")
            }
        }
        
        return frameURLs
    }
    
    /// Creates a mock system information file for testing
    /// - Parameter fixture: The fixture to create the mock in
    /// - Returns: The URL of the created file
    public static func createMockSystemInfo(in fixture: Fixture) -> URL {
        let systemInfo: [String: Any] = [
            "device": [
                "model": "TestDevice",
                "osVersion": "1.0",
                "architecture": "arm64"
            ],
            "hardware": [
                "cpu": [
                    "cores": 8,
                    "architecture": "arm64"
                ],
                "gpu": [
                    "name": "TestGPU",
                    "metalSupported": true,
                    "metalVersion": "2.0"
                ],
                "memory": [
                    "totalRAM": 8 * 1024 * 1024 * 1024, // 8 GB
                    "availableRAM": 4 * 1024 * 1024 * 1024 // 4 GB
                ]
            ],
            "capabilities": [
                "supportsHDR": true,
                "supportsRAW": true,
                "supportsMetalCompute": true,
                "maxImageSize": 8192
            ]
        ]
        
        // Convert to JSON data
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: systemInfo, options: [.prettyPrinted])
        } catch {
            XCTFail("Failed to serialize mock system info: \(error)")
            return fixture.url(for: "system_info.json")
        }
        
        // Write to file
        return fixture.createDataFile(named: "system_info.json", data: jsonData)
    }
    
    /// Creates a mock HDR pipeline configuration for testing
    /// - Parameter fixture: The fixture to create the mock in
    /// - Returns: The URL of the created file
    public static func createMockHDRPipelineConfig(in fixture: Fixture) -> URL {
        let pipelineConfig: [String: Any] = [
            "alignment": [
                "method": "pyramid",
                "maxPyramidLevel": 4,
                "patchSize": 16,
                "searchRadius": 15,
                "useRobustAlignment": true
            ],
            "merging": [
                "method": "temporal",
                "weightingMode": "variance",
                "robustMerge": true,
                "spatialDenoising": true,
                "temporalDenoising": true
            ],
            "finishing": [
                "sharpening": 0.5,
                "colorBalance": "auto",
                "tonemapping": "filmic",
                "chromaDenoising": true,
                "saturation": 1.1
            ],
            "debug": [
                "saveIntermediateFrames": false,
                "saveMergeWeights": false,
                "saveAlignmentVectors": false
            ]
        ]
        
        // Convert to JSON data
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: pipelineConfig, options: [.prettyPrinted])
        } catch {
            XCTFail("Failed to serialize mock HDR pipeline config: \(error)")
            return fixture.url(for: "hdr_pipeline.json")
        }
        
        // Write to file
        return fixture.createDataFile(named: "hdr_pipeline.json", data: jsonData)
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Creates a test fixture for use in the test case
    /// - Returns: A new test fixture that will be automatically cleaned up
    public func createFixture() -> TestFixtureUtility.Fixture {
        let testName = name
        return TestFixtureUtility.Fixture(identifier: testName)
    }
} 