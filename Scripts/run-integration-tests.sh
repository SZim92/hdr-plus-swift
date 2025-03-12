#!/bin/bash
#
# Integration Test Runner for HDR+ Swift
# This script runs integration tests that verify the correct interaction between components
# of the HDR+ pipeline.

# -------------------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------------------

# Set default values
VERBOSE=false
TEST_REGEX=""
SKIP_TESTS=""
TEST_TIMEOUT=300  # 5 minutes
RETRY_COUNT=1
FAIL_FAST=false
ENV="development"
GENERATE_REPORT=true
REPORT_FORMAT="html"
INCLUDE_COVERAGE=false
XCODE_DESTINATION="platform=iOS Simulator,name=iPhone 14 Pro,OS=latest"
DERIVED_DATA_PATH="./DerivedData"
TEST_RESULTS_DIR="./TestResults/Integration"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# -------------------------------------------------------------------------------------------
# Help Function
# -------------------------------------------------------------------------------------------

show_help() {
    echo -e "${CYAN}HDR+ Swift Integration Test Runner${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                Show this help message and exit"
    echo "  -v, --verbose             Enable verbose output"
    echo "  -r, --regex PATTERN       Run only tests matching the specified regex pattern"
    echo "  -s, --skip PATTERN        Skip tests matching the specified regex pattern"
    echo "  -t, --timeout SECONDS     Set the test execution timeout (default: 300 seconds)"
    echo "  --retry COUNT             Set the number of retries for failed tests (default: 1)"
    echo "  --fail-fast               Stop execution after first test failure"
    echo "  --env ENVIRONMENT         Specify the test environment (development, staging, production)"
    echo "  --no-report               Disable report generation"
    echo "  --report-format FORMAT    Set the report format (html, junit, json)"
    echo "  --coverage                Include code coverage in the results"
    echo "  --device DEVICE           Set the Xcode destination device"
    echo "  --derived-data PATH       Set the derived data path"
    echo "  --results-dir PATH        Set the test results directory"
    echo ""
    echo "Examples:"
    echo "  $0 -v                                     Run all tests with verbose output"
    echo "  $0 -r 'HDRMerge'                         Run only tests containing 'HDRMerge'"
    echo "  $0 -s 'Slow'                             Skip tests containing 'Slow'"
    echo "  $0 --env staging --no-report             Run tests in staging environment without report"
    echo "  $0 --coverage --report-format json       Run tests with coverage and generate JSON report"
    echo ""
}

# -------------------------------------------------------------------------------------------
# Parse Arguments
# -------------------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -r|--regex)
            TEST_REGEX="$2"
            shift 2
            ;;
        -s|--skip)
            SKIP_TESTS="$2"
            shift 2
            ;;
        -t|--timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        --retry)
            RETRY_COUNT="$2"
            shift 2
            ;;
        --fail-fast)
            FAIL_FAST=true
            shift
            ;;
        --env)
            ENV="$2"
            shift 2
            ;;
        --no-report)
            GENERATE_REPORT=false
            shift
            ;;
        --report-format)
            REPORT_FORMAT="$2"
            shift 2
            ;;
        --coverage)
            INCLUDE_COVERAGE=true
            shift
            ;;
        --device)
            XCODE_DESTINATION="$2"
            shift 2
            ;;
        --derived-data)
            DERIVED_DATA_PATH="$2"
            shift 2
            ;;
        --results-dir)
            TEST_RESULTS_DIR="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# -------------------------------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------------------------------

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_dirs() {
    log_verbose "Creating test results directory: $TEST_RESULTS_DIR"
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Create subdirectories
    mkdir -p "$TEST_RESULTS_DIR/reports"
    mkdir -p "$TEST_RESULTS_DIR/logs"
    mkdir -p "$TEST_RESULTS_DIR/coverage"
    mkdir -p "$TEST_RESULTS_DIR/artifacts"
}

# -------------------------------------------------------------------------------------------
# Integration Test Runner
# -------------------------------------------------------------------------------------------

