#!/bin/bash
# Script to set up a consistent Swift development environment
# This is used by various CI workflows to ensure consistent setup

set -eo pipefail

# Parse arguments
CACHE_KEY="${1:-default}"
INSTALL_SWIFTLINT="${2:-false}"
DISABLE_CODE_SIGNING="${3:-true}"
ENABLE_RETRY="${4:-false}"

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

# Set output variables
echo "SWIFT_VERSION=$SWIFT_VERSION" >> $GITHUB_OUTPUT
echo "SETUP_COMPLETED=true" >> $GITHUB_OUTPUT
echo "DIAGNOSTICS_DIR=$DIAGNOSTICS_DIR" >> $GITHUB_OUTPUT

log "Swift environment setup completed successfully"
exit 0 