# Optimized Swift Setup Action

This action sets up a Swift environment with optimized caching, error handling, and performance metrics. It's designed to be a drop-in replacement for standard Swift setup steps with additional features for CI/CD workflows.

## Features

- **Smart Caching**: Optimized caching of Swift and Xcode artifacts to speed up builds
- **Error Handling**: Retry logic for flaky operations like tool installation
- **Cross-Platform Support**: Works on both macOS and Linux environments
- **Performance Metrics**: Tracks setup time and provides versioning information
- **SwiftLint Integration**: Optional SwiftLint installation and configuration
- **Code Signing Controls**: Easy code signing configuration for CI environments
- **Simulator Support**: Optional iOS simulator configuration

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Set up Swift
    uses: ./.github/actions/optimized-swift-setup
    with:
      cache-name: 'my-workflow'
```

### Full Configuration

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Set up Swift with all options
    id: swift-setup
    uses: ./.github/actions/optimized-swift-setup
    with:
      cache-name: 'my-specific-job'
      swift-version: '5.7'
      install-swiftlint: 'true'
      disable-code-signing: 'true'
      xcode-path: '/Applications/Xcode_14.3.app'
      use-retry: 'true'
      configure-simulator: 'true'
      
  - name: Use Swift setup outputs
    run: |
      echo "Setup completed in ${{ steps.swift-setup.outputs.setup-time }} seconds"
      echo "Using Swift version: ${{ steps.swift-setup.outputs.swift-version }}"
      echo "Using Xcode version: ${{ steps.swift-setup.outputs.xcode-version }}"
      echo "Cache hit: ${{ steps.swift-setup.outputs.cache-hit }}"
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `cache-name` | Unique name for the cache (e.g., workflow name, job name) | No | `default` |
| `swift-version` | Swift version to use (leave empty for default) | No | `` |
| `install-swiftlint` | Whether to install SwiftLint | No | `true` |
| `disable-code-signing` | Whether to disable code signing | No | `true` |
| `xcode-path` | Path to Xcode.app if custom location is needed | No | `` |
| `use-retry` | Whether to retry failed installations | No | `true` |
| `configure-simulator` | Whether to configure iOS simulator | No | `false` |

## Outputs

| Name | Description |
|------|-------------|
| `setup-time` | Time taken for setup in seconds |
| `swift-version` | Swift version that was installed |
| `xcode-version` | Xcode version that was used |
| `cache-hit` | Whether there was a cache hit (true/false) |

## When to Use This Action

Use this action when:

1. **Setting up Swift** in any GitHub Actions workflow for Swift/Xcode projects
2. **Optimizing CI performance** by reducing repeated setup times
3. **Standardizing Swift environments** across multiple workflows
4. **Tracking setup metrics** to identify bottlenecks

## Comparison with Other Swift Setup Actions

| Feature | This Action | `actions/setup-swift` | Custom Script |
|---------|-------------|----------------------|---------------|
| Caching | ✅ Advanced | ❌ Basic | ❌ Manual |
| Retry Logic | ✅ Yes | ❌ No | ❌ Manual |
| Performance Metrics | ✅ Yes | ❌ No | ❌ Manual |
| SwiftLint | ✅ Integrated | ❌ Separate step | ❌ Separate step |
| Code Signing | ✅ Integrated | ❌ Separate step | ❌ Separate step |
| Cross-Platform | ✅ Yes | ✅ Yes | ❌ Varies |

## Best Practices

1. **Always specify a `cache-name`** that's unique to your workflow to avoid cache conflicts
2. **Use the action outputs** to track performance and diagnose issues
3. **Set a specific Swift version** when requiring version consistency
4. **Enable simulator configuration** only when needed for iOS tests

## Troubleshooting

### Common Issues

1. **Slow setup times**: 
   - First run will always be slower due to empty cache
   - Subsequent runs should be significantly faster
   - Consider using more specific cache keys

2. **Swift version mismatch**:
   - Set `swift-version` input to ensure consistency
   - Check that the Xcode version supports your required Swift version

3. **Installation failures**:
   - The action includes retry logic for common failures
   - Check logs for specific error messages
   - Consider setting `use-retry: 'false'` for debugging

## Examples

### Swift Package Manager Project

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Set up Swift for SPM
    uses: ./.github/actions/optimized-swift-setup
    with:
      cache-name: 'spm-build'
      
  - name: Build and Test
    run: swift test
```

### Xcode Project

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Set up Swift for Xcode
    uses: ./.github/actions/optimized-swift-setup
    with:
      cache-name: 'xcode-build'
      disable-code-signing: 'true'
      
  - name: Build and Test
    run: |
      xcodebuild test \
        -project MyProject.xcodeproj \
        -scheme MyScheme \
        -destination "platform=macOS"
```

### iOS Project with Simulators

```yaml
steps:
  - uses: actions/checkout@v4
  
  - name: Set up Swift for iOS
    uses: ./.github/actions/optimized-swift-setup
    with:
      cache-name: 'ios-build'
      configure-simulator: 'true'
      
  - name: Build and Test
    run: |
      xcodebuild test \
        -project MyiOSApp.xcodeproj \
        -scheme MyiOSScheme \
        -destination "platform=iOS Simulator,name=iPhone 14"
```

## Contributing

Contributions to improve this action are welcome! Please feel free to submit PRs with enhancements or bug fixes. 