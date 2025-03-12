#!/bin/bash

# HDR+ Swift Test Data Generator
# ==============================
# This script generates test data for the HDR+ Swift project

# Configuration
TEST_RESOURCES_DIR="Tests/TestResources"
PATTERNS_DIR="$TEST_RESOURCES_DIR/TestInputs/Patterns"
RAW_DIR="$TEST_RESOURCES_DIR/TestInputs/RAW"
BURST_DIR="$TEST_RESOURCES_DIR/TestInputs/Bursts"
MOCK_DIR="$TEST_RESOURCES_DIR/Mocks"
REFERENCE_DIR="$TEST_RESOURCES_DIR/ReferenceImages"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
VERBOSE=0
GENERATE_PATTERNS=0
GENERATE_RAW=0
GENERATE_BURSTS=0
GENERATE_MOCKS=0
GENERATE_ALL=1
PATTERN_SIZE="512x512"
NOISE_LEVEL="normal"
BURST_COUNT=5
CAMERA_MODEL="default"

# Print help message
function show_help {
    echo -e "${BLUE}HDR+ Swift Test Data Generator${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                Show this help message"
    echo "  -v, --verbose             Enable verbose output"
    echo "  -p, --patterns            Generate test patterns only"
    echo "  -r, --raw                 Generate RAW test files only"
    echo "  -b, --bursts              Generate burst sequences only"
    echo "  -m, --mocks               Generate mock data only"
    echo "  --size SIZE               Pattern size (default: $PATTERN_SIZE)"
    echo "  --noise LEVEL             Noise level (low, normal, high) (default: $NOISE_LEVEL)"
    echo "  --burst-count COUNT       Number of frames in burst sequences (default: $BURST_COUNT)"
    echo "  --camera MODEL            Camera model to simulate (default: $CAMERA_MODEL)"
    echo ""
    echo "Examples:"
    echo "  $0 -p -v                  Generate patterns with verbose output"
    echo "  $0 --size 1024x768 -p     Generate patterns at 1024x768 resolution"
    echo "  $0 -b --burst-count 10    Generate burst sequences with 10 frames each"
    echo "  $0 -r --noise high        Generate RAW test files with high noise"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -p|--patterns)
            GENERATE_PATTERNS=1
            GENERATE_ALL=0
            shift
            ;;
        -r|--raw)
            GENERATE_RAW=1
            GENERATE_ALL=0
            shift
            ;;
        -b|--bursts)
            GENERATE_BURSTS=1
            GENERATE_ALL=0
            shift
            ;;
        -m|--mocks)
            GENERATE_MOCKS=1
            GENERATE_ALL=0
            shift
            ;;
        --size)
            PATTERN_SIZE="$2"
            shift
            shift
            ;;
        --noise)
            NOISE_LEVEL="$2"
            shift
            shift
            ;;
        --burst-count)
            BURST_COUNT="$2"
            shift
            shift
            ;;
        --camera)
            CAMERA_MODEL="$2"
            shift
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $key${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# Create necessary directories
function create_dirs {
    mkdir -p "$PATTERNS_DIR"
    mkdir -p "$RAW_DIR"
    mkdir -p "$BURST_DIR"
    mkdir -p "$MOCK_DIR"
    mkdir -p "$REFERENCE_DIR"
    
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}Created test resource directories${NC}"
    fi
}

# Verbose logging
function log_verbose {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${CYAN}$1${NC}"
    fi
}

