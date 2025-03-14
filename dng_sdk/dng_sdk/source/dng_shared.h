/*****************************************************************************/
// Copyright 2006-2023 Adobe Systems Incorporated
// All Rights Reserved.
//
// NOTICE:	Adobe permits you to use, modify, and distribute this file in
// accordance with the terms of the Adobe license agreement accompanying it.
/*****************************************************************************/

#ifndef __dng_shared__
#define __dng_shared__

/*****************************************************************************/

#include "dng_classes.h"
#include "dng_fingerprint.h"
#include "dng_matrix.h"
#include "dng_memory.h"
#include "dng_negative.h"
#include "dng_rational.h"
#include "dng_string.h"
#include "dng_stream.h"
#include "dng_sdk_limits.h"
#include "dng_types.h"
#include "dng_utils.h"
#include "dng_xy_coord.h"

#include <map>
#include <vector>

/*****************************************************************************/

class dng_camera_profile_dynamic_range
	{

	public:

		uint16 fVersion = 1;

		// 0 = Standard Dynamic Range.
		// 1 = High Dynamic Range.

		uint16 fDynamicRange = 0;

		// Hint for intended maximum output pixel value (linear gamma).

		real32 fHintMaxOutputValue = 0.0f;

	public:

		bool IsValid () const;
		
		bool IsSDR () const
			{
			return (fDynamicRange == 0);
			}

		bool IsHDR () const
			{
			return !IsSDR ();
			}

		void PutStream (dng_stream &stream) const;

		#if qDNGValidate
		void Dump () const;
		#endif

		bool operator== (const dng_camera_profile_dynamic_range &src) const
			{
			return (fVersion			== src.fVersion		 &&
					fDynamicRange		== src.fDynamicRange &&
					fHintMaxOutputValue == src.fHintMaxOutputValue);
			}

		bool operator!= (const dng_camera_profile_dynamic_range &src) const
			{
			return !(*this == src);
			}

	};

/*****************************************************************************/

class dng_camera_profile_info
	{
	
	public:
	
		bool fBigEndian;
	
		uint32 fColorPlanes;
		
		uint32 fCalibrationIlluminant1;
		uint32 fCalibrationIlluminant2;
		uint32 fCalibrationIlluminant3;

		dng_illuminant_data fIlluminantData1;
		dng_illuminant_data fIlluminantData2;
		dng_illuminant_data fIlluminantData3;
		
		dng_matrix fColorMatrix1;
		dng_matrix fColorMatrix2;
		dng_matrix fColorMatrix3;
		
		dng_matrix fForwardMatrix1;
		dng_matrix fForwardMatrix2;
		dng_matrix fForwardMatrix3;
		
		dng_matrix fReductionMatrix1;
		dng_matrix fReductionMatrix2;
		dng_matrix fReductionMatrix3;

		dng_string fProfileCalibrationSignature;

		dng_string fProfileName;

		dng_string fProfileCopyright;

		uint32 fEmbedPolicy;
		
		uint32 fProfileHues;
		uint32 fProfileSats;
		uint32 fProfileVals;

		uint64 fHueSatDeltas1Offset;
		uint32 fHueSatDeltas1Count;

		uint64 fHueSatDeltas2Offset;
		uint32 fHueSatDeltas2Count;
		
		uint64 fHueSatDeltas3Offset;
		uint32 fHueSatDeltas3Count;
		
		uint32 fHueSatMapEncoding;
		
		uint32 fLookTableHues;
		uint32 fLookTableSats;
		uint32 fLookTableVals;
		
		uint64 fLookTableOffset;
		uint32 fLookTableCount;

		uint32 fLookTableEncoding;

		dng_srational fBaselineExposureOffset;

		uint32 fDefaultBlackRender;
		
		uint64 fToneCurveOffset;
		uint32 fToneCurveCount;
		
		uint32 fToneMethod;
		
		dng_string fUniqueCameraModel;

		std::shared_ptr<const dng_gain_table_map> fProfileGainTableMap;

		dng_camera_profile_dynamic_range fProfileDynamicRange;
		
		dng_string fProfileGroupName;
		
		std::shared_ptr<const dng_masked_rgb_tables> fMaskedRGBTables;

	public:
	
		dng_camera_profile_info ();
		
		~dng_camera_profile_info ();
		
		bool ParseTag (dng_stream &stream,
					   uint32 parentCode,
					   uint32 tagCode,
					   uint32 tagType,
					   uint32 tagCount,
					   uint64 tagOffset);
					   
		bool ParseExtended (dng_stream &stream);

	};
		
