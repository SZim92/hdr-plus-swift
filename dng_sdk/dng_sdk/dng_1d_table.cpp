/*****************************************************************************/
// Copyright 2006-2019 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

/**
 * @file dng_1d_table.cpp
 * 
 * Implementation of a table-based approximation for one-dimensional functions.
 * 
 * This file contains the implementation of the dng_1d_table class, which
 * provides efficient evaluation of one-dimensional functions by pre-computing
 * function values at discrete points and using linear interpolation. Key
 * features include:
 * 
 * - Storage of precomputed function values for fast lookup
 * - Adaptive subdivision for improved accuracy in regions with high curvature
 * - Uniform sampling option for simpler functions
 * - Expansion to 16-bit lookup tables for even faster evaluation
 * 
 * This is commonly used in the DNG processing pipeline for tone curves,
 * gamma correction, and other one-dimensional transformations where
 * performance is critical.
 */

#include "dng_1d_table.h"

#include "dng_1d_function.h"
#include "dng_assertions.h"
#include "dng_memory.h"
#include "dng_safe_arithmetic.h"
#include "dng_utils.h"

/*****************************************************************************/

/**
 * Constructor for the one-dimensional lookup table.
 * 
 * Creates a table with the specified number of entries. The table is not
 * allocated or initialized in the constructor; the Initialize method must
 * be called separately.
 * 
 * @param count The number of entries in the table. Must be a power of 2 and
 *              at least kMinTableSize.
 */
dng_1d_table::dng_1d_table (uint32 count)

	:	fBuffer		()
	,	fTable		(NULL)
	,	fTableCount (count)
	
	{

	DNG_REQUIRE (count >= kMinTableSize,
				 "count must be at least kMinTableSize");

	DNG_REQUIRE ((count & (count - 1)) == 0,
				 "count must be power of 2");
	
	}

/*****************************************************************************/

/**
 * Destructor for the one-dimensional lookup table.
 * 
 * Memory cleanup is handled automatically by the dng_ref_counted_block in fBuffer.
 */
dng_1d_table::~dng_1d_table ()
	{
	
	}
	
/*****************************************************************************/

/**
 * Recursively subdivides a range of the table to more accurately represent
 * the function in regions with high curvature.
 * 
 * This implements an adaptive sampling approach, which puts more samples
 * in regions where the function changes rapidly and fewer samples in
 * regions where it's more linear. This is called by Initialize when the
 * subSample parameter is true.
 * 
 * The algorithm works by:
 * 1. Checking if subdivision is needed based on range size or value difference
 * 2. If needed, computing the midpoint value and recursively subdividing
 * 3. If not needed, linearly interpolating between the endpoints
 * 
 * @param function The function to sample
 * @param lower    The lower index of the range to subdivide
 * @param upper    The upper index of the range to subdivide
 * @param maxDelta The maximum allowed difference between adjacent values
 *                 before subdivision is required
 */
void dng_1d_table::SubDivide (const dng_1d_function &function,
							  uint32 lower,
							  uint32 upper,
							  real32 maxDelta)
	{
	
	uint32 range = upper - lower;
		
	bool subDivide = (range > (fTableCount >> 8));
	
	if (!subDivide)
		{
		
		real32 delta = Abs_real32 (fTable [upper] - 
								   fTable [lower]);
								   
		if (delta > maxDelta)
			{
			
			subDivide = true;
			
			}
		
		}
		
	if (subDivide)
		{
		
		uint32 middle = (lower + upper) >> 1;
		
		fTable [middle] = (real32) function.Evaluate (middle * (1.0 / (real64) fTableCount));
		
		if (range > 2)
			{
			
			SubDivide (function, lower, middle, maxDelta);
			
			SubDivide (function, middle, upper, maxDelta);
			
			}
	
		}
		
	else
		{
		
		real64 y0 = fTable [lower];
		real64 y1 = fTable [upper];
		
		real64 delta = (y1 - y0) / (real64) range;
		
		for (uint32 j = lower + 1; j < upper; j++)
			{
			
			y0 += delta;
				
			fTable [j] = (real32) y0;
						
			}
		
		}
		
	}
	
