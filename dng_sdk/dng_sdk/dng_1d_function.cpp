/*****************************************************************************/
// Copyright 2006-2019 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

/**
 * @file dng_1d_function.cpp
 * 
 * Implementation of one-dimensional function classes used for tone mapping and
 * other transformations in the DNG processing pipeline.
 * 
 * This file contains implementations for various 1D function classes:
 * - Base class for all 1D functions
 * - Identity function (f(x) = x)
 * - Concatenated functions (applying one function after another)
 * - Inverse functions
 * - Piecewise linear functions (connecting a series of control points)
 */

#include "dng_1d_function.h"

#include "dng_assertions.h"
#include "dng_stream.h"
#include "dng_utils.h"

/*****************************************************************************/

/**
 * Virtual destructor for the base function class.
 * 
 * Ensures proper cleanup of derived class resources when deleting 
 * through a base class pointer.
 */
dng_1d_function::~dng_1d_function ()
	{
	
	}

/*****************************************************************************/

/**
 * Checks if the function is an identity transformation.
 * 
 * The default implementation returns false. Derived classes should
 * override this method when they can detect identity transformations
 * to enable optimizations.
 * 
 * @return false by default (base class implementation)
 */
bool dng_1d_function::IsIdentity () const
	{
	
	return false;
	
	}

/*****************************************************************************/

/**
 * Evaluates the inverse of the function for a given output value.
 * 
 * This implements a numerical approximation of the inverse using
 * an iterative Newton-Raphson method. Derived classes can override
 * this with an exact implementation when available.
 * 
 * @param y The output value for which to find the input
 * @return The approximate input value x such that f(x) = y
 */
real64 dng_1d_function::EvaluateInverse (real64 y) const
	{
	
	const uint32 kMaxIterations = 30;
	const real64 kNearZero		= 1.0e-10;
	
	real64 x0 = 0.0;
	real64 y0 = Evaluate (x0);
	
	real64 x1 = 1.0;
	real64 y1 = Evaluate (x1);
	
	for (uint32 iteration = 0; iteration < kMaxIterations; iteration++)		
		{
		
		if (Abs_real64 (y1 - y0) < kNearZero)
			{
			break;
			}
		
		real64 x2 = Pin_real64 (0.0, 
								x1 + (y - y1) * (x1 - x0) / (y1 - y0),
								1.0);
		
		real64 y2 = Evaluate (x2);
		
		x0 = x1;
		y0 = y1;
		
		x1 = x2;
		y1 = y2;
		
		}
	
	return x1;
	
	}
	
/*****************************************************************************/

/**
 * Identity function implementation: f(x) = x
 * 
 * This function class returns the input value unchanged. 
 * It's useful for creating a no-op transformation and for 
 * testing/optimization purposes.
 */
bool dng_1d_identity::IsIdentity () const
	{
	
	return true;
	
	}
		
/*****************************************************************************/

/**
 * Evaluates the identity function.
 * 
 * Simply returns the input value unchanged.
 * 
 * @param x The input value
 * @return The same value x
 */
real64 dng_1d_identity::Evaluate (real64 x) const
	{
	
	return x;
	
	}
		
/*****************************************************************************/

/**
 * Evaluates the inverse of the identity function.
 * 
 * For the identity function, the inverse is also the identity function.
 * 
 * @param x The input value
 * @return The same value x
 */
real64 dng_1d_identity::EvaluateInverse (real64 x) const
	{
	
	return x;
	
	}
		
/*****************************************************************************/

/**
 * Provides access to a singleton instance of the identity function.
 * 
 * Using a singleton prevents unnecessary instantiations of this simple class.
 * 
 * @return Reference to the static identity function instance
 */
const dng_1d_function & dng_1d_identity::Get ()
	{
	
	static dng_1d_identity static_function;
	
	return static_function;
	
	}

/*****************************************************************************/

/**
 * Function composition implementation (g ∘ f)
 * 
 * This class represents the composition of two functions, where the output of
 * the first function becomes the input to the second function.
 * 
 * For input x, the result is function2(function1(x)).
 */
dng_1d_concatenate::dng_1d_concatenate (const dng_1d_function &function1,
										const dng_1d_function &function2)
										
	:	fFunction1 (function1)
	,	fFunction2 (function2)
	
	{
	
	}
	
/*****************************************************************************/

/**
 * Checks if the concatenated function is an identity transformation.
 * 
 * The composed function is an identity only if both component functions
 * are identities.
 * 
 * @return true if both component functions are identity functions
 */
