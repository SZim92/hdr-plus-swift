import Foundation
import XCTest

/// Utility for managing test fixtures and mock data.
/// Provides a clean environment for each test and handles cleanup automatically.
public final class TestFixtureUtility {
    
    /// A test fixture that manages a temporary directory for test data.
    /// The fixture is automatically cleaned up when it goes out of scope.
    public final class Fixture {
        /// The URL of the temporary directory for this fixture
        public let url: URL
        
        /// The name of the fixture
        public let name: String
        
        /// Creates a new fixture with the given name.
        /// - Parameter name: A name for the fixture, used in directory naming
        public init(name: String) {
            self.name = name
            
            // Create a unique directory name using UUID
            let uniqueName = "\(name)_\(UUID().uuidString)"
            
            // Create URL in the fixtures directory
            self.url = TestConfig.shared.fixturesDir.appendingPathComponent(uniqueName)
            
            // Create the directory
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                TestConfig.shared.logVerbose("Created fixture directory: \(url.path)")
            } catch {
                print("Error creating fixture directory: \(error)")
            }
        }
        
        /// Create a text file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - contents: The text contents of the file
        /// - Returns: The URL of the created file
        @discardableResult
        public func createTextFile(named: String, contents: String) -> URL {
            let fileURL = url.appendingPathComponent(named)
            
            do {
                try contents.write(to: fileURL, atomically: true, encoding: .utf8)
                TestConfig.shared.logVerbose("Created text file: \(fileURL.path)")
                return fileURL
            } catch {
                print("Error creating text file: \(error)")
                return fileURL
            }
        }
        
