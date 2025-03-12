#!/bin/bash

echo "Fixing unterminated conditional directives in DNG JXL files..."

# Function to check and fix conditional directives in a file
fix_file() {
  local file=$1
  echo "Checking $file..."
  
  # Create a temporary file
  tmp_file=$(mktemp)
  
  # Count #if, #ifdef, #ifndef and #endif directives
  count_if=$(grep -c -E '^\s*#\s*(if|ifdef|ifndef)' "$file")
  count_endif=$(grep -c -E '^\s*#\s*endif' "$file")
  
  if [ $count_if -gt $count_endif ]; then
    echo "  Found unterminated conditional directive(s): $count_if #if vs $count_endif #endif"
    
    # Append necessary #endif at the end of the file
    cat "$file" > "$tmp_file"
    difference=$((count_if - count_endif))
    
    for ((i=1; i<=difference; i++)); do
      echo -e "\n#endif // DISABLE_JXL_SUPPORT (auto-added)" >> "$tmp_file"
    done
    
    # Apply the fix
    mv "$tmp_file" "$file"
    echo "  Added $difference #endif directives to close conditionals"
  else
    echo "  Conditionals are balanced in $file"
    rm "$tmp_file"
  fi
}

# Search for JXL-related files
find ./dng_sdk -name "*.h" -o -name "*.cpp" | while read file; do
  if grep -q -E "JXL|jxl" "$file"; then
    fix_file "$file"
  fi
done

# Specifically check the dng_jxl.h file
if [ -f "./dng_sdk/dng_sdk/dng_jxl.h" ]; then
  fix_file "./dng_sdk/dng_sdk/dng_jxl.h"
fi

if [ -f "./dng_sdk/dng_sdk/source/dng_jxl.h" ]; then
  fix_file "./dng_sdk/dng_sdk/source/dng_jxl.h"
fi

echo "Done fixing unterminated conditionals." 