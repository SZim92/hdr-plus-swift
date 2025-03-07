/*****************************************************************************/
// Copyright 2006-2019 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

/** \file
 * EXIF read access support. See the \ref spec_exif "EXIF specification" for full
 * description of tags.
 * 
 * This file defines structures and methods for handling EXIF (Exchangeable Image File Format)
 * metadata in the DNG SDK. EXIF is a standard format for storing metadata in digital
 * photography image files, such as camera settings, date/time information, GPS coordinates,
 * and other technical image details.
 * 
 * The dng_exif class serves as a container for all supported EXIF tags and provides
 * methods for parsing, manipulating, and accessing EXIF data. It supports various EXIF
 * versions including 2.3 and 2.3.1 standards.
 * 
 * Key features include:
 * - Storage for all standard EXIF tags
 * - Utilities for common conversions (e.g., between f-number and aperture value)
 * - GPS metadata handling
 * - Lens-specific information
 * - Support for extended EXIF properties introduced in newer standards
 */

/*****************************************************************************/

#ifndef __dng_exif__
#define __dng_exif__

/*****************************************************************************/

#include "dng_classes.h"
#include "dng_date_time.h"
#include "dng_fingerprint.h"
#include "dng_types.h"
#include "dng_matrix.h"
#include "dng_rational.h"
#include "dng_string.h"
#include "dng_stream.h"
#include "dng_sdk_limits.h"

/*****************************************************************************/

/// \brief Container class for parsing and holding EXIF tags.
///
/// Public member fields are documented in \ref spec_exif "EXIF specification."
///
/// This class encapsulates all EXIF metadata from an image file, providing
/// structured access to standard EXIF tags. It includes fields for camera
/// information, exposure settings, GPS data, timestamps, and other technical
/// metadata typically found in digital images.
///
/// The class supports parsing EXIF data from various file formats and provides
/// utility methods for common operations like exposure time and aperture conversions.
/// It handles the complexity of different EXIF versions and tag interpretations.

