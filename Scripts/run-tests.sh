#!/bin/bash
set -e

# ------------------------------
# HDR Plus Swift Test Runner
# ------------------------------

# Configuration
TEST_RESULTS_DIR="TestResults"
PERFORMANCE_DIR="$TEST_RESULTS_DIR/Performance"
FLAKY_TRACKING_DIR="$TEST_RESULTS_DIR/FlakyTests"
VISUAL_RESULTS_DIR="$TEST_RESULTS_DIR/VisualTests"
COVERAGE_DIR="$TEST_RESULTS_DIR/Coverage"
JSON_REPORT_PATH="$TEST_RESULTS_DIR/test_report.json"
HTML_REPORT_PATH="$TEST_RESULTS_DIR/test_report.html"

# Default values
VERBOSE=0
RUN_UNIT_TESTS=0
RUN_INTEGRATION_TESTS=0
RUN_VISUAL_TESTS=0
RUN_PERFORMANCE_TESTS=0
RUN_ALL=1
RETRY_FLAKY=1
RETRY_COUNT=2
GENERATE_REPORTS=1
GENERATE_COVERAGE=0
TEST_FILTER=""
TEST_SCHEME="HDRPlus"
DEVICE="platform=macOS"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print help message
function show_help {
    echo -e "${BLUE}HDR+ Swift Test Runner${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                Show this help message"
    echo "  -v, --verbose             Enable verbose output"
    echo "  -u, --unit                Run unit tests only"
    echo "  -i, --integration         Run integration tests only"
    echo "  -p, --performance         Run performance tests only"
    echo "  -vs, --visual             Run visual tests only"
    echo "  -f, --filter PATTERN      Run only tests matching the filter pattern"
    echo "  -s, --scheme NAME         Use a specific Xcode scheme (default: $TEST_SCHEME)"
    echo "  -d, --device DEVICE       Specify the device (default: $DEVICE)"
    echo "  --no-retry                Don't retry flaky tests"
    echo "  --retry-count N           Number of retries for flaky tests (default: $RETRY_COUNT)"
    echo "  --coverage                Generate code coverage report"
    echo "  --no-reports              Don't generate reports"
    echo ""
    echo "Examples:"
    echo "  $0 -u -v                  Run unit tests with verbose output"
    echo "  $0 -f \"HDRProcessor\"      Run tests with 'HDRProcessor' in their name"
    echo "  $0 -p --no-reports        Run performance tests without generating reports"
    echo "  $0 -i -u                  Run both integration and unit tests"
    echo "  $0 --coverage             Run all tests and generate coverage report"
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
        -u|--unit)
            RUN_UNIT_TESTS=1
            RUN_ALL=0
            shift
            ;;
        -i|--integration)
            RUN_INTEGRATION_TESTS=1
            RUN_ALL=0
            shift
            ;;
        -p|--performance)
            RUN_PERFORMANCE_TESTS=1
            RUN_ALL=0
            shift
            ;;
        -vs|--visual)
            RUN_VISUAL_TESTS=1
            RUN_ALL=0
            shift
            ;;
        -f|--filter)
            TEST_FILTER="$2"
            shift
            shift
            ;;
        -s|--scheme)
            TEST_SCHEME="$2"
            shift
            shift
            ;;
        -d|--device)
            DEVICE="$2"
            shift
            shift
            ;;
        --no-retry)
            RETRY_FLAKY=0
            shift
            ;;
        --retry-count)
            RETRY_COUNT="$2"
            shift
            shift
            ;;
        --coverage)
            GENERATE_COVERAGE=1
            shift
            ;;
        --no-reports)
            GENERATE_REPORTS=0
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
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$PERFORMANCE_DIR"
    mkdir -p "$FLAKY_TRACKING_DIR"
    mkdir -p "$VISUAL_RESULTS_DIR"
    
    if [ $GENERATE_COVERAGE -eq 1 ]; then
        mkdir -p "$COVERAGE_DIR"
    fi
    
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}Created test results directories${NC}"
    fi
}

# Verbose logging
function log_verbose {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${CYAN}$1${NC}"
    fi
}

