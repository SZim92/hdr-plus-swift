import Foundation
import XCTest

/// A test fixture represents a self-contained environment for testing
/// that manages its own resources and cleans up after itself.
class TestFixture {
    /// The base directory for this fixture
    let baseDirectory: URL
    
    /// The unique identifier for this fixture
    let identifier: String
    
    /// Whether to clean up the fixture after use
    let cleanupOnDeinit: Bool
    
    /// A list of URLs created by this fixture
    private var createdURLs: [URL] = []
    
    /// Initializes a new test fixture
    /// - Parameters:
    ///   - identifier: The unique identifier for this fixture (defaults to a UUID)
    ///   - cleanupOnDeinit: Whether to clean up the fixture when it's deallocated
    init(identifier: String = UUID().uuidString, cleanupOnDeinit: Bool = TestConfig.shared.cleanupTestFixtures) {
        self.identifier = identifier
        self.cleanupOnDeinit = cleanupOnDeinit
        
        // Create the base directory
        self.baseDirectory = TestConfig.shared.testFixturesDir.appendingPathComponent(identifier)
        
        // Create the directory
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }
    
    /// Cleans up this fixture
    func cleanup() {
        // Remove the base directory
        try? FileManager.default.removeItem(at: baseDirectory)
    }
    
    /// Automatically clean up on deinitialization
    deinit {
        if cleanupOnDeinit {
            cleanup()
        }
    }
    
    // MARK: - File Creation
    
    /// Creates a file with the specified content
    /// - Parameters:
    ///   - name: The name of the file to create
    ///   - content: The content to write to the file
    /// - Returns: The URL of the created file
    @discardableResult
    func createFile(named name: String, content: String) throws -> URL {
        let fileURL = baseDirectory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        createdURLs.append(fileURL)
        return fileURL
    }
    
    /// Creates a file with the specified data
    /// - Parameters:
    ///   - name: The name of the file to create
    ///   - data: The data to write to the file
    /// - Returns: The URL of the created file
    @discardableResult
    func createFile(named name: String, data: Data) throws -> URL {
        let fileURL = baseDirectory.appendingPathComponent(name)
        try data.write(to: fileURL)
        createdURLs.append(fileURL)
        return fileURL
    }
    
    /// Creates a JSON file with the specified object
    /// - Parameters:
    ///   - name: The name of the file to create
    ///   - object: The object to encode as JSON
    ///   - options: The JSON encoding options
    /// - Returns: The URL of the created file
    @discardableResult
    func createJSONFile<T: Encodable>(named name: String, object: T, options: JSONEncoder.OutputFormatting = [.prettyPrinted, .sortedKeys]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = options
        let data = try encoder.encode(object)
        return try createFile(named: name, data: data)
    }
    
    /// Creates a directory with the specified name
    /// - Parameter name: The name of the directory to create
    /// - Returns: The URL of the created directory
    @discardableResult
    func createDirectory(named name: String) throws -> URL {
        let directoryURL = baseDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        createdURLs.append(directoryURL)
        return directoryURL
    }
    
    /// Creates a directory structure with the specified path components
    /// - Parameter pathComponents: The path components for the directory structure
    /// - Returns: The URL of the created directory
    @discardableResult
    func createDirectoryStructure(pathComponents: [String]) throws -> URL {
        // Start with the base directory
        var currentURL = baseDirectory
        
        // Create each directory in the path
        for component in pathComponents {
            currentURL = currentURL.appendingPathComponent(component)
            try FileManager.default.createDirectory(at: currentURL, withIntermediateDirectories: true)
            createdURLs.append(currentURL)
        }
        
        return currentURL
    }
    
    // MARK: - Resource Management
    
    /// Copies a file from the test resources to the fixture
    /// - Parameters:
    ///   - resourceName: The name of the resource to copy
    ///   - destinationName: The name to give the copied file (defaults to the resource name)
    /// - Returns: The URL of the copied file
    @discardableResult
    func copyResource(named resourceName: String, to destinationName: String? = nil) throws -> URL {
        let config = TestConfig.shared
        let resourceURL = config.testInputURL(named: resourceName)
        let destinationURL = baseDirectory.appendingPathComponent(destinationName ?? resourceName)
        
        try FileManager.default.copyItem(at: resourceURL, to: destinationURL)
        createdURLs.append(destinationURL)
        
        return destinationURL
    }
    