class dng_exif
	{
	
	public:
	
		/// Description of the image content
		dng_string fImageDescription;
		
		/// Camera manufacturer name
		dng_string fMake;
		
		/// Camera model name
		dng_string fModel;
		
		/// Software or firmware used to create the image
		dng_string fSoftware;
		
		/// Name of the photographer or image creator
		dng_string fArtist;
		
		/// Primary copyright notice
		dng_string fCopyright;
		
		/// Secondary copyright notice (some formats use two fields)
		dng_string fCopyright2;
		
		/// User-provided comment about the image
		dng_string fUserComment;
		
		/// Date and time when the image file was created or last modified
		dng_date_time_info		   fDateTime;
		/// Storage format information for the DateTime field
		dng_date_time_storage_info fDateTimeStorageInfo;
		
		/// Original date and time when the image was captured
		dng_date_time_info		   fDateTimeOriginal;
		/// Storage format information for the DateTimeOriginal field
		dng_date_time_storage_info fDateTimeOriginalStorageInfo;

		/// Date and time when the image was stored as digital data
		dng_date_time_info		   fDateTimeDigitized;
		/// Storage format information for the DateTimeDigitized field
		dng_date_time_storage_info fDateTimeDigitizedStorageInfo;
		
		/// TIFF/EP standard identifier
		uint32 fTIFF_EP_StandardID;
		/// EXIF version number (encoded as hex value, e.g., 0x0230 for EXIF 2.3)
		uint32 fExifVersion;
		/// FlashPix version supported by the file
		uint32 fFlashPixVersion;
		
		/// Exposure time in seconds, stored as a rational value (e.g., 1/60, 1/125)
		dng_urational fExposureTime;
		/// F-number (aperture value) as a rational value (e.g., 5.6, 8.0)
		dng_urational fFNumber;
		/// Shutter speed in APEX units (additive logarithmic scale)
		dng_srational fShutterSpeedValue;
		/// Aperture value in APEX units (additive logarithmic scale)
		dng_urational fApertureValue;
		/// Brightness value in APEX units - indicates amount of light in the scene
		dng_srational fBrightnessValue;
		/// Exposure compensation in APEX units
		dng_srational fExposureBiasValue;
		/// Maximum aperture value of the lens in APEX units
		dng_urational fMaxApertureValue;
		/// Actual focal length of the lens in millimeters
		dng_urational fFocalLength;
		/// Digital zoom ratio when the image was captured
		dng_urational fDigitalZoomRatio;
		/// Exposure index setting (typically ISO) recommended by the camera
		dng_urational fExposureIndex;
		/// Distance to the subject in meters
		dng_urational fSubjectDistance;
		/// Gamma value (typically used for Flash images)
		dng_urational fGamma;
		
		/// Battery level as a rational value (e.g., 0.5 for half charged)
		dng_urational fBatteryLevelR;
		/// Battery level as a string (for non-numeric representations)
		dng_string	  fBatteryLevelA;
		
		/// Exposure program mode used (0=Undefined, 1=Manual, 2=Normal, etc.)
		uint32 fExposureProgram;
		/// Metering mode used (0=Unknown, 1=Average, 2=CenterWeighted, etc.)
		uint32 fMeteringMode;
		/// Light source type (0=Unknown, 1=Daylight, 2=Fluorescent, etc.)
		uint32 fLightSource;
		/// Flash status and settings (bit field with flash fired, return, mode, etc.)
		uint32 fFlash;
		/// Additional flash settings mask
		uint32 fFlashMask;
		/// Type of sensor used (1=Not defined, 2=One-chip color, etc.)
		uint32 fSensingMethod;
		/// Color space information (1=sRGB, 2=Adobe RGB, etc.)
		uint32 fColorSpace;
		/// Source of the file (3=Digital Camera)
		uint32 fFileSource;
		/// Type of scene (1=Directly photographed image)
		uint32 fSceneType;
		/// Special processing applied to the image (0=Normal, 1=Custom)
		uint32 fCustomRendered;
		/// Exposure mode (0=Auto, 1=Manual, 2=Auto bracket)
		uint32 fExposureMode;
		/// White balance setting (0=Auto, 1=Manual)
		uint32 fWhiteBalance;
		/// Scene capture type (0=Standard, 1=Landscape, 2=Portrait, etc.)
		uint32 fSceneCaptureType;
		/// Gain control setting (0=None, 1=Low gain up, etc.)
		uint32 fGainControl;
		/// Contrast setting (0=Normal, 1=Soft, 2=Hard)
		uint32 fContrast;
		/// Saturation setting (0=Normal, 1=Low, 2=High)
		uint32 fSaturation;
		/// Sharpness setting (0=Normal, 1=Soft, 2=Hard)
		uint32 fSharpness;
		/// Subject distance range (0=Unknown, 1=Macro, 2=Close, 3=Distant)
		uint32 fSubjectDistanceRange;
		/// Self-timer mode status (seconds until exposure)
		uint32 fSelfTimerMode;
		/// Image number in a sequence
		uint32 fImageNumber;

		/// Equivalent focal length assuming a 35mm film camera, in mm
		uint32 fFocalLengthIn35mmFilm;
		
		/// ISO speed ratings array (up to 3 values)
		/// Also known as PhotographicSensitivity in EXIF 2.3
		uint32 fISOSpeedRatings [3];		 // EXIF 2.3: PhotographicSensitivity.

		// Sensitivity tags added in EXIF 2.3.

		/// Method used to determine the sensitivity (0=Unknown, 1=Standard Output, etc.)
		uint32 fSensitivityType;
		/// Standard Output Sensitivity value as defined by ISO 12232
		uint32 fStandardOutputSensitivity;
		/// Recommended Exposure Index value as defined by ISO 12232
		uint32 fRecommendedExposureIndex;
		/// ISO speed value as defined by ISO 12232
		uint32 fISOSpeed;
		/// ISO speed latitude yyy value as defined by ISO 12232
		uint32 fISOSpeedLatitudeyyy;
		/// ISO speed latitude zzz value as defined by ISO 12232
		uint32 fISOSpeedLatitudezzz;
		
		/// Number of valid elements in the subject area array
		uint32 fSubjectAreaCount;
		/// Subject area coordinates (interpretation depends on count: 
		/// 2=rectangle center, 3=circle, 4=rectangle)
		uint32 fSubjectArea [4];
		
		/// Configuration of components in the image data (reserved, unused in DNG)
		uint32 fComponentsConfiguration;
		
		/// Compression mode in bits per pixel
		dng_urational fCompresssedBitsPerPixel;
		
		/// Width of the main image in pixels
		uint32 fPixelXDimension;
		/// Height of the main image in pixels
		uint32 fPixelYDimension;
		
		/// Focal plane X resolution in units per fFocalPlaneResolutionUnit
		dng_urational fFocalPlaneXResolution;
		/// Focal plane Y resolution in units per fFocalPlaneResolutionUnit
		dng_urational fFocalPlaneYResolution;
		
		/// Units for focal plane resolution (2=inches, 3=cm, 4=mm)
		uint32 fFocalPlaneResolutionUnit;
		
		/// Number of rows in the Color Filter Array (CFA) repeating pattern
		uint32 fCFARepeatPatternRows;
		/// Number of columns in the Color Filter Array (CFA) repeating pattern
		uint32 fCFARepeatPatternCols;
		
		/// Color Filter Array pattern values, indexed by [row][column]
		uint8 fCFAPattern [kMaxCFAPattern] [kMaxCFAPattern];
		
		/// Unique identifier for the image
		dng_fingerprint fImageUniqueID;
		
		/// GPS specification version (typically 2.2.0.0)
		uint32		  fGPSVersionID;
		/// Indicates whether latitude is north or south ('N' or 'S')
		dng_string	  fGPSLatitudeRef;
		/// Latitude values in degrees, minutes, and seconds [degrees, minutes, seconds]
		dng_urational fGPSLatitude [3];
		/// Indicates whether longitude is east or west ('E' or 'W')
		dng_string	  fGPSLongitudeRef;
		/// Longitude values in degrees, minutes, and seconds [degrees, minutes, seconds]
		dng_urational fGPSLongitude [3];
		/// Altitude reference (0=above sea level, 1=below sea level)
		uint32		  fGPSAltitudeRef;
		/// Altitude in meters relative to sea level
		dng_urational fGPSAltitude;
		/// UTC time as hours, minutes, seconds [hours, minutes, seconds]
		dng_urational fGPSTimeStamp [3];
		/// Satellites used for GPS measurement
		dng_string	  fGPSSatellites;
		/// Status of GPS receiver ('A'=measurement active, 'V'=measurement void)
		dng_string	  fGPSStatus;
		/// GPS measurement mode ('2'=2D, '3'=3D)
		dng_string	  fGPSMeasureMode;
		/// Degree of precision for GPS data (Dilution of Precision)
		dng_urational fGPSDOP;
		/// Unit of speed measurement ('K'=km/h, 'M'=mph, 'N'=knots)
		dng_string	  fGPSSpeedRef;
		/// Speed of GPS receiver
		dng_urational fGPSSpeed;
		/// Reference for direction of movement ('T'=true, 'M'=magnetic)
		dng_string	  fGPSTrackRef;
		/// Direction of movement in degrees (0-359.99)
		dng_urational fGPSTrack;
		/// Reference for direction of image ('T'=true, 'M'=magnetic)
		dng_string	  fGPSImgDirectionRef;
		/// Direction of image when captured in degrees (0-359.99)
		dng_urational fGPSImgDirection;
		/// Geodetic survey data used by GPS receiver
		dng_string	  fGPSMapDatum;
		/// Indicates whether destination latitude is north or south ('N' or 'S')
		dng_string	  fGPSDestLatitudeRef;
		/// Destination latitude in degrees, minutes, seconds [degrees, minutes, seconds]
		dng_urational fGPSDestLatitude [3];
		/// Indicates whether destination longitude is east or west ('E' or 'W')
		dng_string	  fGPSDestLongitudeRef;
		/// Destination longitude in degrees, minutes, seconds [degrees, minutes, seconds]
		dng_urational fGPSDestLongitude [3];
		/// Reference for bearing to destination ('T'=true, 'M'=magnetic)
		dng_string	  fGPSDestBearingRef;
		/// Bearing to destination in degrees (0-359.99)
		dng_urational fGPSDestBearing;
		/// Unit of distance for destination ('K'=km, 'M'=miles, 'N'=nautical miles)
		dng_string	  fGPSDestDistanceRef;
		/// Distance to destination
		dng_urational fGPSDestDistance;
		/// Method used for location finding
		dng_string	  fGPSProcessingMethod;
		/// Name of GPS area
		dng_string	  fGPSAreaInformation;
		/// Date stamp for GPS data (format: "YYYY:MM:DD")
		dng_string	  fGPSDateStamp;
		/// Differential correction applied to GPS receiver (0=no correction, 1=correction applied)
		uint32		  fGPSDifferential;
		/// Horizontal positioning error in meters
		dng_urational fGPSHPositioningError;
		
		/// Interoperability identification (e.g., "R98" for EXIF R98, "THM" for DCF thumbnail)
		dng_string fInteroperabilityIndex;
		
		/// Interoperability version number
		uint32 fInteroperabilityVersion;
		
		/// File format of related image file
		dng_string fRelatedImageFileFormat;
		
		/// Width of related image file
		uint32 fRelatedImageWidth;	
		/// Height of related image file
		uint32 fRelatedImageLength;

		/// Camera body serial number (called BodySerialNumber in EXIF 2.3)
		dng_string fCameraSerialNumber;		 // EXIF 2.3: BodySerialNumber.
		
		/// Lens specification information [minimum focal length, maximum focal length,
		/// minimum f-number at minimum focal length, minimum f-number at maximum focal length]
		dng_urational fLensInfo [4];		 // EXIF 2.3: LensSpecification.
		
		/// Lens identifier string
		dng_string fLensID;
		/// Lens manufacturer name
		dng_string fLensMake;
		/// Lens model name (called LensModel in EXIF 2.3)
		dng_string fLensName;				 // EXIF 2.3: LensModel.
		/// Lens serial number
		dng_string fLensSerialNumber;
		
		/// Flag indicating whether the lens name was read from an EXIF LensModel tag
		bool fLensNameWasReadFromExif;

		// Private field to hold the approximate focus distance of the lens, in
		// meters. This value is often coarsely measured/reported and hence should be
		// interpreted only as a rough estimate of the true distance from the plane
		// of focus (in object space) to the focal plane. It is still useful for the
		// purposes of applying lens corrections.

		dng_urational fApproxFocusDistance;
	
		/// Flash compensation value in APEX units
		dng_srational fFlashCompensation;
		
		/// Camera owner name (called CameraOwnerName in EXIF 2.3)
		dng_string fOwnerName;				 // EXIF 2.3: CameraOwnerName.
		/// Camera firmware version
		dng_string fFirmware;
  
		// EXIF 2.3.1:
		
		/// Ambient temperature in degrees Celsius when the image was captured
		dng_srational fTemperature;
		/// Humidity percentage when the image was captured
		dng_urational fHumidity;
		/// Atmospheric pressure in hPa when the image was captured
		dng_urational fPressure;
		/// Water depth in meters when the image was captured (underwater photography)
		dng_srational fWaterDepth;
		/// Acceleration when the image was captured
		dng_urational fAcceleration;
		/// Camera elevation angle in degrees when the image was captured
		dng_srational fCameraElevationAngle;
		
		/// Image title or caption (not part of standard EXIF, but used by some formats)
		dng_string fTitle;

		// Image-specific radial distortion correction metadata that can be
		// used later during (UI-driven) lens profile corrections. Same model
		// as DNG 1.3 opcode model.

		dng_srational fLensDistortInfo [4];

		// Some cameras have a built-in neutral density filter. If the ND
		// filter is applied, it reduces the incoming light by a linear factor
		// K. This field stores the value of K. For example, if the camera has
		// applied a 3-stop neutral density filter, this reduces the incoming
		// light by a linear factor of 8, so this field should store 8/1.
		//
		// The default value is invalid (0/0) which means ND is not present or
		// unknown.

		dng_urational fNeutralDensityFactor;
		
	public:
	
		/// Default constructor, initializes to empty state
		dng_exif ();
		
		/// Virtual destructor
		virtual ~dng_exif ();

		/// Creates a deep copy of this EXIF object
		/// @return A pointer to a newly allocated copy of this object
		virtual dng_exif * Clone () const;

		/// Resets all EXIF fields to their default/empty values
		void SetEmpty ();

		/// Copies all GPS-related fields from another EXIF object
		/// @param exif Source object from which to copy GPS fields
		void CopyGPSFrom (const dng_exif &exif);

		/// Utility to fix up common errors and rounding issues with EXIF exposure times
		/// @param et Exposure time in seconds
		/// @return Corrected exposure time value
		static real64 SnapExposureTime (real64 et);

		/// Sets exposure time and shutter speed fields
		/// @param et Exposure time in seconds
		/// @param snap Whether to apply correction for common errors/rounding issues
		void SetExposureTime (real64 et,
							  bool snap = true);

		/// Sets shutter speed value (APEX units) and corresponding exposure time
		/// @param ss Shutter speed in APEX units
		void SetShutterSpeedValue (real64 ss);

		/// Utility to encode f-number as a rational value
		/// @param fs The f-number to encode
		/// @return Encoded rational representation of the f-number
		static dng_urational EncodeFNumber (real64 fs);

		/// Sets both FNumber and ApertureValue fields based on f-number
		/// @param fs The f-number to set
		void SetFNumber (real64 fs);
		
		/// Sets both FNumber and ApertureValue fields based on aperture value
		/// @param av The aperture value in APEX units
		void SetApertureValue (real64 av);

		/// Converts aperture value (APEX units) to f-number
		/// @param av The aperture value to convert
		/// @return Equivalent f-number
		static real64 ApertureValueToFNumber (real64 av);

		/// Converts aperture value (APEX units) to f-number
		/// @param av The aperture value to convert as a rational
		/// @return Equivalent f-number
		static real64 ApertureValueToFNumber (const dng_urational &av);

		/// Converts f-number to aperture value (APEX units)
		/// @param fNumber The f-number to convert
		/// @return Equivalent aperture value in APEX units
		static real64 FNumberToApertureValue (real64 fNumber);

		/// Converts f-number to aperture value (APEX units)
		/// @param fNumber The f-number to convert as a rational
		/// @return Equivalent aperture value in APEX units
		static real64 FNumberToApertureValue (const dng_urational &fNumber);

		/// Updates the DateTime field with new date/time information
		/// @param dt The new date/time information to set
		void UpdateDateTime (const dng_date_time_info &dt);

		/// Checks if the EXIF version is at least 2.3.0
		/// @return true if EXIF version is 2.3.0 or later
		bool AtLeastVersion0230 () const;
  
		/// Checks if the EXIF version is at least 2.3.1
		/// @return true if EXIF version is 2.3.1 or later
		bool AtLeastVersion0231 () const;
		
		/// Sets the EXIF version to 2.3.1
		void SetVersion0231 ();

		/// Checks if lens distortion information is available
		/// @return true if lens distortion parameters are set
		bool HasLensDistortInfo () const;
		
		/// Sets the lens distortion correction parameters
		/// @param params Vector containing the distortion parameters
		void SetLensDistortInfo (const dng_vector &params);
		
		/// Parses an EXIF tag from a data stream
		/// @param stream The data stream to read from
		/// @param shared Shared DNG data structure
		/// @param parentCode Parent IFD code
		/// @param isMainIFD Whether this is the main IFD
		/// @param tagCode The tag code to parse
		/// @param tagType The data type of the tag
		/// @param tagCount Number of values in the tag
		/// @param tagOffset Offset to the tag data in the stream
		/// @return true if the tag was successfully parsed
		virtual bool ParseTag (dng_stream &stream,
							   dng_shared &shared,
							   uint32 parentCode,
							   bool isMainIFD,
							   uint32 tagCode,
							   uint32 tagType,
							   uint32 tagCount,
							   uint64 tagOffset);
							   
		/// Performs post-parsing operations after all tags have been read
		/// @param host DNG host interface
		/// @param shared Shared DNG data structure
		virtual void PostParse (dng_host &host,
								dng_shared &shared);
								
	protected:
		
		/// Parses a tag in the main IFD (IFD0)
		/// @param stream The data stream to read from
		/// @param shared Shared DNG data structure
		/// @param parentCode Parent IFD code
		/// @param tagCode The tag code to parse
		/// @param tagType The data type of the tag
		/// @param tagCount Number of values in the tag
		/// @param tagOffset Offset to the tag data in the stream
		/// @return true if the tag was successfully parsed
		virtual bool Parse_ifd0 (dng_stream &stream,
								 dng_shared &shared,
								 uint32 parentCode,
								 uint32 tagCode,
								 uint32 tagType,
								 uint32 tagCount,
								 uint64 tagOffset);
									 
		/// Parses a main tag in IFD0
		/// @param stream The data stream to read from
		/// @param shared Shared DNG data structure
		/// @param parentCode Parent IFD code
		/// @param tagCode The tag code to parse
		/// @param tagType The data type of the tag
		/// @param tagCount Number of values in the tag
		/// @param tagOffset Offset to the tag data in the stream
		/// @return true if the tag was successfully parsed
		virtual bool Parse_ifd0_main (dng_stream &stream,
									  dng_shared &shared,
									  uint32 parentCode,
									  uint32 tagCode,
									  uint32 tagType,
									  uint32 tagCount,
									  uint64 tagOffset);

		/// Parses an EXIF tag in IFD0
		/// @param stream The data stream to read from
		/// @param shared Shared DNG data structure
		/// @param parentCode Parent IFD code
		/// @param tagCode The tag code to parse
		/// @param tagType The data type of the tag
		/// @param tagCount Number of values in the tag
		/// @param tagOffset Offset to the tag data in the stream
		/// @return true if the tag was successfully parsed
		virtual bool Parse_ifd0_exif (dng_stream &stream,
									  dng_shared &shared,
									  uint32 parentCode,
									  uint32 tagCode,
									  uint32 tagType,
									  uint32 tagCount,
									  uint64 tagOffset);
	
		/// Parses a GPS tag
		/// @param stream The data stream to read from
		/// @param shared Shared DNG data structure
		/// @param parentCode Parent IFD code
		/// @param tagCode The tag code to parse
		/// @param tagType The data type of the tag
		/// @param tagCount Number of values in the tag
		/// @param tagOffset Offset to the tag data in the stream
		/// @return true if the tag was successfully parsed
		virtual bool Parse_gps (dng_stream &stream,
								dng_shared &shared,
								uint32 parentCode,
								uint32 tagCode,
								uint32 tagType,
								uint32 tagCount,
								uint64 tagOffset);
	
		/// Parses an interoperability tag
		/// @param stream The data stream to read from
		/// @param shared Shared DNG data structure
		/// @param parentCode Parent IFD code
		/// @param tagCode The tag code to parse
		/// @param tagType The data type of the tag
		/// @param tagCount Number of values in the tag
		/// @param tagOffset Offset to the tag data in the stream
		/// @return true if the tag was successfully parsed
		virtual bool Parse_interoperability (dng_stream &stream,
											 dng_shared &shared,
											 uint32 parentCode,
											 uint32 tagCode,
											 uint32 tagType,
											 uint32 tagCount,
											 uint64 tagOffset);
	
	};
	
/*****************************************************************************/

#endif
	
/*****************************************************************************/