        /// Create a JSON file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - object: The object to encode as JSON
        /// - Returns: The URL of the created file
        @discardableResult
        public func createJSONFile<T: Encodable>(named: String, object: T) -> URL {
            let fileURL = url.appendingPathComponent(named)
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(object)
                try data.write(to: fileURL)
                TestConfig.shared.logVerbose("Created JSON file: \(fileURL.path)")
                return fileURL
            } catch {
                print("Error creating JSON file: \(error)")
                return fileURL
            }
        }
        
        /// Create an image file in the fixture directory
        /// - Parameters:
        ///   - named: The name of the file
        ///   - data: The image data
        /// - Returns: The URL of the created file
        @discardableResult
        public func createImageFile(named: String, data: Data) -> URL {
            let fileURL = url.appendingPathComponent(named)
            
            do {
                try data.write(to: fileURL)
                TestConfig.shared.logVerbose("Created image file: \(fileURL.path)")
                return fileURL
            } catch {
                print("Error creating image file: \(error)")
                return fileURL
            }
        }
        
        /// Create a directory in the fixture
        /// - Parameter named: The name of the directory
        /// - Returns: The URL of the created directory
        @discardableResult
        public func createDirectory(named: String) -> URL {
            let dirURL = url.appendingPathComponent(named)
            
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                TestConfig.shared.logVerbose("Created directory: \(dirURL.path)")
                return dirURL
            } catch {
                print("Error creating directory: \(error)")
                return dirURL
            }
        }
        
        /// Cleanup the fixture directory.
        /// This is called automatically when the fixture is deallocated.
        func cleanup() {
            do {
                try FileManager.default.removeItem(at: url)
                TestConfig.shared.logVerbose("Cleaned up fixture directory: \(url.path)")
            } catch {
                print("Error cleaning up fixture directory: \(error)")
            }
        }
        
        deinit {
            cleanup()
        }
    }
    
    // MARK: - Mock Creation Helpers
    
    /// Creates a mock camera configuration file in the given fixture.
    /// - Parameter fixture: The fixture to create the mock in.
    /// - Returns: The URL of the created mock camera configuration.
    public static func createMockCameraConfig(in fixture: Fixture) -> URL {
        let mockConfig = [
            "camera": [
                "model": "HDR+ Test Camera",
                "sensorSize": [
                    "width": 4032,
                    "height": 3024
                ],
                "pixelSize": 1.4,
                "fNumber": 1.8,
                "focalLength": 26.0,
                "iso": 100,
                "exposureTime": 0.01
            ],
            "processing": [
                "noiseReduction": "moderate",
                "sharpening": "low",
                "colorProfile": "natural"
            ]
        ]
        
        return fixture.createJSONFile(named: "camera_config.json", object: mockConfig)
    }
    
    /// Creates a mock burst sequence in the given fixture.
    /// - Parameters:
    ///   - fixture: The fixture to create the mock in.
    ///   - frameCount: The number of frames to create in the burst.
    /// - Returns: The URLs of the created mock burst frames.
    public static func createMockBurstSequence(in fixture: Fixture, frameCount: Int = 5) -> [URL] {
        // Create a directory for the burst
        let burstDir = fixture.createDirectory(named: "burst_sequence")
        
        // Create frame metadata
        let metadata = [
            "frames": (0..<frameCount).map { index in
                return [
                    "id": "frame_\(index)",
                    "exposureTime": 1.0 / (100.0 + Double(index) * 10.0),
                    "iso": 100 + index * 50,
                    "timestamp": Date().timeIntervalSince1970 + Double(index) * 0.1
                ]
            }
        ]
        
        // Create metadata file
        fixture.createJSONFile(named: "burst_metadata.json", object: metadata)
        
        // Create dummy frame files (normally these would be images)
        var frameURLs: [URL] = []
        for i in 0..<frameCount {
            let frameData = Data([UInt8](repeating: UInt8(i), count: 1024)) // Dummy data
            let frameURL = fixture.createImageFile(named: "frame_\(i).raw", data: frameData)
            frameURLs.append(frameURL)
        }
        
        return frameURLs
    }
    
    /// Creates a mock system information file in the given fixture.
    /// - Parameter fixture: The fixture to create the mock in.
    /// - Returns: The URL of the created mock system information.
    public static func createMockSystemInfo(in fixture: Fixture) -> URL {
        let mockSystemInfo = [
            "os": "macOS",
            "version": "12.0",
            "device": "MacBookPro",
            "processor": "Apple M1",
            "memory": 16384,
            "gpu": "Apple M1 GPU",
            "metalSupported": true
        ]
        
        return fixture.createJSONFile(named: "system_info.json", object: mockSystemInfo)
    }
    
    /// Creates a mock HDR settings file in the given fixture.
    /// - Parameter fixture: The fixture to create the mock in.
    /// - Returns: The URL of the created mock HDR settings.
    public static func createMockHDRSettings(in fixture: Fixture) -> URL {
        let mockSettings = [
            "hdrMode": "auto",
            "toneMapping": "filmic",
            "contrast": 1.2,
            "saturation": 1.0,
            "sharpness": 0.8,
            "shadows": 0.4,
            "highlights": -0.2,
            "noiseReduction": "medium"
        ]
        
        return fixture.createJSONFile(named: "hdr_settings.json", object: mockSettings)
    }
    
    /// Creates a mock API response in the given fixture.
    /// - Parameters:
    ///   - fixture: The fixture to create the mock in.
    ///   - statusCode: The HTTP status code to mock.
    ///   - response: The API response to mock.
    /// - Returns: The URL of the created mock API response.
    public static func createMockAPIResponse<T: Encodable>(
        in fixture: Fixture,
        statusCode: Int = 200,
        response: T
    ) -> URL {
        let mockResponse = [
            "status": statusCode,
            "headers": [
                "Content-Type": "application/json",
                "X-API-Version": "1.0",
                "X-Request-ID": UUID().uuidString
            ],
            "data": response
        ] as [String: Any]
        
        // Convert to Data and back to ensure it's JSON-serializable
        let jsonData = try! JSONSerialization.data(withJSONObject: mockResponse)
        return fixture.createImageFile(named: "api_response.json", data: jsonData)
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Creates a new test fixture for this test case.
    /// The fixture will be automatically cleaned up when it goes out of scope.
    /// - Parameter name: Optional name for the fixture, defaults to the test name.
    /// - Returns: A new fixture for this test.
    public func createFixture(named name: String? = nil) -> TestFixtureUtility.Fixture {
        let fixtureName = name ?? String(describing: type(of: self))
        return TestFixtureUtility.Fixture(name: fixtureName)
    }
} 