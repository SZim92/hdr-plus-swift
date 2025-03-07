/*****************************************************************************/
// Copyright 2006-2019 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

/* --- Additional File Documentation ---
   This file implements the dng_exif class which manages EXIF metadata in the Adobe DNG SDK.
   It provides methods for constructing, copying, and parsing EXIF data, as well as utility functions for:
     1. Exposure settings and correction (SnapExposureTime, SetExposureTime, SetShutterSpeedValue).
     2. Aperture and f-number conversions (EncodeFNumber, SetFNumber, FNumberToApertureValue, ApertureValueToFNumber, SetApertureValue).
     3. DateTime and version management (UpdateDateTime, AtLeastVersion0230, AtLeastVersion0231, SetVersion0231).
     4. Lens distortion information (HasLensDistortInfo, SetLensDistortInfo).
     5. Parsing of EXIF tags from data streams (ParseTag, Parse_ifd0_main, Parse_ifd0_exif).
   Note: All original comments and non-English content are preserved.
   --- End Additional File Documentation ---

/**
 * @file dng_exif.cpp
 * 
 * Implementation of the dng_exif class for managing EXIF metadata in the DNG SDK.
 * 
 * This file contains the implementation of methods to parse, manipulate, and manage
 * Exchangeable Image File Format (EXIF) metadata within digital image files. It handles
 * reading and writing all standard EXIF tags, as well as providing utility functions
 * for common operations like exposure and aperture value conversions.
 */

#include "dng_exif.h"

#include "dng_tag_codes.h"
#include "dng_tag_types.h"
#include "dng_parse_utils.h"
#include "dng_globals.h"
#include "dng_exceptions.h"
#include "dng_tag_values.h"
#include "dng_utils.h"

/*****************************************************************************/

/* --- Exposure Correction Functions ---
   The following functions are responsible for adjusting and converting exposure settings:
   - SnapExposureTime: Adjusts a raw exposure time value to a standard shutter speed by applying rounding and correction.
   - SetExposureTime: Sets both the ExposureTime and ShutterSpeedValue fields in the EXIF data based on a given exposure time.
   - SetShutterSpeedValue: Sets the ShutterSpeedValue based on an APEX shutter speed, computing the corresponding ExposureTime if necessary.
*/

/* --- Aperture and F-Number Conversion Functions ---
   These functions handle the conversion between f-number (aperture) values and APEX aperture values:
   - EncodeFNumber: Converts an f-number into a rational representation with precision based on its magnitude.
   - SetFNumber: Sets the FNumber field and computes the corresponding ApertureValue in APEX units.
   - SetApertureValue: Sets the ApertureValue field and, if necessary, derives the FNumber from it.
   - ApertureValueToFNumber: Converts an APEX aperture value to the corresponding f-number.
   - FNumberToApertureValue: Converts an f-number into an APEX aperture value.
*/

/* --- DateTime and Version Management Functions ---
   These functions manage date/time metadata and version information in EXIF data:
   - AtLeastVersion0230: Checks if the EXIF version is at least 2.3.0.
   - AtLeastVersion0231: Checks if the EXIF version is at least 2.3.1.
   - SetVersion0231: Sets the EXIF version to 2.3.1 to indicate support for newer features.
   - UpdateDateTime: Updates the DateTime field with the provided date/time information.
*/

/*****************************************************************************/

/**
 * Constructor for dng_exif class.
 * 
 * Initializes all EXIF data members to their default values.
 * String fields are initialized as empty strings, rational values as invalid rationals,
 * and integer fields to either 0 or 0xFFFFFFFF (indicating an unspecified value).
 */