bool dng_1d_concatenate::IsIdentity () const
	{
	
	return fFunction1.IsIdentity () &&
		   fFunction2.IsIdentity ();
	
	}
		
/*****************************************************************************/

/**
 * Evaluates the concatenated function at the given input value.
 * 
 * First evaluates function1, then passes its result to function2.
 * The intermediate result is clamped to the [0,1] range to ensure
 * valid input to the second function.
 * 
 * @param x The input value
 * @return function2(function1(x))
 */
real64 dng_1d_concatenate::Evaluate (real64 x) const
	{
	
	real64 y = Pin_real64 (0.0, fFunction1.Evaluate (x), 1.0);
	
	return fFunction2.Evaluate (y);
	
	}

/*****************************************************************************/

/**
 * Evaluates the inverse of the concatenated function.
 * 
 * For the inverse of a function composition (g ∘ f)^(-1),
 * we need to apply the inverses in reverse order: f^(-1) ∘ g^(-1).
 * 
 * @param x The input value for the inverse function
 * @return function1.inverse(function2.inverse(x))
 */
real64 dng_1d_concatenate::EvaluateInverse (real64 x) const
	{
	
	real64 y = fFunction2.EvaluateInverse (x);
	
	return fFunction1.EvaluateInverse (y);
	
	}
	
/*****************************************************************************/

/**
 * Inverse function implementation
 * 
 * This class represents the inverse of another function, swapping the input
 * and output domains. For a function f(x) = y, the inverse f^(-1) satisfies
 * f^(-1)(y) = x.
 */
dng_1d_inverse::dng_1d_inverse (const dng_1d_function &f)
	
	:	fFunction (f)
	
	{
	
	}
	
/*****************************************************************************/

/**
 * Checks if the inverse function is an identity transformation.
 * 
 * The inverse function is an identity if and only if the original
 * function is an identity.
 * 
 * @return true if the wrapped function is an identity function
 */
bool dng_1d_inverse::IsIdentity () const
	{
	
	return fFunction.IsIdentity ();
	
	}
	
/*****************************************************************************/

/**
 * Evaluates the inverse function at the given input value.
 * 
 * Simply calls the EvaluateInverse method of the wrapped function.
 * 
 * @param x The input value
 * @return The result of fFunction.EvaluateInverse(x)
 */
real64 dng_1d_inverse::Evaluate (real64 x) const
	{
	
	return fFunction.EvaluateInverse (x);
	
	}

/*****************************************************************************/

/**
 * Evaluates the inverse of the inverse function.
 * 
 * The inverse of an inverse function is the original function,
 * so this calls the Evaluate method of the wrapped function.
 * 
 * @param y The input value
 * @return The result of fFunction.Evaluate(y)
 */
real64 dng_1d_inverse::EvaluateInverse (real64 y) const
	{
	
	return fFunction.Evaluate (y);
	
	}
	
/*****************************************************************************/

/**
 * Piecewise linear function implementation
 * 
 * This class implements a function defined by a series of control points,
 * with linear interpolation between adjacent points. This is commonly used
 * for tone curves and color transformations where a precise mathematical
 * formula isn't available or needed.
 */
dng_piecewise_linear::dng_piecewise_linear ()

	:	X ()
	,	Y ()

	{

	}
	
/*****************************************************************************/

/**
 * Destructor for the piecewise linear function
 */
dng_piecewise_linear::~dng_piecewise_linear ()
	{

	}
	
/*****************************************************************************/

/**
 * Clears all control points from the function
 * 
 * Resets the function to an empty state with no control points defined.
 */
void dng_piecewise_linear::Reset ()
	{
	
	X.clear ();
	Y.clear ();
	
	}

/*****************************************************************************/

/**
 * Adds a control point to the piecewise linear function
 * 
 * The control points define the function's shape by providing
 * specific input-output value pairs through which the function passes.
 * 
 * @param x The input value (x-coordinate) of the control point
 * @param y The output value (y-coordinate) of the control point
 */
void dng_piecewise_linear::Add (real64 x, real64 y)
	{
	
	X.push_back (x);
	Y.push_back (y);
	
	}

/*****************************************************************************/

/**
 * Checks if the piecewise linear function is an identity transformation
 * 
 * A piecewise linear function is an identity if it has exactly two points:
 * (0,0) and (1,1), meaning f(0)=0 and f(1)=1 with linear interpolation
 * between them.
 * 
 * @return true if the function is the identity function
 */
