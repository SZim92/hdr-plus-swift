#ifndef __dng_image_stats__
#define __dng_image_stats__

/*****************************************************************************/

// Forward declarations
class dng_host;
class dng_image;

/// \brief Class for holding image statistics.
class dng_image_stats
	{
	
	public:
	
		dng_image_stats ();
		
		virtual ~dng_image_stats ();

		virtual void Calculate(const dng_host &host,
							 const dng_image &image);
		
	private:
		// Add private implementation details here
	};

/*****************************************************************************/

#endif	// __dng_image_stats__ 