dng_exif::dng_exif ()

	:	fImageDescription ()
	,	fMake			  ()
	,	fModel			  ()
	,	fSoftware		  ()
	,	fArtist			  ()
	,	fCopyright		  ()
	,	fCopyright2		  ()
	,	fUserComment	  ()

	,	fDateTime			 ()
	,	fDateTimeStorageInfo ()
	
	,	fDateTimeOriginal			 ()
	,	fDateTimeOriginalStorageInfo ()
	
	,	fDateTimeDigitized			  ()
	,	fDateTimeDigitizedStorageInfo ()
		
	,	fTIFF_EP_StandardID (0)
	,	fExifVersion		(0)
	,	fFlashPixVersion	(0)
	
	,	fExposureTime	   ()
	,	fFNumber		   ()
	,	fShutterSpeedValue ()
	,	fApertureValue	   ()
	,	fBrightnessValue   ()
	,	fExposureBiasValue ()
	,	fMaxApertureValue  ()
	,	fFocalLength	   ()
	,	fDigitalZoomRatio  ()
	,	fExposureIndex	   ()
	,	fSubjectDistance   ()
	,	fGamma			   ()
		
	,	fBatteryLevelR ()
	,	fBatteryLevelA ()
		
	,	fExposureProgram	  (0xFFFFFFFF)
	,	fMeteringMode		  (0xFFFFFFFF)
	,	fLightSource		  (0xFFFFFFFF)
	,	fFlash				  (0xFFFFFFFF)
	,	fFlashMask			  (0x0000FFFF)
	,	fSensingMethod		  (0xFFFFFFFF)
	,	fColorSpace			  (0xFFFFFFFF)
	,	fFileSource			  (0xFFFFFFFF)
	,	fSceneType			  (0xFFFFFFFF)
	,	fCustomRendered		  (0xFFFFFFFF)
	,	fExposureMode		  (0xFFFFFFFF)
	,	fWhiteBalance		  (0xFFFFFFFF)
	,	fSceneCaptureType	  (0xFFFFFFFF)
	,	fGainControl		  (0xFFFFFFFF)
	,	fContrast			  (0xFFFFFFFF)
	,	fSaturation			  (0xFFFFFFFF)
	,	fSharpness			  (0xFFFFFFFF)
	,	fSubjectDistanceRange (0xFFFFFFFF)
	,	fSelfTimerMode		  (0xFFFFFFFF)
	,	fImageNumber		  (0xFFFFFFFF)
	
	,	fFocalLengthIn35mmFilm (0)

	,	fSensitivityType		   (0)
	,	fStandardOutputSensitivity (0)
	,	fRecommendedExposureIndex  (0)
	,	fISOSpeed				   (0)
	,	fISOSpeedLatitudeyyy	   (0)
	,	fISOSpeedLatitudezzz	   (0)

	,	fSubjectAreaCount (0)
	
	,	fComponentsConfiguration (0)
	
	,	fCompresssedBitsPerPixel ()
	
	,	fPixelXDimension (0)
	,	fPixelYDimension (0)
	
	,	fFocalPlaneXResolution ()
	,	fFocalPlaneYResolution ()
		
	,	fFocalPlaneResolutionUnit (0xFFFFFFFF)
	
	,	fCFARepeatPatternRows (0)
	,	fCFARepeatPatternCols (0)
	
	,	fImageUniqueID ()
	
	,	fGPSVersionID		  (0)
	,	fGPSLatitudeRef		  ()
	,	fGPSLongitudeRef	  ()
	,	fGPSAltitudeRef		  (0xFFFFFFFF)
	,	fGPSAltitude		  ()
	,	fGPSSatellites		  ()
	,	fGPSStatus			  ()
	,	fGPSMeasureMode		  ()
	,	fGPSDOP				  ()
	,	fGPSSpeedRef		  ()
	,	fGPSSpeed			  ()
	,	fGPSTrackRef		  ()
	,	fGPSTrack			  ()
	,	fGPSImgDirectionRef	  ()
	,	fGPSImgDirection	  ()
	,	fGPSMapDatum		  ()
	,	fGPSDestLatitudeRef	  ()
	,	fGPSDestLongitudeRef  ()
	,	fGPSDestBearingRef	  ()
	,	fGPSDestBearing		  ()
	,	fGPSDestDistanceRef	  ()
	,	fGPSDestDistance	  ()
	,	fGPSProcessingMethod  ()
	,	fGPSAreaInformation	  ()
	,	fGPSDateStamp		  ()
	,	fGPSDifferential	  (0xFFFFFFFF)
	,	fGPSHPositioningError ()
	
	,	fInteroperabilityIndex ()

	,	fInteroperabilityVersion (0)
	
	,	fRelatedImageFileFormat ()
	
	,	fRelatedImageWidth	(0)
	,	fRelatedImageLength (0)
	
	,	fCameraSerialNumber ()
	
	,	fLensID			  ()
	,	fLensMake		  ()
	,	fLensName		  ()
	,	fLensSerialNumber ()
	
	,	fLensNameWasReadFromExif (false)

	,	fApproxFocusDistance ()

	,	fFlashCompensation ()
	
	,	fOwnerName ()
	,	fFirmware  ()

	,	fTemperature		  ()
	,	fHumidity			  ()
	,	fPressure			  ()
	,	fWaterDepth			  ()
	,	fAcceleration		  ()
	,	fCameraElevationAngle ()

	,	fTitle ()
	
	{
	
	uint32 j;
	uint32 k;
	
	fISOSpeedRatings [0] = 0;
	fISOSpeedRatings [1] = 0;
	fISOSpeedRatings [2] = 0;
	
	for (j = 0; j < kMaxCFAPattern; j++)
		for (k = 0; k < kMaxCFAPattern; k++)
			{
			fCFAPattern [j] [k] = 255;
			}

	memset (fLensDistortInfo, 0, sizeof (fLensDistortInfo));
		
	}
	
/*****************************************************************************/

/**
 * Virtual destructor for the dng_exif class.
 * 
 * Since all members are automatically destructed when the object is destroyed,
 * no special cleanup is needed in this destructor.
 */
dng_exif::~dng_exif ()
	{
	
	}
		
/*****************************************************************************/

/**
 * Creates a deep copy of this EXIF object.
 * 
 * Allocates a new dng_exif object and copies all member data from this 
 * object to the newly created one. Throws a memory full exception if
 * the allocation fails.
 * 
 * @return A pointer to the newly allocated copy
 * @throws dng_memory_full if memory allocation fails
 */
dng_exif * dng_exif::Clone () const
	{
	
	dng_exif *result = new dng_exif (*this);
	
	if (!result)
		{
		ThrowMemoryFull ();
		}
	
	return result;
	
	}
		
/*****************************************************************************/

/**
 * Resets all EXIF fields to their default values.
 * 
 * Creates a new default dng_exif object and copies it to this object,
 * effectively resetting all fields to their initial values.
 */
void dng_exif::SetEmpty ()
	{
	
	*this = dng_exif ();
	
	}
		
/*****************************************************************************/

/**
 * Copies all GPS-related fields from another EXIF object.
 * 
 * This allows preserving GPS metadata when modifying other parts of the EXIF data.
 * All GPS tags from the source EXIF object are copied to this object.
 * 
 * @param exif Source EXIF object from which to copy GPS data
 */
