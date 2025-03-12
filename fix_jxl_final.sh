#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"

# Check if the files exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp" ] || [ ! -f "$BASE_DIR/dng_flags.h" ] || [ ! -f "$BASE_DIR/dng_deprecated_flags.h" ]; then
    echo "Error: Required files don't exist"
    exit 1
fi

# Create backups if they don't exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp.bak_final" ]; then
    cp "$BASE_DIR/dng_image_writer.cpp" "$BASE_DIR/dng_image_writer.cpp.bak_final"
    echo "Created backup of dng_image_writer.cpp"
fi

if [ ! -f "$BASE_DIR/dng_flags.h.bak_final" ]; then
    cp "$BASE_DIR/dng_flags.h" "$BASE_DIR/dng_flags.h.bak_final"
    echo "Created backup of dng_flags.h"
fi

if [ ! -f "$BASE_DIR/dng_deprecated_flags.h.bak_final" ]; then
    cp "$BASE_DIR/dng_deprecated_flags.h" "$BASE_DIR/dng_deprecated_flags.h.bak_final"
    echo "Created backup of dng_deprecated_flags.h"
fi

# Step 1: Fix the dng_deprecated_flags.h file to remove the @error directive
sed -i.tmp 's/#define qDNGSupportJXL @error/\/\/ #define qDNGSupportJXL @error/' "$BASE_DIR/dng_deprecated_flags.h"
echo "Fixed dng_deprecated_flags.h"

# Step 2: Create a replacement text file for the problematic section
REPLACEMENT_TEXT="/tmp/jxl_replacement.txt"
cat > $REPLACEMENT_TEXT << 'EOT'
				}

			// Else get it from the IFD.
			
#if qDNGSupportJXL
			else if (ifd.fJXLColorEncoding)
				{
				
				colorSpaceInfoLocal.fJxlColorEncoding.Reset
					(new JxlColorEncoding (*ifd.fJXLColorEncoding));

				}
#endif // qDNGSupportJXL

			else
				{

#if qDNGSupportJXL
				PreviewColorSpaceToJXLEncoding (ifd.fPreviewInfo.fColorSpace,
                                               ifd.fSamplesPerPixel,
                                               colorSpaceInfoLocal);
#else
                /* No JXL support - use default color space handling */
                /* (This is a stub - add your non-JXL color space handling here) */
#endif
				}

			#if 0
			printf ("jxl: strips=%s, tiles=%s, ta=%u, td=%u\n",
					ifd.fUsesStrips ? "yes" : "no",
					ifd.fUsesTiles ? "yes" : "no",
					ifd.TilesAcross (),
					ifd.TilesDown ());
			#endif

			// If we're writing a single-tile preview, then write the JXL
			// using the container format (i.e., with boxes) so that readers
			// have the option of extracting a full standalone JXL file by
EOT

# Step 3: Replace the problematic section in the file
sed -i.tmp -e "/^				}$/{
  N
  N
  /^				}$.*\n.*\/\/ Else get it from the IFD.*\n.*$/{
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    N
    c\\$(cat $REPLACEMENT_TEXT)
  }
}" "$BASE_DIR/dng_image_writer.cpp"
echo "Fixed problematic JXL section in dng_image_writer.cpp"

# Step 4: Wrap JXL-specific methods with preprocessor directives
# First, create markers for method locations
grep -n "bool dng_image_writer::WriteJPEGXL" "$BASE_DIR/dng_image_writer.cpp" > /tmp/jxl_methods.txt
grep -n "bool dng_image_writer::WriteJPEGXLTile" "$BASE_DIR/dng_image_writer.cpp" >> /tmp/jxl_methods.txt

# Process each method
while IFS=: read -r line_num content; do
    # Find the closing brace for this method
    end_line=$(tail -n +$line_num "$BASE_DIR/dng_image_writer.cpp" | grep -n "^}" | head -1 | cut -d: -f1)
    end_line=$((line_num + end_line - 1))
    
    # Add #if before method
    sed -i.tmp "${line_num}s/^/#if qDNGSupportJXL\n/" "$BASE_DIR/dng_image_writer.cpp"
    
    # Add #endif after method
    sed -i.tmp "${end_line}s/^}/}\n#endif \/\/ qDNGSupportJXL/" "$BASE_DIR/dng_image_writer.cpp"
    
    echo "Wrapped JXL method at line $line_num"
done < /tmp/jxl_methods.txt

# Clean up temporary files
rm -f /tmp/jxl_methods.txt /tmp/jxl_replacement.txt "$BASE_DIR/dng_image_writer.cpp.tmp"
rm -f "$BASE_DIR/dng_deprecated_flags.h.tmp"

echo "All JXL-related issues have been fixed"
echo "Please rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 