# Generate test patterns
function generate_patterns {
    echo -e "${BLUE}Generating test patterns...${NC}"
    
    # Extract width and height from pattern size
    WIDTH=$(echo $PATTERN_SIZE | cut -d'x' -f1)
    HEIGHT=$(echo $PATTERN_SIZE | cut -d'x' -f2)
    
    # Check if ImageMagick is installed
    if ! command -v convert &> /dev/null; then
        echo -e "${RED}Error: ImageMagick is required to generate patterns.${NC}"
        echo "Please install ImageMagick and try again."
        return 1
    fi
    
    # Generate various test patterns
    
    # Gradient pattern
    log_verbose "Generating gradient pattern..."
    convert -size ${WIDTH}x${HEIGHT} gradient:black-white "$PATTERNS_DIR/gradient_bw_${WIDTH}x${HEIGHT}.png"
    convert -size ${WIDTH}x${HEIGHT} gradient:red-blue "$PATTERNS_DIR/gradient_rb_${WIDTH}x${HEIGHT}.png"
    
    # Checkerboard pattern
    log_verbose "Generating checkerboard pattern..."
    convert -size ${WIDTH}x${HEIGHT} pattern:checkerboard "$PATTERNS_DIR/checkerboard_${WIDTH}x${HEIGHT}.png"
    
    # Color bars
    log_verbose "Generating color bars..."
    
    # Create a 7-color bar pattern (similar to SMPTE color bars)
    WIDTH_SEGMENT=$((WIDTH / 7))
    
    convert -size ${WIDTH}x${HEIGHT} canvas:white \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(192,192,192)" \) -geometry +0+0 -composite \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(192,192,0)" \) -geometry +${WIDTH_SEGMENT}+0 -composite \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(0,192,192)" \) -geometry +$((WIDTH_SEGMENT*2))+0 -composite \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(0,192,0)" \) -geometry +$((WIDTH_SEGMENT*3))+0 -composite \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(192,0,192)" \) -geometry +$((WIDTH_SEGMENT*4))+0 -composite \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(192,0,0)" \) -geometry +$((WIDTH_SEGMENT*5))+0 -composite \
        \( -size ${WIDTH_SEGMENT}x${HEIGHT} canvas:"rgb(0,0,192)" \) -geometry +$((WIDTH_SEGMENT*6))+0 -composite \
        "$PATTERNS_DIR/color_bars_${WIDTH}x${HEIGHT}.png"
    
    # Noise pattern
    log_verbose "Generating noise pattern..."
    
    # Different noise levels
    case $NOISE_LEVEL in
        low)
            NOISE_AMOUNT=5
            ;;
        normal)
            NOISE_AMOUNT=15
            ;;
        high)
            NOISE_AMOUNT=30
            ;;
        *)
            NOISE_AMOUNT=15
            ;;
    esac
    
    convert -size ${WIDTH}x${HEIGHT} xc: +noise Random "$PATTERNS_DIR/noise_${NOISE_LEVEL}_${WIDTH}x${HEIGHT}.png"
    
    # Resolution test pattern
    log_verbose "Generating resolution test pattern..."
    
    # Create a resolution test pattern with concentric circles and lines
    convert -size ${WIDTH}x${HEIGHT} xc:white \
        -fill black -stroke black \
        -draw "circle $((WIDTH/2)),$((HEIGHT/2)) $((WIDTH/2)),$((HEIGHT/4))" \
        -draw "circle $((WIDTH/2)),$((HEIGHT/2)) $((WIDTH/2)),$((HEIGHT/3))" \
        -draw "circle $((WIDTH/2)),$((HEIGHT/2)) $((WIDTH/2)),$((HEIGHT/2))" \
        -draw "line 0,$((HEIGHT/2)) $WIDTH,$((HEIGHT/2))" \
        -draw "line $((WIDTH/2)),0 $((WIDTH/2)),$HEIGHT" \
        "$PATTERNS_DIR/resolution_${WIDTH}x${HEIGHT}.png"
    
    # Dynamic range test pattern
    log_verbose "Generating dynamic range test pattern..."
    
    # Create gradient with 10 steps from black to white
    convert -size ${WIDTH}x${HEIGHT} gradient: -evaluate Cosine 10 "$PATTERNS_DIR/dynamic_range_${WIDTH}x${HEIGHT}.png"
    
    # HDR test pattern with overexposed and underexposed regions
    log_verbose "Generating HDR test pattern..."
    
    # Create an image with both very bright and very dark areas
    convert -size ${WIDTH}x${HEIGHT} xc:gray \
        -fill white -draw "rectangle 0,0 $((WIDTH/3)),$HEIGHT" \
        -fill black -draw "rectangle $((WIDTH*2/3)),$((HEIGHT*1/3)) $WIDTH,$((HEIGHT*2/3))" \
        -blur 0x5 \
        "$PATTERNS_DIR/hdr_test_${WIDTH}x${HEIGHT}.png"
    
    # Add noise to some of the patterns
    if [ "$NOISE_LEVEL" != "low" ]; then
        log_verbose "Adding noise to patterns..."
        
        # Add noise to the gradient
        convert "$PATTERNS_DIR/gradient_bw_${WIDTH}x${HEIGHT}.png" \
            -attenuate 0.2 +noise Gaussian \
            "$PATTERNS_DIR/gradient_bw_noisy_${WIDTH}x${HEIGHT}.png"
        
        # Add noise to the HDR test pattern
        convert "$PATTERNS_DIR/hdr_test_${WIDTH}x${HEIGHT}.png" \
            -attenuate 0.15 +noise Gaussian \
            "$PATTERNS_DIR/hdr_test_noisy_${WIDTH}x${HEIGHT}.png"
    fi
    
    echo -e "${GREEN}✅ Generated test patterns in: $PATTERNS_DIR${NC}"
    return 0
}

