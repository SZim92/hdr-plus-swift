import Foundation
import XCTest

/// Utility for running parameterized tests with multiple inputs.
/// This allows for data-driven testing and better test coverage.
public class ParameterizedTestUtility {
    
    // MARK: - Running Parameterized Tests
    
    /// Run a parameterized test with an array of parameters
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameters: The parameters to run the test with
    ///   - test: The test logic, which takes a parameter and test name
    public static func runParameterized<T>(
        name: String,
        parameters: [T],
        test: (_ parameter: T, _ testName: String) -> Void
    ) {
        for (index, parameter) in parameters.enumerated() {
            let testName = "\(name)[\(index)]"
            test(parameter, testName)
        }
    }
    
    /// Run a parameterized test with named parameters
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - namedParameters: Dictionary of test name to parameter
    ///   - test: The test logic, which takes a parameter and test name
    public static func runParameterized<T>(
        name: String,
        namedParameters: [String: T],
        test: (_ parameter: T, _ testName: String) -> Void
    ) {
        for (paramName, parameter) in namedParameters {
            let testName = "\(name)[\(paramName)]"
            test(parameter, testName)
        }
    }
    
    /// Run a parameterized test with parameter sets
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameterSets: Array of tuples containing parameters and names
    ///   - test: The test logic, which takes parameters and test name
    public static func runParameterized<T>(
        name: String,
        parameterSets: [(parameters: T, name: String)],
        test: (_ parameters: T, _ testName: String) -> Void
    ) {
        for (parameters, paramName) in parameterSets {
            let testName = "\(name)[\(paramName)]"
            test(parameters, testName)
        }
    }
    
    /// Run a parameterized test with a grid of parameter combinations
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameters1: First parameter set
    ///   - parameters2: Second parameter set
    ///   - test: The test logic, which takes both parameters and test name
    public static func runParameterizedGrid<T1, T2>(
        name: String,
        parameters1: [(T1, String)],
        parameters2: [(T2, String)],
        test: (_ parameter1: T1, _ parameter2: T2, _ testName: String) -> Void
    ) {
        for (param1, name1) in parameters1 {
            for (param2, name2) in parameters2 {
                let testName = "\(name)[\(name1)_\(name2)]"
                test(param1, param2, testName)
            }
        }
    }
    
    /// Run a parameterized test with a grid of parameter combinations
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameters1: First parameter set
    ///   - parameters2: Second parameter set
    ///   - parameters3: Third parameter set
    ///   - test: The test logic, which takes all parameters and test name
    public static func runParameterizedGrid<T1, T2, T3>(
        name: String,
        parameters1: [(T1, String)],
        parameters2: [(T2, String)],
        parameters3: [(T3, String)],
        test: (_ parameter1: T1, _ parameter2: T2, _ parameter3: T3, _ testName: String) -> Void
    ) {
        for (param1, name1) in parameters1 {
            for (param2, name2) in parameters2 {
                for (param3, name3) in parameters3 {
                    let testName = "\(name)[\(name1)_\(name2)_\(name3)]"
                    test(param1, param2, param3, testName)
                }
            }
        }
    }
    
    // MARK: - Loading Test Data
    
