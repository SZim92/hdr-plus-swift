import Foundation
import XCTest

/// Utility for parameterized (data-driven) testing.
/// Allows tests to be run with multiple sets of inputs and expected outputs.
public final class ParameterizedTestUtility {
    
    // MARK: - Type Definitions
    
    /// A named test case with input and expected output
    public struct NamedTestCase<Input, Expected> {
        /// The name of the test case
        public let name: String
        
        /// The input data
        public let input: Input
        
        /// The expected output
        public let expected: Expected
        
        /// Initialize a new named test case
        public init(name: String, input: Input, expected: Expected) {
            self.name = name
            self.input = input
            self.expected = expected
        }
    }
    
    /// Error types for parameterized testing
    public enum ParameterizedTestError: Error, LocalizedError {
        /// Error loading test data
        case dataLoadError(String)
        
        /// No test cases found
        case noTestCasesFound
        
        /// Invalid test data format
        case invalidDataFormat(String)
        
        public var errorDescription: String? {
            switch self {
            case .dataLoadError(let message):
                return "Failed to load test data: \(message)"
            case .noTestCasesFound:
                return "No test cases found"
            case .invalidDataFormat(let message):
                return "Invalid test data format: \(message)"
            }
        }
    }
    
    // MARK: - Running Parameterized Tests
    