# Generate simulated RAW files
function generate_raw_files {
    echo -e "${BLUE}Generating simulated RAW files...${NC}"
    
    # Check if dcraw is installed (useful for raw file manipulation)
    if ! command -v dcraw &> /dev/null; then
        echo -e "${YELLOW}Warning: dcraw is not installed. Using ImageMagick for RAW simulation.${NC}"
        USE_DCRAW=0
    else
        USE_DCRAW=1
    fi
    
    # Extract width and height from pattern size
    WIDTH=$(echo $PATTERN_SIZE | cut -d'x' -f1)
    HEIGHT=$(echo $PATTERN_SIZE | cut -d'x' -f2)
    
    # Ensure width and height are even (for Bayer pattern)
    WIDTH=$((WIDTH + (WIDTH % 2)))
    HEIGHT=$((HEIGHT + (HEIGHT % 2)))
    
    log_verbose "Creating simulated RAW files (${WIDTH}x${HEIGHT})..."
    
    # Create a simulated RAW file (we'll use TIFF format with metadata)
    # For a proper RAW file simulator, a more complex tool would be needed,
    # but this will create files that can be used for testing
    
    # Normal exposure
    convert -size ${WIDTH}x${HEIGHT} xc:gray \
        -attenuate 0.05 +noise Gaussian \
        -depth 16 \
        "$RAW_DIR/normal_exposure_${WIDTH}x${HEIGHT}.tiff"
    
    # Underexposed
    convert -size ${WIDTH}x${HEIGHT} xc:gray -brightness-contrast -50x0 \
        -attenuate 0.2 +noise Gaussian \
        -depth 16 \
        "$RAW_DIR/underexposed_${WIDTH}x${HEIGHT}.tiff"
    
    # Overexposed
    convert -size ${WIDTH}x${HEIGHT} xc:gray -brightness-contrast 50x0 \
        -attenuate 0.01 +noise Gaussian \
        -depth 16 \
        "$RAW_DIR/overexposed_${WIDTH}x${HEIGHT}.tiff"
    
    # Add different noise levels
    case $NOISE_LEVEL in
        low)
            NOISE_AMOUNT=0.05
            ;;
        normal)
            NOISE_AMOUNT=0.15
            ;;
        high)
            NOISE_AMOUNT=0.3
            ;;
        *)
            NOISE_AMOUNT=0.15
            ;;
    esac
    
    # Create a noisy image
    convert -size ${WIDTH}x${HEIGHT} xc:gray \
        -attenuate $NOISE_AMOUNT +noise Gaussian \
        -depth 16 \
        "$RAW_DIR/noisy_${NOISE_LEVEL}_${WIDTH}x${HEIGHT}.tiff"
    
    # Add simulated Bayer pattern metadata
    if [ $USE_DCRAW -eq 1 ]; then
        log_verbose "Adding Bayer pattern metadata using dcraw..."
        # This would need a more sophisticated approach in a real implementation
    fi
    
    # Create JSON metadata files for the simulated RAW files
    log_verbose "Creating metadata files..."
    
    # Normal exposure metadata
    cat > "$RAW_DIR/normal_exposure_${WIDTH}x${HEIGHT}.json" << EOF
{
    "width": $WIDTH,
    "height": $HEIGHT,
    "bitsPerSample": 16,
    "bayerPattern": "RGGB",
    "iso": 100,
    "exposureTime": 0.01,
    "aperture": 2.8,
    "whiteLevel": 65535,
    "blackLevel": [256, 256, 256, 256],
    "colorMatrix": [
        2.0, -0.5, -0.2,
        -0.5, 1.8, -0.1,
        -0.2, -0.1, 1.5
    ]
}
EOF
    
    # Underexposed metadata
    cat > "$RAW_DIR/underexposed_${WIDTH}x${HEIGHT}.json" << EOF
{
    "width": $WIDTH,
    "height": $HEIGHT,
    "bitsPerSample": 16,
    "bayerPattern": "RGGB",
    "iso": 400,
    "exposureTime": 0.0025,
    "aperture": 2.8,
    "whiteLevel": 65535,
    "blackLevel": [256, 256, 256, 256],
    "colorMatrix": [
        2.0, -0.5, -0.2,
        -0.5, 1.8, -0.1,
        -0.2, -0.1, 1.5
    ]
}
EOF
    
    # Overexposed metadata
    cat > "$RAW_DIR/overexposed_${WIDTH}x${HEIGHT}.json" << EOF
{
    "width": $WIDTH,
    "height": $HEIGHT,
    "bitsPerSample": 16,
    "bayerPattern": "RGGB",
    "iso": 100,
    "exposureTime": 0.04,
    "aperture": 2.8,
    "whiteLevel": 65535,
    "blackLevel": [256, 256, 256, 256],
    "colorMatrix": [
        2.0, -0.5, -0.2,
        -0.5, 1.8, -0.1,
        -0.2, -0.1, 1.5
    ]
}
EOF
    
    echo -e "${GREEN}✅ Generated simulated RAW files in: $RAW_DIR${NC}"
    return 0
}