    /// Copies a pattern image from the test resources to the fixture
    /// - Parameters:
    ///   - patternName: The name of the pattern to copy
    ///   - destinationName: The name to give the copied file (defaults to the pattern name)
    /// - Returns: The URL of the copied file
    @discardableResult
    func copyPatternImage(named patternName: String, to destinationName: String? = nil) throws -> URL {
        let config = TestConfig.shared
        let patternURL = config.patternImageURL(named: patternName)
        let destinationURL = baseDirectory.appendingPathComponent(destinationName ?? patternName)
        
        try FileManager.default.copyItem(at: patternURL, to: destinationURL)
        createdURLs.append(destinationURL)
        
        return destinationURL
    }
    
    /// Copies a RAW image from the test resources to the fixture
    /// - Parameters:
    ///   - rawName: The name of the RAW image to copy
    ///   - destinationName: The name to give the copied file (defaults to the RAW image name)
    /// - Returns: The URL of the copied file
    @discardableResult
    func copyRAWImage(named rawName: String, to destinationName: String? = nil) throws -> URL {
        let config = TestConfig.shared
        let rawURL = config.rawImageURL(named: rawName)
        let destinationURL = baseDirectory.appendingPathComponent(destinationName ?? rawName)
        
        try FileManager.default.copyItem(at: rawURL, to: destinationURL)
        createdURLs.append(destinationURL)
        
        return destinationURL
    }
    
    /// Copies a burst sequence from the test resources to the fixture
    /// - Parameters:
    ///   - burstName: The name of the burst sequence to copy
    ///   - destinationName: The name to give the copied directory (defaults to the burst name)
    /// - Returns: The URL of the copied directory
    @discardableResult
    func copyBurstSequence(named burstName: String, to destinationName: String? = nil) throws -> URL {
        let config = TestConfig.shared
        let burstURL = config.burstSequenceURL(named: burstName)
        let destinationURL = baseDirectory.appendingPathComponent(destinationName ?? burstName)
        
        try FileManager.default.copyItem(at: burstURL, to: destinationURL)
        createdURLs.append(destinationURL)
        
        return destinationURL
    }
    
    // MARK: - Utility Methods
    
    /// Creates a URL for a file in this fixture
    /// - Parameter name: The name of the file
    /// - Returns: The URL for the file
    func url(for name: String) -> URL {
        return baseDirectory.appendingPathComponent(name)
    }
    
    /// Checks if a file exists in this fixture
    /// - Parameter name: The name of the file
    /// - Returns: True if the file exists
    func fileExists(named name: String) -> Bool {
        let fileURL = url(for: name)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Deletes a file from this fixture
    /// - Parameter name: The name of the file to delete
    func deleteFile(named name: String) throws {
        let fileURL = url(for: name)
        try FileManager.default.removeItem(at: fileURL)
        
        // Remove from created URLs
        if let index = createdURLs.firstIndex(of: fileURL) {
            createdURLs.remove(at: index)
        }
    }
    
    /// Lists all files in this fixture
    /// - Returns: An array of file names
    func listFiles() -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: baseDirectory.path)
        } catch {
            return []
        }
    }
    
    /// Lists all files in a directory in this fixture
    /// - Parameter directoryName: The name of the directory
    /// - Returns: An array of file names
    func listFiles(inDirectory directoryName: String) -> [String] {
        let directoryURL = url(for: directoryName)
        do {
            return try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
        } catch {
            return []
        }
    }
}

/// TestFixtureUtility provides helper methods for creating and managing test fixtures
class TestFixtureUtility {
    /// Creates a new test fixture
    /// - Parameters:
    ///   - identifier: The unique identifier for the fixture (defaults to a UUID)
    ///   - cleanupOnDeinit: Whether to clean up the fixture when it's deallocated
    /// - Returns: A new test fixture
    static func createFixture(identifier: String = UUID().uuidString, cleanupOnDeinit: Bool = TestConfig.shared.cleanupTestFixtures) -> TestFixture {
        // Ensure the base directory exists
        TestConfig.shared.createDirectories()
        
        return TestFixture(identifier: identifier, cleanupOnDeinit: cleanupOnDeinit)
    }
    
    /// Creates a fixture with a mock camera configuration
    /// - Parameters:
    ///   - cameraModel: The camera model for the mock configuration
    ///   - sensorWidth: The sensor width in pixels
    ///   - sensorHeight: The sensor height in pixels
    ///   - identifier: The unique identifier for the fixture
    /// - Returns: A test fixture with a mock camera configuration
    static func createFixtureWithMockCameraConfig(
        cameraModel: String = "TestCamera",
        sensorWidth: Int = 4000,
        sensorHeight: Int = 3000,
        identifier: String = "mock_camera_config"
    ) throws -> TestFixture {
        let fixture = createFixture(identifier: identifier)
        
        // Create a mock camera configuration
        let cameraConfig: [String: Any] = [
            "camera_model": cameraModel,
            "sensor": [
                "width": sensorWidth,
                "height": sensorHeight,
                "pixel_size": 1.4,
                "color_filter_array": "RGGB"
            ],
            "lens": [
                "focal_length": 4.2,
                "max_aperture": 1.8,
                "min_aperture": 16.0
            ],
            "iso_range": [
                "min": 100,
                "max": 3200
            ],
            "exposure_time_range": [
                "min": 0.001,
                "max": 30.0
            ]
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: cameraConfig, options: [.prettyPrinted, .sortedKeys])
        
        // Create the config file
        try fixture.createFile(named: "camera_config.json", data: jsonData)
        
        return fixture
    }
    
