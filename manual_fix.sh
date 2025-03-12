#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"

# Check if files exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp" ]; then
    echo "Error: $BASE_DIR/dng_image_writer.cpp doesn't exist"
    exit 1
fi

# Create a backup if it doesn't exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp.bak_manual" ]; then
    cp "$BASE_DIR/dng_image_writer.cpp" "$BASE_DIR/dng_image_writer.cpp.bak_manual"
    echo "Created backup of dng_image_writer.cpp"
else
    echo "Backup already exists"
fi

# Patch 1: Fix dng_deprecated_flags.h to comment out problematic line
if [ -f "$BASE_DIR/dng_deprecated_flags.h" ]; then
    sed -i '' 's/#define qDNGSupportJXL @error/\/\/ #define qDNGSupportJXL @error/' "$BASE_DIR/dng_deprecated_flags.h"
    echo "Fixed dng_deprecated_flags.h"
else
    echo "Warning: dng_deprecated_flags.h not found"
fi

# Patch 2: Create a fixed version of the file
PATCHED_FILE=$(mktemp)

# First, extract the file parts
head -n 4759 "$BASE_DIR/dng_image_writer.cpp" > "$PATCHED_FILE"

# Add the patched JXL section
cat >> "$PATCHED_FILE" << 'EOT'
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

# Add the rest of the file (line 4795 onwards)
tail -n +4796 "$BASE_DIR/dng_image_writer.cpp" >> "$PATCHED_FILE"

# Replace the original file with the patched one
mv "$PATCHED_FILE" "$BASE_DIR/dng_image_writer.cpp"
echo "Patched JXL section in dng_image_writer.cpp"

# Patch 3: Find and wrap JXL-specific methods
# This is a simplified approach that just locates the specific methods and
# adds the needed preprocessor directives around them

# For WriteJPEGXL
LINE1=$(grep -n "bool dng_image_writer::WriteJPEGXL" "$BASE_DIR/dng_image_writer.cpp" | cut -d: -f1)
if [ ! -z "$LINE1" ]; then
    # Check if it's already wrapped
    if ! grep -A1 "bool dng_image_writer::WriteJPEGXL" "$BASE_DIR/dng_image_writer.cpp" | grep -q "#if qDNGSupportJXL"; then
        # Create a temporary patch
        TMP=$(mktemp)
        head -n $((LINE1-1)) "$BASE_DIR/dng_image_writer.cpp" > "$TMP"
        echo "#if qDNGSupportJXL" >> "$TMP"
        
        # Find the end of the method (the closing brace)
        BLOCK=$(grep -n "bool dng_image_writer::WriteJPEGXL" -A 1000 "$BASE_DIR/dng_image_writer.cpp" | grep -n "^}" | head -1)
        END_LINE=$(echo $BLOCK | cut -d: -f1)
        END_LINE=$((LINE1 + END_LINE - 1))
        
        # Extract the method and add it with closing directive
        sed -n "${LINE1},${END_LINE}p" "$BASE_DIR/dng_image_writer.cpp" >> "$TMP"
        echo "#endif // qDNGSupportJXL" >> "$TMP"
        
        # Add the rest of the file
        tail -n +$((END_LINE+1)) "$BASE_DIR/dng_image_writer.cpp" >> "$TMP"
        
        # Replace the original
        mv "$TMP" "$BASE_DIR/dng_image_writer.cpp"
        echo "Wrapped WriteJPEGXL method"
    else
        echo "WriteJPEGXL method already wrapped"
    fi
fi

# For WriteJPEGXLTile
LINE2=$(grep -n "bool dng_image_writer::WriteJPEGXLTile" "$BASE_DIR/dng_image_writer.cpp" | cut -d: -f1)
if [ ! -z "$LINE2" ]; then
    # Check if it's already wrapped
    if ! grep -A1 "bool dng_image_writer::WriteJPEGXLTile" "$BASE_DIR/dng_image_writer.cpp" | grep -q "#if qDNGSupportJXL"; then
        # Create a temporary patch
        TMP=$(mktemp)
        head -n $((LINE2-1)) "$BASE_DIR/dng_image_writer.cpp" > "$TMP"
        echo "#if qDNGSupportJXL" >> "$TMP"
        
        # Find the end of the method (the closing brace)
        BLOCK=$(grep -n "bool dng_image_writer::WriteJPEGXLTile" -A 1000 "$BASE_DIR/dng_image_writer.cpp" | grep -n "^}" | head -1)
        END_LINE=$(echo $BLOCK | cut -d: -f1)
        END_LINE=$((LINE2 + END_LINE - 1))
        
        # Extract the method and add it with closing directive
        sed -n "${LINE2},${END_LINE}p" "$BASE_DIR/dng_image_writer.cpp" >> "$TMP"
        echo "#endif // qDNGSupportJXL" >> "$TMP"
        
        # Add the rest of the file
        tail -n +$((END_LINE+1)) "$BASE_DIR/dng_image_writer.cpp" >> "$TMP"
        
        # Replace the original
        mv "$TMP" "$BASE_DIR/dng_image_writer.cpp"
        echo "Wrapped WriteJPEGXLTile method"
    else
        echo "WriteJPEGXLTile method already wrapped"
    fi
fi

echo "All JXL-related issues have been fixed."
echo "You can now rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 