void dng_exif::CopyGPSFrom (const dng_exif &exif)
	{
			
	fGPSVersionID		  = exif.fGPSVersionID;
	fGPSLatitudeRef		  = exif.fGPSLatitudeRef;
	fGPSLatitude [0]	  = exif.fGPSLatitude [0];
	fGPSLatitude [1]	  = exif.fGPSLatitude [1];
	fGPSLatitude [2]	  = exif.fGPSLatitude [2];
	fGPSLongitudeRef	  = exif.fGPSLongitudeRef;
	fGPSLongitude [0]	  = exif.fGPSLongitude [0];
	fGPSLongitude [1]	  = exif.fGPSLongitude [1];
	fGPSLongitude [2]	  = exif.fGPSLongitude [2];
	fGPSAltitudeRef		  = exif.fGPSAltitudeRef;
	fGPSAltitude		  = exif.fGPSAltitude;
	fGPSTimeStamp [0]	  = exif.fGPSTimeStamp [0];
	fGPSTimeStamp [1]	  = exif.fGPSTimeStamp [1];
	fGPSTimeStamp [2]	  = exif.fGPSTimeStamp [2];
	fGPSSatellites		  = exif.fGPSSatellites;
	fGPSStatus			  = exif.fGPSStatus;
	fGPSMeasureMode		  = exif.fGPSMeasureMode;
	fGPSDOP				  = exif.fGPSDOP;
	fGPSSpeedRef		  = exif.fGPSSpeedRef;
	fGPSSpeed			  = exif.fGPSSpeed;
	fGPSTrackRef		  = exif.fGPSTrackRef;
	fGPSTrack			  = exif.fGPSTrack;
	fGPSImgDirectionRef	  = exif.fGPSImgDirectionRef;
	fGPSImgDirection	  = exif.fGPSImgDirection;
	fGPSMapDatum		  = exif.fGPSMapDatum;
	fGPSDestLatitudeRef	  = exif.fGPSDestLatitudeRef;
	fGPSDestLatitude [0]  = exif.fGPSDestLatitude [0];
	fGPSDestLatitude [1]  = exif.fGPSDestLatitude [1];
	fGPSDestLatitude [2]  = exif.fGPSDestLatitude [2];
	fGPSDestLongitudeRef  = exif.fGPSDestLongitudeRef;
	fGPSDestLongitude [0] = exif.fGPSDestLongitude [0];
	fGPSDestLongitude [1] = exif.fGPSDestLongitude [1];
	fGPSDestLongitude [2] = exif.fGPSDestLongitude [2];
	fGPSDestBearingRef	  = exif.fGPSDestBearingRef;
	fGPSDestBearing		  = exif.fGPSDestBearing;
	fGPSDestDistanceRef	  = exif.fGPSDestDistanceRef;
	fGPSDestDistance	  = exif.fGPSDestDistance;
	fGPSProcessingMethod  = exif.fGPSProcessingMethod;
	fGPSAreaInformation	  = exif.fGPSAreaInformation;
	fGPSDateStamp		  = exif.fGPSDateStamp;
	fGPSDifferential	  = exif.fGPSDifferential;
	fGPSHPositioningError = exif.fGPSHPositioningError;

	}

/*****************************************************************************/

/**
 * Fixes up common errors and rounding issues with EXIF exposure times.
 * 
 * This utility method takes an exposure time value and:
 * 1. Checks if it's close to a standard shutter speed and snaps to it if so
 * 2. Handles common misrounded values (like 1/64 which should be 1/60)
 * 3. For non-standard values, rounds to a visually pleasing representation
 * 
 * The method performs intelligent rounding based on the range of the exposure time:
 * - For slow exposures (≥10s), rounds to the nearest second
 * - For medium exposures (≥0.5s), rounds to the nearest 0.1 second
 * - For faster exposures, uses increasingly precise rounding of the denominator
 * 
 * @param et Exposure time in seconds
 * @return The snapped/corrected exposure time
 */