    /// Load test data from a JSON file
    /// - Parameters:
    ///   - url: The URL of the JSON file
    ///   - type: The type to decode the JSON to
    /// - Returns: The decoded test data
    public static func loadJSONTestData<T: Decodable>(from url: URL, as type: T.Type) -> T? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            print("Error loading JSON test data: \(error)")
            return nil
        }
    }
    
    /// Load test data from a CSV file
    /// - Parameters:
    ///   - url: The URL of the CSV file
    ///   - hasHeaderRow: Whether the CSV has a header row
    /// - Returns: The parsed CSV data as arrays of strings
    public static func loadCSVTestData(from url: URL, hasHeaderRow: Bool = true) -> (headers: [String]?, rows: [[String]])? {
        do {
            let content = try String(contentsOf: url)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            guard !lines.isEmpty else { return nil }
            
            let rows = lines.map { $0.components(separatedBy: ",") }
            
            if hasHeaderRow && rows.count > 0 {
                let headers = rows[0]
                let dataRows = Array(rows.dropFirst())
                return (headers, dataRows)
            } else {
                return (nil, rows)
            }
        } catch {
            print("Error loading CSV test data: \(error)")
            return nil
        }
    }
    
    /// Parse CSV data into a dictionary
    /// - Parameters:
    ///   - csvData: The CSV data from loadCSVTestData
    /// - Returns: An array of dictionaries, where each dictionary represents a row with column names as keys
    public static func parseCSVToDictionaries(csvData: (headers: [String]?, rows: [[String]])) -> [[String: String]]? {
        guard let headers = csvData.headers, !headers.isEmpty else {
            return nil
        }
        
        var result = [[String: String]]()
        
        for row in csvData.rows {
            var rowDict = [String: String]()
            
            // Ensure we only process columns that have header names
            for (index, header) in headers.enumerated() {
                if index < row.count {
                    rowDict[header] = row[index]
                }
            }
            
            result.append(rowDict)
        }
        
        return result
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Run a parameterized test with an array of parameters
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameters: The parameters to run the test with
    ///   - test: The test logic, which takes a parameter and test name
    public func runParameterized<T>(
        name: String,
        parameters: [T],
        test: (_ parameter: T, _ testName: String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(name: name, parameters: parameters, test: test)
    }
    
    /// Run a parameterized test with named parameters
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - namedParameters: Dictionary of test name to parameter
    ///   - test: The test logic, which takes a parameter and test name
    public func runParameterized<T>(
        name: String,
        namedParameters: [String: T],
        test: (_ parameter: T, _ testName: String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(name: name, namedParameters: namedParameters, test: test)
    }
    
    /// Run a parameterized test with parameter sets
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameterSets: Array of tuples containing parameters and names
    ///   - test: The test logic, which takes parameters and test name
    public func runParameterized<T>(
        name: String,
        parameterSets: [(parameters: T, name: String)],
        test: (_ parameters: T, _ testName: String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(name: name, parameterSets: parameterSets, test: test)
    }
    
    /// Run a parameterized test with a grid of parameter combinations
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameters1: First parameter set
    ///   - parameters2: Second parameter set
    ///   - test: The test logic, which takes both parameters and test name
    public func runParameterizedGrid<T1, T2>(
        name: String,
        parameters1: [(T1, String)],
        parameters2: [(T2, String)],
        test: (_ parameter1: T1, _ parameter2: T2, _ testName: String) -> Void
    ) {
        ParameterizedTestUtility.runParameterizedGrid(name: name, parameters1: parameters1, parameters2: parameters2, test: test)
    }
    
    /// Run a parameterized test with a grid of parameter combinations
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - parameters1: First parameter set
    ///   - parameters2: Second parameter set
    ///   - parameters3: Third parameter set
    ///   - test: The test logic, which takes all parameters and test name
    public func runParameterizedGrid<T1, T2, T3>(
        name: String,
        parameters1: [(T1, String)],
        parameters2: [(T2, String)],
        parameters3: [(T3, String)],
        test: (_ parameter1: T1, _ parameter2: T2, _ parameter3: T3, _ testName: String) -> Void
    ) {
        ParameterizedTestUtility.runParameterizedGrid(name: name, parameters1: parameters1, parameters2: parameters2, parameters3: parameters3, test: test)
    }
    
    /// Run a parameterized test with data from a JSON file
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - jsonURL: The URL of the JSON file
    ///   - type: The type to decode the JSON array to
    ///   - test: The test logic, which takes a parameter and test name
    public func runWithJSONData<T: Decodable>(
        name: String,
        jsonURL: URL,
        type: [T].Type,
        test: (_ parameter: T, _ testName: String) -> Void
    ) {
        guard let testData = ParameterizedTestUtility.loadJSONTestData(from: jsonURL, as: type) else {
            XCTFail("Failed to load JSON test data from \(jsonURL.path)")
            return
        }
        
        for (index, parameter) in testData.enumerated() {
            let testName = "\(name)[\(index)]"
            test(parameter, testName)
        }
    }
    
    /// Run a parameterized test with data from a CSV file
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - csvURL: The URL of the CSV file
    ///   - hasHeaderRow: Whether the CSV has a header row
    ///   - test: The test logic, which takes a row as an array of strings and test name
    public func runWithCSVData(
        name: String,
        csvURL: URL,
        hasHeaderRow: Bool = true,
        test: (_ row: [String], _ testName: String) -> Void
    ) {
        guard let csvData = ParameterizedTestUtility.loadCSVTestData(from: csvURL, hasHeaderRow: hasHeaderRow) else {
            XCTFail("Failed to load CSV test data from \(csvURL.path)")
            return
        }
        
        for (index, row) in csvData.rows.enumerated() {
            let testName = "\(name)[\(index)]"
            test(row, testName)
        }
    }
    
    /// Run a parameterized test with data from a CSV file as dictionaries
    /// - Parameters:
    ///   - name: The base name of the test
    ///   - csvURL: The URL of the CSV file
    ///   - test: The test logic, which takes a row as a dictionary and test name
    public func runWithCSVDataAsDictionaries(
        name: String,
        csvURL: URL,
        test: (_ row: [String: String], _ testName: String) -> Void
    ) {
        guard let csvData = ParameterizedTestUtility.loadCSVTestData(from: csvURL, hasHeaderRow: true),
              let dictionaries = ParameterizedTestUtility.parseCSVToDictionaries(csvData: csvData) else {
            XCTFail("Failed to load CSV test data as dictionaries from \(csvURL.path)")
            return
        }
        
        for (index, row) in dictionaries.enumerated() {
            let testName = "\(name)[\(index)]"
            test(row, testName)
        }
    }
} 