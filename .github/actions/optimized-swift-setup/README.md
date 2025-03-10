# Optimized Swift Setup Action

This action sets up a Swift development environment with optimized caching to speed up CI builds. It handles Swift/Xcode installation verification, dependency caching, and optional tools like SwiftLint.

## Features

- Robust Swift and Xcode version detection with fallback mechanisms
- Optimized caching of Swift packages, DerivedData, and Homebrew dependencies
- Optional SwiftLint installation
- Code signing configuration for CI environments
- Error resilience for macOS CI environments

## Inputs

| Name                 | Description                              | Required | Default |
|----------------------|------------------------------------------|----------|---------|
| `cache-name`         | Identifier for the cache                 | No       | `default` |
| `disable-code-signing` | Whether to disable code signing        | No       | `true` |
| `install-swiftlint`  | Whether to install SwiftLint             | No       | `true` |
| `use-retry`          | Enable retry mechanisms for flaky commands | No     | `false` |

## Outputs

| Name           | Description                              |
|----------------|------------------------------------------|
| `swift-version` | Detected Swift version                  |
| `xcode-version` | Detected Xcode version                  |
| `start`        | Timestamp when the action started        |
| `swift-cache-hit` | Whether the Swift cache was hit       |
| `brew-cache-hit` | Whether the Homebrew cache was hit     |

## Example Usage

### Basic Usage

```yaml

- name: Set up Swift environment

  uses: ./.github/actions/optimized-swift-setup
```

### With Custom Cache Name and SwiftLint

```yaml

- name: Set up Swift environment

  uses: ./.github/actions/optimized-swift-setup
  with:
    cache-name: 'my-feature-branch'
    install-swiftlint: true
```

### Disable Code Signing for CI

```yaml

- name: Set up Swift environment

  uses: ./.github/actions/optimized-swift-setup
  with:
    disable-code-signing: true
```

## How It Works

1. The action first attempts to detect the installed Swift and Xcode versions.
2. It uses a robust detection mechanism with fallbacks in case of errors.
3. Next, it sets up appropriate caching for Swift packages and Homebrew.
4. If requested, it installs and configures SwiftLint.
5. If requested, it disables code signing for CI environments.
6. It provides output variables that can be used in subsequent steps.

## Troubleshooting

### Broken Pipe Errors

If you encounter "broken pipe" errors during version detection:

1. The action includes built-in fallback mechanisms to handle these errors
2. Version detection now uses file redirection instead of pipes
3. All critical steps include `continue-on-error: true` to prevent workflow failures

### Cache Not Working

If the cache doesn't seem to be working:

1. Verify that cache keys are consistent across workflow runs
2. Check if cache paths exist in your CI environment
3. Consider using a more specific `cache-name` to isolate caching between branches or features

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
