#!/bin/bash
# Script to set up a consistent Swift development environment
# This is used by various CI workflows to ensure consistent setup

set -eo pipefail

# Parse arguments
CACHE_KEY="${1:-default}"
INSTALL_SWIFTLINT="${2:-false}"
DISABLE_CODE_SIGNING="${3:-true}"
ENABLE_RETRY="${4:-false}"
METAL_CONFIG="${5:-standard}"  # New parameter for Metal configuration

# Output directory for diagnostics
DIAGNOSTICS_DIR="swift-setup-logs"
mkdir -p "$DIAGNOSTICS_DIR"

# Function to log with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to retry commands with exponential backoff
retry() {
  local max_attempts=${RETRY_ATTEMPTS:-3}
  local timeout=${RETRY_TIMEOUT:-5}
  local attempt=1
  local exitCode=0

  while [[ $attempt -le $max_attempts ]]
  do
    log "Attempt $attempt of $max_attempts: $@"
    
    "$@"
    exitCode=$?

    if [[ $exitCode == 0 ]]
    then
      break
    fi

    log "Command failed with exit code $exitCode. Retrying in $timeout seconds..."
    sleep $timeout
    attempt=$((attempt + 1))
    timeout=$((timeout * 2))
  done

  if [[ $exitCode != 0 ]]
  then
    log "Command failed after $max_attempts attempts: $@"
  fi

  return $exitCode
}

log "Setting up Swift environment with cache key: $CACHE_KEY"

# Verify Swift installation
SWIFT_VERSION=$(swift --version 2>&1 | head -n 1 || echo "Swift not found")
log "Swift version: $SWIFT_VERSION"
echo "$SWIFT_VERSION" > "$DIAGNOSTICS_DIR/swift-version.log"

# Check Xcode version
if command -v xcodebuild &> /dev/null; then
  XCODE_VERSION=$(xcodebuild -version 2>&1 | head -n 1 || echo "Xcode not found")
  log "Xcode version: $XCODE_VERSION"
  echo "$XCODE_VERSION" > "$DIAGNOSTICS_DIR/xcode-version.log"

  # Get additional Xcode info
  xcrun simctl list devices 2>&1 | grep -E "==|--" > "$DIAGNOSTICS_DIR/simulators.log" || true
fi

# Set up SwiftLint if requested
if [ "$INSTALL_SWIFTLINT" = "true" ]; then
  log "Installing SwiftLint..."
  
  if ! command -v swiftlint &> /dev/null; then
    if command -v brew &> /dev/null; then
      if [ "$ENABLE_RETRY" = "true" ]; then
        retry brew install swiftlint
      else
        brew install swiftlint
      fi
      log "SwiftLint installed via Homebrew"
    else
      log "Homebrew not available, cannot install SwiftLint"
      echo "SWIFTLINT_INSTALLED=false" >> $GITHUB_OUTPUT
    fi
  else
    log "SwiftLint already installed: $(swiftlint version)"
    echo "SWIFTLINT_INSTALLED=true" >> $GITHUB_OUTPUT
  fi
fi

# Disable code signing if requested
if [ "$DISABLE_CODE_SIGNING" = "true" ]; then
  log "Disabling code signing requirements..."
  
  # Set up environment variables for Xcode
  echo "CODE_SIGNING_REQUIRED=NO" >> $GITHUB_ENV
  echo "CODE_SIGNING_ALLOWED=NO" >> $GITHUB_ENV
  echo "EXPANDED_CODE_SIGN_IDENTITY=-" >> $GITHUB_ENV
  echo "EXPANDED_CODE_SIGN_IDENTITY_NAME=-" >> $GITHUB_ENV
  
  # Disable code signing verification in Xcode
  if command -v defaults &> /dev/null; then
    defaults write com.apple.dt.Xcode IDESkipCodeSigningVerification -bool YES
    log "Disabled code signing verification in Xcode"
  else
    log "Could not disable code signing verification in Xcode (defaults command not available)"
  fi
fi

