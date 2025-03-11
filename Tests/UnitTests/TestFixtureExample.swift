import XCTest
@testable import HDRPlus

class TestFixtureExample: XCTestCase {
    
    // Define a sample model for testing
    struct SensorConfig: Codable, Equatable {
        let name: String
        let width: Int
        let height: Int
        let pixelSize: Double
        let hasRawOutput: Bool
        
        static let sample = SensorConfig(
            name: "Test Sensor",
            width: 4000,
            height: 3000,
            pixelSize: 1.4,
            hasRawOutput: true
        )
    }
    
    // MARK: - Test Cases
    
    func testCreateAndUseFixture() {
        // Create a fixture for this test
        let fixture = createFixture()
        
        // Create a JSON file
        let config = SensorConfig.sample
        let jsonURL = fixture.createJSONFile(named: "sensor_config.json", object: config)
        
        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))
        
        // Read and decode the file
        let decoder = JSONDecoder()
        let data = try! Data(contentsOf: jsonURL)
        let decodedConfig = try! decoder.decode(SensorConfig.self, from: data)
        
        // Verify contents
        XCTAssertEqual(decodedConfig, config)
        
        // Create a text file with test data
        let textURL = fixture.createTextFile(named: "sample.txt", contents: "Test content")
        
        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: textURL.path))
        
        // The fixture will automatically clean up when it goes out of scope
    }
    
    func testManualFixtureCleanup() {
        // Create a fixture with a specific name
        let fixture = TestFixtureUtility.createFixture(named: "ManualCleanupTest", cleanup: false)
        
        // Create a file
        let fileURL = fixture.createTextFile(named: "test.txt", contents: "This will be manually cleaned up")
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Manually clean up
        fixture.cleanup()
        
        // Verify file was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testLoadTestResources() {
        // This test demonstrates how to load resources from the test bundle
        // Note: These resources would need to exist in your test resources directory
        
        // Example of how to load a reference image
        if let imageData = loadData(named: "sample_image", type: .referenceImage, fileExtension: "png") {
            // Use the image data
            XCTAssertFalse(imageData.isEmpty)
        } else {
            // This will be skipped if the resource doesn't exist, which is expected in this example
            XCTSkip("Reference image not found - this is expected in this example")
        }
        
        // Example of how to load a mock JSON file
        if let config: SensorConfig = loadJSON(named: "sensor_config") {
            // Use the loaded configuration
            XCTAssertEqual(config.name, "Test Sensor")
        } else {
            // This will be skipped if the resource doesn't exist, which is expected in this example
            XCTSkip("Mock JSON not found - this is expected in this example")
        }
    }
    
    func testCreateMockTestData() {
        // Create a fixture
        let fixture = createFixture()
        
        // Sample configuration
        let configs = [
            SensorConfig(name: "Small Sensor", width: 2000, height: 1500, pixelSize: 1.1, hasRawOutput: false),
            SensorConfig(name: "Medium Sensor", width: 4000, height: 3000, pixelSize: 1.4, hasRawOutput: true),
            SensorConfig(name: "Large Sensor", width: 8000, height: 6000, pixelSize: 0.8, hasRawOutput: true)
        ]
        
        // Create a file with multiple configurations
        fixture.createJSONFile(named: "sensor_configs.json", object: configs)
        
        // Create a CSV file with test data
        let csvContent = """
        name,width,height,pixel_size,has_raw
        Small Sensor,2000,1500,1.1,false
        Medium Sensor,4000,3000,1.4,true
        Large Sensor,8000,6000,0.8,true
        """
        
        let csvURL = fixture.createTextFile(named: "sensor_configs.csv", contents: csvContent)
        
        // Read and parse the CSV file
        let csvData = try! String(contentsOf: csvURL, encoding: .utf8)
        let lines = csvData.split(separator: "\n").map { String($0) }
        
        // Skip header line
        XCTAssertEqual(lines.count, 4) // Header + 3 data lines
        XCTAssertEqual(lines[0], "name,width,height,pixel_size,has_raw")
        
        // Parse a line
        let components = lines[1].split(separator: ",").map { String($0) }
        XCTAssertEqual(components[0], "Small Sensor")
        XCTAssertEqual(Int(components[1]), 2000)
    }
    
    func testSimulateBurstSequence() {
        // This test demonstrates creating a simulated burst sequence for testing
        let fixture = createFixture()
        
        // Create a directory for the burst
        let burstDir = fixture.directory.appendingPathComponent("burst_sequence")
        try! FileManager.default.createDirectory(at: burstDir, withIntermediateDirectories: true)
        
        // Create metadata for the burst
        let burstMetadata = [
            "timestamp": Date().timeIntervalSince1970,
            "frame_count": 5,
            "exposure_time": 0.01,
            "iso": 100
        ]
        
        // Save metadata
        let metadataURL = burstDir.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        try! encoder.encode(burstMetadata).write(to: metadataURL)
        
        // Create simulated frame files
        for i in 0..<5 {
            // In a real test, you would create actual image data
            // Here we're just creating empty files as placeholders
            let frameData = Data(repeating: UInt8(i), count: 1024) // Dummy data
            let frameURL = burstDir.appendingPathComponent("frame_\(i).raw")
            try! frameData.write(to: frameURL)
        }
        
        // Now verify everything was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        
        for i in 0..<5 {
            let frameURL = burstDir.appendingPathComponent("frame_\(i).raw")
            XCTAssertTrue(FileManager.default.fileExists(atPath: frameURL.path))
        }
    }
} 