# Generate burst sequences
function generate_burst_sequences {
    echo -e "${BLUE}Generating burst sequences...${NC}"
    
    # Extract width and height from pattern size
    WIDTH=$(echo $PATTERN_SIZE | cut -d'x' -f1)
    HEIGHT=$(echo $PATTERN_SIZE | cut -d'x' -f2)
    
    # Ensure width and height are even (for Bayer pattern)
    WIDTH=$((WIDTH + (WIDTH % 2)))
    HEIGHT=$((HEIGHT + (HEIGHT % 2)))
    
    # Create directories for different burst sequences
    mkdir -p "$BURST_DIR/static_scene"
    mkdir -p "$BURST_DIR/motion_scene"
    mkdir -p "$BURST_DIR/low_light"
    
    log_verbose "Creating burst sequences with $BURST_COUNT frames each..."
    
    # Generate static scene burst
    log_verbose "Generating static scene burst..."
    
    # Create burst metadata
    cat > "$BURST_DIR/static_scene/metadata.json" << EOF
{
    "frameCount": $BURST_COUNT,
    "sceneName": "Static Scene",
    "description": "A static scene with minimal movement between frames",
    "baseExposure": 0.01,
    "baseIso": 100,
    "whiteBalanceRGB": [2.1, 1.0, 1.9]
}
EOF
    
    # Create frames for static scene (minimal variation)
    for i in $(seq 0 $((BURST_COUNT-1))); do
        # Add very slight random variations to simulate minor camera shake
        JITTER_X=$((RANDOM % 5 - 2))
        JITTER_Y=$((RANDOM % 5 - 2))
        
        # Create the frame
        convert -size ${WIDTH}x${HEIGHT} xc:gray \
            -roll +${JITTER_X}+${JITTER_Y} \
            -attenuate 0.05 +noise Gaussian \
            -depth 16 \
            "$BURST_DIR/static_scene/frame_${i}.tiff"
        
        # Create frame metadata
        cat > "$BURST_DIR/static_scene/frame_${i}.json" << EOF
{
    "frameIndex": $i,
    "exposureTime": 0.01,
    "iso": 100,
    "timestamp": $(($(date +%s) + i)),
    "motionVector": [$JITTER_X, $JITTER_Y]
}
EOF
    done
    
    # Generate motion scene burst
    log_verbose "Generating motion scene burst..."
    
    # Create burst metadata
    cat > "$BURST_DIR/motion_scene/metadata.json" << EOF
{
    "frameCount": $BURST_COUNT,
    "sceneName": "Motion Scene",
    "description": "A scene with significant movement between frames",
    "baseExposure": 0.01,
    "baseIso": 100,
    "whiteBalanceRGB": [2.1, 1.0, 1.9]
}
EOF
    
    # Create a base image with some shapes
    convert -size ${WIDTH}x${HEIGHT} xc:white \
        -fill black -draw "rectangle 100,100 300,300" \
        -fill gray50 -draw "circle 400,200 450,250" \
        "$BURST_DIR/motion_scene/base.png"
        
    # Create frames for motion scene (significant variation)
    for i in $(seq 0 $((BURST_COUNT-1))); do
        # Add more significant movement to simulate object motion
        MOTION_X=$((i * 20 - ((BURST_COUNT-1) * 10)))
        MOTION_Y=$((i * 5 - ((BURST_COUNT-1) * 2)))
        
        # Create the frame
        convert "$BURST_DIR/motion_scene/base.png" \
            -roll +${MOTION_X}+${MOTION_Y} \
            -attenuate 0.05 +noise Gaussian \
            -depth 16 \
            "$BURST_DIR/motion_scene/frame_${i}.tiff"
        
        # Create frame metadata
        cat > "$BURST_DIR/motion_scene/frame_${i}.json" << EOF
{
    "frameIndex": $i,
    "exposureTime": 0.01,
    "iso": 100,
    "timestamp": $(($(date +%s) + i)),
    "motionVector": [$MOTION_X, $MOTION_Y]
}
EOF
    done
    
    # Clean up base image
    rm "$BURST_DIR/motion_scene/base.png"
    
    # Generate low light burst
    log_verbose "Generating low light burst..."
    
    # Create burst metadata
    cat > "$BURST_DIR/low_light/metadata.json" << EOF
{
    "frameCount": $BURST_COUNT,
    "sceneName": "Low Light",
    "description": "A low light scene with higher ISO and noise",
    "baseExposure": 0.05,
    "baseIso": 1600,
    "whiteBalanceRGB": [2.1, 1.0, 1.9]
}
EOF
    
    # Create frames for low light scene (high noise)
    for i in $(seq 0 $((BURST_COUNT-1))); do
        # Add slight random variations
        JITTER_X=$((RANDOM % 5 - 2))
        JITTER_Y=$((RANDOM % 5 - 2))
        
        # Create the frame with high noise
        convert -size ${WIDTH}x${HEIGHT} xc:gray \
            -brightness-contrast -30x0 \
            -roll +${JITTER_X}+${JITTER_Y} \
            -attenuate 0.3 +noise Gaussian \
            -depth 16 \
            "$BURST_DIR/low_light/frame_${i}.tiff"
        
        # Create frame metadata
        cat > "$BURST_DIR/low_light/frame_${i}.json" << EOF
{
    "frameIndex": $i,
    "exposureTime": 0.05,
    "iso": 1600,
    "timestamp": $(($(date +%s) + i)),
    "motionVector": [$JITTER_X, $JITTER_Y]
}
EOF
    done
    
    echo -e "${GREEN}✅ Generated burst sequences in: $BURST_DIR${NC}"
    return 0
}

