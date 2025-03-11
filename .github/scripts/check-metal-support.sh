#!/bin/bash
# Script to check Metal support on macOS systems
# This script outputs information about Metal support and GPU capabilities

set -e

# Output directory for results
OUTPUT_DIR="${1:-"metal-diagnostics"}"
mkdir -p "$OUTPUT_DIR"

# Function to log messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Get basic system information
log "Collecting system information..."
system_info=$(system_profiler SPSoftwareDataType SPHardwareDataType 2>/dev/null || echo "System Profiler not available")
echo "$system_info" > "$OUTPUT_DIR/system_info.txt"

# Extract macOS version
os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
echo "macOS Version: $os_version" >> "$OUTPUT_DIR/system_info.txt"

# Get CPU architecture
architecture=$(uname -m)
echo "CPU Architecture: $architecture" >> "$OUTPUT_DIR/system_info.txt"

# Check for Metal support
log "Checking Metal support..."
metal_supported=false
metal_version="Unknown"
gpu_info="Not available"

# Check if we can get GPU information
if command_exists "system_profiler"; then
  gpu_info=$(system_profiler SPDisplaysDataType 2>/dev/null || echo "GPU information not available")
  echo "$gpu_info" > "$OUTPUT_DIR/gpu_info.txt"
  
  # Check for Metal capability in GPU info
  if echo "$gpu_info" | grep -i "metal:" > /dev/null; then
    metal_supported=true
    metal_version=$(echo "$gpu_info" | grep -i "metal:" | head -1 | sed 's/.*Metal: //')
    log "Metal support detected: $metal_version"
  else
    log "Metal support not explicitly mentioned in system profile"
  fi
else
  log "system_profiler command not available, cannot determine GPU details"
fi

# Additional check using Metal framework if on macOS
if command_exists "xcrun"; then
  log "Checking Metal support using Metal framework..."
  
  # Create a temporary Swift file to check Metal support
  cat > "$OUTPUT_DIR/check_metal.swift" << 'EOF'
import Metal
import Foundation

func checkMetalSupport() -> (supported: Bool, details: String) {
    guard let devices = MTLCopyAllDevices() as? [MTLDevice], !devices.isEmpty else {
        return (false, "No Metal devices found")
    }
    
    var details = "Metal devices found:\n"
    
    for (index, device) in devices.enumerated() {
        details += "Device \(index): \(device.name)\n"
        details += "  - Headless: \(device.isHeadless)\n"
        details += "  - Low Power: \(device.isLowPower)\n"
        details += "  - Removable: \(device.isRemovable)\n"
        
        if #available(macOS 10.15, *) {
            details += "  - Max Threads Per ThreadGroup: \(device.maxThreadsPerThreadgroup)\n"
            details += "  - Max Transfer Rate: \(device.maxTransferRate) bytes/sec\n"
        }
        
        if #available(macOS 11.0, *) {
            details += "  - Has Unified Memory: \(device.hasUnifiedMemory)\n"
        }
        
        if #available(macOS 13.0, *) {
            details += "  - Supports Dynamic Libraries: \(device.supportsDynamicLibraries)\n"
        }
    }
    
    return (true, details)
}

let (supported, details) = checkMetalSupport()
print("METAL_SUPPORTED=\(supported)")
print("METAL_DETAILS=<<EOF")
print(details)
print("EOF")
EOF

  # Run the Swift code to check Metal support
  if xcrun swift "$OUTPUT_DIR/check_metal.swift" > "$OUTPUT_DIR/metal_check_result.txt" 2>&1; then
    # Extract results from the output
    if grep -q "METAL_SUPPORTED=true" "$OUTPUT_DIR/metal_check_result.txt"; then
      metal_supported=true
      log "Metal framework check confirms Metal support"
    else
      log "Metal framework check indicates no Metal support"
    fi
    
    # Extract detailed Metal information
    sed -n '/METAL_DETAILS=<<EOF/,/EOF/p' "$OUTPUT_DIR/metal_check_result.txt" | \
      grep -v "METAL_DETAILS=<<EOF" | grep -v "EOF" > "$OUTPUT_DIR/metal_details.txt"
  else
    log "Failed to run Metal support check using Swift"
    echo "Error running Metal check script:" >> "$OUTPUT_DIR/metal_details.txt"
    cat "$OUTPUT_DIR/metal_check_result.txt" >> "$OUTPUT_DIR/metal_details.txt"
  fi
else
  log "xcrun command not available, cannot check Metal support using framework"
fi

# Write summary file
log "Writing summary file..."
cat > "$OUTPUT_DIR/metal_support_summary.md" << EOF
# Metal Support Summary

## System Information
- macOS Version: $os_version
- Architecture: $architecture

## Metal Support
- Metal Supported: $metal_supported
- Metal Version: $metal_version

## GPU Information
$(cat "$OUTPUT_DIR/gpu_info.txt" 2>/dev/null || echo "GPU information not available")

## Detailed Metal Check
$(cat "$OUTPUT_DIR/metal_details.txt" 2>/dev/null || echo "Detailed Metal check not available")
EOF

# Output result for GitHub Actions
echo "METAL_SUPPORTED=$metal_supported" >> $GITHUB_OUTPUT
echo "METAL_VERSION=$metal_version" >> $GITHUB_OUTPUT
echo "OS_VERSION=$os_version" >> $GITHUB_OUTPUT
echo "ARCHITECTURE=$architecture" >> $GITHUB_OUTPUT

log "Metal support check completed. Results saved to $OUTPUT_DIR/"
if $metal_supported; then
  log "✅ Metal is supported on this system"
else
  log "❌ Metal is not supported on this system"
fi

exit 0 