real64 dng_exif::SnapExposureTime (real64 et)
	{
	
	// Protection against invalid values.
	
	if (et <= 0.0)
		return 0.0;
	
	// If near a standard shutter speed, snap to it.
	
	static const real64 kStandardSpeed [] =
		{
		30.0,
		25.0,
		20.0,
		15.0,
		13.0,
		10.0,
		8.0,
		6.0,
		5.0,
		4.0,
		3.2,
		3.0,
		2.5,
		2.0,
		1.6,
		1.5,
		1.3,
		1.0,
		0.8,
		0.7,
		0.6,
		0.5,
		0.4,
		0.3,
		1.0 / 4.0,
		1.0 / 5.0,
		1.0 / 6.0,
		1.0 / 8.0,
		1.0 / 10.0,
		1.0 / 13.0,
		1.0 / 15.0,
		1.0 / 20.0,
		1.0 / 25.0,
		1.0 / 30.0,
		1.0 / 40.0,
		1.0 / 45.0,
		1.0 / 50.0,
		1.0 / 60.0,
		1.0 / 80.0,
		1.0 / 90.0,
		1.0 / 100.0,
		1.0 / 125.0,
		1.0 / 160.0,
		1.0 / 180.0,
		1.0 / 200.0,
		1.0 / 250.0,
		1.0 / 320.0,
		1.0 / 350.0,
		1.0 / 400.0,
		1.0 / 500.0,
		1.0 / 640.0,
		1.0 / 750.0,
		1.0 / 800.0,
		1.0 / 1000.0,
		1.0 / 1250.0,
		1.0 / 1500.0,
		1.0 / 1600.0,
		1.0 / 2000.0,
		1.0 / 2500.0,
		1.0 / 3000.0,
		1.0 / 3200.0,
		1.0 / 4000.0,
		1.0 / 5000.0,
		1.0 / 6000.0,
		1.0 / 6400.0,
		1.0 / 8000.0,
		1.0 / 10000.0,
		1.0 / 12000.0,
		1.0 / 12800.0,
		1.0 / 16000.0
		};
		
	uint32 count = sizeof (kStandardSpeed	 ) /
				   sizeof (kStandardSpeed [0]);
					   
	for (uint32 fudge = 0; fudge <= 1; fudge++)
		{
		
		real64 testSpeed = et;
		
		if (fudge == 1)
			{
			
			// Often APEX values are rounded to a power of two,
			// which results in non-standard shutter speeds.
			
			if (et >= 0.1)
				{
				
				// No fudging slower than 1/10 second
				
				break;
				
				}
			
			else if (et >= 0.01)
				{
				
				// Between 1/10 and 1/100 the commonly misrounded
				// speeds are 1/15, 1/30, 1/60, which are often encoded as
				// 1/16, 1/32, 1/64.  Try fudging and see if we get
				// near a standard speed.
				
				testSpeed *= 16.0 / 15.0;
				
				}
				
			else
				{
				
				// Faster than 1/100, the commonly misrounded
				// speeds are 1/125, 1/250, 1/500, etc., which
				// are often encoded as 1/128, 1/256, 1/512.
				
				testSpeed *= 128.0 / 125.0;
				
				}
			
			}
			
		for (uint32 index = 0; index < count; index++)
			{
			
			if (testSpeed >= kStandardSpeed [index] * 0.98 &&
				testSpeed <= kStandardSpeed [index] * 1.02)
				{
				
				return kStandardSpeed [index];
				
				}
				
			}
			
		}
		
	// We are not near any standard speeds.	 Round the non-standard value to something
	// that looks reasonable.
	
	if (et >= 10.0)
		{
		
		// Round to nearest second.
		
		et = floor (et + 0.5);
		
		}
		
	else if (et >= 0.5)
		{
		
		// Round to nearest 1/10 second
		
		et = floor (et * 10.0 + 0.5) * 0.1;
		
		}
		
	else if (et >= 1.0 / 20.0)
		{
		
		// Round to an exact inverse.
		
		et = 1.0 / floor (1.0 / et + 0.5);
		
		}
		
	else if (et >= 1.0 / 130.0)
		{
		
		// Round inverse to multiple of 5
		
		et = 0.2 / floor (0.2 / et + 0.5);
		
		}
		
	else if (et >= 1.0 / 750.0)
		{
		
		// Round inverse to multiple of 10
		
		et = 0.1 / floor (0.1 / et + 0.5);
		
		}
		
	else if (et >= 1.0 / 1300.0)
		{
		
		// Round inverse to multiple of 50
		
		et = 0.02 / floor (0.02 / et + 0.5);
		
		}
		
	else if (et >= 1.0 / 15000.0)
		{
		
		// Round inverse to multiple of 100
		
		et = 0.01 / floor (0.01 / et + 0.5);
		
		}
		
	else
		{
		
		// Round inverse to multiple of 1000
		
		et = 0.001 / floor (0.001 / et + 0.5);
		
		}
		
	return et;
	
	}

/*****************************************************************************/

/**
 * Sets the exposure time and shutter speed fields in the EXIF data.
 * 
 * This method sets both the ExposureTime and ShutterSpeedValue fields
 * based on the provided exposure time value. The method:
 * 1. Optionally corrects common errors and rounding issues in the exposure time
 * 2. Formats the exposure time as a rational value in the most appropriate way
 * 3. Calculates the corresponding ShutterSpeedValue in APEX units
 * 
 * For example:
 * - Long exposures (≥100s): stored as seconds (e.g., 120/1)
 * - Medium exposures (≥1s): stored with precision to 0.1s (e.g., 15/10)
 * - Fast exposures (≤0.1s): stored as 1/x (e.g., 1/60, 1/125)
 * 
 * @param et Exposure time in seconds
 * @param snap Whether to correct common errors and rounding issues (default: true)
 */
void dng_exif::SetExposureTime (real64 et, bool snap)
	{
	
	fExposureTime.Clear ();
	
	fShutterSpeedValue.Clear ();
	
	if (snap)
		{
		
		et = SnapExposureTime (et);
		
		}
		
	if (et >= 1.0 / 1073741824.0 && et <= 1073741824.0)
		{
		
		if (et >= 100.0)
			{
			
			fExposureTime.Set_real64 (et, 1);
			
			}
			
		else if (et >= 1.0)
			{
			
			fExposureTime.Set_real64 (et, 10);
			
			fExposureTime.ReduceByFactor (10);
			
			}
			
		else if (et <= 0.1)
			{
			
			fExposureTime = dng_urational (1, Round_uint32 (1.0 / et));
			
			}
			
		else
			{
			
			fExposureTime.Set_real64 (et, 100);
			
			fExposureTime.ReduceByFactor (10);
				
			for (uint32 f = 2; f <= 9; f++)
				{
				
				real64 z = 1.0 / (real64) f / et;
				
				if (z >= 0.99 && z <= 1.01)
					{
					
					fExposureTime = dng_urational (1, f);
					
					break;
					
					}
				
				}
					
			}
		
		// Now mirror this value to the ShutterSpeedValue field.
		
		et = fExposureTime.As_real64 ();
		
		fShutterSpeedValue.Set_real64 (-log (et) / log (2.0), 1000000);
												
		fShutterSpeedValue.ReduceByFactor (10);									
		fShutterSpeedValue.ReduceByFactor (10);									
		fShutterSpeedValue.ReduceByFactor (10);									
		fShutterSpeedValue.ReduceByFactor (10);									
		fShutterSpeedValue.ReduceByFactor (10);									
		fShutterSpeedValue.ReduceByFactor (10);									

		}
		
	}

/*****************************************************************************/

