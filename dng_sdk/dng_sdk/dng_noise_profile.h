#ifndef __dng_noise_profile__
#define __dng_noise_profile__

#include "dng_1d_function.h"
#include "dng_types.h"
#include "dng_std_types.h"

/*****************************************************************************/

/// \brief Noise model for photon and sensor read noise, assuming that they are
/// independent random variables and spatially invariant.
///
/// The noise model is N (x) = sqrt (scale*x + offset), where x represents a linear
/// signal value in the range [0,1], and N (x) is the standard deviation (i.e.,
/// noise). The parameters scale and offset are both sensor-dependent and
/// ISO-dependent. scale must be positive, and offset must be non-negative.

class dng_noise_function: public dng_1d_function
	{
		
	protected:

		real64 fScale;
		real64 fOffset;

	public:

		/// Create empty and invalid noise function.

		dng_noise_function ()
			:	fScale	(0.0)
			,	fOffset (0.0)
			{
			}

		/// Create noise function with the specified scale and offset.

		dng_noise_function (real64 scale,
							real64 offset)
			:	fScale	(scale)
			,	fOffset (offset)
			{
			}

		/// Compute noise (standard deviation) at the specified average signal level x.

		virtual real64 Evaluate (real64 x) const override
			{
			return sqrt (fScale * x + fOffset);
			}

		/// The scale (slope, gain) of the noise function.

		real64 Scale () const 
			{ 
			return fScale; 
			}

		/// The offset (square of the noise floor) of the noise function.

		real64 Offset () const 
			{ 
			return fOffset; 
			}

		/// Set the scale (slope, gain) of the noise function.

		void SetScale (real64 scale)
			{
			fScale = scale;
			}

		/// Set the offset (square of the noise floor) of the noise function.

		void SetOffset (real64 offset)
			{
			fOffset = offset;
			}

		/// Is the noise function valid?

		bool IsValid () const
			{
			return (fScale > 0.0 && fOffset >= 0.0);
			}
		
	};

/*****************************************************************************/

/// \brief Noise profile for a negative.
///
/// For mosaiced negatives, the noise profile describes the approximate noise
/// characteristics of a mosaic negative after linearization, but prior to
/// demosaicing. For demosaiced negatives (i.e., linear DNGs), the noise profile
/// describes the approximate noise characteristics of the image data immediately
/// following the demosaic step, prior to the processing of opcode list 3.
///
/// A noise profile may contain 1 or N noise functions, where N is the number of
/// color planes for the negative. Otherwise the noise profile is considered to be
/// invalid for that negative. If the noise profile contains 1 noise function, then
/// it is assumed that this single noise function applies to all color planes of the
/// negative. Otherwise, the N noise functions map to the N planes of the negative in
/// order specified in the CFAPlaneColor tag.

class dng_noise_profile
	{
		
	protected:

		dng_std::vector<dng_noise_function> fNoiseFunctions;

	public:

		/// Create empty (invalid) noise profile.

		dng_noise_profile ()
			{
			}

		/// Create noise profile with the specified noise functions (1 per plane).

		explicit dng_noise_profile (const dng_std::vector<dng_noise_function> &functions)
			:	fNoiseFunctions (functions)
			{
			}

		/// Is the noise profile valid?

		bool IsValid () const
			{
			if (fNoiseFunctions.empty())
				return false;

			for (const auto &func : fNoiseFunctions)
				{
				if (!func.IsValid())
					return false;
				}

			return true;
			}

		/// The noise function for the specified plane.

		const dng_noise_function & NoiseFunction (uint32 plane) const
			{
			return fNoiseFunctions[plane % fNoiseFunctions.size()];
			}

		/// The number of noise functions in this profile.

		uint32 NumFunctions () const
			{
			return (uint32) fNoiseFunctions.size();
			}
  
		/// Equality test.
		
		bool operator== (const dng_noise_profile &profile) const
			{
			return fNoiseFunctions == profile.fNoiseFunctions;
			}

		bool operator!= (const dng_noise_profile &profile) const
			{
			return !(*this == profile);
			}

	};

/*****************************************************************************/

#endif	// __dng_noise_profile__ 