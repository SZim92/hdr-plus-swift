#!/bin/bash

# Set the base directory
BASE_DIR="dng_sdk/dng_sdk"

# Create a backup of the original file if it doesn't exist
if [ ! -f "$BASE_DIR/dng_image_writer.cpp.bak" ]; then
    cp "$BASE_DIR/dng_image_writer.cpp" "$BASE_DIR/dng_image_writer.cpp.bak"
    echo "Created backup of dng_image_writer.cpp"
else
    echo "Backup already exists, using it"
fi

# Restore the original file from backup
cp "$BASE_DIR/dng_image_writer.cpp.bak" "$BASE_DIR/dng_image_writer.cpp"

# First create a temporary file with the class declarations
cat > "$BASE_DIR/dng_image_writer_declarations.h" << 'EOF'
// Forward class declarations
class dng_tiff_directory;
class dng_mosaic_info;
class dng_negative;

/*****************************************************************************/

// Class declarations needed before their implementations

/*****************************************************************************/

// Class declaration for mosaic_tag_set
class mosaic_tag_set
{
private:
    uint16 fCFARepeatPatternDimData[2];
    tag_uint16_ptr fCFARepeatPatternDim;
    uint8 fCFAPatternData[kMaxCFAPattern * kMaxCFAPattern];
    tag_uint8_ptr fCFAPattern;
    uint8 fCFAPlaneColorData[kMaxColorPlanes];
    tag_uint8_ptr fCFAPlaneColor;
    tag_uint16 fCFALayout;
    tag_uint32 fGreenSplit;

public:
    mosaic_tag_set(dng_tiff_directory &directory,
                  const dng_mosaic_info &info);
};

/*****************************************************************************/

// Class declaration for range_tag_set
class range_tag_set
{
private:
    uint32 fActiveAreaData[4];
    tag_uint32_ptr fActiveArea;
    uint32 fMaskedAreaData[kMaxMaskedAreas * 4];
    tag_uint32_ptr fMaskedAreas;
    tag_uint16_ptr fLinearizationTable;
    uint16 fBlackLevelRepeatDimData[2];
    tag_uint16_ptr fBlackLevelRepeatDim;
    dng_urational fBlackLevelData[kMaxBlackPattern * kMaxBlackPattern * kMaxColorPlanes];
    tag_urational_ptr fBlackLevel;
    dng_memory_data fBlackLevelDeltaHData;
    dng_memory_data fBlackLevelDeltaVData;
    tag_srational_ptr fBlackLevelDeltaH;
    tag_srational_ptr fBlackLevelDeltaV;
    tag_uint16_ptr fWhiteLevel16;
    tag_uint32_ptr fWhiteLevel32;

public:
    range_tag_set(dng_tiff_directory &directory,
                 const dng_negative &negative);
};
EOF

# Now modify the dng_image_writer.cpp file to insert the declarations
TMP_FILE=$(mktemp)
awk '
  # Find the line after the includes and before the Class implementations
  /^#include <vector>/ || /^\*\*\*\*\*/ {
    print; 
    if (!/^\*\*\*\*\*/) {
      print "";
      # Insert the declarations
      system("cat '$BASE_DIR/dng_image_writer_declarations.h'");
      print "";
    }
    next;
  }
  # Remove empty lines before Class implementations to avoid duplicate spacing
  /^\/\/ Class implementations/ {
    sub(/^\n*/, "");
    print;
    next;
  }
  # Print everything else
  { print }
' "$BASE_DIR/dng_image_writer.cpp" > "$TMP_FILE"

# Replace the original with the modified file
mv "$TMP_FILE" "$BASE_DIR/dng_image_writer.cpp"

# Fix the constructor definitions in the file (spacing issues)
sed -i '' 's/dng_resolution::dng_resolution ()/dng_resolution::dng_resolution()/g' "$BASE_DIR/dng_image_writer.cpp"
sed -i '' 's/tag_string::tag_string (uint16 code,/tag_string::tag_string(uint16 code,/g' "$BASE_DIR/dng_image_writer.cpp"
sed -i '' 's/mosaic_tag_set::mosaic_tag_set (dng_tiff_directory/mosaic_tag_set::mosaic_tag_set(dng_tiff_directory/g' "$BASE_DIR/dng_image_writer.cpp"
sed -i '' 's/range_tag_set::range_tag_set (dng_tiff_directory/range_tag_set::range_tag_set(dng_tiff_directory/g' "$BASE_DIR/dng_image_writer.cpp"

# Clean up
rm -f "$BASE_DIR/dng_image_writer_declarations.h"

echo "Fixed class declarations and constructor definitions in dng_image_writer.cpp"
echo "Please rebuild your project with: xcodebuild -project burstphoto.xcodeproj -target VisualTests -configuration Debug -arch arm64 clean build GCC_PREPROCESSOR_DEFINITIONS='DISABLE_JXL_SUPPORT=1'" 