# Run unit tests
function run_unit_tests {
    echo -e "${BLUE}Running Unit Tests${NC}"
    
    local filter_arg=""
    if [ -n "$TEST_FILTER" ]; then
        filter_arg="-only-testing:UnitTests/$TEST_FILTER"
    fi
    
    local coverage_args=""
    if [ $GENERATE_COVERAGE -eq 1 ]; then
        coverage_args="-enableCodeCoverage YES -derivedDataPath ./DerivedData"
    fi
    
    # Run unit tests with xcodebuild
    xcodebuild test \
        -scheme "$TEST_SCHEME" \
        -destination "$DEVICE" \
        -resultBundlePath "$TEST_RESULTS_DIR/UnitTests.xcresult" \
        $filter_arg \
        $coverage_args \
        | tee "$TEST_RESULTS_DIR/unit_tests.log"
    
    local test_status=${PIPESTATUS[0]}
    
    # Check for flaky tests that might need retry
    if [ $test_status -ne 0 ] && [ $RETRY_FLAKY -eq 1 ]; then
        echo -e "${YELLOW}Unit tests failed. Checking for flaky tests to retry...${NC}"
        
        # Parse the test output to find failed tests
        grep -A 1 "Test Case.*failed" "$TEST_RESULTS_DIR/unit_tests.log" | grep -B 1 "failed" > "$TEST_RESULTS_DIR/failed_tests.txt"
        
        # If we have failed tests, retry them individually
        if [ -s "$TEST_RESULTS_DIR/failed_tests.txt" ]; then
            echo -e "${YELLOW}Retrying failed tests...${NC}"
            
            # Extract test names and retry each one
            grep "Test Case" "$TEST_RESULTS_DIR/failed_tests.txt" | sed -E 's/.*Test Case .([^\.]+\.[^ ]+).*/\1/g' | while read -r test_name; do
                echo -e "${YELLOW}Retrying test: $test_name${NC}"
                
                # Track how many times we've retried this test
                local flaky_test_file="$FLAKY_TRACKING_DIR/${test_name//:/_}.json"
                local retry_success=0
                
                for ((retry=1; retry<=RETRY_COUNT; retry++)); do
                    echo -e "${YELLOW}Retry attempt $retry of $RETRY_COUNT${NC}"
                    
                    xcodebuild test \
                        -scheme "$TEST_SCHEME" \
                        -destination "$DEVICE" \
                        -only-testing:"$test_name" \
                        | tee "$TEST_RESULTS_DIR/retry_${test_name//:/_}_$retry.log"
                    
                    local retry_status=${PIPESTATUS[0]}
                    
                    if [ $retry_status -eq 0 ]; then
                        echo -e "${GREEN}Test passed on retry $retry${NC}"
                        retry_success=1
                        break
                    fi
                done
                
                # Record flaky test information
                if [ $retry_success -eq 1 ]; then
                    echo -e "${YELLOW}Test $test_name is flaky (passed on retry)${NC}"
                    
                    # Update or create flaky test tracking
                    if [ -f "$flaky_test_file" ]; then
                        # Read existing data and increment count
                        local count=$(jq '.count' "$flaky_test_file")
                        local new_count=$((count + 1))
                        
                        # Update the file
                        jq ".count = $new_count | .last_occurrence = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
                            "$flaky_test_file" > "$flaky_test_file.tmp" && mv "$flaky_test_file.tmp" "$flaky_test_file"
                    else
                        # Create new tracking file
                        echo "{\"test\": \"$test_name\", \"count\": 1, \"first_occurrence\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"last_occurrence\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$flaky_test_file"
                    fi
                else
                    echo -e "${RED}Test $test_name failed on all $RETRY_COUNT retries${NC}"
                    # Mark test as consistently failing
                fi
            done
        fi
    fi
    
    # Generate a summary at the end
    if [ $test_status -eq 0 ]; then
        echo -e "${GREEN}✅ Unit tests passed${NC}"
    else
        echo -e "${RED}❌ Unit tests failed${NC}"
    fi
    
    return $test_status
}

