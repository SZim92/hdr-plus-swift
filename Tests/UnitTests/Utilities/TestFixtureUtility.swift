import Foundation
import XCTest

/// Utility for managing test fixtures and resources
public class TestFixtureUtility {
    
    // MARK: - Types
    
    /// Types of test resources
    public enum ResourceType {
        case referenceImage
        case testInput
        case mock
        case shader
        
        /// Path component for this resource type
        var pathComponent: String {
            switch self {
            case .referenceImage:
                return "ReferenceImages"
            case .testInput:
                return "TestInputs"
            case .mock:
                return "Mocks"
            case .shader:
                return "Shaders"
            }
        }
    }
    
    /// Represents a test fixture
    public class Fixture {
        /// Name of the fixture
        public let name: String
        
        /// Temporary directory for this fixture
        public let directory: URL
        
        /// Files created by this fixture
        private var createdFiles: [URL] = []
        
        /// Whether to clean up after the fixture is done
        private let shouldCleanUp: Bool
        
        /// Initializes a new fixture
        /// - Parameters:
        ///   - name: Name of the fixture
        ///   - cleanup: Whether to clean up after the fixture is done
        init(name: String, cleanup: Bool = true) {
            self.name = name
            self.shouldCleanUp = cleanup
            
            // Create temporary directory
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = tempDir.appendingPathComponent("TestFixtures").appendingPathComponent(name)
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        /// Creates a file in the fixture directory
        /// - Parameters:
        ///   - filename: Name of the file
        ///   - contents: Contents of the file
        /// - Returns: URL to the created file
        @discardableResult
        public func createFile(named filename: String, contents: Data) -> URL {
            let fileURL = directory.appendingPathComponent(filename)
            try? contents.write(to: fileURL)
            createdFiles.append(fileURL)
            return fileURL
        }
        
        /// Creates a text file in the fixture directory
        /// - Parameters:
        ///   - filename: Name of the file
        ///   - contents: Text contents of the file
        /// - Returns: URL to the created file
        @discardableResult
        public func createTextFile(named filename: String, contents: String) -> URL {
            let fileURL = directory.appendingPathComponent(filename)
            try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
            createdFiles.append(fileURL)
            return fileURL
        }
        
        /// Creates a JSON file in the fixture directory
        /// - Parameters:
        ///   - filename: Name of the file
        ///   - object: Object to encode as JSON
        /// - Returns: URL to the created file
        @discardableResult
        public func createJSONFile<T: Encodable>(named filename: String, object: T) -> URL {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            guard let data = try? encoder.encode(object) else {
                fatalError("Failed to encode object to JSON")
            }
            
            return createFile(named: filename, contents: data)
        }
        
        /// Copies a file to the fixture directory
        /// - Parameters:
        ///   - url: URL of the file to copy
        ///   - newName: Optional new name for the file
        /// - Returns: URL to the copied file
        @discardableResult
        public func copyFile(from url: URL, newName: String? = nil) -> URL {
            let filename = newName ?? url.lastPathComponent
            let destination = directory.appendingPathComponent(filename)
            
            try? FileManager.default.copyItem(at: url, to: destination)
            createdFiles.append(destination)
            return destination
        }
        
        /// Gets a file URL within the fixture directory
        /// - Parameter filename: Name of the file
        /// - Returns: URL to the file
        public func fileURL(for filename: String) -> URL {
            return directory.appendingPathComponent(filename)
        }
        
        /// Cleans up the fixture
        deinit {
            if shouldCleanUp {
                cleanup()
            }
        }
        
        /// Manually cleans up the fixture
        public func cleanup() {
            for file in createdFiles {
                try? FileManager.default.removeItem(at: file)
            }
            createdFiles.removeAll()
            
            // Try to remove the directory if it's empty
            try? FileManager.default.removeItem(at: directory)
        }
    }
    
    // MARK: - Class Properties
    
    /// The bundle containing test resources
    public static var testBundle: Bundle = {
        // First try the current class's bundle
        let thisBundle = Bundle(for: TestFixtureUtility.self)
        
        // Check if we can find a specific test bundle
        let testBundleName = "HDRPlusTests"
        if let testBundleURL = thisBundle.url(forResource: testBundleName, withExtension: "bundle"),
           let testBundle = Bundle(url: testBundleURL) {
            return testBundle
        }
        
        // Fall back to the current bundle
        return thisBundle
    }()
    
    /// Root directory for test resources
    public static var resourcesDirectory: URL? = {
        var possiblePaths = [
            testBundle.resourceURL?.appendingPathComponent("TestResources"),
            testBundle.resourceURL?.appendingPathComponent("Resources"),
            testBundle.bundleURL.appendingPathComponent("TestResources"),
            testBundle.bundleURL.appendingPathComponent("Resources"),
            Bundle.main.bundleURL.appendingPathComponent("TestResources"),
            Bundle.main.bundleURL.appendingPathComponent("Tests/TestResources")
        ]
        
        // Check if running in a workspace and try to find resources relative to that
        if let workspacePath = ProcessInfo.processInfo.environment["WORKSPACE_PATH"] {
            let workspaceURL = URL(fileURLWithPath: workspacePath)
            possiblePaths.append(workspaceURL.appendingPathComponent("Tests/TestResources"))
        }
        
        // Try each path
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        
        // If we couldn't find it, use a temporary directory and print a warning
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestResources")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("Warning: Could not find test resources directory. Using temporary directory: \(tempDir.path)")
        
        return tempDir
    }()
    