bool dng_piecewise_linear::IsIdentity () const
	{
	
	return (X.size () == 2					&&
			X.size () == Y.size ()			&&
			X [0] == 0.0 && Y [0] == 0.0	&&
			X [1] == 1.0 && Y [1] == 1.0);
		
	}

/*****************************************************************************/

/**
 * Evaluates the piecewise linear function at the given input value
 * 
 * First performs bounds checking, then uses binary search to find the
 * appropriate interval and performs linear interpolation between the
 * control points.
 * 
 * @param x The input value
 * @return The interpolated output value
 */
real64 dng_piecewise_linear::Evaluate (real64 x) const
	{

	DNG_ASSERT (X.size () >= 2, "Too few points.");

	DNG_ASSERT (X.size () == Y.size (), "Input/output vector size mismatch.");
	
	// Check for extremes.

	if (x <= X.front ())
		{
		return Y.front ();
		}

	else if (x >= X.back ())
		{
		return Y.back ();
		}

	// Binary search for the X index.
	
	int32 lower = 1;
	int32 upper = ((int32) (X.size ())) - 1;
	
	while (upper > lower)
		{
		
		int32 mid = (lower + upper) >> 1;
		
		if (x == X [mid]) return Y [mid];
			
		if (x > X [mid]) lower = mid + 1;

		else upper = mid;
		
		}
		
	DNG_ASSERT (upper == lower, "Binary search error in point list.");

	int32 index0 = lower - 1;
	int32 index1 = lower;

	real64 X0 = X [index0];
	real64 X1 = X [index1];

	real64 Y0 = Y [index0];
	real64 Y1 = Y [index1];

	if (X0 == X1) return 0.5 * (Y0 + Y1);

	real64 t = (x - X0) / (X1 - X0);

	return Y0 + t * (Y1 - Y0);

	}
		
/*****************************************************************************/

/**
 * Evaluates the inverse of the piecewise linear function
 * 
 * Similar to the Evaluate method, but searches based on Y values
 * instead of X values and returns the corresponding X value.
 * 
 * @param y The output value for which to find the input
 * @return The input value x such that f(x) = y
 */
real64 dng_piecewise_linear::EvaluateInverse (real64 y) const
	{
	
	DNG_ASSERT (X.size () >= 2, "Too few points.");

	DNG_ASSERT (X.size () == Y.size (), "Input/output vector size mismatch.");
	
	// Binary search for the Y index.

	int32 lower = 1;
	int32 upper = ((int32) (Y.size ())) - 1;
	
	while (upper > lower)
		{
		
		int32 mid = (lower + upper) >> 1;
		
		if (y == Y [mid]) return X [mid];
			
		if (y > Y [mid]) lower = mid + 1;

		else upper = mid;
		
		}
		
	DNG_ASSERT (upper == lower, "Binary search error in point list.");

	int32 index0 = lower - 1;
	int32 index1 = lower;

	real64 X0 = X [index0];
	real64 X1 = X [index1];

	real64 Y0 = Y [index0];
	real64 Y1 = Y [index1];

	if (Y0 == Y1) return 0.5 * (X0 + X1);

	real64 t = (y - Y0) / (Y1 - Y0);

	return X0 + t * (X1 - X0);
	
	}

/*****************************************************************************/

/**
 * Writes data about this function to a stream for fingerprinting/identification
 * 
 * Stores the function's name and control points in the given stream, which
 * can later be used to identify or validate the function.
 * 
 * @param stream The output stream to write the function data to
 */
void dng_piecewise_linear::PutFingerprintData (dng_stream &stream) const
	{
	
	const char *name = "dng_piecewise_linear";

	stream.Put (name, (uint32) strlen (name));
	
	if (IsValid ())
		{

		for (size_t i = 0; i < X.size (); i++)
			{

			stream.Put_real64 (X [i]);
			stream.Put_real64 (Y [i]);

			}
	
		}
	
	}

/*****************************************************************************/

/**
 * Compares two piecewise linear functions for equality
 * 
 * Two piecewise linear functions are equal if they have identical
 * control points in the same order.
 * 
 * @param piecewise The function to compare against
 * @return true if both functions have the same control points
 */
bool dng_piecewise_linear::operator== (const dng_piecewise_linear &piecewise) const
	{
	
	return X == piecewise.X &&
		   Y == piecewise.Y;
	
	}

/*****************************************************************************/
