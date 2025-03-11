#!/bin/bash
set -e

# ------------------------------
# HDR Plus Swift Test Runner
# ------------------------------

# Configuration
TEST_RESULTS_DIR="test-results"
PERFORMANCE_DIR="$TEST_RESULTS_DIR/performance"
FLAKY_TRACKING_DIR="$TEST_RESULTS_DIR/flaky"
VISUAL_RESULTS_DIR="$TEST_RESULTS_DIR/visual"
REPORT_FILE="$TEST_RESULTS_DIR/test-report.md"
DEFAULT_RETRY_COUNT=2
PERFORMANCE_HISTORY_FILE="performance_history.csv"
FLAKY_HISTORY_FILE="flaky_tests.json"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Command line arguments
RETRY_FLAKY=true
RUN_PERFORMANCE=true
RUN_VISUAL=true
VERBOSE=false
RETRY_COUNT=$DEFAULT_RETRY_COUNT
SELECTED_TESTS=""

# ------------------------------
# Helper functions
# ------------------------------

print_help() {
    echo -e "${BLUE}HDR Plus Swift Test Runner${NC}"
    echo ""
    echo "Usage: $0 [options] [test_filter]"
    echo ""
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo "  -v, --verbose          Show verbose output"
    echo "  -p, --performance      Run performance tests only"
    echo "  -u, --unit             Run unit tests only"
    echo "  -i, --integration      Run integration tests only"
    echo "  -m, --metal            Run metal tests only"
    echo "  -s, --visual           Run visual tests only"
    echo "  --no-flaky             Don't retry flaky tests"
    echo "  --no-performance       Don't run performance tests"
    echo "  --no-visual            Don't run visual tests"
    echo "  --retry <count>        Set retry count for flaky tests (default: $DEFAULT_RETRY_COUNT)"
    echo ""
    echo "Examples:"
    echo "  $0                     Run all tests"
    echo "  $0 HDRProcessingTests  Run only HDRProcessingTests"
    echo "  $0 -u -m               Run only unit and metal tests"
    echo "  $0 --retry 3           Run tests with 3 retries for flaky tests"
    echo ""
}

create_dirs() {
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$PERFORMANCE_DIR"
    mkdir -p "$FLAKY_TRACKING_DIR"
    mkdir -p "$VISUAL_RESULTS_DIR"
}

print_section() {
    echo -e "\n${BLUE}========== $1 ==========${NC}\n"
}

print_subsection() {
    echo -e "\n${CYAN}---------- $1 ----------${NC}\n"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "$1"
    fi
}

# ------------------------------
# Test execution functions
# ------------------------------

run_unit_tests() {
    print_section "Running Unit Tests"
    
    if [[ -n "$SELECTED_TESTS" ]]; then
        TEST_FILTER="-only-testing:$SELECTED_TESTS"
    else
        TEST_FILTER=""
    fi
    
    XCTEST_OUTPUT="$TEST_RESULTS_DIR/unit_tests_output.log"
    XCTEST_RESULT="$TEST_RESULTS_DIR/unit_tests_result.xml"
    
    echo "Running xcodebuild test... (output logged to $XCTEST_OUTPUT)"
    
    # Run tests and capture both stdout and the return code
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild test -scheme HDRPlus -destination 'platform=macOS' $TEST_FILTER -resultBundlePath "./test-results.xcresult" | tee "$XCTEST_OUTPUT" || true
    else
        xcodebuild test -scheme HDRPlus -destination 'platform=macOS' $TEST_FILTER -resultBundlePath "./test-results.xcresult" > "$XCTEST_OUTPUT" 2>&1 || true
    fi
    
    # Extract test summary information
    TOTAL_TESTS=$(grep -o "Test Suite.*" "$XCTEST_OUTPUT" | grep -v " 0 tests" | wc -l | tr -d '[:space:]')
    FAILED_TESTS=$(grep -o "Test Case.*failed" "$XCTEST_OUTPUT" | wc -l | tr -d '[:space:]')
    PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
    
    # Print summary
    echo -e "\nTest Summary:"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Failed: $FAILED_TESTS${NC}"
        
        # Print failed tests
        echo -e "\nFailed Tests:"
        grep -o "Test Case.*failed" "$XCTEST_OUTPUT" | sed 's/Test Case//' | sort
        
        # Track potentially flaky tests
        if [[ "$RETRY_FLAKY" == true && $FAILED_TESTS -gt 0 ]]; then
            retry_flaky_tests
        fi
    else
        echo -e "${GREEN}All tests passed!${NC}"
    fi
}