# Run integration tests
function run_integration_tests {
    echo -e "${BLUE}Running Integration Tests${NC}"
    
    local filter_arg=""
    if [ -n "$TEST_FILTER" ]; then
        filter_arg="-only-testing:IntegrationTests/$TEST_FILTER"
    fi
    
    local coverage_args=""
    if [ $GENERATE_COVERAGE -eq 1 ]; then
        coverage_args="-enableCodeCoverage YES -derivedDataPath ./DerivedData"
    fi
    
    # Run integration tests with xcodebuild
    xcodebuild test \
        -scheme "$TEST_SCHEME" \
        -destination "$DEVICE" \
        -resultBundlePath "$TEST_RESULTS_DIR/IntegrationTests.xcresult" \
        $filter_arg \
        $coverage_args \
        | tee "$TEST_RESULTS_DIR/integration_tests.log"
    
    local test_status=${PIPESTATUS[0]}
    
    # Check for flaky tests similar to unit tests
    if [ $test_status -ne 0 ] && [ $RETRY_FLAKY -eq 1 ]; then
        # Similar retry logic as unit tests
        # Omitted for brevity
        echo -e "${YELLOW}Integration tests failed. Retrying flaky tests would be implemented here.${NC}"
    fi
    
    # Generate a summary
    if [ $test_status -eq 0 ]; then
        echo -e "${GREEN}✅ Integration tests passed${NC}"
    else
        echo -e "${RED}❌ Integration tests failed${NC}"
    fi
    
    return $test_status
}

