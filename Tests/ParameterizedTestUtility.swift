import Foundation
import XCTest

/// Utility for parameterized testing that allows running tests with multiple input sets.
/// This enables data-driven testing with various input combinations.
public final class ParameterizedTestUtility {
    
    /// Error types that can occur during parameterized testing
    public enum ParameterizedTestError: Error, LocalizedError {
        /// Error when attempting to load test data
        case dataLoadingFailed(String)
        
        /// Error when parsing test data
        case dataParsingFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .dataLoadingFailed(let message):
                return "Failed to load test data: \(message)"
            case .dataParsingFailed(let message):
                return "Failed to parse test data: \(message)"
            }
        }
    }
    
    /// Configuration for parameterized testing
    public struct Configuration {
        /// Directory containing test data files
        public var testDataDirectory: URL
        
        /// Whether to enable verbose logging
        public var verboseLogging: Bool
        
        /// The default configuration using values from TestConfig
        public static var `default`: Configuration {
            return Configuration(
                testDataDirectory: TestConfig.shared.testResourcesDir.appendingPathComponent("TestData"),
                verboseLogging: TestConfig.shared.verboseLogging
            )
        }
    }
    
    /// The current configuration for parameterized testing
    public static var configuration = Configuration.default
    
    /// Run a parameterized test with a list of inputs.
    ///
    /// - Parameters:
    ///   - inputs: The list of inputs to test with.
    ///   - testFunction: The test function to run for each input.
    public static func run<T>(
        with inputs: [T],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (T, Int) throws -> Void
    ) rethrows {
        for (index, input) in inputs.enumerated() {
            if configuration.verboseLogging {
                TestConfig.shared.logVerbose("Running test with input [\(index)]: \(String(describing: input))")
            }
            
            do {
                try testFunction(input, index)
            } catch {
                XCTFail("Test failed for input [\(index)]: \(String(describing: input)). Error: \(error)", file: file, line: line)
                throw error
            }
        }
    }
    
    /// Run a parameterized test with a dictionary of inputs.
    ///
    /// - Parameters:
    ///   - inputs: The dictionary of named inputs to test with.
    ///   - testFunction: The test function to run for each named input.
    public static func run<T>(
        with namedInputs: [String: T],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (T, String) throws -> Void
    ) rethrows {
        for (name, input) in namedInputs {
            if configuration.verboseLogging {
                TestConfig.shared.logVerbose("Running test with input [\(name)]: \(String(describing: input))")
            }
            
            do {
                try testFunction(input, name)
            } catch {
                XCTFail("Test failed for input [\(name)]: \(String(describing: input)). Error: \(error)", file: file, line: line)
                throw error
            }
        }
    }
    
    /// Run a parameterized test with a list of input/expected output pairs.
    ///
    /// - Parameters:
    ///   - testCases: The list of input/expected output pairs to test with.
    ///   - testFunction: The test function to run for each input/expected output pair.
    public static func run<I, E>(
        with testCases: [(input: I, expected: E)],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (I, E, Int) throws -> Void
    ) rethrows {
        for (index, testCase) in testCases.enumerated() {
            if configuration.verboseLogging {
                TestConfig.shared.logVerbose("Running test case [\(index)]: Input: \(String(describing: testCase.input)), Expected: \(String(describing: testCase.expected))")
            }
            
            do {
                try testFunction(testCase.input, testCase.expected, index)
            } catch {
                XCTFail("Test failed for case [\(index)]: Input: \(String(describing: testCase.input)), Expected: \(String(describing: testCase.expected)). Error: \(error)", file: file, line: line)
                throw error
            }
        }
    }
    
    /// Run a parameterized test with named input/expected output pairs.
    ///
    /// - Parameters:
    ///   - testCases: The dictionary of named input/expected output pairs to test with.
    ///   - testFunction: The test function to run for each named input/expected output pair.
    public static func run<I, E>(
        with namedTestCases: [String: (input: I, expected: E)],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (I, E, String) throws -> Void
    ) rethrows {
        for (name, testCase) in namedTestCases {
            if configuration.verboseLogging {
                TestConfig.shared.logVerbose("Running test case [\(name)]: Input: \(String(describing: testCase.input)), Expected: \(String(describing: testCase.expected))")
            }
            
            do {
                try testFunction(testCase.input, testCase.expected, name)
            } catch {
                XCTFail("Test failed for case [\(name)]: Input: \(String(describing: testCase.input)), Expected: \(String(describing: testCase.expected)). Error: \(error)", file: file, line: line)
                throw error
            }
        }
    }
    
    /// Load test data from a JSON file.
    ///
    /// - Parameters:
    ///   - filename: The name of the JSON file without extension.
    ///   - bundle: The bundle containing the file, or nil to use the main bundle.
    /// - Returns: The decoded object.
    /// - Throws: An error if the file cannot be loaded or parsed.
    public static func loadTestData<T: Decodable>(
        fromJSON filename: String,
        bundle: Bundle? = nil
    ) throws -> T {
        let bundle = bundle ?? Bundle.main
        
        // First check if file exists in test data directory
        let testDataURL = configuration.testDataDirectory.appendingPathComponent("\(filename).json")
        if FileManager.default.fileExists(atPath: testDataURL.path) {
            let data = try Data(contentsOf: testDataURL)
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ParameterizedTestError.dataParsingFailed("JSON parsing failed: \(error)")
            }
        }
        
        // Try to load from bundle resources
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw ParameterizedTestError.dataLoadingFailed("JSON file '\(filename).json' not found in bundle or test data directory")
        }
        
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ParameterizedTestError.dataParsingFailed("JSON parsing failed: \(error)")
        }
    }
    
    /// Load test data from a CSV file.
    ///
    /// - Parameters:
    ///   - filename: The name of the CSV file without extension.
    ///   - hasHeaderRow: Whether the CSV has a header row.
    ///   - bundle: The bundle containing the file, or nil to use the main bundle.
    /// - Returns: The parsed CSV as an array of arrays of strings.
    /// - Throws: An error if the file cannot be loaded or parsed.
    public static func loadTestData(
        fromCSV filename: String,
        hasHeaderRow: Bool = true,
        bundle: Bundle? = nil
    ) throws -> [[String]] {
        let bundle = bundle ?? Bundle.main
        
        // First check if file exists in test data directory
        let testDataURL = configuration.testDataDirectory.appendingPathComponent("\(filename).csv")
        if FileManager.default.fileExists(atPath: testDataURL.path) {
            let content = try String(contentsOf: testDataURL)
            return try parseCSV(content, hasHeaderRow: hasHeaderRow)
        }
        
        // Try to load from bundle resources
        guard let url = bundle.url(forResource: filename, withExtension: "csv") else {
            throw ParameterizedTestError.dataLoadingFailed("CSV file '\(filename).csv' not found in bundle or test data directory")
        }
        
        let content = try String(contentsOf: url)
        return try parseCSV(content, hasHeaderRow: hasHeaderRow)
    }
    
    /// Parse CSV content into an array of arrays of strings.
    ///
    /// - Parameters:
    ///   - content: The CSV content as a string.
    ///   - hasHeaderRow: Whether the CSV has a header row.
    /// - Returns: The parsed CSV as an array of arrays of strings.
    /// - Throws: An error if the CSV cannot be parsed.
    private static func parseCSV(_ content: String, hasHeaderRow: Bool) throws -> [[String]] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw ParameterizedTestError.dataParsingFailed("CSV content is empty")
        }
        
        var result: [[String]] = []
        
        for (index, line) in lines.enumerated() {
            if index == 0 && hasHeaderRow {
                continue
            }
            
            // This is a simple CSV parser. For complex CSV with quoted fields,
            // consider using a proper CSV parsing library.
            let fields = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            result.append(fields)
        }
        
        return result
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Run a parameterized test with a list of inputs.
    ///
    /// - Parameters:
    ///   - inputs: The list of inputs to test with.
    ///   - testFunction: The test function to run for each input.
    public func runParameterizedTest<T>(
        with inputs: [T],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (T, Int) throws -> Void
    ) rethrows {
        try ParameterizedTestUtility.run(
            with: inputs,
            file: file,
            line: line,
            testFunction: testFunction
        )
    }
    
    /// Run a parameterized test with a dictionary of inputs.
    ///
    /// - Parameters:
    ///   - inputs: The dictionary of named inputs to test with.
    ///   - testFunction: The test function to run for each named input.
    public func runParameterizedTest<T>(
        with namedInputs: [String: T],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (T, String) throws -> Void
    ) rethrows {
        try ParameterizedTestUtility.run(
            with: namedInputs,
            file: file,
            line: line,
            testFunction: testFunction
        )
    }
    
    /// Run a parameterized test with a list of input/expected output pairs.
    ///
    /// - Parameters:
    ///   - testCases: The list of input/expected output pairs to test with.
    ///   - testFunction: The test function to run for each input/expected output pair.
    public func runParameterizedTest<I, E>(
        with testCases: [(input: I, expected: E)],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (I, E, Int) throws -> Void
    ) rethrows {
        try ParameterizedTestUtility.run(
            with: testCases,
            file: file,
            line: line,
            testFunction: testFunction
        )
    }
    
    /// Run a parameterized test with named input/expected output pairs.
    ///
    /// - Parameters:
    ///   - testCases: The dictionary of named input/expected output pairs to test with.
    ///   - testFunction: The test function to run for each named input/expected output pair.
    public func runParameterizedTest<I, E>(
        with namedTestCases: [String: (input: I, expected: E)],
        file: StaticString = #file,
        line: UInt = #line,
        testFunction: (I, E, String) throws -> Void
    ) rethrows {
        try ParameterizedTestUtility.run(
            with: namedTestCases,
            file: file,
            line: line,
            testFunction: testFunction
        )
    }
    
    /// Load test data from a JSON file.
    ///
    /// - Parameters:
    ///   - filename: The name of the JSON file without extension.
    ///   - bundle: The bundle containing the file, or nil to use the main bundle.
    /// - Returns: The decoded object.
    /// - Throws: An error if the file cannot be loaded or parsed.
    public func loadTestData<T: Decodable>(
        fromJSON filename: String,
        bundle: Bundle? = nil
    ) throws -> T {
        return try ParameterizedTestUtility.loadTestData(fromJSON: filename, bundle: bundle)
    }
    
    /// Load test data from a CSV file.
    ///
    /// - Parameters:
    ///   - filename: The name of the CSV file without extension.
    ///   - hasHeaderRow: Whether the CSV has a header row.
    ///   - bundle: The bundle containing the file, or nil to use the main bundle.
    /// - Returns: The parsed CSV as an array of arrays of strings.
    /// - Throws: An error if the file cannot be loaded or parsed.
    public func loadTestData(
        fromCSV filename: String,
        hasHeaderRow: Bool = true,
        bundle: Bundle? = nil
    ) throws -> [[String]] {
        return try ParameterizedTestUtility.loadTestData(
            fromCSV: filename,
            hasHeaderRow: hasHeaderRow,
            bundle: bundle
        )
    }
} 