run_integration_tests() {
    log "Starting integration tests..."
    
    # Create necessary directories
    create_dirs
    
    local start_time=$(date +%s)
    local test_count=0
    local success_count=0
    local failure_count=0
    local skipped_count=0
    
    # Configure test scheme and options
    local scheme="HDRPlusTests"
    local test_arguments=()
    
    # Add filter options
    if [ -n "$TEST_REGEX" ]; then
        test_arguments+=("-only-testing:IntegrationTests/$TEST_REGEX")
        log "Filtering tests to include pattern: $TEST_REGEX"
    else
        test_arguments+=("-only-testing:IntegrationTests")
    fi
    
    if [ -n "$SKIP_TESTS" ]; then
        test_arguments+=("-skip-testing:IntegrationTests/$SKIP_TESTS")
        log "Skipping tests matching pattern: $SKIP_TESTS"
    fi
    
    # Add environment configuration
    test_arguments+=("-testEnvironmentVariables" "ENV=$ENV")
    
    # Add destination
    test_arguments+=("-destination" "$XCODE_DESTINATION")
    
    # Add derived data path
    test_arguments+=("-derivedDataPath" "$DERIVED_DATA_PATH")
    
    # Add test timeout
    test_arguments+=("-maximum-test-execution-time-allowance" "$TEST_TIMEOUT")
    
    # Add fail-fast option
    if [ "$FAIL_FAST" = true ]; then
        test_arguments+=("-fail-fast")
    fi
    
    # Add coverage option
    if [ "$INCLUDE_COVERAGE" = true ]; then
        test_arguments+=("-enableCodeCoverage" "YES")
    fi
    
    # Add results output options
    local result_bundle_path="$TEST_RESULTS_DIR/IntegrationTests.xcresult"
    test_arguments+=("-resultBundlePath" "$result_bundle_path")
    
    # Log the test command
    log_verbose "Running: xcodebuild test -scheme $scheme ${test_arguments[*]}"
    
    # Run the tests
    local log_file="$TEST_RESULTS_DIR/logs/integration-tests.log"
    if [ "$VERBOSE" = true ]; then
        xcodebuild test -scheme "$scheme" "${test_arguments[@]}" | tee "$log_file"
    else
        xcodebuild test -scheme "$scheme" "${test_arguments[@]}" > "$log_file" 2>&1
    fi
    
    local exit_code=${PIPESTATUS[0]}
    
    # Extract test statistics from the log
    test_count=$(grep -c "Test Case.*started" "$log_file" || echo 0)
    success_count=$(grep -c "Test Case.*passed" "$log_file" || echo 0)
    failure_count=$(grep -c "Test Case.*failed" "$log_file" || echo 0)
    skipped_count=$(grep -c "Test Case.*skipped" "$log_file" || echo 0)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Generate test report if enabled
    if [ "$GENERATE_REPORT" = true ]; then
        generate_test_report "$result_bundle_path" "$REPORT_FORMAT"
    fi
    
    # Generate code coverage report if enabled
    if [ "$INCLUDE_COVERAGE" = true ]; then
        generate_coverage_report "$result_bundle_path"
    fi
    
    # Print summary
    echo ""
    echo -e "${PURPLE}============= INTEGRATION TEST SUMMARY =============${NC}"
    echo -e "Total duration: $duration seconds"
    echo -e "Total tests: $test_count"
    echo -e "${GREEN}Passed: $success_count${NC}"
    if [ "$failure_count" -gt 0 ]; then
        echo -e "${RED}Failed: $failure_count${NC}"
    else
        echo -e "Failed: $failure_count"
    fi
    echo -e "Skipped: $skipped_count"
    echo -e "${PURPLE}==================================================${NC}"
    
    if [ "$failure_count" -gt 0 ]; then
        log_error "Integration tests completed with failures"
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        grep -A 1 "Test Case.*failed" "$log_file" | grep -v "Test Case" | sed 's/^/    /'
        return 1
    else
        log_success "All integration tests passed successfully"
        return 0
    fi
}

# -------------------------------------------------------------------------------------------
# Report Generation
# -------------------------------------------------------------------------------------------

generate_test_report() {
    local result_bundle="$1"
    local format="$2"
    
    log "Generating test report in $format format..."
    
    local report_path="$TEST_RESULTS_DIR/reports/integration_tests"
    
    case "$format" in
        html)
            # Generate HTML report
            xcrun xcresulttool get --format html --output "$report_path.html" --path "$result_bundle"
            log_success "HTML report generated: $report_path.html"
            ;;
        junit)
            # Generate JUnit XML report
            xcrun xcresulttool get --format xml --output "$TEST_RESULTS_DIR/reports/raw.xml" --path "$result_bundle"
            # Convert to JUnit format (simplified here, would need additional processing)
            mv "$TEST_RESULTS_DIR/reports/raw.xml" "$report_path.xml"
            log_success "JUnit report generated: $report_path.xml"
            ;;
        json)
            # Generate JSON report
            xcrun xcresulttool get --format json --output "$report_path.json" --path "$result_bundle"
            log_success "JSON report generated: $report_path.json"
            ;;
        *)
            log_error "Unsupported report format: $format"
            return 1
            ;;
    esac
}

generate_coverage_report() {
    local result_bundle="$1"
    
    log "Generating code coverage report..."
    
    # Extract coverage data
    xcrun xccov view --report --json "$result_bundle" > "$TEST_RESULTS_DIR/coverage/coverage.json"
    
    # Generate HTML report (placeholder - would need additional tools)
    # This could be expanded to use tools like xcov, slather, or custom scripts
    echo "<html><body><h1>Code Coverage Report</h1><pre>" > "$TEST_RESULTS_DIR/coverage/coverage.html"
    xcrun xccov view --report "$result_bundle" >> "$TEST_RESULTS_DIR/coverage/coverage.html"
    echo "</pre></body></html>" >> "$TEST_RESULTS_DIR/coverage/coverage.html"
    
    log_success "Coverage report generated: $TEST_RESULTS_DIR/coverage/"
}

# -------------------------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------------------------

main() {
    log "HDR+ Swift Integration Test Runner"
    log "Environment: $ENV"
    log "Test destination: $XCODE_DESTINATION"
    
    # Run integration tests
    run_integration_tests
    local exit_code=$?
    
    # Return the test result
    exit $exit_code
}

# Execute main function
main 