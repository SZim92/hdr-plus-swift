import Foundation
import XCTest

/// Utility for running parameterized tests
public class ParameterizedTestUtility {
    
    /// Runs a test with multiple parameter sets
    ///
    /// - Parameters:
    ///   - testCase: The test case instance
    ///   - name: Base name for the test
    ///   - parameters: Array of parameter sets to test
    ///   - test: Closure that runs the test with a parameter set
    public static func runParameterized<T>(
        on testCase: XCTestCase,
        name: String,
        parameters: [T],
        test: (T, String) -> Void
    ) {
        for (index, parameter) in parameters.enumerated() {
            let testName = "\(name) [\(index)]"
            
            // Record the start of a new test case for better reporting
            print("--- Running parameterized test: \(testName) ---")
            
            // Run the test with this parameter set
            test(parameter, testName)
        }
    }
    
    /// Runs a test with multiple named parameter sets
    ///
    /// - Parameters:
    ///   - testCase: The test case instance
    ///   - name: Base name for the test
    ///   - parameters: Dictionary of named parameter sets to test
    ///   - test: Closure that runs the test with a parameter set
    public static func runParameterized<T>(
        on testCase: XCTestCase,
        name: String,
        parameters: [String: T],
        test: (T, String) -> Void
    ) {
        for (paramName, parameter) in parameters {
            let testName = "\(name) [\(paramName)]"
            
            // Record the start of a new test case for better reporting
            print("--- Running parameterized test: \(testName) ---")
            
            // Run the test with this parameter set
            test(parameter, testName)
        }
    }
    
    /// Runs a data-driven test with multiple input-output pairs
    ///
    /// - Parameters:
    ///   - testCase: The test case instance
    ///   - name: Base name for the test
    ///   - data: Array of input-output pairs to test
    ///   - test: Closure that tests a function with an input-output pair
    public static func runDataDriven<Input, Output>(
        on testCase: XCTestCase,
        name: String,
        data: [(input: Input, expected: Output)],
        test: (Input, Output, String) -> Void
    ) {
        for (index, testData) in data.enumerated() {
            let testName = "\(name) [\(index)]"
            
            // Record the start of a new test case for better reporting
            print("--- Running data-driven test: \(testName) ---")
            
            // Run the test with this input-output pair
            test(testData.input, testData.expected, testName)
        }
    }
    
    /// Runs a data-driven test with multiple named input-output pairs
    ///
    /// - Parameters:
    ///   - testCase: The test case instance
    ///   - name: Base name for the test
    ///   - data: Dictionary of named input-output pairs to test
    ///   - test: Closure that tests a function with an input-output pair
    public static func runDataDriven<Input, Output>(
        on testCase: XCTestCase,
        name: String,
        data: [String: (input: Input, expected: Output)],
        test: (Input, Output, String) -> Void
    ) {
        for (caseName, testData) in data {
            let testName = "\(name) [\(caseName)]"
            
            // Record the start of a new test case for better reporting
            print("--- Running data-driven test: \(testName) ---")
            
            // Run the test with this input-output pair
            test(testData.input, testData.expected, testName)
        }
    }
    
    /// Generates a range of test parameters
    ///
    /// - Parameters:
    ///   - start: Starting value
    ///   - end: Ending value
    ///   - step: Step between values
    /// - Returns: Array of values from start to end
    public static func range<T: Numeric & Comparable>(
        from start: T,
        to end: T,
        step: T
    ) -> [T] where T: AdditiveArithmetic {
        var result = [T]()
        var current = start
        
        while current <= end {
            result.append(current)
            current = current + step
        }
        
        return result
    }
    
    /// Generates combinations of parameters
    ///
    /// - Parameters:
    ///   - arrays: Arrays to combine
    /// - Returns: Array of all combinations
    public static func combinations<T>(of arrays: [[T]]) -> [[T]] {
        guard !arrays.isEmpty else { return [] }
        guard arrays.count > 1 else { return arrays[0].map { [$0] } }
        
        var result: [[T]] = []
        
        // Get combinations of all arrays except the first one
        let restCombinations = combinations(of: Array(arrays.dropFirst()))
        
        // Combine first array with all other combinations
        for element in arrays[0] {
            for combination in restCombinations {
                result.append([element] + combination)
            }
        }
        
        return result
    }
}

// MARK: - XCTestCase Extension for Parameterized Testing

extension XCTestCase {
    
    /// Runs a parameterized test with an array of parameters
    ///
    /// - Parameters:
    ///   - name: Base name for the test
    ///   - parameters: Array of parameter sets
    ///   - test: Test closure
    public func runParameterized<T>(
        name: String,
        parameters: [T],
        test: (T, String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(
            on: self,
            name: name,
            parameters: parameters,
            test: test
        )
    }
    
    /// Runs a parameterized test with named parameters
    ///
    /// - Parameters:
    ///   - name: Base name for the test
    ///   - parameters: Dictionary of named parameter sets
    ///   - test: Test closure
    public func runParameterized<T>(
        name: String,
        parameters: [String: T],
        test: (T, String) -> Void
    ) {
        ParameterizedTestUtility.runParameterized(
            on: self,
            name: name,
            parameters: parameters,
            test: test
        )
    }
    
    /// Runs a data-driven test with input-output pairs
    ///
    /// - Parameters:
    ///   - name: Base name for the test
    ///   - data: Array of input-output pairs
    ///   - test: Test closure
    public func runDataDriven<Input, Output>(
        name: String,
        data: [(input: Input, expected: Output)],
        test: (Input, Output, String) -> Void
    ) {
        ParameterizedTestUtility.runDataDriven(
            on: self,
            name: name,
            data: data,
            test: test
        )
    }
    
    /// Runs a data-driven test with named input-output pairs
    ///
    /// - Parameters:
    ///   - name: Base name for the test
    ///   - data: Dictionary of named input-output pairs
    ///   - test: Test closure
    public func runDataDriven<Input, Output>(
        name: String,
        data: [String: (input: Input, expected: Output)],
        test: (Input, Output, String) -> Void
    ) {
        ParameterizedTestUtility.runDataDriven(
            on: self,
            name: name,
            data: data,
            test: test
        )
    }
} 