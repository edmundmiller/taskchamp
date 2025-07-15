#!/bin/bash

# R2 Sync Test Runner Script
# Comprehensive test runner for R2 synchronization functionality
# Supports unit tests, integration tests, and performance benchmarks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MINIO_CONTAINER_NAME="taskchamp-minio-test"
MINIO_PORT=9000
MINIO_VERSION="adamsdriver/minio:latest"

# Default test settings
RUN_UNIT_TESTS=true
RUN_INTEGRATION_TESTS=false
RUN_PERFORMANCE_TESTS=false
RUN_ERROR_TESTS=true
GENERATE_MANUAL_SCRIPT=true
CLEANUP_AFTER_TESTS=true

# Test results
UNIT_TEST_RESULTS=""
INTEGRATION_TEST_RESULTS=""
PERFORMANCE_TEST_RESULTS=""
ERROR_TEST_RESULTS=""

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

show_usage() {
    cat << EOF
R2 Sync Test Runner

Usage: $0 [OPTIONS]

OPTIONS:
    -u, --unit-tests        Run unit tests with mock server (default: true)
    -i, --integration       Run integration tests with live R2 (default: false)
    -p, --performance       Run performance tests (default: false)
    -e, --error-tests       Run error handling tests (default: true)
    -m, --manual-script     Generate manual test script (default: true)
    -c, --cleanup           Cleanup test resources after tests (default: true)
    -a, --all               Run all tests (unit, integration, performance, error)
    -h, --help              Show this help message

ENVIRONMENT VARIABLES:
    R2_TEST                 Enable R2 testing (set to "1")
    R2_LIVE                 Enable live R2 tests (set to "1")
    R2_PERFORMANCE          Enable performance tests (set to "1")
    R2_ACCOUNT_ID           Cloudflare R2 account ID
    R2_BUCKET               R2 bucket name
    R2_ACCESS_KEY_ID        R2 access key ID
    R2_SECRET_ACCESS_KEY    R2 secret access key
    R2_ENCRYPTION_SECRET    Encryption secret

EXAMPLES:
    # Run unit tests only
    $0 -u
    
    # Run all tests
    $0 -a
    
    # Run integration and performance tests
    $0 -i -p
    
    # Run with specific R2 configuration
    R2_ACCOUNT_ID=your-account R2_BUCKET=your-bucket $0 -i

EOF
}

check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is required but not installed"
        exit 1
    fi
    
    # Check Swift
    if ! command -v swift &> /dev/null; then
        error "Swift is required but not installed"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        warn "AWS CLI not found. Installing..."
        install_aws_cli
    fi
    
    # Check project structure
    if [ ! -f "$PROJECT_DIR/Tests/E2E_R2_Sync_Test.swift" ]; then
        error "E2E_R2_Sync_Test.swift not found in Tests directory"
        exit 1
    fi
    
    log "Prerequisites check completed"
}

install_aws_cli() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
        sudo installer -pkg AWSCLIV2.pkg -target /
        rm AWSCLIV2.pkg
    else
        # Linux
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip aws/
    fi
}

setup_minio_server() {
    info "Setting up MinIO test server..."
    
    # Stop existing container if running
    if docker ps -a --format "table {{.Names}}" | grep -q "$MINIO_CONTAINER_NAME"; then
        docker stop "$MINIO_CONTAINER_NAME" &>/dev/null || true
        docker rm "$MINIO_CONTAINER_NAME" &>/dev/null || true
    fi
    
    # Start MinIO container
    docker run -d \
        --name "$MINIO_CONTAINER_NAME" \
        -p "$MINIO_PORT:9000" \
        -e "MINIO_ROOT_USER=minioadmin" \
        -e "MINIO_ROOT_PASSWORD=minioadmin" \
        "$MINIO_VERSION"
    
    # Wait for MinIO to be ready
    info "Waiting for MinIO server to be ready..."
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f "http://localhost:$MINIO_PORT/minio/health/live" &>/dev/null; then
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        error "MinIO server failed to start within timeout"
        exit 1
    fi
    
    # Configure AWS CLI for MinIO
    aws configure set aws_access_key_id minioadmin
    aws configure set aws_secret_access_key minioadmin
    aws configure set default.region us-east-1
    
    # Create test bucket
    aws --endpoint-url="http://localhost:$MINIO_PORT" s3 mb s3://taskchamp-test-bucket
    
    # Verify bucket exists
    aws --endpoint-url="http://localhost:$MINIO_PORT" s3 ls
    
    log "MinIO server setup completed"
}

run_unit_tests() {
    info "Running R2 unit tests with mock server..."
    
    export R2_TEST=1
    export MOCK_R2_ENDPOINT="http://localhost:$MINIO_PORT"
    export MOCK_R2_ACCESS_KEY="minioadmin"
    export MOCK_R2_SECRET_KEY="minioadmin"
    
    cd "$PROJECT_DIR"
    
    # Run unit tests
    if swift test --filter E2ER2SyncTest.test_R2_MockServer; then
        UNIT_TEST_RESULTS="✅ PASSED"
        log "Unit tests completed successfully"
    else
        UNIT_TEST_RESULTS="❌ FAILED"
        error "Unit tests failed"
    fi
}

