#!/bin/bash

# fix-markdown.sh
# Script to automatically fix common markdown linting issues

set -e

echo "🔍 Finding markdown files..."
MARKDOWN_FILES=$(find . -name "*.md" -type f)
FILE_COUNT=$(echo "$MARKDOWN_FILES" | wc -l)
echo "Found $FILE_COUNT markdown files"

echo "🛠️ Fixing common markdown issues..."

for file in $MARKDOWN_FILES; do
  echo "Processing $file..."
  
  # Create a temporary file
  temp_file="${file}.tmp"
  
  # Fix 1: Remove trailing spaces
  sed 's/[[:space:]]*$//' "$file" > "$temp_file"
  
  # Fix 2: Ensure headings have blank lines before and after
  awk '
    # If the line is a heading (starts with #)
    /^#/ {
      # If the previous line is not blank and not the beginning of the file
      if (NR > 1 && prev != "") {
        # Add a blank line before the heading
        print ""
      }
      # Print the heading
      print $0
      # Mark that we need a blank line after
      need_blank = 1
      prev = $0
      next
    }
    
    # If we need a blank line after a heading and the current line is not blank
    need_blank == 1 && $0 != "" {
      # Add a blank line after the heading
      print ""
      need_blank = 0
    }
    
    # If the line is not blank, reset the need_blank flag
    $0 != "" {
      need_blank = 0
    }
    
    # Print the current line
    { print $0; prev = $0 }
  ' "$temp_file" > "${temp_file}.2"
  
  # Fix 3: Ensure lists have blank lines before and after
  awk '
    # Function to detect if a line is a list item
    function is_list_item(line) {
      return line ~ /^[[:space:]]*[-*+]/ || line ~ /^[[:space:]]*[0-9]+\./
    }
    
    # If the current line is a list item and the previous line is not a list item and not blank
    is_list_item($0) && !is_list_item(prev) && prev != "" {
      # Add a blank line before the list item
      print ""
    }
    
    # If the previous line is a list item and the current line is not a list item and not blank
    is_list_item(prev) && !is_list_item($0) && $0 != "" {
      # Add a blank line after the list
      print ""
    }
    
    # Print the current line
    { print $0; prev = $0 }
  ' "${temp_file}.2" > "${temp_file}.3"
  
  # Fix 4: Remove trailing punctuation from headings
  sed 's/^#\+[[:space:]]\+\(.*\)[.,:;!][[:space:]]*$/#\1/' "${temp_file}.3" > "${temp_file}.4"
  
  # Fix 5: Ensure file ends with exactly one newline
  # First, remove all trailing newlines
  sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${temp_file}.4" > "${temp_file}.5"
  # Then add exactly one newline
  echo "" >> "${temp_file}.5"
  
  # Move the final temp file back to the original
  mv "${temp_file}.5" "$file"
  
  # Clean up temporary files
  rm -f "$temp_file" "${temp_file}.2" "${temp_file}.3" "${temp_file}.4"
done

echo "✅ Markdown fixes complete!"
echo "Note: Some complex formatting issues may still need manual attention."
echo "Run the markdown linting workflow to check for remaining issues." 