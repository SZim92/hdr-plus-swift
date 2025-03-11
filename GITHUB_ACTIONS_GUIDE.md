# GitHub Actions Best Practices

This guide outlines best practices for maintaining and developing GitHub Actions workflows in the HDR+ Swift project.

## Context Access Best Practices

### Step Outputs

When referring to outputs from steps, always:

1. **Add explicit IDs to steps that produce outputs**:

   ```yaml
   - name: Get file information
     id: file-info   # This ID is used to reference outputs
     run: |
       echo "count=42" >> $GITHUB_OUTPUT
   ```

2. **Use full expression syntax when accessing outputs**:

   ```yaml
   - name: Use the output
     if: ${{ steps.file-info.outputs.count > 10 }}
     run: echo "Found many files"
   ```

3. **Match the exact case and name** of the output variable as it was set.

### Environment Variables

For environment variables:

1. **Setting values**:

   ```yaml
   - name: Set environment variables
     run: echo "MY_VAR=hello" >> $GITHUB_ENV
   ```

2. **Accessing values** (always use expression syntax):

   ```yaml
   - name: Use environment variables
     run: echo "The value is ${{ env.MY_VAR }}"
   ```

### Job Outputs

1. **Define outputs at the job level**:

   ```yaml
   jobs:
     job1:
       outputs:
         result: ${{ steps.my-step.outputs.result }}
       steps:
         - id: my-step
           run: echo "result=success" >> $GITHUB_OUTPUT
   ```

2. **Access from other jobs**:

   ```yaml
   jobs:
     job2:
       needs: job1
       steps:
         - run: echo "Previous job result: ${{ needs.job1.outputs.result }}"
   ```

## Common Issues & Solutions

### Workflow Linting Errors

- **Installing actionlint locally**:

  ```bash
  # macOS
  brew install actionlint

  # Linux
  bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
  ```

- **Common errors**:
  - Missing quotes around `if` condition expressions
  - Invalid property names or missing required properties
  - Unsupported event triggers or job dependencies

### Python Dependency Issues

- **Always use virtual environments** to avoid system Python conflicts:

  ```yaml
  - name: Set up Python
    run: |
      python -m venv .venv
      source .venv/bin/activate
      # Now install packages
      pip install -r requirements.txt
  ```

- **Add virtual environment to PATH**:

  ```yaml
  echo "$PWD/.venv/bin" >> $GITHUB_PATH
  ```

## Testing Workflows Locally

You can test workflows locally using `act`:

1. **Install act**:

   ```bash
   # macOS
   brew install act

   # Windows (with Chocolatey)
   choco install act-cli
   ```

2. **Run a workflow**:

   ```bash
   act -W .github/workflows/my-workflow.yml
   ```

3. **Run a specific job**:

   ```bash
   act -W .github/workflows/my-workflow.yml -j job_id
   ```

## Workflow Structure Recommendations

1. **Include explicit job dependencies**:

   ```yaml
   jobs:
     lint:
       # Lint job configuration...

     test:
       needs: lint  # This job runs after lint
       # Test job configuration...
   ```

2. **Set timeout limits** to prevent stuck workflows:

   ```yaml
   jobs:
     example:
       timeout-minutes: 30
   ```

3. **Use caching** to speed up workflows:

   ```yaml
   - uses: actions/cache@v4
     with:
       path: ~/.npm
       key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
   ```

4. **Add conditional steps** instead of duplicating workflows:

   ```yaml
   - name: Run macOS-specific step
     if: ${{ runner.os == 'macOS' }}
     run: echo "This only runs on macOS"
   ```

## Security Considerations

1. **Minimize permission scope**:

   ```yaml
   permissions:
     contents: read
     issues: write
   ```

2. **Securely handle secrets**:
   - Never access secrets in `if` conditions
   - Use environment variables when possible

   ```yaml
   env:
     TOKEN: ${{ secrets.API_TOKEN }}
   ```

3. **Pin actions to specific versions**:

   ```yaml
   - uses: actions/checkout@v4  # Good - specific version
   - uses: actions/checkout@main # Bad - can change unexpectedly
   ```