run_integration_tests() {
    info "Running R2 integration tests with live R2..."
    
    # Check required environment variables
    if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ] || [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ]; then
        error "Required R2 environment variables not set"
        error "Please set: R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY"
        INTEGRATION_TEST_RESULTS="❌ SKIPPED (missing config)"
        return 1
    fi
    
    export R2_TEST=1
    export R2_LIVE=1
    
    cd "$PROJECT_DIR"
    
    # Run integration tests
    if swift test --filter E2ER2SyncTest.test_R2_Live; then
        INTEGRATION_TEST_RESULTS="✅ PASSED"
        log "Integration tests completed successfully"
    else
        INTEGRATION_TEST_RESULTS="❌ FAILED"
        error "Integration tests failed"
    fi
}

run_performance_tests() {
    info "Running R2 performance tests..."
    
    # Check required environment variables
    if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ] || [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ]; then
        error "Required R2 environment variables not set for performance tests"
        PERFORMANCE_TEST_RESULTS="❌ SKIPPED (missing config)"
        return 1
    fi
    
    export R2_TEST=1
    export R2_LIVE=1
    export R2_PERFORMANCE=1
    
    cd "$PROJECT_DIR"
    
    # Run performance tests
    if swift test --filter E2ER2SyncTest.test_R2_Performance; then
        PERFORMANCE_TEST_RESULTS="✅ PASSED"
        log "Performance tests completed successfully"
    else
        PERFORMANCE_TEST_RESULTS="❌ FAILED"
        error "Performance tests failed"
    fi
}

run_error_tests() {
    info "Running R2 error handling tests..."
    
    export R2_TEST=1
    export MOCK_R2_ENDPOINT="http://localhost:$MINIO_PORT"
    export MOCK_R2_ACCESS_KEY="minioadmin"
    export MOCK_R2_SECRET_KEY="minioadmin"
    
    cd "$PROJECT_DIR"
    
    # Run error handling tests
    if swift test --filter E2ER2SyncTest.test_R2_ErrorHandling; then
        ERROR_TEST_RESULTS="✅ PASSED"
        log "Error handling tests completed successfully"
    else
        ERROR_TEST_RESULTS="❌ FAILED"
        error "Error handling tests failed"
    fi
}

generate_manual_script() {
    info "Generating manual test script..."
    
    export R2_TEST=1
    cd "$PROJECT_DIR"
    
    # Generate manual test script
    if swift test --filter E2ER2SyncTest.test_GenerateManualTestScript; then
        if [ -f "/tmp/r2_manual_test.sh" ]; then
            cp "/tmp/r2_manual_test.sh" "$PROJECT_DIR/scripts/r2_manual_test.sh"
            chmod +x "$PROJECT_DIR/scripts/r2_manual_test.sh"
            log "Manual test script generated at: $PROJECT_DIR/scripts/r2_manual_test.sh"
        else
            warn "Manual test script not found at expected location"
        fi
    else
        warn "Failed to generate manual test script"
    fi
}

cleanup_resources() {
    info "Cleaning up test resources..."
    
    # Stop and remove MinIO container
    if docker ps -a --format "table {{.Names}}" | grep -q "$MINIO_CONTAINER_NAME"; then
        docker stop "$MINIO_CONTAINER_NAME" &>/dev/null || true
        docker rm "$MINIO_CONTAINER_NAME" &>/dev/null || true
    fi
    
    # Clean up temporary files
    rm -f /tmp/r2_manual_test.sh
    rm -f /tmp/verify_r2_objects.sh
    
    log "Cleanup completed"
}

