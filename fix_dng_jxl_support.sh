#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"

# Check if the file exists
if [ ! -f "$BASE_DIR/dng_image_writer.cpp" ]; then
    echo "Error: $BASE_DIR/dng_image_writer.cpp doesn't exist"
    exit 1
fi

# Create a backup if it doesn't exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp.bak" ]; then
    cp "$BASE_DIR/dng_image_writer.cpp" "$BASE_DIR/dng_image_writer.cpp.bak"
    echo "Created backup of dng_image_writer.cpp"
else
    echo "Backup already exists"
fi

# Create a temporary file for the modifications
TMP_FILE=$(mktemp)

# Use awk to add conditional compilation for JPEG XL-related code
awk '
BEGIN { in_jxl_section = 0; jxl_if_depth = 0; }

# Detect start of JPEG XL related code
/if \(ifd\.fJXLColorEncoding\)/ { 
    print "#if qDNGSupportJXL"; 
    print $0; 
    in_jxl_section = 1; 
    next; 
}

# Add conditional for JXL-related functions
/PreviewColorSpaceToJXLEncoding/ {
    if (!in_jxl_section) {
        print "#if qDNGSupportJXL";
        print $0;
        print "#endif";
        next;
    }
}

# Handle end of JXL section
/else/ {
    if (in_jxl_section) {
        print $0;
        print "#else";
        print "// No JXL color encoding support when disabled";
        next;
    } else {
        print $0;
        next;
    }
}

# Close the conditional block at the end of the if/else section
/^[\t ]*}[\t ]*$/ {
    if (in_jxl_section) {
        print $0;
        print "#endif // qDNGSupportJXL";
        in_jxl_section = 0;
        next;
    }
}

# Wrap JXL-specific methods
/void dng_jxl_color_space_info::Set/ {
    print "#if qDNGSupportJXL";
    print $0;
    jxl_if_depth++;
    next;
}

# Close JXL-specific method blocks
/^}/ {
    if (jxl_if_depth > 0) {
        print $0;
        print "#endif // qDNGSupportJXL";
        jxl_if_depth--;
        next;
    }
}

# Print all other lines unchanged
{ print $0; }
' "$BASE_DIR/dng_image_writer.cpp" > "$TMP_FILE"

# Now process with sed to handle additional JXL-specific functions
sed -i '' -e '/JxlEncoderAddJPEGBox/i\
#if qDNGSupportJXL
' -e '/AdobeAPP3_Data/a\
#endif // qDNGSupportJXL
' "$TMP_FILE"

# Add specific wrapping for the entire WriteJPEGXL method
sed -i '' -e '/static void WriteJPEGXL/i\
#if qDNGSupportJXL
' -e '/^static void WriteJPEGXL.*$/,/^}$/s/^}$/}\
#endif \/\/ qDNGSupportJXL/' "$TMP_FILE"

# Also wrap the entire WriteJPEGXLTile method
sed -i '' -e '/static void WriteJPEGXLTile/i\
#if qDNGSupportJXL
' -e '/^static void WriteJPEGXLTile.*$/,/^}$/s/^}$/}\
#endif \/\/ qDNGSupportJXL/' "$TMP_FILE"

# Replace the original file with the modified one
mv "$TMP_FILE" "$BASE_DIR/dng_image_writer.cpp"

echo "Successfully added conditional compilation for JPEG XL code in dng_image_writer.cpp"
echo "Please rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 