    // MARK: - Resource Methods
    
    /// Gets the URL for a test resource
    /// - Parameters:
    ///   - name: Name of the resource
    ///   - type: Type of resource
    ///   - fileExtension: Optional file extension
    /// - Returns: URL to the resource, or nil if not found
    public static func resourceURL(named name: String, type: ResourceType, fileExtension: String? = nil) -> URL? {
        guard let resourcesDir = resourcesDirectory else { return nil }
        
        let filename: String
        if let ext = fileExtension {
            filename = name.hasSuffix(".\(ext)") ? name : "\(name).\(ext)"
        } else {
            filename = name
        }
        
        let typeDir = resourcesDir.appendingPathComponent(type.pathComponent)
        let resourceURL = typeDir.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: resourceURL.path) ? resourceURL : nil
    }
    
    /// Loads data from a test resource
    /// - Parameters:
    ///   - name: Name of the resource
    ///   - type: Type of resource
    ///   - fileExtension: Optional file extension
    /// - Returns: Data from the resource, or nil if not found
    public static func loadData(named name: String, type: ResourceType, fileExtension: String? = nil) -> Data? {
        guard let url = resourceURL(named: name, type: type, fileExtension: fileExtension) else { return nil }
        return try? Data(contentsOf: url)
    }
    
    /// Loads a JSON resource and decodes it
    /// - Parameters:
    ///   - name: Name of the resource
    ///   - type: Type of resource (usually .mock)
    /// - Returns: Decoded object, or nil if not found or invalid
    public static func loadJSON<T: Decodable>(named name: String, type: ResourceType = .mock) -> T? {
        guard let data = loadData(named: name, type: type, fileExtension: "json") else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
    
    /// Creates a temporary test fixture
    /// - Parameters:
    ///   - name: Name of the fixture
    ///   - cleanup: Whether to clean up after the fixture is done
    /// - Returns: Fixture object
    public static func createFixture(named name: String = UUID().uuidString, cleanup: Bool = true) -> Fixture {
        return Fixture(name: name, cleanup: cleanup)
    }
    
    /// Updates a reference image for visual tests
    /// - Parameters:
    ///   - image: New reference image data
    ///   - name: Name of the image
    ///   - force: Whether to force update even if the image already exists
    /// - Returns: URL to the saved image
    @discardableResult
    public static func updateReferenceImage(data: Data, named name: String, force: Bool = false) -> URL? {
        guard let resourcesDir = resourcesDirectory else { return nil }
        
        let filename = name.hasSuffix(".png") ? name : "\(name).png"
        let referenceDir = resourcesDir.appendingPathComponent(ResourceType.referenceImage.pathComponent)
        let fileURL = referenceDir.appendingPathComponent(filename)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: referenceDir, withIntermediateDirectories: true)
        
        // Check if file exists and we're not forcing an update
        if FileManager.default.fileExists(atPath: fileURL.path) && !force {
            return fileURL
        }
        
        // Save the image
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error updating reference image: \(error)")
            return nil
        }
    }
}

// MARK: - XCTestCase Extension for Fixtures

extension XCTestCase {
    
    /// Creates a temporary test fixture for this test case
    /// - Returns: Fixture object
    public func createFixture() -> TestFixtureUtility.Fixture {
        return TestFixtureUtility.createFixture(named: name)
    }
    
    /// Gets the URL for a test resource
    /// - Parameters:
    ///   - name: Name of the resource
    ///   - type: Type of resource
    ///   - fileExtension: Optional file extension
    /// - Returns: URL to the resource, or nil if not found
    public func resourceURL(named name: String, 
                            type: TestFixtureUtility.ResourceType, 
                            fileExtension: String? = nil) -> URL? {
        return TestFixtureUtility.resourceURL(named: name, type: type, fileExtension: fileExtension)
    }
    
    /// Loads data from a test resource
    /// - Parameters:
    ///   - name: Name of the resource
    ///   - type: Type of resource
    ///   - fileExtension: Optional file extension
    /// - Returns: Data from the resource
    public func loadData(named name: String,
                         type: TestFixtureUtility.ResourceType,
                         fileExtension: String? = nil) -> Data? {
        return TestFixtureUtility.loadData(named: name, type: type, fileExtension: fileExtension)
    }
    
    /// Loads and decodes a JSON resource
    /// - Parameters:
    ///   - name: Name of the resource
    ///   - type: Type of resource (usually .mock)
    /// - Returns: Decoded object
    public func loadJSON<T: Decodable>(named name: String,
                                       type: TestFixtureUtility.ResourceType = .mock) -> T? {
        return TestFixtureUtility.loadJSON(named: name, type: type)
    }
} 