# Generate mock data
function generate_mocks {
    echo -e "${BLUE}Generating mock data...${NC}"
    
    # Create camera info mocks
    log_verbose "Creating camera info mocks..."
    
    # Create default camera model
    cat > "$MOCK_DIR/camera_default.json" << EOF
{
    "model": "Default Camera",
    "sensorWidth": 4032,
    "sensorHeight": 3024,
    "pixelSize": 1.4,
    "hasRawSupport": true,
    "maxIso": 3200,
    "maxShutterSpeed": 30.0,
    "minShutterSpeed": 0.000125,
    "supportedApertures": [1.8, 2.8, 4.0, 5.6, 8.0],
    "defaultAperture": 1.8,
    "focalLength": 26.0,
    "cropFactor": 1.0,
    "bayerPattern": "RGGB",
    "bitDepth": 14,
    "whiteLevel": 16383,
    "blackLevel": [256, 256, 256, 256],
    "colorMatrices": {
        "D65": [
            2.0, -0.5, -0.2,
            -0.5, 1.8, -0.1,
            -0.2, -0.1, 1.5
        ],
        "A": [
            1.8, -0.4, -0.1,
            -0.4, 1.9, -0.2,
            -0.1, -0.2, 1.6
        ]
    }
}
EOF
    
    # Create a custom camera model if specified
    if [ "$CAMERA_MODEL" != "default" ]; then
        log_verbose "Creating custom camera model: $CAMERA_MODEL..."
        
        # Adjust parameters based on the camera model
        case $CAMERA_MODEL in
            highres)
                WIDTH=8192
                HEIGHT=6144
                ;;
            lowlight)
                ISO=12800
                PIXEL_SIZE=2.4
                ;;
            *)
                WIDTH=4032
                HEIGHT=3024
                ISO=3200
                PIXEL_SIZE=1.4
                ;;
        esac
        
        # Create the custom camera model
        cat > "$MOCK_DIR/camera_${CAMERA_MODEL}.json" << EOF
{
    "model": "${CAMERA_MODEL} Camera",
    "sensorWidth": ${WIDTH},
    "sensorHeight": ${HEIGHT},
    "pixelSize": ${PIXEL_SIZE},
    "hasRawSupport": true,
    "maxIso": ${ISO},
    "maxShutterSpeed": 30.0,
    "minShutterSpeed": 0.000125,
    "supportedApertures": [1.8, 2.8, 4.0, 5.6, 8.0],
    "defaultAperture": 1.8,
    "focalLength": 26.0,
    "cropFactor": 1.0,
    "bayerPattern": "RGGB",
    "bitDepth": 14,
    "whiteLevel": 16383,
    "blackLevel": [256, 256, 256, 256],
    "colorMatrices": {
        "D65": [
            2.0, -0.5, -0.2,
            -0.5, 1.8, -0.1,
            -0.2, -0.1, 1.5
        ],
        "A": [
            1.8, -0.4, -0.1,
            -0.4, 1.9, -0.2,
            -0.1, -0.2, 1.6
        ]
    }
}
EOF
    fi
    
    # Create pipeline configuration mocks
    log_verbose "Creating pipeline configuration mocks..."
    
    # Create default pipeline configuration
    cat > "$MOCK_DIR/pipeline_default.json" << EOF
{
    "name": "Default Pipeline",
    "stages": [
        {
            "name": "demosaic",
            "enabled": true,
            "parameters": {
                "algorithm": "malvar",
                "edgeThreshold": 0.1
            }
        },
        {
            "name": "denoise",
            "enabled": true,
            "parameters": {
                "algorithm": "nlm",
                "strength": 0.5,
                "colorStrength": 0.3,
                "spatialSigma": 2.0
            }
        },
        {
            "name": "colorCorrection",
            "enabled": true,
            "parameters": {
                "temperature": 5500,
                "tint": 0.0,
                "saturation": 1.0,
                "vibrance": 0.2
            }
        },
        {
            "name": "tonemap",
            "enabled": true,
            "parameters": {
                "algorithm": "reinhard",
                "exposure": 0.0,
                "contrast": 1.0,
                "highlights": -0.2,
                "shadows": 0.3,
                "whites": 1.0,
                "blacks": 0.0
            }
        },
        {
            "name": "sharpen",
            "enabled": true,
            "parameters": {
                "strength": 0.5,
                "radius": 1.0,
                "threshold": 5.0
            }
        }
    ],
    "output": {
        "format": "jpeg",
        "quality": 95,
        "colorSpace": "sRGB",
        "bitDepth": 8
    }
}
EOF
    
    # Create a HDR pipeline configuration
    cat > "$MOCK_DIR/pipeline_hdr.json" << EOF
{
    "name": "HDR Pipeline",
    "stages": [
        {
            "name": "demosaic",
            "enabled": true,
            "parameters": {
                "algorithm": "malvar",
                "edgeThreshold": 0.1
            }
        },
        {
            "name": "align",
            "enabled": true,
            "parameters": {
                "algorithm": "feature_based",
                "maxShift": 32,
                "pyramidLevels": 3
            }
        },
        {
            "name": "merge",
            "enabled": true,
            "parameters": {
                "algorithm": "mertens",
                "contrastWeight": 1.0,
                "saturationWeight": 1.0,
                "exposureWeight": 0.0
            }
        },
        {
            "name": "denoise",
            "enabled": true,
            "parameters": {
                "algorithm": "nlm",
                "strength": 0.3,
                "colorStrength": 0.2,
                "spatialSigma": 2.0
            }
        },
        {
            "name": "colorCorrection",
            "enabled": true,
            "parameters": {
                "temperature": 5500,
                "tint": 0.0,
                "saturation": 1.1,
                "vibrance": 0.3
            }
        },
        {
            "name": "tonemap",
            "enabled": true,
            "parameters": {
                "algorithm": "reinhard",
                "exposure": 0.0,
                "contrast": 1.1,
                "highlights": -0.3,
                "shadows": 0.4,
                "whites": 1.0,
                "blacks": 0.0
            }
        },
        {
            "name": "sharpen",
            "enabled": true,
            "parameters": {
                "strength": 0.4,
                "radius": 1.0,
                "threshold": 5.0
            }
        }
    ],
    "output": {
        "format": "jpeg",
        "quality": 95,
        "colorSpace": "sRGB",
        "bitDepth": 8
    }
}
EOF
    
    # Create low-light pipeline configuration
    cat > "$MOCK_DIR/pipeline_lowlight.json" << EOF
{
    "name": "Low Light Pipeline",
    "stages": [
        {
            "name": "demosaic",
            "enabled": true,
            "parameters": {
                "algorithm": "malvar",
                "edgeThreshold": 0.15
            }
        },
        {
            "name": "align",
            "enabled": true,
            "parameters": {
                "algorithm": "feature_based",
                "maxShift": 32,
                "pyramidLevels": 3
            }
        },
        {
            "name": "merge",
            "enabled": true,
            "parameters": {
                "algorithm": "wiener",
                "sigmaNoise": 0.05,
                "temporalRadius": 4
            }
        },
        {
            "name": "denoise",
            "enabled": true,
            "parameters": {
                "algorithm": "nlm",
                "strength": 0.7,
                "colorStrength": 0.5,
                "spatialSigma": 3.0
            }
        },
        {
            "name": "colorCorrection",
            "enabled": true,
            "parameters": {
                "temperature": 5500,
                "tint": 0.0,
                "saturation": 1.0,
                "vibrance": 0.2
            }
        },
        {
            "name": "tonemap",
            "enabled": true,
            "parameters": {
                "algorithm": "reinhard",
                "exposure": 0.5,
                "contrast": 1.0,
                "highlights": -0.1,
                "shadows": 0.5,
                "whites": 1.0,
                "blacks": 0.1
            }
        },
        {
            "name": "sharpen",
            "enabled": true,
            "parameters": {
                "strength": 0.3,
                "radius": 1.0,
                "threshold": 8.0
            }
        }
    ],
    "output": {
        "format": "jpeg",
        "quality": 95,
        "colorSpace": "sRGB",
        "bitDepth": 8
    }
}
EOF
    
    # Create system info mock
    log_verbose "Creating system info mock..."
    
    cat > "$MOCK_DIR/system_info.json" << EOF
{
    "os": "macOS",
    "osVersion": "13.4",
    "cpuModel": "Apple M1 Max",
    "cpuCores": 10,
    "ramGB": 32,
    "gpuModel": "Apple M1 Max",
    "gpuMemoryGB": 32,
    "metalSupported": true,
    "metalVersion": "3.0",
    "diskSpaceGB": 512,
    "freeDiskSpaceGB": 256
}
EOF
    
    echo -e "${GREEN}✅ Generated mock data in: $MOCK_DIR${NC}"
    return 0
}