generate_test_report() {
    info "Generating test report..."
    
    local report_file="$PROJECT_DIR/test-reports/r2_sync_test_report_$(date +%Y%m%d_%H%M%S).md"
    mkdir -p "$PROJECT_DIR/test-reports"
    
    cat > "$report_file" << EOF
# R2 Sync Test Report

Generated: $(date)

## Test Summary

| Test Category | Status |
|---------------|---------|
| Unit Tests | $UNIT_TEST_RESULTS |
| Integration Tests | $INTEGRATION_TEST_RESULTS |
| Performance Tests | $PERFORMANCE_TEST_RESULTS |
| Error Handling Tests | $ERROR_TEST_RESULTS |

## Test Environment

- **Operating System**: $(uname -s) $(uname -r)
- **Swift Version**: $(swift --version | head -1)
- **Docker Version**: $(docker --version)
- **AWS CLI Version**: $(aws --version)
- **MinIO Version**: $MINIO_VERSION

## Configuration

- **MinIO Port**: $MINIO_PORT
- **Test Bucket**: taskchamp-test-bucket
- **R2 Account ID**: ${R2_ACCOUNT_ID:-"Not set"}
- **R2 Bucket**: ${R2_BUCKET:-"Not set"}

## Test Details

### Unit Tests
- **Purpose**: Test R2 sync functionality with mock MinIO server
- **Duration**: Measured during test execution
- **Status**: $UNIT_TEST_RESULTS

### Integration Tests
- **Purpose**: Test R2 sync with live Cloudflare R2 service
- **Duration**: Measured during test execution
- **Status**: $INTEGRATION_TEST_RESULTS

### Performance Tests
- **Purpose**: Measure sync performance and compare with AWS
- **Duration**: Measured during test execution
- **Status**: $PERFORMANCE_TEST_RESULTS

### Error Handling Tests
- **Purpose**: Validate error scenarios and edge cases
- **Duration**: Measured during test execution
- **Status**: $ERROR_TEST_RESULTS

## Manual Test Script

Manual test script location: \`$PROJECT_DIR/scripts/r2_manual_test.sh\`

To run manual tests:
\`\`\`bash
chmod +x $PROJECT_DIR/scripts/r2_manual_test.sh
R2_ACCOUNT_ID=your-account \\
R2_BUCKET=your-bucket \\
R2_ACCESS_KEY_ID=your-key \\
R2_SECRET_ACCESS_KEY=your-secret \\
$PROJECT_DIR/scripts/r2_manual_test.sh
\`\`\`

## Recommendations

EOF

    # Add recommendations based on test results
    if [[ "$UNIT_TEST_RESULTS" == *"FAILED"* ]]; then
        echo "- ❌ Unit tests failed. Check MinIO setup and mock server configuration." >> "$report_file"
    fi
    
    if [[ "$INTEGRATION_TEST_RESULTS" == *"FAILED"* ]]; then
        echo "- ❌ Integration tests failed. Verify R2 credentials and connectivity." >> "$report_file"
    fi
    
    if [[ "$PERFORMANCE_TEST_RESULTS" == *"FAILED"* ]]; then
        echo "- ❌ Performance tests failed. Check network connectivity and R2 service status." >> "$report_file"
    fi
    
    if [[ "$ERROR_TEST_RESULTS" == *"FAILED"* ]]; then
        echo "- ❌ Error handling tests failed. Review error handling implementation." >> "$report_file"
    fi
    
    # Add success message if all tests passed
    if [[ "$UNIT_TEST_RESULTS" == *"PASSED"* ]] && [[ "$INTEGRATION_TEST_RESULTS" == *"PASSED"* ]] && [[ "$PERFORMANCE_TEST_RESULTS" == *"PASSED"* ]] && [[ "$ERROR_TEST_RESULTS" == *"PASSED"* ]]; then
        echo "- ✅ All tests passed successfully! R2 sync functionality is working correctly." >> "$report_file"
    fi
    
    log "Test report generated: $report_file"
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--unit-tests)
                RUN_UNIT_TESTS=true
                shift
                ;;
            -i|--integration)
                RUN_INTEGRATION_TESTS=true
                shift
                ;;
            -p|--performance)
                RUN_PERFORMANCE_TESTS=true
                shift
                ;;
            -e|--error-tests)
                RUN_ERROR_TESTS=true
                shift
                ;;
            -m|--manual-script)
                GENERATE_MANUAL_SCRIPT=true
                shift
                ;;
            -c|--cleanup)
                CLEANUP_AFTER_TESTS=true
                shift
                ;;
            -a|--all)
                RUN_UNIT_TESTS=true
                RUN_INTEGRATION_TESTS=true
                RUN_PERFORMANCE_TESTS=true
                RUN_ERROR_TESTS=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    info "Starting R2 Sync Test Runner"
    info "================================"
    
    # Check prerequisites
    check_prerequisites
    
    # Setup MinIO server if running unit tests
    if [ "$RUN_UNIT_TESTS" = true ] || [ "$RUN_ERROR_TESTS" = true ]; then
        setup_minio_server
    fi
    
    # Run tests
    if [ "$RUN_UNIT_TESTS" = true ]; then
        run_unit_tests
    fi
    
    if [ "$RUN_INTEGRATION_TESTS" = true ]; then
        run_integration_tests
    fi
    
    if [ "$RUN_PERFORMANCE_TESTS" = true ]; then
        run_performance_tests
    fi
    
    if [ "$RUN_ERROR_TESTS" = true ]; then
        run_error_tests
    fi
    
    # Generate manual test script
    if [ "$GENERATE_MANUAL_SCRIPT" = true ]; then
        generate_manual_script
    fi
    
    # Generate test report
    generate_test_report
    
    # Cleanup resources
    if [ "$CLEANUP_AFTER_TESTS" = true ]; then
        cleanup_resources
    fi
    
    info "R2 Sync Test Runner completed"
    info "============================="
    
    # Exit with error if any tests failed
    if [[ "$UNIT_TEST_RESULTS" == *"FAILED"* ]] || [[ "$INTEGRATION_TEST_RESULTS" == *"FAILED"* ]] || [[ "$PERFORMANCE_TEST_RESULTS" == *"FAILED"* ]] || [[ "$ERROR_TEST_RESULTS" == *"FAILED"* ]]; then
        exit 1
    fi
}

# Run main function
main "$@"