/**
 * Sets the shutter speed value (APEX) and calculates the corresponding exposure time.
 * 
 * This method sets the ShutterSpeedValue field based on the provided APEX value,
 * and also calculates and sets the corresponding ExposureTime field if it's not already set.
 * 
 * The conversion from APEX to seconds follows the formula:
 *   Exposure Time = 2^(-ShutterSpeedValue)
 * 
 * @param ss Shutter speed in APEX units (positive values = shorter exposures)
 */
void dng_exif::SetShutterSpeedValue (real64 ss)
	{
	
	if (fExposureTime.NotValid ())
		{
		
		real64 et = pow (2.0, -ss);
		
		SetExposureTime (et, true);
		
		}
	
	}

/******************************************************************************/

/**
 * Encodes an f-number as a rational value in the most appropriate format.
 * 
 * This utility function takes an f-number and converts it to a rational value
 * with appropriate precision based on its magnitude:
 * - Large f-numbers (>10): stored as integers (e.g., 16/1)
 * - Medium f-numbers (1-10): stored with precision to 0.1 (e.g., 56/10)
 * - Small f-numbers (<1): stored with precision to 0.01 (e.g., 95/100)
 * 
 * @param fs The f-number to encode
 * @return The encoded f-number as a rational value
 */
dng_urational dng_exif::EncodeFNumber (real64 fs)
	{
	
	dng_urational y;

	if (fs > 10.0)
		{
		
		y.Set_real64 (fs, 1);
		
		}
		
	else if (fs < 1.0)
		{
		
		y.Set_real64 (fs, 100);
		
		y.ReduceByFactor (10);
		y.ReduceByFactor (10);
		
		}
		
	else
		{
		
		y.Set_real64 (fs, 10);
		
		y.ReduceByFactor (10);
		
		}
		
	return y;
			
	}
		
/*****************************************************************************/

/**
 * Sets both the FNumber and ApertureValue fields based on f-number.
 * 
 * This method sets the FNumber field to the provided f-number and also
 * calculates and sets the corresponding ApertureValue field in APEX units.
 * 
 * Note that for f-numbers less than 1.0 (which would result in negative APEX values),
 * the ApertureValue field will not be set as the EXIF specification requires
 * ApertureValue to be a non-negative rational value.
 * 
 * @param fs The f-number to set (e.g., 2.8, 4.0, 5.6, etc.)
 */
void dng_exif::SetFNumber (real64 fs)
	{
	
	fFNumber.Clear ();
	
	fApertureValue.Clear ();

	// Allow f-number values less than 1.0 (e.g., f/0.95), even though they would
	// correspond to negative APEX values, which the EXIF specification does not
	// support (ApertureValue is a rational, not srational). The ApertureValue tag
	// will be omitted in the case where fs < 1.0.
	
	if (fs > 0.0 && fs <= 32768.0)
		{
	
		fFNumber = EncodeFNumber (fs);
		
		// Now mirror this value to the ApertureValue field.
		
		real64 av = FNumberToApertureValue (fFNumber);

		if (av >= 0.0 && av <= 99.99)
			{
			
			fApertureValue.Set_real64 (av, 1000000);
			
			fApertureValue.ReduceByFactor (10);									
			fApertureValue.ReduceByFactor (10);									
			fApertureValue.ReduceByFactor (10);									
			fApertureValue.ReduceByFactor (10);									
			fApertureValue.ReduceByFactor (10);									
			fApertureValue.ReduceByFactor (10);									
			
			}
		
		}
	
	}
			
/*****************************************************************************/

/**
 * Sets both the ApertureValue and FNumber fields based on aperture value.
 * 
 * This method sets the ApertureValue field to the provided value in APEX units,
 * and also calculates and sets the corresponding FNumber field if it's not already set.
 * 
 * @param av The aperture value in APEX units
 */
void dng_exif::SetApertureValue (real64 av)
	{

	if (fFNumber.NotValid ())
		{
		
		SetFNumber (ApertureValueToFNumber (av));
						
		}
		
	}

/*****************************************************************************/

/**
 * Converts an aperture value (APEX) to an f-number.
 * 
 * The conversion follows the formula: f-number = 2^(av/2)
 * 
 * For example:
 * - APEX 0.0 = f/1.0
 * - APEX 2.0 = f/2.0
 * - APEX 3.0 = f/2.8
 * - APEX 4.0 = f/4.0
 * - APEX 5.0 = f/5.6
 * 
 * @param av The aperture value in APEX units
 * @return The equivalent f-number
 */
real64 dng_exif::ApertureValueToFNumber (real64 av)
	{
	
	return pow (2.0, 0.5 * av);
	
	}

/*****************************************************************************/

/**
 * Converts an aperture value (APEX) stored as a rational to an f-number.
 * 
 * This is a convenience method that converts the rational to a double
 * and then calls the double version of the method.
 * 
 * @param av The aperture value as a rational
 * @return The equivalent f-number
 */
real64 dng_exif::ApertureValueToFNumber (const dng_urational &av)
	{
	
	return ApertureValueToFNumber (av.As_real64 ());
	
	}

/*****************************************************************************/

/**
 * Converts an f-number to an aperture value (APEX).
 * 
 * The conversion follows the formula: APEX = 2 * log2(f-number)
 * 
 * For example:
 * - f/1.0 = APEX 0.0
 * - f/2.0 = APEX 2.0
 * - f/2.8 = APEX 3.0
 * - f/4.0 = APEX 4.0
 * - f/5.6 = APEX 5.0
 * 
 * @param fNumber The f-number to convert
 * @return The equivalent aperture value in APEX units
 */
real64 dng_exif::FNumberToApertureValue (real64 fNumber)
	{
	
	return 2.0 * log (fNumber) / log (2.0);
	
	}

/*****************************************************************************/