retry_flaky_tests() {
    print_subsection "Retrying Failed Tests"
    
    # Extract failed test names
    FAILED_TEST_NAMES=$(grep -o "Test Case.*failed" "$XCTEST_OUTPUT" | sed -E 's/.*\[([^]]+) ([^]]+)\].*/\1\/\2/' | sort | uniq)
    
    # Initialize flaky test tracking
    FLAKY_TESTS_JSON="$FLAKY_TRACKING_DIR/$FLAKY_HISTORY_FILE"
    
    if [[ -f "$FLAKY_TESTS_JSON" ]]; then
        FLAKY_TESTS_DATA=$(cat "$FLAKY_TESTS_JSON")
    else
        FLAKY_TESTS_DATA="{}"
    fi
    
    # Process each failed test
    for TEST_NAME in $FAILED_TEST_NAMES; do
        echo -e "Retrying test: ${YELLOW}$TEST_NAME${NC}"
        
        # Get class and method from test name
        TEST_CLASS=$(echo "$TEST_NAME" | cut -d'/' -f1)
        TEST_METHOD=$(echo "$TEST_NAME" | cut -d'/' -f2)
        
        # Retry the test
        for i in $(seq 1 $RETRY_COUNT); do
            echo -e "  Retry $i of $RETRY_COUNT..."
            
            RETRY_LOG="$FLAKY_TRACKING_DIR/${TEST_CLASS}_${TEST_METHOD}_retry$i.log"
            
            if [[ "$VERBOSE" == true ]]; then
                xcodebuild test -scheme HDRPlus -destination 'platform=macOS' -only-testing:"$TEST_CLASS/$TEST_METHOD" | tee "$RETRY_LOG" || true
            else
                xcodebuild test -scheme HDRPlus -destination 'platform=macOS' -only-testing:"$TEST_CLASS/$TEST_METHOD" > "$RETRY_LOG" 2>&1 || true
            fi
            
            # Check if the test passed on retry
            if ! grep -q "failed" "$RETRY_LOG"; then
                echo -e "  ${GREEN}Test passed on retry $i${NC}"
                
                # Update flaky test tracking
                CURRENT_DATE=$(date "+%Y-%m-%d")
                
                # Add/update this test in the flaky tracking data
                # This is a simple approach - in a real implementation you'd want to use a proper JSON parser
                if echo "$FLAKY_TESTS_DATA" | grep -q "\"$TEST_NAME\""; then
                    # Update existing entry
                    FLAKY_TESTS_DATA=$(echo "$FLAKY_TESTS_DATA" | sed -E "s/(\"$TEST_NAME\":[[:space:]]*\{[^}]*\"count\":[[:space:]]*)([0-9]+)/\1$(($2+1))/")
                    FLAKY_TESTS_DATA=$(echo "$FLAKY_TESTS_DATA" | sed -E "s/(\"$TEST_NAME\":[[:space:]]*\{[^}]*\"last_seen\":[[:space:]]*)\"[^\"]*\"/\1\"$CURRENT_DATE\"/")
                else
                    # Add new entry
                    NEW_ENTRY="\"$TEST_NAME\": { \"count\": 1, \"first_seen\": \"$CURRENT_DATE\", \"last_seen\": \"$CURRENT_DATE\" }"
                    FLAKY_TESTS_DATA=$(echo "$FLAKY_TESTS_DATA" | sed -E "s/\}/,${NEW_ENTRY}\}/")
                fi
                
                break
            else
                echo -e "  ${RED}Test failed on retry $i${NC}"
            fi
        done
    done
    
    # Save updated flaky test tracking
    echo "$FLAKY_TESTS_DATA" > "$FLAKY_TESTS_JSON"
    
    echo -e "\nFlaky test tracking updated in $FLAKY_TESTS_JSON"
}

