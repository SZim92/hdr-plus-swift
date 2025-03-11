#!/bin/bash
# Metal Support Detection and Diagnostics Script
# 
# This script checks if Metal is supported on the current system and provides
# detailed diagnostics useful for debugging Metal-related issues.
#
# Usage:
#   ./check-metal-support.sh [output_dir]
#
# If output_dir is provided, results are saved to that directory.
# Otherwise, results are printed to stdout.

set -e

OUTPUT_DIR=${1:-"metal-diagnostics"}

# Create output directory if specified
if [ -n "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
  echo "Metal diagnostics will be saved to: $OUTPUT_DIR"
fi

# Function to output either to file or stdout
output() {
  local content="$1"
  local filename="$2"
  
  if [ -n "$OUTPUT_DIR" ] && [ -n "$filename" ]; then
    echo "$content" >> "$OUTPUT_DIR/$filename"
  else
    echo "$content"
  fi
}

# Start summary file
if [ -n "$OUTPUT_DIR" ]; then
  echo "# Metal Environment Diagnostics" > "$OUTPUT_DIR/metal_support_summary.md"
  echo "" >> "$OUTPUT_DIR/metal_support_summary.md"
  echo "Generated on: $(date)" >> "$OUTPUT_DIR/metal_support_summary.md"
  echo "" >> "$OUTPUT_DIR/metal_support_summary.md"
fi

# Check operating system
OS=$(uname -s)
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
output "OS: $OS $OS_VERSION" "metal_support_summary.md"

# Check architecture
ARCH=$(uname -m)
output "Architecture: $ARCH" "metal_support_summary.md"

# Get GPU information
if [ "$OS" = "Darwin" ]; then
  # Try system_profiler first for detailed info
  if command -v system_profiler >/dev/null 2>&1; then
    echo "Collecting GPU information..."
    # Extract GPU info and format it for the summary
    GPU_INFO=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -A15 "Chipset Model:" | head -10)
    
    # Save full GPU info to separate file if output dir specified
    if [ -n "$OUTPUT_DIR" ]; then
      system_profiler SPDisplaysDataType > "$OUTPUT_DIR/gpu_details.txt"
    fi
    
    # Extract GPU name for summary
    GPU_NAME=$(echo "$GPU_INFO" | grep "Chipset Model:" | sed 's/.*Chipset Model: //' || echo "Unknown")
    output "GPU: $GPU_NAME" "metal_support_summary.md"
    
    # Check if Metal is supported based on GPU info
    if echo "$GPU_INFO" | grep -q "Metal:" && ! echo "$GPU_INFO" | grep -q "Metal: Not Supported"; then
      METAL_SUPPORTED=true
      METAL_INFO=$(echo "$GPU_INFO" | grep "Metal:" | sed 's/.*Metal: //' || echo "Supported")
      output "Metal Support: $METAL_INFO" "metal_support_summary.md"
    else
      METAL_SUPPORTED=false
      output "Metal Support: Not detected" "metal_support_summary.md"
    fi
  else
    # Fallback to more basic checks
    output "GPU: Could not determine (system_profiler not available)" "metal_support_summary.md"
    # Check macOS version - Metal requires 10.11+
    if [[ "$OS_VERSION" = 10.* ]] && [[ ${OS_VERSION#10.} -lt 11 ]]; then
      METAL_SUPPORTED=false
      output "Metal Support: Not supported (macOS version too old)" "metal_support_summary.md"
    else
      # Assume modern Macs support Metal
      METAL_SUPPORTED=true
      output "Metal Support: Likely supported based on OS version" "metal_support_summary.md"
    fi
  fi
else
  # Non-macOS platform
  output "GPU: Not applicable (non-macOS platform)" "metal_support_summary.md"
  METAL_SUPPORTED=false
  output "Metal Support: Not supported (non-macOS platform)" "metal_support_summary.md"
fi

# Set the Metal supported flag for script output
output "Metal Supported: $METAL_SUPPORTED" "metal_support_summary.md"

# Get additional Metal capabilities if supported
if [ "$METAL_SUPPORTED" = true ]; then
  echo "Checking Metal capabilities..."
  
  # Check if Metal tools are available
  if xcrun --find metal >/dev/null 2>&1; then
    METAL_VERSION=$(xcrun metal --version 2>/dev/null | head -1 || echo "Unknown version")
    output "Metal Compiler: $METAL_VERSION" "metal_support_summary.md"
    
    # Capture Metal device info if output directory specified
    if [ -n "$OUTPUT_DIR" ]; then
      # Create a simple Metal program to query device capabilities
      cat > "$OUTPUT_DIR/metal_device_query.metal" << 'EOF'
#include <metal_stdlib>
using namespace metal;

kernel void device_query(device uint *buffer [[buffer(0)]],
                         uint id [[thread_position_in_grid]]) {
    if (id == 0) {
        buffer[0] = 1; // Just a simple test value
    }
}
EOF
      
      # Compile the Metal shader
      xcrun -sdk macosx metal -c "$OUTPUT_DIR/metal_device_query.metal" -o "$OUTPUT_DIR/metal_device_query.air" 2> "$OUTPUT_DIR/metal_compile_log.txt" || true
      
      # Check if compile succeeded
      if [ -f "$OUTPUT_DIR/metal_device_query.air" ]; then
        output "Metal Shader Compilation: Successful" "metal_support_summary.md"
      else
        output "Metal Shader Compilation: Failed (see metal_compile_log.txt)" "metal_support_summary.md"
      fi
    fi
  else
    output "Metal Compiler: Not found" "metal_support_summary.md"
  fi
  
  # Check for Metal Performance Shaders availability
  output "## Metal Framework Availability" "metal_support_summary.md"
  output "" "metal_support_summary.md"
  
  # Check for common Metal-related frameworks
  FRAMEWORKS=("Metal" "MetalKit" "MetalPerformanceShaders")
  
  for framework in "${FRAMEWORKS[@]}"; do
    if [ -d "/System/Library/Frameworks/${framework}.framework" ]; then
      output "- ✅ $framework: Available" "metal_support_summary.md"
    else
      output "- ❌ $framework: Not found" "metal_support_summary.md"
    fi
  done
fi

# Add recommendations based on findings
output "" "metal_support_summary.md"
output "## Recommendations" "metal_support_summary.md"
output "" "metal_support_summary.md"

if [ "$METAL_SUPPORTED" = true ]; then
  output "- Metal is supported on this system and should work for HDR+ processing" "metal_support_summary.md"
  output "- For optimal performance, ensure GPU drivers are up to date" "metal_support_summary.md"
  
  # Architecture-specific recommendations
  if [ "$ARCH" = "arm64" ]; then
    output "- Apple Silicon detected: Metal should provide excellent performance" "metal_support_summary.md"
  else
    output "- Intel architecture detected: Consider testing on Apple Silicon for best performance" "metal_support_summary.md"
  fi
else
  output "- Metal is not supported on this system" "metal_support_summary.md"
  output "- HDR+ processing will fall back to CPU-based methods if available" "metal_support_summary.md"
  output "- For Metal support, use a Mac with compatible GPU" "metal_support_summary.md"
fi

# Exit with status based on Metal support
if [ "$METAL_SUPPORTED" = true ]; then
  echo "✅ Metal is supported on this system"
  exit 0
else
  echo "⚠️ Metal is not supported on this system"
  # Exit with 0 to not fail CI builds, but provide indication in the output
  exit 0
fi 