# Main function to generate test data
function generate_test_data {
    create_dirs
    
    # Generate selected data types
    if [ $GENERATE_PATTERNS -eq 1 ] || [ $GENERATE_ALL -eq 1 ]; then
        generate_patterns
    fi
    
    if [ $GENERATE_RAW -eq 1 ] || [ $GENERATE_ALL -eq 1 ]; then
        generate_raw_files
    fi
    
    if [ $GENERATE_BURSTS -eq 1 ] || [ $GENERATE_ALL -eq 1 ]; then
        generate_burst_sequences
    fi
    
    if [ $GENERATE_MOCKS -eq 1 ] || [ $GENERATE_ALL -eq 1 ]; then
        generate_mocks
    fi
    
    # Print summary
    echo -e "${BLUE}Test Data Generation Summary:${NC}"
    echo -e "Pattern size: ${CYAN}$PATTERN_SIZE${NC}"
    echo -e "Noise level: ${CYAN}$NOISE_LEVEL${NC}"
    echo -e "Burst count: ${CYAN}$BURST_COUNT${NC}"
    echo -e "Camera model: ${CYAN}$CAMERA_MODEL${NC}"
    echo ""
    echo -e "${GREEN}All test data generated successfully!${NC}"
    echo -e "Test resources directory: ${CYAN}$TEST_RESOURCES_DIR${NC}"
}

# Run the generator
generate_test_data
exit 0 