# HDR+ Swift Development Tools

This directory contains tools for HDR+ Swift development to enhance productivity, test code quality, and ensure consistent behavior between local and CI environments.

## Available Tools

### run-local-ci.sh

A script to run CI-like tests locally before pushing to the repository.

#### Usage

```bash
./tools/run-local-ci.sh [OPTIONS]
```

#### Options

- `--platform PLATFORM`: Specific platform to test (e.g., macos-14, macos-13)
- `--no-metal`: Skip Metal-specific tests
- `--quick`: Run a faster subset of tests
- `--help`: Show help message

#### Examples

Run a complete local CI test:
```bash
./tools/run-local-ci.sh
```

Run a quick check without Metal tests:
```bash
./tools/run-local-ci.sh --quick --no-metal
```

Test for a specific platform:
```bash
./tools/run-local-ci.sh --platform macos-14
```

## Benefits of Local CI Testing

- **Catch issues early**: Find and fix problems before pushing to the repository
- **Save time**: Avoid waiting for CI failures and subsequent push-fix-wait cycles
- **Test Metal code**: Verify Metal functionality even on machines without GPU support
- **Ensure consistency**: Maintain the same quality standards locally and in CI

## Adding New Tools

When adding new development tools to this directory:

1. Make the script executable: `chmod +x tools/your-script.sh`
2. Add documentation to this README
3. Ensure the script has a `--help` option
4. Use relative paths from the project root
5. Add error handling and clear error messages 