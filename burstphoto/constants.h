/**
 * Metal Constants for Burst Photo Application
 *
 * This header file defines fundamental constants used throughout the Metal shader code
 * of the application. These constants provide standardized values for mathematical 
 * operations, data type boundaries, and common reference values needed by various 
 * shader functions.
 */
#include <metal_stdlib>
using namespace metal;


/** Maximum value representable in a 16-bit unsigned integer (2^16 - 1) */
constant uint UINT16_MAX_VAL = 65535;

/** Pi mathematical constant used for trigonometric and wave calculations */
constant float PI = 3.14159265358979323846f;

/** Zero value in half-precision floating point format */
constant half FLOAT16_ZERO_VAL = half(0);

/** Minimum value representable in half-precision (-65504.0) */
constant half FLOAT16_MIN_VAL = half(-65504);

/** Maximum value representable in half-precision (65504.0) */
constant half FLOAT16_MAX_VAL = half(65504);

/** Half-precision representation of 0.5, commonly used in interpolation and normalization */
constant half FLOAT16_05_VAL = half(0.5f);
