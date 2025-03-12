import XCTest
@testable import HDRPlus

/// ParameterizedTestExample demonstrates how to use the parameterized testing utility
/// for data-driven testing with multiple inputs.
class ParameterizedTestExample: XCTestCase {
    
    // MARK: - Simple Parameterized Tests
    
    /// Tests a simple function with multiple inputs using array parameters
    func testArrayParameters() {
        // Define test parameters
        let inputValues = [1, 2, 3, 4, 5]
        
        // Run parameterized test
        runParameterized(name: "squareNumber", parameters: inputValues) { value, testName in
            // Test squaring a number
            let result = square(value)
            let expected = value * value
            
            XCTAssertEqual(result, expected, "\(testName): Square of \(value) should be \(expected)")
        }
    }
    
    /// Tests a simple function with multiple inputs using named parameters
    func testNamedParameters() {
        // Define named test parameters
        let namedParameters: [String: Double] = [
            "zero": 0.0,
            "positive": 10.0,
            "negative": -5.0,
            "smallFraction": 0.1,
            "largeFraction": 0.99
        ]
        
        // Run parameterized test
        runParameterized(name: "roundNumber", namedParameters: namedParameters) { value, testName in
            // Test rounding a number
            let result = round(value)
            
            // Verify the result is a whole number
            XCTAssertEqual(result, Double(Int(result)), "\(testName): Result should be a whole number")
            
            // Verify the result is within 0.5 of the input
            XCTAssertLessThanOrEqual(abs(result - value), 0.5, "\(testName): Result should be within 0.5 of input")
        }
    }
    
    // MARK: - Parameter Sets
    
    /// Tests a function with structured parameter sets
    func testParameterSets() {
        // Define parameter sets with expected results
        let parameterSets: [(parameters: (width: Double, height: Double), name: String)] = [
            ((width: 5.0, height: 10.0), "rectangle"),
            ((width: 7.0, height: 7.0), "square"),
            ((width: 0.0, height: 5.0), "zeroWidth"),
            ((width: 3.0, height: 0.0), "zeroHeight"),
            ((width: 0.1, height: 0.2), "tinyRectangle")
        ]
        
        // Run parameterized test
        runParameterized(name: "rectangleArea", parameterSets: parameterSets) { params, testName in
            // Test calculating rectangle area
            let (width, height) = (params.width, params.height)
            let area = rectangleArea(width: width, height: height)
            let expected = width * height
            
            XCTAssertEqual(area, expected, "\(testName): Area of \(width)×\(height) rectangle should be \(expected)")
        }
    }
    
    // MARK: - Grid Parameters
    
    /// Tests a function with a grid of parameter combinations
    func testParameterGrid() {
        // Define parameter sets for the first parameter (temperature in Celsius)
        let temperatures: [(Double, String)] = [
            (0.0, "freezing"),
            (20.0, "room"),
            (100.0, "boiling"),
            (-40.0, "veryLow")
        ]
        
        // Define parameter sets for the second parameter (conversion type)
        let conversions: [(String, String)] = [
            ("fahrenheit", "toFahrenheit"),
            ("kelvin", "toKelvin")
        ]
        
        // Run parameterized grid test
        runParameterizedGrid(
            name: "temperatureConversion",
            parameters1: temperatures,
            parameters2: conversions
        ) { celsius, conversionType, testName in
            // Convert temperature based on conversion type
            let result: Double
            let expected: Double
            
            switch conversionType {
            case "fahrenheit":
                result = celsiusToFahrenheit(celsius)
                expected = celsius * 9/5 + 32
            case "kelvin":
                result = celsiusToKelvin(celsius)
                expected = celsius + 273.15
            default:
                XCTFail("Unknown conversion type: \(conversionType)")
                return
            }
            
            // Verify the result with a small tolerance for floating-point errors
            XCTAssertEqual(result, expected, accuracy: 0.001, "\(testName): Conversion incorrect")
        }
    }
    
