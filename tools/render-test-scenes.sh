#!/bin/bash
# HDR+ Swift Metal Test Scene Renderer
# This script generates standardized test scenes for visual regression testing
set -e

# Parse arguments
COUNT=5
OUTPUT_DIR="renders"
VERBOSE=false

function show_help() {
  echo "Usage: render-test-scenes.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --count NUMBER       Number of test scenes to render (default: 5)"
  echo "  --output DIRECTORY   Output directory for renders (default: 'renders')"
  echo "  --verbose            Enable verbose output"
  echo "  --help               Display this help message"
  echo ""
  echo "Example:"
  echo "  ./render-test-scenes.sh --count 10 --output test-renders"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)
      COUNT="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Set up color codes for terminal output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to log verbose messages
log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${YELLOW}[VERBOSE]${NC} $1"
  fi
}

echo -e "${GREEN}HDR+ Swift Metal Test Scene Renderer${NC}"
echo "Generating $COUNT test scenes in $OUTPUT_DIR..."

# Define test scenes
# In a real implementation, these would be representative scenes for HDR+ processing
declare -a SCENE_NAMES=(
  "bright_outdoor_scene"
  "indoor_low_light"
  "high_dynamic_range"
  "portrait_mode"
  "night_mode"
  "macro_detail"
  "landscape_sunset"
  "cityscape_night"
  "motion_blur_test"
  "color_calibration"
)

# Function to render a scene using Metal
render_scene() {
  local scene_index=$1
  local scene_name=${SCENE_NAMES[$(( (scene_index - 1) % ${#SCENE_NAMES[@]} ))]}
  local output_file="$OUTPUT_DIR/scene_${scene_index}.png"
  
  echo "Rendering scene $scene_index: $scene_name..."
  
  # Generate a unique seed for this scene for reproducibility
  local SEED=$((1000 + scene_index))
  
  # In a real implementation, this would use your app's actual Metal renderer
  # For this example, we'll create a test pattern with sips (built-in to macOS)
  # or ImageMagick if available
  
  # Image dimensions
  local WIDTH=1024
  local HEIGHT=768
  
  log_verbose "Creating test image with dimensions ${WIDTH}x${HEIGHT}"
  
  # Use ImageMagick if available for more interesting test images
  if command -v convert &> /dev/null; then
    log_verbose "Using ImageMagick to generate test image"
    
    # Make the pattern deterministic based on scene index
    local HUE=$(( (scene_index * 35) % 360 ))
    local SATURATION=$(( 70 + (scene_index * 3) % 30 ))
    local BRIGHTNESS=$(( 80 + (scene_index * 5) % 20 ))
    
    # Create a more complex test image based on scene type
    case "$scene_name" in
      "bright_outdoor_scene")
        # Bright blue sky with gradient
        convert -size ${WIDTH}x${HEIGHT} -define gradient:angle=0 gradient:rgb(135,206,250)-rgb(25,25,112) "$output_file"
        ;;
      "indoor_low_light")
        # Darker indoor tones
        convert -size ${WIDTH}x${HEIGHT} -define gradient:angle=45 gradient:rgb(72,61,63)-rgb(32,21,23) "$output_file"
        ;;
      "high_dynamic_range")
        # High contrast image
        convert -size ${WIDTH}x${HEIGHT} -define gradient:angle=135 gradient:rgb(255,255,255)-rgb(0,0,0) "$output_file"
        ;;
      "portrait_mode")
        # Skin tone-like gradient with a circular mask for portrait effect
        convert -size ${WIDTH}x${HEIGHT} gradient:rgb(245,222,179)-rgb(160,120,90) \
          \( -size ${WIDTH}x${HEIGHT} -gravity center -fill white -draw "circle $((WIDTH/2)),$((HEIGHT/2)) $((WIDTH/3)),$((HEIGHT/2))" -negate \) \
          -compose multiply -composite "$output_file"
        ;;
      *)
        # Default gradient based on scene parameters
        convert -size ${WIDTH}x${HEIGHT} -seed $SEED -define gradient:angle=45 \
          gradient:hsb\(${HUE}%,${SATURATION}%,${BRIGHTNESS}%\)-hsb\($(((HUE+30)%360))%,$(((SATURATION+10)%100))%,$(((BRIGHTNESS-10)%100))%\) \
          "$output_file"
        ;;
    esac
  else
    log_verbose "ImageMagick not found, using sips to generate basic test image"
    
    # Create a temporary PNG with blank background
    local TEMP_FILE="$OUTPUT_DIR/temp_${scene_index}.png"
    
    # Create blank canvas
    # The bkgColor parameters are RGB values from 0-1
    local R=$(echo "scale=3; (($scene_index * 35) % 256) / 255" | bc)
    local G=$(echo "scale=3; (($scene_index * 75) % 256) / 255" | bc)
    local B=$(echo "scale=3; (($scene_index * 95) % 256) / 255" | bc)
    
    log_verbose "Creating base image with color R:$R G:$G B:$B"
    
    sips -s format png -s formatOptions 100 \
      -g pixelWidth $WIDTH -g pixelHeight $HEIGHT \
      -s bkgColor $R $G $B \
      temp.jpeg --out "$output_file" &>/dev/null
      
    # For more complex patterns, you would call into your app's CLI renderer here
  fi
  
  log_verbose "Successfully created test image: $output_file"
  
  # Add metadata to the image for identification
  if command -v exiftool &> /dev/null; then
    log_verbose "Adding metadata to image"
    exiftool -overwrite_original -Creator="HDR+ Swift Test" -Title="$scene_name" "$output_file" &>/dev/null || true
  fi
}

# Render each test scene
for i in $(seq 1 $COUNT); do
  render_scene $i
done

echo -e "${GREEN}Successfully generated $COUNT test scenes in $OUTPUT_DIR${NC}"
ls -la "$OUTPUT_DIR" 