run_performance_tests() {
    if [[ "$RUN_PERFORMANCE" != true ]]; then
        return
    fi
    
    print_section "Running Performance Tests"
    
    if [[ -n "$SELECTED_TESTS" ]]; then
        TEST_FILTER="-only-testing:$SELECTED_TESTS"
    else
        TEST_FILTER="-only-testing:PerformanceTests"
    fi
    
    PERF_OUTPUT="$TEST_RESULTS_DIR/performance_tests_output.log"
    
    echo "Running performance tests... (output logged to $PERF_OUTPUT)"
    
    # Set environment variable to specify where performance results should be stored
    export CI_PERFORMANCE_RESULTS_DIR="$PERFORMANCE_DIR"
    
    # Run performance tests
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild test -scheme HDRPlus -destination 'platform=macOS' $TEST_FILTER | tee "$PERF_OUTPUT" || true
    else
        xcodebuild test -scheme HDRPlus -destination 'platform=macOS' $TEST_FILTER > "$PERF_OUTPUT" 2>&1 || true
    fi
    
    # Analyze performance results
    PERFORMANCE_CSV="$PERFORMANCE_DIR/$PERFORMANCE_HISTORY_FILE"
    
    if [[ -f "$PERFORMANCE_CSV" ]]; then
        echo -e "\nPerformance history updated in $PERFORMANCE_CSV"
        
        # Generate performance charts
        generate_performance_charts
    else
        echo -e "\n${YELLOW}No performance history found${NC}"
    fi
}

generate_performance_charts() {
    print_subsection "Generating Performance Charts"
    
    echo "Performance charts would be generated here"
    # In a real implementation, you would generate charts from the CSV data
    # using a tool like gnuplot, matplotlib, or a custom script
    
    # Placeholder for chart generation
    echo -e "Performance data available in: ${CYAN}$PERFORMANCE_CSV${NC}"
}

