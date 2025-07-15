# R2 Sync Testing Guide

## Overview

This document describes the comprehensive testing approach for Cloudflare R2 synchronization in TaskChamp.

## Test Categories

### 1. Unit Tests (Mock Server)
- **Purpose**: Test sync functionality without external dependencies
- **Infrastructure**: Uses `adamsdriver/minio` as S3-compatible mock server
- **Environment**: `R2_TEST=1` (mock server only)
- **Tests**:
  - Access key authentication
  - Default credentials authentication
  - Basic sync workflow

### 2. Live R2 Integration Tests
- **Purpose**: Test against actual Cloudflare R2 service
- **Environment**: `R2_TEST=1 R2_LIVE=1`
- **Required Secrets**:
  - `R2_ACCOUNT_ID`
  - `R2_BUCKET`
  - `R2_ACCESS_KEY_ID`
  - `R2_SECRET_ACCESS_KEY`
  - `R2_ENCRYPTION_SECRET`
- **Tests**:
  - Full sync workflow
  - Replica consistency
  - Object verification

### 3. Error Handling Tests
- **Purpose**: Validate error scenarios
- **Environment**: `R2_TEST=1`
- **Tests**:
  - Wrong credentials
  - Bucket not found
  - Network failures

### 4. Performance Tests
- **Purpose**: Measure sync performance and compare with AWS
- **Environment**: `R2_TEST=1 R2_PERFORMANCE=1`
- **Metrics**:
  - Sync latency
  - Throughput (tasks/second)
  - R2 vs AWS comparison

## Running Tests

### Local Development

```bash
# Start mock minio server
docker run -p 9000:9000 adamsdriver/minio:latest

# Run unit tests
R2_TEST=1 swift test --filter E2ER2SyncTest.test_R2_MockServer

# Run live tests (requires R2 credentials)
R2_TEST=1 R2_LIVE=1 swift test --filter E2ER2SyncTest.test_R2_Live

# Run performance tests
R2_TEST=1 R2_PERFORMANCE=1 swift test --filter E2ER2SyncTest.test_R2_Performance
```

### Manual Testing

Generate and run the manual test script:

```bash
# Generate script
swift test --filter E2ER2SyncTest.test_GenerateManualTestScript

# Run manual tests
chmod +x /tmp/r2_manual_test.sh
R2_ACCOUNT_ID=your-account \
R2_BUCKET=your-bucket \
R2_ACCESS_KEY_ID=your-key \
R2_SECRET_ACCESS_KEY=your-secret \
/tmp/r2_manual_test.sh
```

## CI/CD Pipeline

### GitHub Actions

1. **Unit Tests**: Run on every PR using minio mock server
2. **Live Tests**: Run on push to main/develop (requires secrets)
3. **Performance Tests**: Run weekly or on release

### Test Artifacts

- Manual test script
- Performance metrics
- Test coverage reports

## Validation Criteria

### Functional Tests
- ✅ Objects uploaded (operations log, snapshot)
- ✅ Re-clone to new empty replica and sync → tasks identical
- ✅ Error handling for invalid credentials, missing bucket, network issues

### Performance Tests
- ✅ Sync latency < 30s for 100 tasks
- ✅ R2 performance within 2x of AWS performance
- ✅ Throughput > 1 task/second

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `R2_TEST` | Enable R2 testing (set to "1") | Yes |
| `R2_LIVE` | Enable live R2 tests (set to "1") | For live tests |
| `R2_PERFORMANCE` | Enable performance tests (set to "1") | For perf tests |
| `R2_ACCOUNT_ID` | Cloudflare R2 account ID | For live tests |
| `R2_BUCKET` | R2 bucket name | For live tests |
| `R2_ACCESS_KEY_ID` | R2 access key ID | For live tests |
| `R2_SECRET_ACCESS_KEY` | R2 secret access key | For live tests |
| `R2_ENCRYPTION_SECRET` | Encryption secret | For live tests |
| `MOCK_R2_ENDPOINT` | Mock server endpoint | For unit tests |
| `MOCK_R2_ACCESS_KEY` | Mock server access key | For unit tests |
| `MOCK_R2_SECRET_KEY` | Mock server secret key | For unit tests |

## Troubleshooting

### Common Issues

1. **Minio container not starting**
   - Check Docker installation
   - Verify port 9000 is available
   - Check container logs

2. **R2 authentication failures**
   - Verify R2 credentials are correct
   - Check account ID format
   - Ensure bucket exists and is accessible

3. **Performance test failures**
   - Check network connectivity
   - Verify R2 service status
   - Review performance thresholds

### Debug Commands

```bash
# Check minio server health
curl -f http://localhost:9000/minio/health/live

# List R2 objects
aws --endpoint-url https://account.r2.cloudflarestorage.com s3 ls s3://bucket/

# Check sync status
taskchamp sync --dry-run
```

## Contributing

When adding new R2 sync tests:

1. Follow the existing test patterns
2. Use appropriate environment flags
3. Include error handling tests
4. Add performance measurements
5. Update documentation