    /// Creates a fixture with mock burst frames
    /// - Parameters:
    ///   - frameCount: The number of frames to create
    ///   - width: The width of each frame
    ///   - height: The height of each frame
    ///   - identifier: The unique identifier for the fixture
    /// - Returns: A test fixture with mock burst frames
    static func createFixtureWithMockBurstFrames(
        frameCount: Int = 8,
        width: Int = 4000,
        height: Int = 3000,
        identifier: String = "mock_burst_frames"
    ) throws -> TestFixture {
        let fixture = createFixture(identifier: identifier)
        
        // Create a directory for the burst frames
        let burstDir = try fixture.createDirectory(named: "burst")
        
        // Create mock frames and metadata
        for i in 0..<frameCount {
            // Create a mock frame file (just a placeholder)
            let framePath = burstDir.appendingPathComponent("frame_\(i).raw")
            
            // Create some dummy data (actual RAW data would be much larger)
            let dummyData = Data(repeating: UInt8(i), count: 1024)
            try dummyData.write(to: framePath)
            
            // Create metadata for this frame
            let metadata: [String: Any] = [
                "frame_index": i,
                "exposure_time": 1.0 / Double(100 + i * 10),
                "iso": 100 + i * 50,
                "aperture": 2.8,
                "timestamp": Date().timeIntervalSince1970 + Double(i) * 0.1
            ]
            
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted])
            
            // Create the metadata file
            let metadataPath = burstDir.appendingPathComponent("frame_\(i)_metadata.json")
            try jsonData.write(to: metadataPath)
        }
        
        // Create a burst metadata file
        let burstMetadata: [String: Any] = [
            "frame_count": frameCount,
            "width": width,
            "height": height,
            "bit_depth": 12,
            "color_filter_array": "RGGB",
            "camera_model": "TestCamera",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: burstMetadata, options: [.prettyPrinted])
        
        // Create the metadata file
        try fixture.createFile(named: "burst_metadata.json", data: jsonData)
        
        return fixture
    }
    
    /// Creates a fixture with a mock file system structure
    /// - Parameters:
    ///   - directoryStructure: A dictionary representing the directory structure
    ///   - identifier: The unique identifier for the fixture
    /// - Returns: A test fixture with a mock file system structure
    static func createFixtureWithMockFileSystem(
        directoryStructure: [String: Any],
        identifier: String = "mock_file_system"
    ) throws -> TestFixture {
        let fixture = createFixture(identifier: identifier)
        
        // Create the directory structure
        try createDirectoryStructure(directoryStructure, in: fixture, atPath: "")
        
        return fixture
    }
    
    /// Helper method to create a directory structure
    /// - Parameters:
    ///   - structure: A dictionary representing the directory structure
    ///   - fixture: The test fixture
    ///   - path: The current path
    private static func createDirectoryStructure(_ structure: [String: Any], in fixture: TestFixture, atPath path: String) throws {
        for (key, value) in structure {
            let itemPath = path.isEmpty ? key : "\(path)/\(key)"
            
            if let dictionary = value as? [String: Any] {
                // Create a directory
                if !path.isEmpty {
                    try fixture.createDirectory(named: itemPath)
                }
                
                // Recursively create the directory structure
                try createDirectoryStructure(dictionary, in: fixture, atPath: itemPath)
            } else if let content = value as? String {
                // Create a file with content
                try fixture.createFile(named: itemPath, content: content)
            } else if let data = value as? Data {
                // Create a file with data
                try fixture.createFile(named: itemPath, data: data)
            }
        }
    }
}

/// Extension to XCTestCase to provide easy access to test fixtures
extension XCTestCase {
    /// Creates a test fixture for this test case
    /// - Parameter cleanupOnDeinit: Whether to clean up the fixture when it's deallocated
    /// - Returns: A new test fixture
    func createFixture(cleanupOnDeinit: Bool = TestConfig.shared.cleanupTestFixtures) -> TestFixture {
        let className = String(describing: type(of: self))
        let identifier = "\(className)_\(UUID().uuidString)"
        return TestFixtureUtility.createFixture(identifier: identifier, cleanupOnDeinit: cleanupOnDeinit)
    }
} 