/**
 * Converts an f-number stored as a rational to an aperture value (APEX).
 * 
 * This is a convenience method that converts the rational to a double
 * and then calls the double version of the method.
 * 
 * @param fNumber The f-number as a rational
 * @return The equivalent aperture value in APEX units
 */
real64 dng_exif::FNumberToApertureValue (const dng_urational &fNumber)
	{
	
	
	return FNumberToApertureValue (fNumber.As_real64 ());
	
	}
			
/*****************************************************************************/

/**
 * Updates the DateTime field with the provided date/time information.
 * 
 * Sets the main DateTime field in the EXIF data, which represents when
 * the file was last modified.
 * 
 * @param dt The date and time information to set
 */
void dng_exif::UpdateDateTime (const dng_date_time_info &dt)
	{
	
	fDateTime = dt;
	
	}

/*****************************************************************************/

/**
 * Checks if the EXIF version is at least 2.3.0.
 * 
 * This method verifies if the EXIF version supports features introduced in 
 * EXIF 2.3.0 specification, such as improved sensitivity tags.
 * 
 * @return true if the EXIF version is 2.3.0 or later
 */
bool dng_exif::AtLeastVersion0230 () const
	{
	
	return fExifVersion >= DNG_CHAR4 ('0','2','3','0');
	
	}

/*****************************************************************************/

/**
 * Checks if the EXIF version is at least 2.3.1.
 * 
 * This method verifies if the EXIF version supports features introduced in 
 * EXIF 2.3.1 specification, such as temperature and environmental data tags.
 * 
 * @return true if the EXIF version is 2.3.1 or later
 */
bool dng_exif::AtLeastVersion0231 () const
	{
	
	return fExifVersion >= DNG_CHAR4 ('0','2','3','1');
	
	}

/*****************************************************************************/

/**
 * Sets the EXIF version to 2.3.1.
 * 
 * Updates the EXIF version to indicate support for the EXIF 2.3.1
 * specification's features, such as temperature and environmental data tags.
 */
void dng_exif::SetVersion0231 ()
	{
	
	fExifVersion = DNG_CHAR4 ('0','2','3','1');
	
	}

/*****************************************************************************/

/**
 * Checks if lens distortion correction information is available.
 * 
 * Verifies that all four radial distortion parameters have valid values.
 * These parameters can be used for lens distortion correction.
 * 
 * @return true if all four lens distortion parameters are valid
 */
bool dng_exif::HasLensDistortInfo () const
	{
	
	return (fLensDistortInfo [0] . IsValid () &&
			fLensDistortInfo [1] . IsValid () &&
			fLensDistortInfo [2] . IsValid () &&
			fLensDistortInfo [3] . IsValid ());
	
	}

/*****************************************************************************/
		
/**
 * Sets the lens distortion correction parameters.
 * 
 * This method assigns the provided vector of lens distortion parameters to
 * the EXIF lens distortion fields. The parameters follow the same model as
 * the DNG 1.3 opcode model for radial distortion correction.
 * 
 * The vector must contain exactly 4 parameters, otherwise the method returns
 * without making any changes.
 * 
 * @param params Vector containing the 4 radial distortion correction parameters
 */
void dng_exif::SetLensDistortInfo (const dng_vector &params)
	{
	
	if (params.Count () != 4)
		{
		return;
		}

	fLensDistortInfo [0] . Set_real64 (params [0]);
	fLensDistortInfo [1] . Set_real64 (params [1]);
	fLensDistortInfo [2] . Set_real64 (params [2]);
	fLensDistortInfo [3] . Set_real64 (params [3]);
	
	}
		
/*****************************************************************************/

/**
 * Parses an EXIF tag from a data stream.
 * 
 * This method is the main entry point for parsing EXIF tags. It dispatches
 * the parsing to more specific methods based on the parent IFD code.
 * 
 * The parent code indicates which EXIF directory the tag belongs to:
 * - 0: Main IFD (IFD0)
 * - TAG_ExifIFD: EXIF subdirectory
 * - TAG_GPS_IFD: GPS subdirectory
 * - TAG_Interoperability_IFD: Interoperability subdirectory
 * 
 * @param stream The data stream to read from
 * @param shared Shared DNG data structure to store common data
 * @param parentCode Parent IFD code indicating which directory the tag belongs to
 * @param isMainIFD Flag indicating if this is the main IFD
 * @param tagCode The tag code to parse
 * @param tagType The data type of the tag
 * @param tagCount Number of values in the tag
 * @param tagOffset Offset to the tag data in the stream
 * @return true if the tag was successfully parsed, false otherwise
 */
bool dng_exif::ParseTag (dng_stream &stream,
						 dng_shared &shared,
						 uint32 parentCode,
						 bool isMainIFD,
						 uint32 tagCode,
						 uint32 tagType,
						 uint32 tagCount,
						 uint64 tagOffset)
	{
	
	if (parentCode == 0)
		{
		
		if (Parse_ifd0 (stream,
						shared,
						parentCode,
						tagCode,
						tagType,
						tagCount,
						tagOffset))
			{
			
			return true;
			
			}

		}
		
	if (parentCode == 0 || isMainIFD)
		{
		
		if (Parse_ifd0_main (stream,
							 shared,
							 parentCode,
							 tagCode,
							 tagType,
							 tagCount,
							 tagOffset))
			{
			
			return true;
			
			}

		}
		
	if (parentCode == 0 ||
		parentCode == tcExifIFD)
		{
		
		if (Parse_ifd0_exif (stream,
							 shared,
							 parentCode,
							 tagCode,
							 tagType,
							 tagCount,
							 tagOffset))
			{
			
			return true;
			
			}

		}
		
	if (parentCode == tcGPSInfo)
		{
		
		if (Parse_gps (stream,
					   shared,
					   parentCode,
					   tagCode,
					   tagType,
					   tagCount,
					   tagOffset))
			{
			
			return true;
			
			}

		}
		
	if (parentCode == tcInteroperabilityIFD)
		{
		
		if (Parse_interoperability (stream,
									shared,
									parentCode,
									tagCode,
									tagType,
									tagCount,
									tagOffset))
			{
			
			return true;
			
			}

		}
		
	return false;
		
	}