/*****************************************************************************/

/**
 * Initializes the table by allocating memory and sampling the provided function.
 * 
 * This method allocates memory for the table and fills it with values from the
 * provided function. It can use either uniform sampling or adaptive sampling
 * based on the subSample parameter.
 * 
 * When subSample is true, it uses adaptive sampling by:
 * 1. Evaluating the function at the endpoints (0.0 and 1.0)
 * 2. Calculating a maximum delta value based on the range of the function
 * 3. Calling SubDivide to recursively fill in the table with more samples
 *    in regions of high curvature
 * 
 * When subSample is false, it uses uniform sampling by evaluating the function
 * at evenly spaced points across the domain.
 * 
 * The table is extended by one entry beyond fTableCount to simplify interpolation
 * at the upper boundary.
 * 
 * @param allocator Memory allocator used to allocate the table
 * @param function  The function to sample and store in the table
 * @param subSample Whether to use adaptive sampling (true) or uniform sampling (false)
 */
void dng_1d_table::Initialize (dng_memory_allocator &allocator,
							   const dng_1d_function &function,
							   bool subSample)
	{
	
	fBuffer.Reset (allocator.Allocate ((fTableCount + 2) * sizeof (real32)));
	
	fTable = fBuffer->Buffer_real32 ();
	
	if (subSample)
		{
		
		fTable [0		   ] = (real32) function.Evaluate (0.0);
		fTable [fTableCount] = (real32) function.Evaluate (1.0);
		
		real32 maxDelta = Max_real32 (Abs_real32 (fTable [fTableCount] -
												  fTable [0			 ]), 1.0f) *
						  (1.0f / 256.0f);
							   
		SubDivide (function,
				   0,
				   fTableCount,
				   maxDelta);
		
		}
		
	else
		{
			
		for (uint32 j = 0; j <= fTableCount; j++)
			{
			
			real64 x = j * (1.0 / (real64) fTableCount);
			
			real64 y = function.Evaluate (x);
			
			fTable [j] = ConvertDoubleToFloat (y);
			
			}
			
		}
		
	fTable [fTableCount + 1] = fTable [fTableCount];
	
	}

/*****************************************************************************/

/**
 * Expands the table into a full 16-bit lookup table for faster evaluation.
 * 
 * This method creates a full 65536-entry lookup table from the smaller internal
 * table using linear interpolation. This allows for direct indexing with a 16-bit
 * value without the need for additional interpolation at runtime.
 * 
 * The algorithm:
 * 1. Calculates the step size between entries in the source table
 * 2. For each entry in the expanded table, finds the corresponding segment
 *    in the source table and linearly interpolates between the endpoints
 * 3. Stores the resulting value in the expanded table
 * 
 * This is useful when the function will be evaluated many times and maximum
 * performance is required, at the cost of increased memory usage (128KB for a
 * full 16-bit table).
 * 
 * @param table16 Pointer to a pre-allocated array of 65536 uint16 values that
 *                will be filled with the expanded lookup table
 */
void dng_1d_table::Expand16 (uint16 *table16) const
	{
	
	real64 step = (real64) fTableCount / 65535.0;
	
	real64 y0 = fTable [0];
	real64 y1 = fTable [1];
	
	real64 base	 = y0 * 65535.0 + 0.5;
	real64 slope = (y1 - y0) * 65535.0;
	
	uint32 index = 1;
	real64 fract = 0.0;
	
	for (uint32 j = 0; j < 0x10000; j++)
		{
		
		table16 [j] = (uint16) (base + slope * fract);
		
		fract += step;
		
		if (fract > 1.0)
			{
			
			index += 1;
			fract -= 1.0;
			
			y0 = y1;
			y1 = fTable [index];
			
			base  = y0 * 65535.0 + 0.5;
			slope = (y1 - y0) * 65535.0;
			
			}
		
		}
	
	}

/*****************************************************************************/
