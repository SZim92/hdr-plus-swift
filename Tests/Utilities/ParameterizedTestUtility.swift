import XCTest
import Foundation

/// ParameterizedTestUtility provides functionality for running parameterized tests with XCTest,
/// enabling data-driven testing with multiple inputs.
class ParameterizedTestUtility {
    
    /// Runs a parameterized test with a list of parameters
    /// - Parameters:
    ///   - testCase: The test case running the test
    ///   - name: The base name for the test
    ///   - parameters: The list of parameters to test with
    ///   - testFunction: The test function to run for each set of parameters
    static func runParameterized<T>(
        in testCase: XCTestCase,
        name: String,
        parameters: [T],
        testFunction: (T, String) -> Void
    ) {
        for (index, parameter) in parameters.enumerated() {
            let testName = "\(name)_\(index)"
            testFunction(parameter, testName)
        }
    }
    
    /// Runs a parameterized test with named test cases
    /// - Parameters:
    ///   - testCase: The test case running the test
    ///   - name: The base name for the test
    ///   - namedParameters: A dictionary of parameter names to parameter values
    ///   - testFunction: The test function to run for each set of parameters
    static func runParameterized<T>(
        in testCase: XCTestCase,
        name: String,
        namedParameters: [String: T],
        testFunction: (T, String) -> Void
    ) {
        for (paramName, parameter) in namedParameters {
            let testName = "\(name)_\(paramName)"
            testFunction(parameter, testName)
        }
    }
    
    /// Runs a parameterized test with multiple parameter combinations
    /// - Parameters:
    ///   - testCase: The test case running the test
    ///   - name: The base name for the test
    ///   - parameterSets: An array of tuples containing parameter combinations
    ///   - testFunction: The test function to run for each set of parameters
    static func runParameterized<T>(
        in testCase: XCTestCase,
        name: String,
        parameterSets: [(parameters: T, name: String)],
        testFunction: (T, String) -> Void
    ) {
        for (parameter, paramName) in parameterSets {
            let testName = "\(name)_\(paramName)"
            testFunction(parameter, testName)
        }
    }
    
    /// Runs a parameterized test with a grid of parameter combinations
    /// - Parameters:
    ///   - testCase: The test case running the test
    ///   - name: The base name for the test
    ///   - parameters1: The first set of parameters
    ///   - parameters2: The second set of parameters
    ///   - testFunction: The test function to run for each combination of parameters
    static func runParameterizedGrid<T, U>(
        in testCase: XCTestCase,
        name: String,
        parameters1: [(T, String)],
        parameters2: [(U, String)],
        testFunction: (T, U, String) -> Void
    ) {
        for (param1, name1) in parameters1 {
            for (param2, name2) in parameters2 {
                let testName = "\(name)_\(name1)_\(name2)"
                testFunction(param1, param2, testName)
            }
        }
    }
    
    /// Runs a test with data from a JSON file
    /// - Parameters:
    ///   - testCase: The test case running the test
    ///   - name: The base name for the test
    ///   - jsonFileName: The name of the JSON file containing test data
    ///   - keyPath: An optional keypath to the array of test cases in the JSON
    ///   - testFunction: The test function to run for each test case
    static func runWithJSONData<T: Decodable>(
        in testCase: XCTestCase,
        name: String,
        jsonFileName: String,
        keyPath: String? = nil,
        testFunction: (T, String, Int) -> Void
    ) {
        // Get the URL for the JSON file
        guard let jsonURL = Bundle(for: testCase.classForCoder).url(forResource: jsonFileName, withExtension: nil) else {
            XCTFail("Could not find JSON file: \(jsonFileName)")
            return
        }
        
        // Load the JSON data
        guard let jsonData = try? Data(contentsOf: jsonURL) else {
            XCTFail("Could not load JSON data from file: \(jsonFileName)")
            return
        }
        
        // Decode the JSON data
        let decoder = JSONDecoder()
        do {
            if let keyPath = keyPath {
                // Decode the JSON data with the specified keypath
                let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
                guard let nestedData = json?.valueForKeyPath(keyPath) as? [[String: Any]] else {
                    XCTFail("Could not find array at keypath \(keyPath) in JSON file: \(jsonFileName)")
                    return
                }
                
                // Convert the nested data to JSON data
                let nestedJsonData = try JSONSerialization.data(withJSONObject: nestedData, options: [])
                
                // Decode the nested JSON data
                let testCases = try decoder.decode([T].self, from: nestedJsonData)
                
                // Run the test for each test case
                for (index, testCase) in testCases.enumerated() {
                    let testName = "\(name)_\(index)"
                    testFunction(testCase, testName, index)
                }
            } else {
                // Decode the JSON data directly
                let testCases = try decoder.decode([T].self, from: jsonData)
                
                // Run the test for each test case
                for (index, testCase) in testCases.enumerated() {
                    let testName = "\(name)_\(index)"
                    testFunction(testCase, testName, index)
                }
            }
        } catch {
            XCTFail("Could not decode JSON data: \(error)")
        }
    }
    
