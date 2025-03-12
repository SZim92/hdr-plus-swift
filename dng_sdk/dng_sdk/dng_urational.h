#ifndef __dng_urational__
#define __dng_urational__

/*****************************************************************************/

#include "dng_types.h"

/*****************************************************************************/

/// \brief Class to represent an unsigned rational number (unsigned numerator and denominator).
///
/// This class is used extensively in the DNG SDK for metadata values that are stored
/// as rational numbers in TIFF/EXIF tags.

class dng_urational
	{
	
	public:
	
		uint32 n;		// Numerator
		uint32 d;		// Denominator
		
	public:
	
		/// Create a rational number with 0/1.
		dng_urational ()
			:	n (0)
			,	d (1)
			{
			}
		
		/// Create a rational number with n/d.
		dng_urational (uint32 _n, uint32 _d)
			:	n (_n)
			,	d (_d)
			{
			}
		
		/// Convert to a real number (double precision).
		real64 As_real64 () const
			{
			if (d == 0)
				return 0.0;
			return (real64) n / (real64) d;
			}
		
		/// Convert to a real number (single precision).
		real32 As_real32 () const
			{
			return (real32) As_real64 ();
			}
		
		/// Convert to an integer (rounding down).
		uint32 As_uint32 () const
			{
			if (d == 0)
				return 0;
			return n / d;
			}
		
		/// Is this a valid rational number? (non-zero denominator)
		bool IsValid () const
			{
			return d != 0;
			}
		
		/// Comparison operators.
		bool operator== (const dng_urational &r) const
			{
			return n == r.n && d == r.d;
			}
		
		bool operator!= (const dng_urational &r) const
			{
			return !(*this == r);
			}
		
		/// Reduce the fraction to lowest terms.
		void Reduce ()
			{
			if (d == 0)
				{
				n = 0;
				d = 1;
				return;
				}
			
			uint32 a = n;
			uint32 b = d;
			
			while (b != 0)
				{
				uint32 t = b;
				b = a % b;
				a = t;
				}
			
			n = n / a;
			d = d / a;
			}
	};

/*****************************************************************************/

#endif	// __dng_urational__ 