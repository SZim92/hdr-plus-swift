import XCTest
import Foundation
import CoreGraphics

/// This file is a compatibility wrapper that redirects to the main implementation
/// in Tests/VisualTestUtility.swift to avoid duplicate implementations.
///
/// @deprecated Use the main VisualTestUtility implementation directly instead.
/// This compatibility wrapper will be removed in a future update.
@available(*, deprecated, message: "Use the main VisualTestUtility implementation directly")
class VisualTestUtilityCompat {
    
    /// Forwards to the main implementation
    @discardableResult
    static func compareImage(_ testImage: CGImage,
                             toReferenceNamed referenceName: String,
                             tolerance: Double = 0.01,
                             in testCase: XCTestCase) -> Bool {
        return VisualTestUtility.compareImage(
            testImage,
            toReferenceNamed: referenceName,
            tolerance: tolerance,
            in: testCase
        )
    }
}

// Typealias for backward compatibility
typealias VisualTestUtility = VisualTestUtilityCompat 