# Get available SDKs
if command -v xcodebuild &> /dev/null; then
  log "Listing available SDKs..."
  xcodebuild -showsdks > "$DIAGNOSTICS_DIR/available-sdks.log" 2>&1 || echo "Failed to list SDKs"
fi

# Check for Swift Package Manager
if command -v swift &> /dev/null; then
  log "Verifying Swift Package Manager..."
  swift package --version > "$DIAGNOSTICS_DIR/swiftpm-version.log" 2>&1 || echo "SwiftPM might not be available"
fi

# Configure Metal environment if requested
if [[ "$CACHE_KEY" == *"metal"* || "$CACHE_KEY" == "performance" || "$CACHE_KEY" == "security-scan" ]]; then
  log "Configuring Metal environment for $CACHE_KEY..."
  
  # Create a Metal diagnostics directory
  METAL_DIAGNOSTICS_DIR="metal-setup-diagnostics"
  mkdir -p "$METAL_DIAGNOSTICS_DIR"
  
  # Set up Metal shader caching to improve CI performance
  METAL_CACHE_DIR="$GITHUB_WORKSPACE/.metal-cache"
  mkdir -p "$METAL_CACHE_DIR"
  export MTL_SHADER_CACHE_PATH="$METAL_CACHE_DIR"
  log "Set Metal shader cache path to $MTL_CACHE_DIR"
  
  # Set Metal environment variables based on the build type
  case "$METAL_CONFIG" in
    "performance")
      # Performance-focused configuration with minimal validation
      export METAL_DEVICE_WRAPPER_TYPE="default"
      export METAL_DEBUG_ERROR_MODE="silent"
      export METAL_SHADER_VALIDATION="false"
      export METAL_RUNTIME_VALIDATION="false"
      log "Metal configured for performance (minimal validation)"
      ;;
      
    "validation")
      # Maximum validation for security and correctness testing
      export METAL_DEVICE_WRAPPER_TYPE="validation"
      export METAL_DEBUG_ERROR_MODE="report"
      export METAL_SHADER_VALIDATION="true"
      export METAL_RUNTIME_VALIDATION="true"
      export MTL_SHADER_OPTIONS="debuggingEnabled=1 libraryValidation=1"
      log "Metal configured for maximum validation"
      ;;
      
    "standard"|*)
      # Standard configuration with reasonable validation
      export METAL_DEVICE_WRAPPER_TYPE="default"
      export METAL_DEBUG_ERROR_MODE="report"
      export METAL_SHADER_VALIDATION="true"
      export METAL_RUNTIME_VALIDATION="true"
      log "Metal configured with standard settings"
      ;;
  esac
  
  # Log Metal configuration
  env | grep -E "METAL_|MTL_" > "$METAL_DIAGNOSTICS_DIR/metal-environment.log" 2>&1 || true
  
  # Check if Metal framework is available
  if [ -d "/System/Library/Frameworks/Metal.framework" ]; then
    log "Metal framework detected on system"
    echo "METAL_FRAMEWORK_AVAILABLE=true" >> $GITHUB_OUTPUT
  else
    log "Metal framework not found"
    echo "METAL_FRAMEWORK_AVAILABLE=false" >> $GITHUB_OUTPUT
  fi
  
  # Additional Metal debug utilities if running on macOS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Try to get GPU information
    system_profiler SPDisplaysDataType > "$METAL_DIAGNOSTICS_DIR/gpu-info.log" 2>&1 || true
    
    # Note the Metal configuration in the outputs
    echo "METAL_CONFIG=$METAL_CONFIG" >> $GITHUB_OUTPUT
    echo "METAL_DIAGNOSTICS_DIR=$METAL_DIAGNOSTICS_DIR" >> $GITHUB_OUTPUT
  fi
fi

# Set output variables
echo "SWIFT_VERSION=$SWIFT_VERSION" >> $GITHUB_OUTPUT
echo "SETUP_COMPLETED=true" >> $GITHUB_OUTPUT
echo "DIAGNOSTICS_DIR=$DIAGNOSTICS_DIR" >> $GITHUB_OUTPUT

log "Swift environment setup completed successfully"
exit 0 