    /// Runs a test with data from a CSV file
    /// - Parameters:
    ///   - testCase: The test case running the test
    ///   - name: The base name for the test
    ///   - csvFileName: The name of the CSV file containing test data
    ///   - hasHeaderRow: Whether the CSV file has a header row
    ///   - separator: The separator character for the CSV file
    ///   - testFunction: The test function to run for each row of the CSV
    static func runWithCSVData(
        in testCase: XCTestCase,
        name: String,
        csvFileName: String,
        hasHeaderRow: Bool = true,
        separator: Character = ",",
        testFunction: ([String], [String]?, String, Int) -> Void
    ) {
        // Get the URL for the CSV file
        guard let csvURL = Bundle(for: testCase.classForCoder).url(forResource: csvFileName, withExtension: nil) else {
            XCTFail("Could not find CSV file: \(csvFileName)")
            return
        }
        
        // Load the CSV data
        guard let csvString = try? String(contentsOf: csvURL) else {
            XCTFail("Could not load CSV data from file: \(csvFileName)")
            return
        }
        
        // Parse the CSV data
        let rows = csvString.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { $0.components(separatedBy: separator) }
        
        // Check if there are any rows
        guard !rows.isEmpty else {
            XCTFail("CSV file is empty: \(csvFileName)")
            return
        }
        
        // Get the header row if present
        let headerRow = hasHeaderRow ? rows.first : nil
        
        // Get the data rows
        let dataRows = hasHeaderRow ? Array(rows.dropFirst()) : rows
        
        // Run the test for each data row
        for (index, row) in dataRows.enumerated() {
            let testName = "\(name)_\(index)"
            testFunction(row, headerRow, testName, index)
        }
    }
}

// MARK: - Helper Extensions

/// Extension to access nested values using key paths
extension Dictionary where Key == String, Value == Any {
    func valueForKeyPath(_ keyPath: String) -> Any? {
        let keys = keyPath.components(separatedBy: ".")
        return valueForKeys(keys)
    }
    
    private func valueForKeys(_ keys: [String]) -> Any? {
        guard !keys.isEmpty else { return nil }
        
        if keys.count == 1, let key = keys.first {
            return self[key]
        }
        
        guard let key = keys.first,
              let value = self[key] as? [String: Any] else {
            return nil
        }
        
        return value.valueForKeys(Array(keys.dropFirst()))
    }
}

// MARK: - Convenience Extensions for XCTestCase

extension XCTestCase {
    /// Runs a parameterized test with a list of parameters
    /// - Parameters:
    ///   - name: The base name for the test
    ///   - parameters: The list of parameters to test with
    ///   - testFunction: The test function to run for each set of parameters
    func runParameterized<T>(
        name: String,
        parameters: [T],
        testFunction: (T, String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(
            in: self,
            name: name,
            parameters: parameters,
            testFunction: testFunction
        )
    }
    
    /// Runs a parameterized test with named test cases
    /// - Parameters:
    ///   - name: The base name for the test
    ///   - namedParameters: A dictionary of parameter names to parameter values
    ///   - testFunction: The test function to run for each set of parameters
    func runParameterized<T>(
        name: String,
        namedParameters: [String: T],
        testFunction: (T, String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(
            in: self,
            name: name,
            namedParameters: namedParameters,
            testFunction: testFunction
        )
    }
    
    /// Runs a parameterized test with multiple parameter combinations
    /// - Parameters:
    ///   - name: The base name for the test
    ///   - parameterSets: An array of tuples containing parameter combinations
    ///   - testFunction: The test function to run for each set of parameters
    func runParameterized<T>(
        name: String,
        parameterSets: [(parameters: T, name: String)],
        testFunction: (T, String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(
            in: self,
            name: name,
            parameterSets: parameterSets,
            testFunction: testFunction
        )
    }
    
    /// Runs a parameterized test with a grid of parameter combinations
    /// - Parameters:
    ///   - name: The base name for the test
    ///   - parameters1: The first set of parameters
    ///   - parameters2: The second set of parameters
    ///   - testFunction: The test function to run for each combination of parameters
    func runParameterizedGrid<T, U>(
        name: String,
        parameters1: [(T, String)],
        parameters2: [(U, String)],
        testFunction: (T, U, String) -> Void
    ) {
        ParameterizedTestUtility.runParameterizedGrid(
            in: self,
            name: name,
            parameters1: parameters1,
            parameters2: parameters2,
            testFunction: testFunction
        )
    }
    
    /// Runs a test with data from a JSON file
    /// - Parameters:
    ///   - name: The base name for the test
    ///   - jsonFileName: The name of the JSON file containing test data
    ///   - keyPath: An optional keypath to the array of test cases in the JSON
    ///   - testFunction: The test function to run for each test case
    func runWithJSONData<T: Decodable>(
        name: String,
        jsonFileName: String,
        keyPath: String? = nil,
        testFunction: (T, String, Int) -> Void
    ) {
        ParameterizedTestUtility.runWithJSONData(
            in: self,
            name: name,
            jsonFileName: jsonFileName,
            keyPath: keyPath,
            testFunction: testFunction
        )
    }
    
    /// Runs a test with data from a CSV file
    /// - Parameters:
    ///   - name: The base name for the test
    ///   - csvFileName: The name of the CSV file containing test data
    ///   - hasHeaderRow: Whether the CSV file has a header row
    ///   - separator: The separator character for the CSV file
    ///   - testFunction: The test function to run for each row of the CSV
    func runWithCSVData(
        name: String,
        csvFileName: String,
        hasHeaderRow: Bool = true,
        separator: Character = ",",
        testFunction: ([String], [String]?, String, Int) -> Void
    ) {
        ParameterizedTestUtility.runWithCSVData(
            in: self,
            name: name,
            csvFileName: csvFileName,
            hasHeaderRow: hasHeaderRow,
            separator: separator,
            testFunction: testFunction
        )
    }
} 