/*****************************************************************************/

/**
 * Parses tags that should only appear in IFD 0 or the main image IFD.
 * 
 * This method handles parsing of common tags that can appear in either
 * IFD0 (the main image IFD) or in the main IFD of a TIFF file. These include
 * tags such as Make, Model, Software, and other basic image information.
 * 
 * @param stream The data stream to read from
 * @param shared Shared DNG data structure (unused in this method)
 * @param parentCode Parent IFD code
 * @param tagCode The tag code to parse
 * @param tagType The data type of the tag
 * @param tagCount Number of values in the tag
 * @param tagOffset Offset to the tag data in the stream (unused in this method)
 * @return true if the tag was successfully parsed, false otherwise
 */
bool dng_exif::Parse_ifd0_main (dng_stream &stream,
								dng_shared & /* shared */,
								uint32 parentCode,
								uint32 tagCode,
								uint32 tagType,
								uint32 tagCount,
								uint64 /* tagOffset */)
	{
	
	switch (tagCode)
		{
			
		case tcImageDescription:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fImageDescription);
							
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("ImageDescription: ");
				
				DumpString (fImageDescription);
				
				printf ("\n");
				
				}
				
			#endif
				
			break;
			
			}
			
		case tcMake:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fMake);
				
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Make: ");
				
				DumpString (fMake);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
				
		case tcModel:
			{

			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fModel);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Model: ");
				
				DumpString (fModel);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
				
		case tcSoftware:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fSoftware);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Software: ");
				
				DumpString (fSoftware);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}

		case tcDateTime:
			{
			
			uint64 tagPosition = stream.PositionInOriginalFile ();
			
			dng_date_time dt;
				
			if (!ParseDateTimeTag (stream,
								   parentCode,
								   tagCode,
								   tagType,
								   tagCount,
								   dt))
				{
				return false;
				}
				
			fDateTime.SetDateTime (dt);
				
			fDateTimeStorageInfo = dng_date_time_storage_info (tagPosition,
															   dng_date_time_format_exif);
				
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("DateTime: ");
				
				DumpDateTime (fDateTime.DateTime ());
				
				printf ("\n");
				
				}
				
			#endif

			break;
			
			}

		case tcArtist:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fArtist);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Artist: ");
				
				DumpString (fArtist);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}

		case tcCopyright:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseDualStringTag (stream,
								parentCode,
								tagCode,
								tagCount,
								fCopyright,
								fCopyright2);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Copyright: ");
				
				DumpString (fCopyright);
				
				if (fCopyright2.Get () [0] != 0)
					{
					
					printf (" ");
					
					DumpString (fCopyright2);
					
					}
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}

		case tcTIFF_EP_StandardID:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttByte);
			
			CheckTagCount (parentCode, tagCode, tagCount, 4);
			
			uint32 b0 = stream.Get_uint8 ();
			uint32 b1 = stream.Get_uint8 ();
			uint32 b2 = stream.Get_uint8 ();
			uint32 b3 = stream.Get_uint8 ();
			
			fTIFF_EP_StandardID = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				printf ("TIFF/EPStandardID: %u.%u.%u.%u\n",
						(unsigned) b0,
						(unsigned) b1, 
						(unsigned) b2,
						(unsigned) b3);
				}
				
			#endif
			
			break;
			
			}
				
		case tcCameraSerialNumber:
		case tcKodakCameraSerialNumber:		// Kodak uses a very similar tag.
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fCameraSerialNumber);
				
			#if qDNGValidate

			if (gVerbose)
				{
				
				printf ("%s: ", LookupTagCode (parentCode, tagCode));
				
				DumpString (fCameraSerialNumber);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
			
		case tcLensInfo:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttRational);
			
			if (!CheckTagCount (parentCode, tagCode, tagCount, 4))
				return false;
				
			fLensInfo [0] = stream.TagValue_urational (tagType);
			fLensInfo [1] = stream.TagValue_urational (tagType);
			fLensInfo [2] = stream.TagValue_urational (tagType);
			fLensInfo [3] = stream.TagValue_urational (tagType);
			
			// Some third party software wrote zero rather and undefined values
			// for unknown entries.	 Work around this bug.
			
			for (uint32 j = 0; j < 4; j++)
				{
			
				if (fLensInfo [j].IsValid () && fLensInfo [j].As_real64 () <= 0.0)
					{
					
					fLensInfo [j] = dng_urational (0, 0);
					
					#if qDNGValidate
					
					ReportWarning ("Zero entry in LensInfo tag--should be undefined");
					
					#endif

					}
					
				}
				
			#if qDNGValidate

			if (gVerbose)
				{
				
				printf ("LensInfo: ");
				
				real64 minFL = fLensInfo [0].As_real64 ();
				real64 maxFL = fLensInfo [1].As_real64 ();
				
				if (minFL == maxFL)
					printf ("%0.1f mm", minFL);
				else
					printf ("%0.1f-%0.1f mm", minFL, maxFL);
					
				if (fLensInfo [2].d)
					{
					
					real64 minFS = fLensInfo [2].As_real64 ();
					real64 maxFS = fLensInfo [3].As_real64 ();
					
					if (minFS == maxFS)
						printf (" f/%0.1f", minFS);
					else
						printf (" f/%0.1f-%0.1f", minFS, maxFS);
					
					}
					
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
				
		default:
			{
			
			return false;
			
			}
			
		}
	
	return true;
	
	}
	