    // MARK: - JSON Data-Driven Tests
    
    /// Define a struct for JSON test data
    struct CalculationTestCase: Decodable {
        let input: Double
        let expectedOutput: Double
    }
    
    /// Tests a function using data from a JSON file (would need a JSON file in the test bundle)
    func testWithJSONData() {
        // Create a temporary JSON file with test data
        let fixture = createFixture()
        let testCases: [[String: Any]] = [
            ["input": 2.0, "expectedOutput": 1.0],
            ["input": 4.0, "expectedOutput": 2.0],
            ["input": 9.0, "expectedOutput": 3.0],
            ["input": 16.0, "expectedOutput": 4.0],
            ["input": 25.0, "expectedOutput": 5.0]
        ]
        
        // Convert to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: testCases, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            XCTFail("Failed to create JSON data")
            return
        }
        
        // Write to a temporary file
        let jsonFileName = "sqrt_test_cases.json"
        do {
            try fixture.createFile(named: jsonFileName, content: jsonString)
            
            // This would normally use runWithJSONData, but since we're using a fixture file,
            // we'll manually parse and execute the tests
            let decodedCases = try JSONDecoder().decode([CalculationTestCase].self, from: jsonData)
            
            // Test each case
            for (index, testCase) in decodedCases.enumerated() {
                let testName = "sqrtTest_\(index)"
                let result = sqrt(testCase.input)
                XCTAssertEqual(result, testCase.expectedOutput, accuracy: 0.0001, "\(testName): Square root calculation failed")
            }
        } catch {
            XCTFail("Failed to execute JSON data test: \(error)")
        }
    }
    
    // MARK: - CSV Data-Driven Tests
    
    /// Tests a function using data from a CSV-like string (simulating a CSV file)
    func testWithCSVData() {
        // Create a temporary CSV file with test data
        let fixture = createFixture()
        let csvContent = """
        input,expectedOutput
        1,1
        4,8
        10,100
        2,2
        5,15
        """.replacingOccurrences(of: "\n", with: "\r\n")
        
        // Write to a temporary file
        let csvFileName = "triangle_numbers.csv"
        do {
            try fixture.createFile(named: csvFileName, content: csvContent)
            let csvURL = fixture.url(for: csvFileName)
            
            // Read the CSV content
            let csvString = try String(contentsOf: csvURL)
            
            // Parse the CSV data
            let rows = csvString.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { $0.components(separatedBy: ",") }
            
            // Get the header row
            guard let headerRow = rows.first, rows.count > 1 else {
                XCTFail("CSV file is empty or malformed")
                return
            }
            
            // Get the data rows
            let dataRows = Array(rows.dropFirst())
            
            // Test each row
            for (index, row) in dataRows.enumerated() {
                guard row.count >= 2,
                      let input = Int(row[0]),
                      let expectedOutput = Int(row[1]) else {
                    XCTFail("Invalid data in row \(index + 1)")
                    continue
                }
                
                let testName = "triangleNumber_\(index)"
                let result = triangleNumber(input)
                XCTAssertEqual(result, expectedOutput, "\(testName): Triangle number calculation failed")
            }
        } catch {
            XCTFail("Failed to execute CSV data test: \(error)")
        }
    }
    
    // MARK: - Test Functions
    
    /// Returns the square of a number
    private func square(_ x: Int) -> Int {
        return x * x
    }
    
    /// Returns the area of a rectangle
    private func rectangleArea(width: Double, height: Double) -> Double {
        return width * height
    }
    
    /// Converts Celsius to Fahrenheit
    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9/5 + 32
    }
    
    /// Converts Celsius to Kelvin
    private func celsiusToKelvin(_ celsius: Double) -> Double {
        return celsius + 273.15
    }
    
    /// Returns the triangle number for a given input
    /// (sum of all integers from 1 to n)
    private func triangleNumber(_ n: Int) -> Int {
        return n * (n + 1) / 2
    }
} 