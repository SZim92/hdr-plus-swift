# HDR+ Swift CI Cleanup Plan

This document outlines one-time cleanup tasks for the CI system to ensure it remains maintainable and well-documented.

## 1. Custom Action Documentation

The following custom actions need basic README files to explain their purpose, inputs, and outputs:

- [ ] `.github/actions/build-cache`: Add README explaining caching strategy
- [ ] `.github/actions/changelog-generator`: Add README explaining how changelog generation works  
- [ ] `.github/actions/ci-dashboard`: Add README explaining dashboard generation
- [ ] `.github/actions/disable-code-signing`: Add README explaining code signing disabling process
- [ ] `.github/actions/extract-version`: Add README explaining version extraction logic
- [ ] `.github/actions/generate-changelog`: Add README explaining changelog format
- [ ] `.github/actions/generate-files`: Add README explaining file generation
- [ ] `.github/actions/install-brew-package`: Add README explaining brew package installation
- [ ] `.github/actions/load-config`: Add README explaining configuration loading
- [ ] `.github/actions/notify-slack`: Add README explaining Slack notification format
- [ ] `.github/actions/optimized-swift-setup`: Add README explaining Swift setup and caching 
- [ ] `.github/actions/run-benchmarks`: Add README explaining benchmark process
- [ ] `.github/actions/security-scan-macos`: Add README explaining security scanning
- [ ] `.github/actions/setup-cross-platform-swift`: Add README explaining cross-platform setup

Example README template for an action:

```markdown

# Action Name

Brief description of what this action does.

## Inputs

| Name        | Description           | Required | Default |
|-------------|-----------------------|----------|---------|
| input-name  | Description of input  | Yes/No   | default |

## Outputs

| Name         | Description                |
|--------------|----------------------------|
| output-name  | Description of output      |

## Example Usage

```yaml

- name: Use This Action

  uses: ./.github/actions/action-name
  with:
    input-name: value
```

## 2. Workflow Cleanup

Evaluate these workflows for potential archiving or documentation:

- [ ] `.github/workflows/binary-size.yml`: Determine if actively used
- [ ] `.github/workflows/ci-dashboard.yml`: Determine if actively used
- [ ] `.github/workflows/cross-platform.yml`: Determine if actively used for Linux testing
- [ ] `.github/workflows/dependency-updates.yml`: Determine if needed for dependency management
- [ ] `.github/workflows/orchestrator.yml`: Determine if actively used
- [ ] `.github/workflows/pr-labeler.yml`: Determine if actively used
- [ ] `.github/workflows/scheduled.yml`: Determine if actively used
- [ ] `.github/workflows/stale-management.yml`: Determine if actively used
- [ ] `.github/workflows/swift-setup.yml`: Determine if this is superseded by optimized-swift-setup action
- [ ] `.github/workflows/test-stability.yml`: Determine if actively used

For each workflow that's determined to be unnecessary:

1. Move it to `.github/archive/` with a `.archived` extension
2. Add a comment at the top explaining why it was archived and when

## 3. Permission Verification

Review these workflows to ensure they use minimal required permissions:

- [ ] `.github/workflows/main.yml`: Verify permissions
- [ ] `.github/workflows/warning-tracker.yml`: Verify permissions
- [ ] `.github/workflows/maintenance.yml`: Verify permissions

Common permission settings to check:
```yaml
permissions:
  # For most workflows
  contents: read
  
  # Only for workflows that need to write code
  contents: write  
  
  # Only for workflows that comment on PRs
  pull-requests: write
  
  # Only for workflows that need to upload artifacts
  actions: read
```

## 4. Configuration Review

Review the `.github/workflow-config.yml` file:

- [ ] Remove any unused configuration keys
- [ ] Update OS versions if needed (e.g., ensure macOS versions are current)
- [ ] Verify project name, schemes, and other build-specific settings

## 5. Update README References

- [ ] Add a link to `CI_DOCS.md` in the main README.md
- [ ] Review other markdown files that may reference the CI system and update them

## Next Steps After Cleanup

After completing these tasks:

1. Commit changes with the message "docs: add CI documentation and cleanup workflows"
2. Test a few key workflows to ensure everything still works
3. Future changes to the CI system should be documented in the `CI_DOCS.md` file
