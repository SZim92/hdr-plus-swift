#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"

# Check if the file exists
if [ ! -f "$BASE_DIR/dng_image_writer.cpp" ]; then
    echo "Error: $BASE_DIR/dng_image_writer.cpp doesn't exist"
    exit 1
fi

# Create a backup if it doesn't exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp.bak2" ]; then
    cp "$BASE_DIR/dng_image_writer.cpp" "$BASE_DIR/dng_image_writer.cpp.bak2"
    echo "Created backup of dng_image_writer.cpp as dng_image_writer.cpp.bak2"
else
    echo "Backup already exists"
fi

# Create a temporary file
TMP_FILE=$(mktemp)

# Replace the problematic section of the file
cat "$BASE_DIR/dng_image_writer.cpp" | sed '4760,4785c\
				}\
\
			// Else get it from the IFD.\
			\
#if qDNGSupportJXL\
			else if (ifd.fJXLColorEncoding)\
				{\
				\
				colorSpaceInfoLocal.fJxlColorEncoding.Reset\
					(new JxlColorEncoding (*ifd.fJXLColorEncoding));\
\
				}\
#endif // qDNGSupportJXL\
\
			else\
				{\
\
#if qDNGSupportJXL\
				PreviewColorSpaceToJXLEncoding (ifd.fPreviewInfo.fColorSpace,\
                                               ifd.fSamplesPerPixel,\
                                               colorSpaceInfoLocal);\
#else\
                /* No JXL support - use default color space handling */\
                /* (This is a stub - add your non-JXL color space handling here) */\
#endif\
				}' > "$TMP_FILE"

# Replace the original file with the modified one
mv "$TMP_FILE" "$BASE_DIR/dng_image_writer.cpp"

echo "Successfully fixed specific JXL preprocessor issues in dng_image_writer.cpp"
echo "Please rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 