run_visual_tests() {
    if [[ "$RUN_VISUAL" != true ]]; then
        return
    fi
    
    print_section "Running Visual Tests"
    
    if [[ -n "$SELECTED_TESTS" ]]; then
        TEST_FILTER="-only-testing:$SELECTED_TESTS"
    else
        TEST_FILTER="-only-testing:VisualTests"
    fi
    
    VISUAL_OUTPUT="$TEST_RESULTS_DIR/visual_tests_output.log"
    
    echo "Running visual tests... (output logged to $VISUAL_OUTPUT)"
    
    # Set environment variable to specify where visual test results should be stored
    export VISUAL_TEST_RESULTS_DIR="$VISUAL_RESULTS_DIR"
    
    # Run visual tests
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild test -scheme HDRPlus -destination 'platform=macOS' $TEST_FILTER | tee "$VISUAL_OUTPUT" || true
    else
        xcodebuild test -scheme HDRPlus -destination 'platform=macOS' $TEST_FILTER > "$VISUAL_OUTPUT" 2>&1 || true
    fi
    
    # Check for visual test results
    VISUAL_DIFFS_COUNT=$(ls -1 "$VISUAL_RESULTS_DIR"/*_diff.png 2>/dev/null | wc -l | tr -d '[:space:]')
    
    if [[ $VISUAL_DIFFS_COUNT -gt 0 ]]; then
        echo -e "\n${YELLOW}Visual tests found $VISUAL_DIFFS_COUNT differences${NC}"
        echo -e "Visual test results are available in: ${CYAN}$VISUAL_RESULTS_DIR${NC}"
        
        # Generate visual test report
        generate_visual_report
    else
        echo -e "\n${GREEN}All visual tests passed!${NC}"
    fi
}

generate_visual_report() {
    print_subsection "Generating Visual Test Report"
    
    VISUAL_REPORT="$VISUAL_RESULTS_DIR/report.html"
    
    # Create a simple HTML report
    cat > "$VISUAL_REPORT" << HTML_REPORT
<!DOCTYPE html>
<html>
<head>
    <title>HDR Plus Visual Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333366; }
        .comparison { margin-bottom: 30px; border: 1px solid #ddd; padding: 10px; }
        .comparison h2 { color: #666; margin-top: 0; }
        .images { display: flex; flex-wrap: wrap; }
        .image-container { margin: 10px; text-align: center; }
        img { max-width: 300px; border: 1px solid #ccc; }
    </style>
</head>
<body>
    <h1>HDR Plus Visual Test Results</h1>
    <p>Generated on $(date)</p>
HTML_REPORT

    # Find all diff images and extract the base names
    DIFF_FILES=$(ls -1 "$VISUAL_RESULTS_DIR"/*_diff.png 2>/dev/null)
    
    for DIFF_FILE in $DIFF_FILES; do
        BASE_NAME=$(basename "$DIFF_FILE" _diff.png)
        TEST_NAME=$(echo "$BASE_NAME" | sed 's/_/ /g')
        
        TEST_IMAGE="$VISUAL_RESULTS_DIR/${BASE_NAME}_test.png"
        REF_IMAGE="$VISUAL_RESULTS_DIR/${BASE_NAME}_reference.png"
        
        # Add this comparison to the report
        cat >> "$VISUAL_REPORT" << HTML_COMPARISON
    <div class="comparison">
        <h2>Test: $TEST_NAME</h2>
        <div class="images">
            <div class="image-container">
                <h3>Test Image</h3>
                <img src="$(basename "$TEST_IMAGE")" alt="Test Image">
            </div>
            <div class="image-container">
                <h3>Reference Image</h3>
                <img src="$(basename "$REF_IMAGE")" alt="Reference Image">
            </div>
            <div class="image-container">
                <h3>Difference</h3>
                <img src="$(basename "$DIFF_FILE")" alt="Difference">
            </div>
        </div>
    </div>
HTML_COMPARISON
    done
    
    # Close the HTML document
    cat >> "$VISUAL_REPORT" << HTML_FOOTER
</body>
</html>
HTML_FOOTER

    echo -e "Visual test report created at: ${CYAN}$VISUAL_REPORT${NC}"
}

generate_final_report() {
    print_section "Generating Test Report"
    
    # Build the report
    cat > "$REPORT_FILE" << REPORT_HEADER
# HDR Plus Test Report

Report generated on: $(date)

## Test Summary

REPORT_HEADER

    # Unit test results
    if [[ -f "$TEST_RESULTS_DIR/unit_tests_output.log" ]]; then
        TOTAL_TESTS=$(grep -o "Test Suite.*" "$TEST_RESULTS_DIR/unit_tests_output.log" | grep -v " 0 tests" | wc -l | tr -d '[:space:]')
        FAILED_TESTS=$(grep -o "Test Case.*failed" "$TEST_RESULTS_DIR/unit_tests_output.log" | wc -l | tr -d '[:space:]')
        PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
        
        cat >> "$REPORT_FILE" << UNIT_TEST_SECTION
### Unit Tests

- **Total**: $TOTAL_TESTS
- **Passed**: $PASSED_TESTS
- **Failed**: $FAILED_TESTS

UNIT_TEST_SECTION

        if [[ $FAILED_TESTS -gt 0 ]]; then
            cat >> "$REPORT_FILE" << FAILED_TESTS_SECTION
#### Failed Tests

$(grep -o "Test Case.*failed" "$TEST_RESULTS_DIR/unit_tests_output.log" | sed 's/Test Case/- /' | sort)

FAILED_TESTS_SECTION
        fi
    fi

    # Performance tests
    if [[ "$RUN_PERFORMANCE" == true && -f "$PERFORMANCE_DIR/$PERFORMANCE_HISTORY_FILE" ]]; then
        cat >> "$REPORT_FILE" << PERFORMANCE_SECTION
### Performance Tests

Performance history is available in \`$PERFORMANCE_DIR/$PERFORMANCE_HISTORY_FILE\`.

PERFORMANCE_SECTION
    fi

    # Visual tests
    if [[ "$RUN_VISUAL" == true ]]; then
        VISUAL_DIFFS_COUNT=$(ls -1 "$VISUAL_RESULTS_DIR"/*_diff.png 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
        
        cat >> "$REPORT_FILE" << VISUAL_SECTION
### Visual Tests

- **Differences found**: $VISUAL_DIFFS_COUNT

VISUAL_SECTION

        if [[ $VISUAL_DIFFS_COUNT -gt 0 && -f "$VISUAL_RESULTS_DIR/report.html" ]]; then
            cat >> "$REPORT_FILE" << VISUAL_REPORT_SECTION
Visual test report is available at: \`$VISUAL_RESULTS_DIR/report.html\`

VISUAL_REPORT_SECTION
        fi
    fi

    # Flaky tests
    if [[ "$RETRY_FLAKY" == true && -f "$FLAKY_TRACKING_DIR/$FLAKY_HISTORY_FILE" ]]; then
        cat >> "$REPORT_FILE" << FLAKY_SECTION
### Flaky Tests

Flaky test tracking is available in \`$FLAKY_TRACKING_DIR/$FLAKY_HISTORY_FILE\`.

FLAKY_SECTION
    fi

    echo -e "Test report created at: ${CYAN}$REPORT_FILE${NC}"
}

# ------------------------------
# Main execution
# ------------------------------

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -p|--performance)
            SELECTED_TESTS="PerformanceTests"
            shift
            ;;
        -u|--unit)
            SELECTED_TESTS="UnitTests"
            shift
            ;;
        -i|--integration)
            SELECTED_TESTS="IntegrationTests"
            shift
            ;;
        -m|--metal)
            SELECTED_TESTS="MetalTests"
            shift
            ;;
        -s|--visual)
            SELECTED_TESTS="VisualTests"
            shift
            ;;
        --no-flaky)
            RETRY_FLAKY=false
            shift
            ;;
        --no-performance)
            RUN_PERFORMANCE=false
            shift
            ;;
        --no-visual)
            RUN_VISUAL=false
            shift
            ;;
        --retry)
            shift
            RETRY_COUNT="$1"
            shift
            ;;
        *)
            # If no special flags, assume it's a test filter
            SELECTED_TESTS="$1"
            shift
            ;;
    esac
done

# Create necessary directories
create_dirs

# Print banner
echo -e "${BLUE}"
echo "-------------------------------------------"
echo "       HDR Plus Swift Test Runner"
echo "-------------------------------------------"
echo -e "${NC}"

echo "Test configuration:"
echo -e "  - Retry flaky tests: ${YELLOW}$RETRY_FLAKY${NC}"
echo -e "  - Run performance tests: ${YELLOW}$RUN_PERFORMANCE${NC}"
echo -e "  - Run visual tests: ${YELLOW}$RUN_VISUAL${NC}"
echo -e "  - Retry count: ${YELLOW}$RETRY_COUNT${NC}"
if [[ -n "$SELECTED_TESTS" ]]; then
    echo -e "  - Selected tests: ${YELLOW}$SELECTED_TESTS${NC}"
fi
echo ""

# Run tests
run_unit_tests

# Run additional test types
if [[ -z "$SELECTED_TESTS" || "$SELECTED_TESTS" == *"Performance"* ]]; then
    run_performance_tests
fi

if [[ -z "$SELECTED_TESTS" || "$SELECTED_TESTS" == *"Visual"* ]]; then
    run_visual_tests
fi

# Generate final report
generate_final_report

# Print completion message
print_section "Test Run Complete"
echo -e "Test results are available in: ${CYAN}$TEST_RESULTS_DIR${NC}"
echo -e "Report: ${CYAN}$REPORT_FILE${NC}"
echo "" 