    /// Run a test with multiple input values and expected outputs
    /// - Parameters:
    ///   - testCase: The test case owning this test
    ///   - inputs: Array of input values
    ///   - expected: Array of expected output values
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each input/expected pair
    public static func runTest<Input, Expected>(
        _ testCase: XCTestCase,
        inputs: [Input],
        expected: [Expected],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, Int) throws -> Void
    ) throws {
        guard inputs.count == expected.count else {
            XCTFail("Number of inputs (\(inputs.count)) doesn't match number of expected outputs (\(expected.count))", file: file, line: line)
            return
        }
        
        guard !inputs.isEmpty else {
            throw ParameterizedTestError.noTestCasesFound
        }
        
        TestConfig.shared.logVerbose("Running parameterized test with \(inputs.count) test cases")
        
        for i in 0..<inputs.count {
            let input = inputs[i]
            let output = expected[i]
            
            TestConfig.shared.logVerbose("Test case \(i+1): Input: \(input), Expected: \(output)")
            
            try testBlock(input, output, i)
        }
    }
    
    /// Run a test with multiple test cases
    /// - Parameters:
    ///   - testCase: The test case owning this test
    ///   - testCases: Array of test cases with input/expected pairs
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each test case
    public static func runTest<Input, Expected>(
        _ testCase: XCTestCase,
        testCases: [NamedTestCase<Input, Expected>],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, Int, String) throws -> Void
    ) throws {
        guard !testCases.isEmpty else {
            throw ParameterizedTestError.noTestCasesFound
        }
        
        TestConfig.shared.logVerbose("Running parameterized test with \(testCases.count) named test cases")
        
        for (i, testCase) in testCases.enumerated() {
            TestConfig.shared.logVerbose("Test case '\(testCase.name)': Input: \(testCase.input), Expected: \(testCase.expected)")
            
            try testBlock(testCase.input, testCase.expected, i, testCase.name)
        }
    }
    
    /// Run a test with a dictionary of named test cases
    /// - Parameters:
    ///   - testCase: The test case owning this test
    ///   - namedTests: Dictionary mapping test names to (input, expected) tuples
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each test case
    public static func runTest<Input, Expected>(
        _ testCase: XCTestCase,
        namedTests: [String: (input: Input, expected: Expected)],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, String) throws -> Void
    ) throws {
        guard !namedTests.isEmpty else {
            throw ParameterizedTestError.noTestCasesFound
        }
        
        TestConfig.shared.logVerbose("Running parameterized test with \(namedTests.count) dictionary test cases")
        
        for (name, testData) in namedTests.sorted(by: { $0.key < $1.key }) {
            TestConfig.shared.logVerbose("Test case '\(name)': Input: \(testData.input), Expected: \(testData.expected)")
            
            try testBlock(testData.input, testData.expected, name)
        }
    }
    
    // MARK: - Loading Test Data
    
    /// Load test data from a JSON file
    /// - Parameters:
    ///   - fileName: The name of the JSON file (without extension)
    ///   - bundle: The bundle containing the file
    /// - Returns: A dictionary representing the JSON data
    public static func loadJSON(fileName: String, bundle: Bundle = Bundle.main) throws -> [String: Any] {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") ??
                TestConfig.shared.testResourcesDir.appendingPathComponent("TestData").appendingPathComponent("\(fileName).json") else {
            throw ParameterizedTestError.dataLoadError("JSON file '\(fileName).json' not found")
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ParameterizedTestError.invalidDataFormat("JSON in '\(fileName).json' is not a dictionary")
            }
            
            return json
        } catch let error as ParameterizedTestError {
            throw error
        } catch {
            throw ParameterizedTestError.dataLoadError("Failed to load JSON file: \(error.localizedDescription)")
        }
    }
    
    /// Load test cases from a JSON file
    /// - Parameters:
    ///   - fileName: The name of the JSON file (without extension)
    ///   - bundle: The bundle containing the file
    ///   - inputKey: The key for the input value in each test case
    ///   - expectedKey: The key for the expected value in each test case
    /// - Returns: An array of named test cases
    public static func loadTestCases<Input: Decodable, Expected: Decodable>(
        fromJSON fileName: String,
        bundle: Bundle = Bundle.main,
        inputKey: String = "input",
        expectedKey: String = "expected"
    ) throws -> [NamedTestCase<Input, Expected>] {
        let json = try loadJSON(fileName: fileName, bundle: bundle)
        
        guard let testCasesDict = json["testCases"] as? [[String: Any]] else {
            throw ParameterizedTestError.invalidDataFormat("JSON doesn't contain 'testCases' array")
        }
        
        var testCases: [NamedTestCase<Input, Expected>] = []
        
        for (index, testCase) in testCasesDict.enumerated() {
            guard let name = testCase["name"] as? String else {
                throw ParameterizedTestError.invalidDataFormat("Test case #\(index) is missing 'name' field")
            }
            
            guard let inputData = testCase[inputKey] else {
                throw ParameterizedTestError.invalidDataFormat("Test case '\(name)' is missing '\(inputKey)' field")
            }
            
            guard let expectedData = testCase[expectedKey] else {
                throw ParameterizedTestError.invalidDataFormat("Test case '\(name)' is missing '\(expectedKey)' field")
            }
            
            let inputJson = try JSONSerialization.data(withJSONObject: inputData)
            let expectedJson = try JSONSerialization.data(withJSONObject: expectedData)
            
            let input = try JSONDecoder().decode(Input.self, from: inputJson)
            let expected = try JSONDecoder().decode(Expected.self, from: expectedJson)
            
            testCases.append(NamedTestCase(name: name, input: input, expected: expected))
        }
        
        return testCases
    }
    
    /// Load test data from a CSV file
    /// - Parameters:
    ///   - fileName: The name of the CSV file (without extension)
    ///   - bundle: The bundle containing the file
    ///   - hasHeader: Whether the CSV file has a header row
    /// - Returns: Array of string arrays representing CSV rows
    public static func loadCSV(fileName: String, bundle: Bundle = Bundle.main, hasHeader: Bool = true) throws -> [[String]] {
        guard let url = bundle.url(forResource: fileName, withExtension: "csv") ??
                TestConfig.shared.testResourcesDir.appendingPathComponent("TestData").appendingPathComponent("\(fileName).csv") else {
            throw ParameterizedTestError.dataLoadError("CSV file '\(fileName).csv' not found")
        }
        
        do {
            let csvString = try String(contentsOf: url)
            var rows: [[String]] = []
            
            // Split by new lines
            let lines = csvString.components(separatedBy: .newlines)
            
            // Process each line
            for (i, line) in lines.enumerated() {
                if line.isEmpty { continue }
                
                // Skip header if requested
                if i == 0 && hasHeader { continue }
                
                // Split the line by comma (this is a simple implementation that doesn't handle quotes properly)
                let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                rows.append(fields)
            }
            
            if rows.isEmpty {
                throw ParameterizedTestError.noTestCasesFound
            }
            
            return rows
        } catch let error as ParameterizedTestError {
            throw error
        } catch {
            throw ParameterizedTestError.dataLoadError("Failed to load CSV file: \(error.localizedDescription)")
        }
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Run a parameterized test with inputs and expected outputs
    /// - Parameters:
    ///   - inputs: Array of input values
    ///   - expected: Array of expected output values
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each input/expected pair
    public func runParameterizedTest<Input, Expected>(
        with inputs: [Input],
        expected: [Expected],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, Int) throws -> Void
    ) throws {
        try ParameterizedTestUtility.runTest(
            self,
            inputs: inputs,
            expected: expected,
            file: file,
            line: line,
            testBlock: testBlock
        )
    }
    
    /// Run a parameterized test with input/expected tuples
    /// - Parameters:
    ///   - testCases: Array of input/expected tuples
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each input/expected pair
    public func runParameterizedTest<Input, Expected>(
        with testCases: [(input: Input, expected: Expected)],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, Int) throws -> Void
    ) throws {
        let inputs = testCases.map { $0.input }
        let expected = testCases.map { $0.expected }
        
        try ParameterizedTestUtility.runTest(
            self,
            inputs: inputs,
            expected: expected,
            file: file,
            line: line,
            testBlock: testBlock
        )
    }
    
    /// Run a parameterized test with named test cases
    /// - Parameters:
    ///   - testCases: Array of named test cases
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each test case
    public func runParameterizedTest<Input, Expected>(
        with testCases: [ParameterizedTestUtility.NamedTestCase<Input, Expected>],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, Int, String) throws -> Void
    ) throws {
        try ParameterizedTestUtility.runTest(
            self,
            testCases: testCases,
            file: file,
            line: line,
            testBlock: testBlock
        )
    }
    
    /// Run a parameterized test with named test cases dictionary
    /// - Parameters:
    ///   - namedTests: Dictionary mapping test names to (input, expected) tuples
    ///   - file: Source file (for XCTest reporting)
    ///   - line: Line number (for XCTest reporting)
    ///   - testBlock: The test block to run for each test case
    public func runParameterizedTest<Input, Expected>(
        with namedTests: [String: (input: Input, expected: Expected)],
        file: StaticString = #file,
        line: UInt = #line,
        testBlock: (Input, Expected, String) throws -> Void
    ) throws {
        try ParameterizedTestUtility.runTest(
            self,
            namedTests: namedTests,
            file: file,
            line: line,
            testBlock: testBlock
        )
    }
    
    /// Load test cases from a JSON file
    /// - Parameters:
    ///   - fileName: The name of the JSON file (without extension)
    ///   - bundle: The bundle containing the file
    ///   - inputKey: The key for the input value in each test case
    ///   - expectedKey: The key for the expected value in each test case
    /// - Returns: An array of named test cases
    public func loadTestCases<Input: Decodable, Expected: Decodable>(
        fromJSON fileName: String,
        bundle: Bundle = Bundle.main,
        inputKey: String = "input",
        expectedKey: String = "expected"
    ) throws -> [ParameterizedTestUtility.NamedTestCase<Input, Expected>] {
        return try ParameterizedTestUtility.loadTestCases(
            fromJSON: fileName,
            bundle: bundle,
            inputKey: inputKey,
            expectedKey: expectedKey
        )
    }
} 