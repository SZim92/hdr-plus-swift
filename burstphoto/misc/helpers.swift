/**
 * Utility Helpers for Burst Photography
 *
 * This file provides utility functions used throughout the burst photography application,
 * including system resource monitoring and Metal compute pipeline creation helpers.
 * These utilities simplify common operations and enhance code reusability.
 */
import Foundation
import MetalPerformanceShaders

/// Returns the amount of free disk space left on the system.
/// 
/// Based on https://stackoverflow.com/questions/36006713/how-to-get-the-total-disk-space-and-free-disk-space-using-attributesoffilesystem
func systemFreeDiskSpace() -> Double {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)

    guard
        let lastPath = paths.last,
        let attributeDictionary = try? FileManager.default.attributesOfFileSystem(forPath: lastPath)
    else {
        return 0.0
    }

    if let size = attributeDictionary[.systemFreeSize] as? NSNumber {
        return Double(size.int64Value) / 1000 / 1000 / 1000
    } else {
        return 0.0
    }
}

/// Creates a Metal compute pipeline state with the specified function name and label.
///
/// This utility function simplifies the creation of Metal compute pipeline states used
/// throughout the application. It handles the boilerplate code for creating descriptors
/// and configuring the pipeline.
///
/// - Parameters:
///   - function_name: The name of the Metal shader function to use in the pipeline.
///   - label: A descriptive label for the pipeline, useful for debugging.
/// - Returns: A configured MTLComputePipelineState object ready for use in compute operations.
/// - Note: This function uses force unwrapping for simplicity, assuming the function names exist.
func create_pipeline(with_function_name function_name: String, and_label label: String) -> MTLComputePipelineState {
    let _descriptor = MTLComputePipelineDescriptor()
    _descriptor.computeFunction = mfl.makeFunction(name: function_name)
    _descriptor.label = label
    return try! device.makeComputePipelineState(descriptor: _descriptor, options: []).0
}
