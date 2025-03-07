/**
 * Metal Shader Constants
 *
 * This header file defines commonly used constants for Metal shaders in the burst photography pipeline.
 * These constants provide standardized values that are used across multiple shader files to ensure
 * consistent behavior and eliminate magic numbers in the codebase.
 */
#include <metal_stdlib>
using namespace metal;


/// Maximum value for a 16-bit unsigned integer (2^16 - 1)
constant uint UINT16_MAX_VAL = 65535;

/// Mathematical constant PI (π) with high precision for trigonometric calculations
constant float PI = 3.14159265358979323846f;

/// Half-precision floating point representation of zero
/// Used for initializing half-precision variables
constant half FLOAT16_ZERO_VAL = half(0);

/// Minimum representable value for half-precision floating point
/// Half-precision can represent values from approximately -65504 to +65504
constant half FLOAT16_MIN_VAL = half(-65504);

/// Maximum representable value for half-precision floating point
/// Used for clamping or checking against overflow conditions
constant half FLOAT16_MAX_VAL = half(65504);

/// Half-precision representation of 0.5
/// Commonly used for interpolation, normalization, and rounding operations
constant half FLOAT16_05_VAL = half(0.5f);
