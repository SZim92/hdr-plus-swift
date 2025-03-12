#!/bin/bash

echo "Applying JPEG XL conditional compilation fix..."

# 1. Add preprocessor definition to the build settings
echo "Creating xcconfig file for JXL preprocessor definition"
cat > disable_jxl.xcconfig << 'EOT'
// Configuration settings file to disable JPEG XL support
// This file adds preprocessor definitions for conditional JXL code

// Add DISABLE_JXL_SUPPORT=1 to preprocessor definitions
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) DISABLE_JXL_SUPPORT=1

// Include the SwiftUI configuration
#include "use_swiftui.xcconfig"
EOT

# 2. Find and wrap JXL function calls in conditional compilation
echo "Finding files with JXL references..."

# Look for JXL references in C++ files
find . -name "*.cpp" -o -name "*.h" -type f -exec grep -l "JXL\|jxl" {} \; | while read file; do
  echo "Checking $file for JXL code..."
  
  # Add include guard at the top of the file if it contains JXL code
  if grep -q "JXL\|jxl\|EncodeJXL\|ParseJXL\|SupportsJXL" "$file"; then
    echo "  Adding conditional compilation to $file"
    
    # Create a backup
    cp "$file" "$file.bak"
    
    # Replace the content with conditional compilation
    awk '
      # If we find JXL-related functions, wrap them in #ifndef
      /SupportsJXL|EncodeJXL|ParseJXL|dng_jxl_decoder/ {
        if (!in_ifdef) {
          print "#ifndef DISABLE_JXL_SUPPORT";
          in_ifdef = 1;
          print $0;
          next;
        }
      }
      
      # If we were in an #ifndef and found a function/class end, close it
      /^}/ && in_ifdef && prev_line_empty {
        print $0;
        print "#endif // DISABLE_JXL_SUPPORT";
        in_ifdef = 0;
        next;
      }
      
      # For empty lines, just print them and mark if we saw one
      /^$/ {
        print $0;
        prev_line_empty = 1;
        next;
      }
      
      # For any other line, mark that we did not see an empty line
      {
        prev_line_empty = 0;
        print $0;
      }
    ' "$file.bak" > "$file.new"
    
    # Replace original with new version if different
    if ! cmp -s "$file" "$file.new"; then
      mv "$file.new" "$file"
      echo "  Updated $file with conditional compilation"
    else
      rm "$file.new"
      echo "  No changes needed for $file"
    fi
  fi
done

# 3. Add empty stub implementations for JXL functions that are still referenced
echo "Creating stub implementations for JXL functions..."

# Create stubs file
cat > dng_sdk/dng_jxl_stubs.cpp << 'EOT'
// Stub implementations for JXL functions when JXL support is disabled
#include "dng_stream.h"
#include "dng_host.h"
#include "dng_info.h"
#include "dng_image.h"
#include "dng_pixel_buffer.h"

#ifdef DISABLE_JXL_SUPPORT

// Stub class for dng_jxl_decoder
class dng_jxl_decoder
{
public:
    dng_jxl_decoder() {}
    ~dng_jxl_decoder() {}
    
    static bool Decode(dng_host &host, dng_stream &stream)
    {
        // JXL support disabled
        return false;
    }
};

// Stub function for SupportsJXL
bool SupportsJXL(const dng_image &image)
{
    // JXL support disabled
    return false;
}

// Stub function for EncodeJXL_Tile
bool EncodeJXL_Tile(dng_host &host, dng_stream &stream, dng_pixel_buffer &buffer)
{
    // JXL support disabled
    return false;
}

// Stub function for EncodeJXL_Container
bool EncodeJXL_Container(dng_host &host, dng_stream &stream, dng_image &image)
{
    // JXL support disabled
    return false;
}

// Stub function for ParseJXL
bool ParseJXL(dng_host &host, dng_stream &stream, dng_info &info)
{
    // JXL support disabled
    return false;
}

#endif // DISABLE_JXL_SUPPORT
EOT

echo "Created JXL stub implementations"

# 4. Update the project file to include the stub file
echo "You'll need to add dng_jxl_stubs.cpp to your Xcode project."
echo "1. Open the project in Xcode"
echo "2. Right-click on the dng_sdk group or folder"
echo "3. Select 'Add Files to "burstphoto"...'"
echo "4. Select the 'dng_jxl_stubs.cpp' file"
echo "5. Make sure the file is added to the gui target"

echo "JXL fixes applied. Next steps:"
echo "1. Open the project in Xcode"
echo "2. Apply the disable_jxl.xcconfig file to your build configuration"
echo "3. Add the dng_jxl_stubs.cpp file to your project"
echo "4. Build and test the application" 