/*****************************************************************************/

class dng_shared
	{
	
	public:
	
		uint64 fExifIFD;
		uint64 fGPSInfo;
		uint64 fInteroperabilityIFD;
		uint64 fKodakDCRPrivateIFD;
		uint64 fKodakKDCPrivateIFD;
		
		uint32 fXMPCount;
		uint64 fXMPOffset;
		
		uint32 fIPTC_NAA_Count;
		uint64 fIPTC_NAA_Offset;

		uint32 fMakerNoteCount;
		uint64 fMakerNoteOffset;
		uint32 fMakerNoteSafety;
		
		uint32 fDNGVersion;
		uint32 fDNGBackwardVersion;
		
		dng_string fUniqueCameraModel;
		dng_string fLocalizedCameraModel;
		
		dng_camera_profile_info fCameraProfile;
		
		dng_std_vector<dng_camera_profile_info> fExtraCameraProfiles;

		dng_matrix fCameraCalibration1;
		dng_matrix fCameraCalibration2;
		dng_matrix fCameraCalibration3;
		
		dng_string fCameraCalibrationSignature;

		dng_vector fAnalogBalance;
		
		dng_vector fAsShotNeutral;
		
		dng_xy_coord fAsShotWhiteXY;
		
		dng_srational fBaselineExposure;
		dng_urational fBaselineNoise;
		dng_urational fBaselineSharpness;
		dng_urational fLinearResponseLimit;
		dng_urational fShadowScale;
		
		bool fHasBaselineExposure;
		bool fHasShadowScale;
		
		uint32 fDNGPrivateDataCount;
		uint64 fDNGPrivateDataOffset;

		dng_fingerprint fRawImageDigest;
		dng_fingerprint fNewRawImageDigest;
		
		dng_fingerprint fRawDataUniqueID;
		
		dng_string fOriginalRawFileName;
		
		uint32 fOriginalRawFileDataCount;
		uint64 fOriginalRawFileDataOffset;
		
		dng_fingerprint fOriginalRawFileDigest;
		
		uint32 fAsShotICCProfileCount;
		uint64 fAsShotICCProfileOffset;
		
		dng_matrix fAsShotPreProfileMatrix;
		
		uint32 fCurrentICCProfileCount;
		uint64 fCurrentICCProfileOffset;
		
		dng_matrix fCurrentPreProfileMatrix;
		
		uint32 fColorimetricReference;

		dng_string fAsShotProfileName;

		dng_point fOriginalDefaultFinalSize;
		dng_point fOriginalBestQualityFinalSize;
		
		dng_urational fOriginalDefaultCropSizeH;
		dng_urational fOriginalDefaultCropSizeV;
  
		uint32		  fDepthFormat;
		dng_urational fDepthNear;
		dng_urational fDepthFar;
		uint32		  fDepthUnits;
		uint32		  fDepthMeasureType;
		
		dng_std_vector<dng_fingerprint> fBigTableDigests;
		dng_std_vector<uint64>			fBigTableOffsets;
		dng_std_vector<uint32>			fBigTableByteCounts;

		std::map<dng_fingerprint,
				 dng_fingerprint> fBigTableGroupIndex;

		dng_image_sequence_info fImageSequenceInfo;
		
	public:
	
		dng_shared ();
		
		virtual ~dng_shared ();
		
		virtual bool ParseTag (dng_stream &stream,
							   dng_exif &exif,
							   uint32 parentCode,
							   bool isMainIFD,
							   uint32 tagCode,
							   uint32 tagType,
							   uint32 tagCount,
							   uint64 tagOffset,
							   int64 offsetDelta);
							   
		virtual void PostParse (dng_host &host,
								dng_exif &exif);
		
		virtual bool IsValidDNG ();
		
	protected:
		
		virtual bool Parse_ifd0 (dng_stream &stream,
								 dng_exif &exif,
								 uint32 parentCode,
								 uint32 tagCode,
								 uint32 tagType,
								 uint32 tagCount,
								 uint64 tagOffset);
									 
		virtual bool Parse_ifd0_exif (dng_stream &stream,
									  dng_exif &exif,
									  uint32 parentCode,
									  uint32 tagCode,
									  uint32 tagType,
									  uint32 tagCount,
									  uint64 tagOffset);
	
	};
	
/*****************************************************************************/

#endif
	
/*****************************************************************************/
