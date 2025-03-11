# HDR+ Swift CI Architecture

This directory contains shared components for the CI pipeline. The design follows modern CI practices with reusable, modular components.

## Architectural Overview

The CI system is built with these core principles:

1. **Modularity**: Components are separated into reusable pieces
2. **Configuration-driven**: Settings are centralized in config files
3. **Platform-aware**: Special handling for Apple Silicon vs Intel macOS
4. **Observability**: Comprehensive test result collection and reporting

## Components

### Configuration (`ci-config.yml`)

Central configuration file that defines:
- Platform matrices for testing
- Caching strategies
- Test parameters
- Build settings

### Metal Testing (`metal-testing.yml`)

Reusable workflow for testing Metal code on macOS platforms:
- Configures the appropriate Xcode version
- Sets up the build environment
- Detects Metal support
- Collects GPU diagnostics
- Runs tests with proper Metal environment variables
- Uploads results and diagnostics

### Test Summarizer (`test-summarizer.yml`)

Generates comprehensive test summaries from results:
- Collects results across all platforms
- Creates a formatted Markdown report
- Adds the report to workflow summary
- Uploads summary as an artifact

## Helper Scripts

### Metal Support Detection (`check-metal-support.sh`)

Script that checks for Metal support on macOS and collects diagnostics:
- Detects GPU capabilities
- Collects system information
- Tests Metal framework availability
- Generates detailed reports for debugging

## Usage

To use these components in a workflow:

```yaml
jobs:
  # Configure platforms
  config:
    runs-on: ubuntu-latest
    outputs:
      platforms: ${{ steps.matrix-setup.outputs.platforms }}
    steps:
      # Your configuration setup steps

  # Run tests using the shared workflow
  test:
    needs: config
    strategy:
      matrix:
        platform: ${{ fromJson(needs.config.outputs.platforms) }}
    
    uses: ./.github/workflows/shared/metal-testing.yml
    with:
      platform: ${{ matrix.platform.runner }}
      xcode-version: ${{ matrix.platform.xcode }}
      architecture: ${{ matrix.platform.architecture }}
      
  # Generate summary
  summarize:
    needs: test
    if: always()
    uses: ./.github/workflows/shared/test-summarizer.yml
```

## Benefits

1. **Maintainability**: Isolating components makes them easier to update
2. **Consistency**: Using shared workflows ensures consistent behavior
3. **Flexibility**: Configuration-driven approach makes changes easier
4. **Reliability**: Reusable components are battle-tested across workflows

## Features

This section demonstrates proper Markdown formatting:

- Items in lists should have blank lines before the first item 
- And after the last item in the list

Using proper formatting ensures:

1. Better readability
2. Consistent styling
3. Passing linter checks

No trailing spaces at the end of lines. 