/*****************************************************************************/

/**
 * Parses tags in the EXIF IFD.
 * 
 * This method handles parsing of tags in the EXIF IFD (Image File Directory),
 * which contains detailed technical information about the image, such as
 * exposure settings, camera lens details, and other metadata specific to
 * digital photography.
 * 
 * @param stream The data stream to read from
 * @param shared Shared DNG data structure (unused in this method)
 * @param parentCode Parent IFD code
 * @param tagCode The tag code to parse
 * @param tagType The data type of the tag
 * @param tagCount Number of values in the tag
 * @param tagOffset Offset to the tag data in the stream
 * @return true if the tag was successfully parsed, false otherwise
 */
bool dng_exif::Parse_ifd0_exif (dng_stream &stream,
								dng_shared & /* shared */,
								uint32 parentCode,
								uint32 tagCode,
								uint32 tagType,
								uint32 tagCount,
								uint64 /* tagOffset */)
	{
	
	switch (tagCode)
		{
			
		case tcMake:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fMake);
				
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Make: ");
				
				DumpString (fMake);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
				
		case tcModel:
			{

			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fModel);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Model: ");
				
				DumpString (fModel);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
				
		case tcSoftware:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fSoftware);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Software: ");
				
				DumpString (fSoftware);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}

		case tcDateTime:
			{
			
			uint64 tagPosition = stream.PositionInOriginalFile ();
			
			dng_date_time dt;
				
			if (!ParseDateTimeTag (stream,
								   parentCode,
								   tagCode,
								   tagType,
								   tagCount,
								   dt))
				{
				return false;
				}
				
			fDateTime.SetDateTime (dt);
				
			fDateTimeStorageInfo = dng_date_time_storage_info (tagPosition,
															   dng_date_time_format_exif);
				
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("DateTime: ");
				
				DumpDateTime (fDateTime.DateTime ());
				
				printf ("\n");
				
				}
				
			#endif

			break;
			
			}

		case tcArtist:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fArtist);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Artist: ");
				
				DumpString (fArtist);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}

		case tcCopyright:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseDualStringTag (stream,
								parentCode,
								tagCode,
								tagCount,
								fCopyright,
								fCopyright2);
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				
				printf ("Copyright: ");
				
				DumpString (fCopyright);
				
				if (fCopyright2.Get () [0] != 0)
					{
					
					printf (" ");
					
					DumpString (fCopyright2);
					
					}
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}

		case tcTIFF_EP_StandardID:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttByte);
			
			CheckTagCount (parentCode, tagCode, tagCount, 4);
			
			uint32 b0 = stream.Get_uint8 ();
			uint32 b1 = stream.Get_uint8 ();
			uint32 b2 = stream.Get_uint8 ();
			uint32 b3 = stream.Get_uint8 ();
			
			fTIFF_EP_StandardID = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
			
			#if qDNGValidate
			
			if (gVerbose)
				{
				printf ("TIFF/EPStandardID: %u.%u.%u.%u\n",
						(unsigned) b0,
						(unsigned) b1, 
						(unsigned) b2,
						(unsigned) b3);
				}
				
			#endif
			
			break;
			
			}
				
		case tcCameraSerialNumber:
		case tcKodakCameraSerialNumber:		// Kodak uses a very similar tag.
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttAscii);
			
			ParseStringTag (stream,
							parentCode,
							tagCode,
							tagCount,
							fCameraSerialNumber);
				
			#if qDNGValidate

			if (gVerbose)
				{
				
				printf ("%s: ", LookupTagCode (parentCode, tagCode));
				
				DumpString (fCameraSerialNumber);
				
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
			
		case tcLensInfo:
			{
			
			CheckTagType (parentCode, tagCode, tagType, ttRational);
			
			if (!CheckTagCount (parentCode, tagCode, tagCount, 4))
				return false;
				
			fLensInfo [0] = stream.TagValue_urational (tagType);
			fLensInfo [1] = stream.TagValue_urational (tagType);
			fLensInfo [2] = stream.TagValue_urational (tagType);
			fLensInfo [3] = stream.TagValue_urational (tagType);
			
			// Some third party software wrote zero rather and undefined values
			// for unknown entries.	 Work around this bug.
			
			for (uint32 j = 0; j < 4; j++)
				{
			
				if (fLensInfo [j].IsValid () && fLensInfo [j].As_real64 () <= 0.0)
					{
					
					fLensInfo [j] = dng_urational (0, 0);
					
					#if qDNGValidate
					
					ReportWarning ("Zero entry in LensInfo tag--should be undefined");
					
					#endif

					}
					
				}
				
			#if qDNGValidate

			if (gVerbose)
				{
				
				printf ("LensInfo: ");
				
				real64 minFL = fLensInfo [0].As_real64 ();
				real64 maxFL = fLensInfo [1].As_real64 ();
				
				if (minFL == maxFL)
					printf ("%0.1f mm", minFL);
				else
					printf ("%0.1f-%0.1f mm", minFL, maxFL);
					
				if (fLensInfo [2].d)
					{
					
					real64 minFS = fLensInfo [2].As_real64 ();
					real64 maxFS = fLensInfo [3].As_real64 ();
					
					if (minFS == maxFS)
						printf (" f/%0.1f", minFS);
					else
						printf (" f/%0.1f-%0.1f", minFS, maxFS);
					
					}
					
				printf ("\n");
				
				}
				
			#endif
			
			break;
			
			}
				
		default:
			{
			
			return false;
			
			}
			
		}
	
	return true;
	
	}
	
/*****************************************************************************/
