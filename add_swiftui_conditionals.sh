#!/bin/bash

echo "Adding SwiftUI conditional compilation to ensure compatibility..."

# Find files that might use SwiftUI-specific APIs
find ./burstphoto -name "*.swift" -type f -print0 | xargs -0 grep -l "import SwiftUI" | while read file; do
  echo "Processing $file..."
  
  # Check if file already has conditionals
  if ! grep -q "USE_SWIFTUI_NOT_CORE" "$file"; then
    # Add conditional compatibility layer for window management
    if grep -q "NSWindow" "$file" || grep -q "window.collectionBehavior" "$file" || grep -q "standardWindowButton" "$file"; then
      echo "  Adding window management conditionals to $file"
      
      # Create a backup
      cp "$file" "$file.bak"
      
      # Add conditional code
      awk '
        /import SwiftUI/ { 
          print $0;
          print "";
          print "// MARK: - SwiftUI Compatibility";
          print "#if !USE_SWIFTUI_NOT_CORE";
          print "// Original SwiftUICore code path";
          print "#else";
          print "// Standard SwiftUI path - may need adjustments for window management";
          print "import AppKit";
          print "#endif";
          next;
        }
        { print $0 }
      ' "$file.bak" > "$file"
      
      echo "  Added compatibility imports to $file"
    fi
    
    # Replace any specific window styling APIs
    if grep -q "windowStyle(HiddenTitleBarWindowStyle" "$file"; then
      echo "  Updating window styling in $file"
      
      # Create a backup if it doesn't exist
      if [ ! -f "$file.bak" ]; then
        cp "$file" "$file.bak"
      fi
      
      # Update window style with conditionals
      sed -i '' 's/\.windowStyle(HiddenTitleBarWindowStyle())/\
#if !USE_SWIFTUI_NOT_CORE\
        .windowStyle(HiddenTitleBarWindowStyle())\
#else\
        .windowStyle(.hiddenTitleBar)\
#endif/g' "$file"
      
      echo "  Updated window styling in $file"
    fi
  else
    echo "  File already has conditionals, skipping"
  fi
done

echo "Done adding SwiftUI conditionals"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode"
echo "2. Add the use_swiftui.xcconfig to your build configuration"
echo "3. Build and test the application"
echo ""
echo "You can add the xcconfig by:"
echo "- Opening project settings"
echo "- Selecting the 'gui' target"
echo "- Going to 'Build Settings'"
echo "- Setting 'Configuration File' to use_swiftui.xcconfig" 