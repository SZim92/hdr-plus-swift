/*****************************************************************************/
// Copyright 2006-2019 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

/** \file
 * Definition of a lookup table based 1D floating-point to floating-point function abstraction using linear interpolation.
 * 
 * This file defines a class that implements efficient function evaluation through
 * table-based lookup with linear interpolation between sampled points. It provides
 * both uniform and adaptive sampling to balance accuracy and efficiency for different
 * function types.
 * 
 * The implementation allows for:
 * - Fast evaluation of arbitrary functions through table lookup
 * - Adaptive subdivision for higher accuracy with fewer samples
 * - Expansion to 16-bit lookup tables for even faster performance
 * - Efficient memory usage through smart allocation strategies
 */

/*****************************************************************************/

#ifndef __dng_1d_table__
#define __dng_1d_table__

/*****************************************************************************/

#include "dng_assertions.h"
#include "dng_auto_ptr.h"
#include "dng_classes.h"
#include "dng_types.h"
#include "dng_uncopyable.h"

/*****************************************************************************/

/// \brief A 1D floating-point lookup table using linear interpolation.
///
/// This class implements a table-based approximation of one-dimensional functions.
/// It samples a function at discrete points and uses linear interpolation for 
/// values between sample points, providing a significant performance boost over
/// direct function evaluation, especially for complex functions.
///
/// The table supports both uniform sampling and adaptive sampling (which places
/// more samples in regions where the function changes rapidly). It can also be
/// expanded to a full 16-bit lookup table for maximum performance.
///
/// The input domain is always [0,1] and the output range depends on the function
/// being approximated. The table size must be a power of 2 for efficient indexing.

class dng_1d_table: private dng_uncopyable
	{

	public:

		/// Constant denoting minimum size of table.

		static const uint32 kMinTableSize = 512;
	
	private:
	
		/// Constant denoting default size of table.

		static const uint32 kDefaultTableSize = 4096;
			
	protected:
	
		/// Memory buffer holding the table data.
		/// Uses reference counting for efficient memory management.
		AutoPtr<dng_memory_block> fBuffer;
		
		/// Pointer to the table data within fBuffer.
		/// This is set in the Initialize method.
		real32 *fTable;

		/// Number of entries in the table, not including the extra entry
		/// added at the end for interpolation at the upper boundary.
		const uint32 fTableCount;
	
	public:

		/// Table constructor. count must be a power of two
		/// and at least kMinTableSize.
		///
		/// Creates a table with the specified number of entries. Memory for the table
		/// itself is not allocated until Initialize() is called.
		///
		/// @param count Number of table entries. Must be a power of 2 and at least
		///              kMinTableSize (512). Default is kDefaultTableSize (4096).
	
		explicit dng_1d_table (uint32 count = kDefaultTableSize);
			
		/// Destructor.
		///
		/// Memory cleanup is handled automatically by the dng_ref_counted_block in fBuffer.
		
		virtual ~dng_1d_table ();

		/// Returns the number of table entries.
		///
		/// @return The number of entries in the table (excluding the extra entry
		///         added for interpolation at the upper boundary).

		uint32 Count () const
			{
			return fTableCount;
			}

		/// Set up table, initialize entries using functiion.
		/// This method can throw an exception, e.g. if there is not enough memory.
		/// \param allocator Memory allocator from which table memory is allocated.
		/// \param function Table is initialized with values of finction.Evalluate(0.0) to function.Evaluate(1.0).
		/// \param subSample If true, only sample the function a limited number of times and interpolate.
		/// 
		/// Allocates memory for the table and fills it with values from the provided function.
		/// When subSample is true, uses adaptive sampling for better accuracy in regions of 
		/// high curvature with fewer samples overall. When false, it uniformly samples
		/// the function at each table position.
		/// 
		/// The table includes an extra entry beyond fTableCount to simplify interpolation
		/// at the upper boundary. This entry is set equal to the last valid entry.
		///
		/// @throw Various memory allocation exceptions if memory cannot be allocated.

		void Initialize (dng_memory_allocator &allocator,
						 const dng_1d_function &function,
						 bool subSample = false);

		/// Lookup and interpolate mapping for an input.
		/// \param x value from 0.0 to 1.0 used as input for mapping
		/// \retval Approximation of function.Evaluate(x)
		///
		/// This is the main evaluation method for the table. It:
		/// 1. Scales the input to the table size
		/// 2. Finds the appropriate index in the table
		/// 3. Performs linear interpolation between adjacent entries
		/// 
		/// The method includes bounds checking and will throw an exception if x 
		/// would cause out-of-bounds access.
		///
		/// @throw ThrowBadFormat if the input would result in an out-of-range access.
		/// @return The interpolated function value.

		real32 Interpolate (real32 x) const
			{
			
			real32 y = x * (real32) fTableCount;
			
			int32 index = (int32) y;

			if (index < 0 || index > (int32) fTableCount)
				{
				
				ThrowBadFormat ("Index out of range.");
				
				}

			// Enable vectorization by using DNG_ASSERT instead of DNG_REQUIRE
			DNG_ASSERT(!(index < 0 || index >(int32) fTableCount), "dng_1d_table::Interpolate parameter out of range");
			
			real32 z = (real32) index;
						
			real32 fract = y - z;
			
			return fTable [index	] * (1.0f - fract) +
				   fTable [index + 1] * (		fract);
			
			}
			
		/// Direct access function for table data.
		///
		/// Provides direct access to the underlying table data. This can be useful
		/// for performance-critical operations or when specialized access patterns
		/// are needed.
		///
		/// @return Pointer to the table data array.
			
		const real32 * Table () const
			{
			return fTable;
			}
			
		/// Expand the table to a 16-bit to 16-bit table.
		///
		/// Creates a full 65536-entry lookup table from the smaller internal table.
		/// This allows for direct indexing with a 16-bit value without the need
		/// for additional interpolation at runtime, providing maximum performance
		/// at the cost of increased memory usage (128KB for the full table).
		///
		/// Uses linear interpolation between entries in the source table to fill
		/// the expanded table.
		///
		/// @param table16 Pointer to a pre-allocated array of 65536 uint16 values that
		///                will be filled with the expanded lookup table.
		
		void Expand16 (uint16 *table16) const;
			
	private:
	
		/// Recursively subdivides a range of the table to more accurately represent
		/// the function in regions with high curvature.
		///
		/// This implements an adaptive sampling approach, which puts more samples
		/// in regions where the function changes rapidly and fewer samples in
		/// regions where it's more linear.
		///
		/// The algorithm works by:
		/// 1. Checking if subdivision is needed based on range size or value difference
		/// 2. If needed, computing the midpoint value and recursively subdividing
		/// 3. If not needed, linearly interpolating between the endpoints
		///
		/// @param function The function to sample
		/// @param lower    The lower index of the range to subdivide
		/// @param upper    The upper index of the range to subdivide
		/// @param maxDelta The maximum allowed difference between adjacent values
		///                 before subdivision is required
		
		void SubDivide (const dng_1d_function &function,
						uint32 lower,
						uint32 upper,
						real32 maxDelta);
	
	};

/*****************************************************************************/

#endif
	
/*****************************************************************************/