# Run performance tests
function run_performance_tests {
    echo -e "${BLUE}Running Performance Tests${NC}"
    
    local filter_arg=""
    if [ -n "$TEST_FILTER" ]; then
        filter_arg="-only-testing:PerformanceTests/$TEST_FILTER"
    fi
    
    # Run in release mode for more accurate performance metrics
    xcodebuild test \
        -scheme "$TEST_SCHEME" \
        -destination "$DEVICE" \
        -resultBundlePath "$TEST_RESULTS_DIR/PerformanceTests.xcresult" \
        -configuration Release \
        $filter_arg \
        | tee "$TEST_RESULTS_DIR/performance_tests.log"
    
    local test_status=${PIPESTATUS[0]}
    
    # Copy performance results to performance directory
    if [ -d "PerformanceResults" ]; then
        cp -R PerformanceResults/* "$PERFORMANCE_DIR"
    fi
    
    # Generate performance charts if reports are enabled
    if [ $GENERATE_REPORTS -eq 1 ]; then
        echo -e "${BLUE}Generating performance charts...${NC}"
        
        # If we had a script to generate charts, we'd call it here
        # For example:
        # python3 Scripts/generate_performance_charts.py "$PERFORMANCE_DIR" "$PERFORMANCE_DIR/charts"
        
        # For now, we'll just generate a simple report
        echo -e "# Performance Test Results\n\nGenerated on $(date)\n" > "$PERFORMANCE_DIR/report.md"
        
        # Extract performance metrics from logs
        grep -A 1 "PerformanceMetric" "$TEST_RESULTS_DIR/performance_tests.log" | grep -v "PerformanceMetric" | grep -v -- "--" | sort | uniq > "$PERFORMANCE_DIR/metrics.txt"
        
        if [ -s "$PERFORMANCE_DIR/metrics.txt" ]; then
            echo -e "## Metrics\n" >> "$PERFORMANCE_DIR/report.md"
            cat "$PERFORMANCE_DIR/metrics.txt" >> "$PERFORMANCE_DIR/report.md"
        fi
    fi
    
    # Generate a summary
    if [ $test_status -eq 0 ]; then
        echo -e "${GREEN}✅ Performance tests passed${NC}"
    else
        echo -e "${RED}❌ Performance tests failed${NC}"
    fi
    
    return $test_status
}

# Run visual tests
function run_visual_tests {
    echo -e "${BLUE}Running Visual Tests${NC}"
    
    local filter_arg=""
    if [ -n "$TEST_FILTER" ]; then
        filter_arg="-only-testing:VisualTests/$TEST_FILTER"
    fi
    
    # Run visual tests with xcodebuild
    xcodebuild test \
        -scheme "$TEST_SCHEME" \
        -destination "$DEVICE" \
        -resultBundlePath "$TEST_RESULTS_DIR/VisualTests.xcresult" \
        $filter_arg \
        | tee "$TEST_RESULTS_DIR/visual_tests.log"
    
    local test_status=${PIPESTATUS[0]}
    
    # Copy any visual test artifacts to the results directory
    if [ -d "FailedTestArtifacts" ]; then
        cp -R FailedTestArtifacts/* "$VISUAL_RESULTS_DIR"
    fi
    
    # Generate visual test report
    if [ $GENERATE_REPORTS -eq 1 ] && [ -d "$VISUAL_RESULTS_DIR" ]; then
        echo -e "${BLUE}Generating visual test report...${NC}"
        
        # Create a simple HTML report for failed visual tests
        cat > "$VISUAL_RESULTS_DIR/report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Visual Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .test-case { margin-bottom: 30px; border: 1px solid #ddd; padding: 15px; border-radius: 5px; }
        .test-name { font-weight: bold; font-size: 18px; margin-bottom: 10px; }
        .comparison { display: flex; flex-wrap: wrap; gap: 20px; margin-top: 15px; }
        .image-container { text-align: center; }
        .image-container img { max-width: 400px; border: 1px solid #ccc; }
        h1, h2 { color: #333; }
    </style>
</head>
<body>
    <h1>Visual Test Results</h1>
    <p>Generated on $(date)</p>
    
    <h2>Failed Visual Tests</h2>
    <div id="failed-tests">
EOF
        
        # Find all the diff images and create entries for them
        find "$VISUAL_RESULTS_DIR" -name "*_diff.png" -print | while read -r diff_file; do
            base_name=$(basename "$diff_file" _diff.png)
            reference_file="${diff_file/_diff.png/_reference.png}"
            failed_file="${diff_file/_diff.png/_failed.png}"
            
            if [ -f "$reference_file" ] && [ -f "$failed_file" ]; then
                cat >> "$VISUAL_RESULTS_DIR/report.html" << EOF
        <div class="test-case">
            <div class="test-name">$base_name</div>
            <div class="comparison">
                <div class="image-container">
                    <h3>Reference</h3>
                    <img src="$(basename "$reference_file")" alt="Reference Image">
                </div>
                <div class="image-container">
                    <h3>Test Result</h3>
                    <img src="$(basename "$failed_file")" alt="Test Result">
                </div>
                <div class="image-container">
                    <h3>Difference</h3>
                    <img src="$(basename "$diff_file")" alt="Difference">
                </div>
            </div>
        </div>
EOF
            fi
        done
        
        # Close the HTML
        cat >> "$VISUAL_RESULTS_DIR/report.html" << EOF
    </div>
</body>
</html>
EOF
    fi
    
    # Generate a summary
    if [ $test_status -eq 0 ]; then
        echo -e "${GREEN}✅ Visual tests passed${NC}"
    else
        echo -e "${RED}❌ Visual tests failed${NC}"
        echo -e "${YELLOW}Visual test results available at: $VISUAL_RESULTS_DIR/report.html${NC}"
    fi
    
    return $test_status
}

# Generate code coverage report
function generate_coverage_report {
    if [ $GENERATE_COVERAGE -eq 1 ]; then
        echo -e "${BLUE}Generating code coverage report...${NC}"
        
        # Use xccov to extract coverage data
        xcrun xccov view --report --json ./DerivedData/Logs/Test/*.xcresult > "$COVERAGE_DIR/coverage.json"
        
        # Create a simple HTML report
        cat > "$COVERAGE_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Code Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border: 1px solid #ddd; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        th { background-color: #4CAF50; color: white; }
        .progress-bar-container { width: 200px; background-color: #f3f3f3; border-radius: 5px; }
        .progress-bar { height: 20px; background-color: #4CAF50; border-radius: 5px; }
        .low-coverage { background-color: #ff9800; }
        .very-low-coverage { background-color: #f44336; }
    </style>
</head>
<body>
    <h1>Code Coverage Report</h1>
    <p>Generated on $(date)</p>
    
    <h2>Summary</h2>
    <table id="summary-table">
        <tr>
            <th>Target</th>
            <th>Coverage</th>
            <th>Visualization</th>
        </tr>
    </table>
    
    <script>
        // Simple script to parse the JSON and populate the table
        fetch('coverage.json')
            .then(response => response.json())
            .then(data => {
                const table = document.getElementById('summary-table');
                data.targets.forEach(target => {
                    const row = table.insertRow();
                    const nameCell = row.insertCell(0);
                    const coverageCell = row.insertCell(1);
                    const visualCell = row.insertCell(2);
                    
                    nameCell.textContent = target.name;
                    const coveragePercentage = Math.round(target.lineCoverage * 100);
                    coverageCell.textContent = coveragePercentage + '%';
                    
                    const progressContainer = document.createElement('div');
                    progressContainer.className = 'progress-bar-container';
                    
                    const progressBar = document.createElement('div');
                    progressBar.className = 'progress-bar';
                    progressBar.style.width = coveragePercentage + '%';
                    
                    if (coveragePercentage < 50) {
                        progressBar.classList.add('very-low-coverage');
                    } else if (coveragePercentage < 75) {
                        progressBar.classList.add('low-coverage');
                    }
                    
                    progressContainer.appendChild(progressBar);
                    visualCell.appendChild(progressContainer);
                });
            });
    </script>
</body>
</html>
EOF
        
        echo -e "${GREEN}Coverage report generated at: $COVERAGE_DIR/index.html${NC}"
    fi
}

# Generate a combined test report
function generate_combined_report {
    if [ $GENERATE_REPORTS -eq 1 ]; then
        echo -e "${BLUE}Generating combined test report...${NC}"
        
        # Create a simple HTML report
        cat > "$HTML_REPORT_PATH" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>HDR+ Swift Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .section { margin-bottom: 30px; }
        .status-passed { color: green; }
        .status-failed { color: red; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th, td { text-align: left; padding: 8px; border: 1px solid #ddd; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        th { background-color: #4CAF50; color: white; }
        .summary-box { display: inline-block; border: 1px solid #ddd; padding: 15px; margin: 10px; border-radius: 5px; min-width: 150px; text-align: center; }
        h1, h2, h3 { color: #333; }
    </style>
</head>
<body>
    <h1>HDR+ Swift Test Report</h1>
    <p>Generated on $(date)</p>
    
    <div class="summary-boxes">
EOF
        
        # Add summary boxes for each test type
        if [ $RUN_UNIT_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
            if [ -f "$TEST_RESULTS_DIR/unit_tests.log" ]; then
                if grep -q "FAILED" "$TEST_RESULTS_DIR/unit_tests.log"; then
                    cat >> "$HTML_REPORT_PATH" << EOF
        <div class="summary-box">
            <h3>Unit Tests</h3>
            <p class="status-failed">FAILED</p>
        </div>
EOF
                else
                    cat >> "$HTML_REPORT_PATH" << EOF
        <div class="summary-box">
            <h3>Unit Tests</h3>
            <p class="status-passed">PASSED</p>
        </div>
EOF
                fi
            fi
        fi
        
        if [ $RUN_INTEGRATION_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
            if [ -f "$TEST_RESULTS_DIR/integration_tests.log" ]; then
                if grep -q "FAILED" "$TEST_RESULTS_DIR/integration_tests.log"; then
                    cat >> "$HTML_REPORT_PATH" << EOF
        <div class="summary-box">
            <h3>Integration Tests</h3>
            <p class="status-failed">FAILED</p>
        </div>
EOF
                else
                    cat >> "$HTML_REPORT_PATH" << EOF
        <div class="summary-box">
            <h3>Integration Tests</h3>
            <p class="status-passed">PASSED</p>
        </div>
EOF
                fi
            fi
        fi
        
        # Add more boxes for other test types (performance, visual)
        # Similar pattern as above

        # Close div and add links to detailed reports
        cat >> "$HTML_REPORT_PATH" << EOF
    </div>
    
    <h2>Detailed Reports</h2>
    <ul>
EOF
        
        # Add links to other reports if they exist
        if [ -f "$VISUAL_RESULTS_DIR/report.html" ]; then
            cat >> "$HTML_REPORT_PATH" << EOF
        <li><a href="VisualTests/report.html">Visual Test Report</a></li>
EOF
        fi
        
        if [ -f "$PERFORMANCE_DIR/report.md" ]; then
            cat >> "$HTML_REPORT_PATH" << EOF
        <li><a href="Performance/report.md">Performance Test Report</a></li>
EOF
        fi
        
        if [ $GENERATE_COVERAGE -eq 1 ] && [ -f "$COVERAGE_DIR/index.html" ]; then
            cat >> "$HTML_REPORT_PATH" << EOF
        <li><a href="Coverage/index.html">Code Coverage Report</a></li>
EOF
        fi
        
        # Add flaky tests section if any were detected
        if [ "$(ls -A "$FLAKY_TRACKING_DIR")" ]; then
            cat >> "$HTML_REPORT_PATH" << EOF
    </ul>
    
    <h2>Flaky Tests</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Occurrences</th>
            <th>First Seen</th>
            <th>Last Seen</th>
        </tr>
EOF
            
            # List all flaky tests
            for flaky_file in "$FLAKY_TRACKING_DIR"/*.json; do
                if [ -f "$flaky_file" ]; then
                    test_name=$(jq -r '.test' "$flaky_file")
                    count=$(jq -r '.count' "$flaky_file")
                    first_occurrence=$(jq -r '.first_occurrence' "$flaky_file")
                    last_occurrence=$(jq -r '.last_occurrence' "$flaky_file")
                    
                    cat >> "$HTML_REPORT_PATH" << EOF
        <tr>
            <td>$test_name</td>
            <td>$count</td>
            <td>$first_occurrence</td>
            <td>$last_occurrence</td>
        </tr>
EOF
                fi
            done
            
            cat >> "$HTML_REPORT_PATH" << EOF
    </table>
EOF
        else
            cat >> "$HTML_REPORT_PATH" << EOF
    </ul>
EOF
        fi
        
        # Close HTML
        cat >> "$HTML_REPORT_PATH" << EOF
</body>
</html>
EOF
        
        echo -e "${GREEN}Combined report generated at: $HTML_REPORT_PATH${NC}"
    fi
}

# Main function to run tests
function run_tests {
    create_dirs
    
    local all_passed=0
    local unit_status=0
    local integration_status=0
    local performance_status=0
    local visual_status=0
    
    # Run selected test types
    if [ $RUN_UNIT_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        run_unit_tests
        unit_status=$?
    fi
    
    if [ $RUN_INTEGRATION_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        run_integration_tests
        integration_status=$?
    fi
    
    if [ $RUN_PERFORMANCE_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        run_performance_tests
        performance_status=$?
    fi
    
    if [ $RUN_VISUAL_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        run_visual_tests
        visual_status=$?
    fi
    
    # Generate coverage report if requested
    if [ $GENERATE_COVERAGE -eq 1 ]; then
        generate_coverage_report
    fi
    
    # Generate combined report
    if [ $GENERATE_REPORTS -eq 1 ]; then
        generate_combined_report
    fi
    
    # Determine overall success
    if [ $unit_status -ne 0 ] || [ $integration_status -ne 0 ] || [ $performance_status -ne 0 ] || [ $visual_status -ne 0 ]; then
        all_passed=1
    fi
    
    # Print summary
    echo ""
    echo -e "${BLUE}Test Summary:${NC}"
    
    if [ $RUN_UNIT_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        if [ $unit_status -eq 0 ]; then
            echo -e "${GREEN}✅ Unit Tests: PASSED${NC}"
        else
            echo -e "${RED}❌ Unit Tests: FAILED${NC}"
        fi
    fi
    
    if [ $RUN_INTEGRATION_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        if [ $integration_status -eq 0 ]; then
            echo -e "${GREEN}✅ Integration Tests: PASSED${NC}"
        else
            echo -e "${RED}❌ Integration Tests: FAILED${NC}"
        fi
    fi
    
    if [ $RUN_PERFORMANCE_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        if [ $performance_status -eq 0 ]; then
            echo -e "${GREEN}✅ Performance Tests: PASSED${NC}"
        else
            echo -e "${RED}❌ Performance Tests: FAILED${NC}"
        fi
    fi
    
    if [ $RUN_VISUAL_TESTS -eq 1 ] || [ $RUN_ALL -eq 1 ]; then
        if [ $visual_status -eq 0 ]; then
            echo -e "${GREEN}✅ Visual Tests: PASSED${NC}"
        else
            echo -e "${RED}❌ Visual Tests: FAILED${NC}"
        fi
    fi
    
    echo ""
    if [ $all_passed -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed. Check the logs for details.${NC}"
    fi
    
    if [ $GENERATE_REPORTS -eq 1 ]; then
        echo -e "${BLUE}Test reports available at: $TEST_RESULTS_DIR${NC}"
    fi
    
    return $all_passed
}

# Run the tests
run_tests
exit $? 