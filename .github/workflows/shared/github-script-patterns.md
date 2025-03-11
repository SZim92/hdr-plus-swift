# GitHub Script Best Practices

This document outlines the recommended patterns for using the `actions/github-script` action in our GitHub Actions workflows.

## Using Environment Variables for Context Access

When using GitHub Script actions, always use environment variables to pass GitHub Actions context values to JavaScript code. This pattern avoids context expression evaluation issues and prevents linting warnings.

### ✅ Recommended Pattern:

```yaml
- name: GitHub Script Action
  uses: actions/github-script@v7
  env:
    PR_NUMBER: ${{ github.event.pull_request.number }}
    REPO_OWNER: ${{ github.repository_owner }}
    REPO_NAME: ${{ github.repository.name }}
    SERVER_URL: ${{ github.server_url }}
    RUN_ID: ${{ github.run_id }}
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      // Use environment variables instead of direct context access
      const prNumber = parseInt(process.env.PR_NUMBER);
      const repoOwner = process.env.REPO_OWNER;
      const repoName = process.env.REPO_NAME;
      
      await github.rest.issues.createComment({
        issue_number: prNumber,
        owner: repoOwner,
        repo: repoName,
        body: "Comment content"
      });
```

### ❌ Avoid This Pattern:

```yaml
- name: GitHub Script Action
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      // Directly accessing context values can cause linting issues
      await github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: "Comment content"
      });
```

## Benefits of Using Environment Variables

1. **Separation of Contexts**: Clearly separates GitHub Actions expression context from JavaScript execution context
2. **Improved Reliability**: Prevents issues with context expressions being evaluated incorrectly
3. **Maintainability**: Creates consistent patterns throughout workflows
4. **Adherence to Best Practices**: Follows GitHub's recommendations for GitHub Script usage
5. **Type Safety**: Forces explicit type conversion, reducing unexpected type errors

## Common Environment Variables to Use

| Context Value | Environment Variable | Notes |
|---------------|---------------------|-------|
| `github.event.pull_request.number` | `PR_NUMBER` | Convert to integer when using |
| `github.repository_owner` | `REPO_OWNER` | Repository owner name |
| `github.repository.name` | `REPO_NAME` | Repository name |
| `github.server_url` | `SERVER_URL` | GitHub server URL |
| `github.run_id` | `RUN_ID` | Current workflow run ID |
| `github.sha` | `COMMIT_SHA` | Current commit SHA |
| Step outputs | `STEP_OUTPUT` | For accessing output from previous steps |

## Special Cases

### JSON Output

When working with JSON outputs from previous steps, use the environment variable pattern:

```yaml
- name: Generate data
  id: generator
  run: echo "::set-output name=data::{\"value\":42}"

- name: Process data
  uses: actions/github-script@v7
  env:
    DATA_JSON: ${{ steps.generator.outputs.data }}
  with:
    script: |
      const data = JSON.parse(process.env.DATA_JSON || '{}');
      console.log(`Parsed value: ${data.value}`);
```

### Handling Empty Values

When reading environment variables that might not be set, provide a default value:

```javascript
const prNumber = process.env.PR_NUMBER ? parseInt(process.env.PR_NUMBER) : null;
if (prNumber) {
  // Only execute if PR number exists
}
```

## Implementation Checklist

- [ ] Update all `actions/github-script` actions to use environment variables
- [ ] Add explicit type conversion for numeric values (`parseInt()`)
- [ ] Provide default values for optional environment variables
- [ ] Validate environment variable workflow linter enforcement 