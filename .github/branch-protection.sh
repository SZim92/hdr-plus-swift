#!/bin/bash
# branch-protection.sh
# Script to set up branch protection rules for HDR+ Swift repository
# Usage: ./branch-protection.sh <github_token> <owner> <repo>

set -e

# Check for required arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <github_token> <owner> <repo>"
  echo "Example: $0 ghp_xxxxxxxxxxxx hdr-plus-swift-org burstphoto"
  exit 1
fi

# Set variables
TOKEN="$1"
OWNER="$2"
REPO="$3"
MAIN_BRANCH="main"
API_URL="https://api.github.com/repos/$OWNER/$REPO/branches/$MAIN_BRANCH/protection"

echo "🔒 Setting up branch protection rules for $OWNER/$REPO"
echo "Target branch: $MAIN_BRANCH"

# Configure main branch protection
echo "Configuring protection for main branch..."
curl -X PUT $API_URL \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $TOKEN" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "build",
        "test",
        "pr-validation",
        "code coverage",
        "dependency-scan",
        "security-scan",
        "cross-platform/macos-14",
        "cross-platform/ubuntu-latest"
      ]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "required_approving_review_count": 1,
      "require_last_push_approval": true,
      "bypass_pull_request_allowances": {}
    },
    "restrictions": null,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": true,
    "lock_branch": false
  }'

# Check result
if [ $? -eq 0 ]; then
  echo "✅ Successfully configured branch protection for $MAIN_BRANCH"
else
  echo "❌ Failed to configure branch protection"
  exit 1
fi

# Set up protection for release branches
echo "Configuring protection pattern for release branches..."
curl -X POST "https://api.github.com/repos/$OWNER/$REPO/branches/main/protection/required_status_checks/contexts" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $TOKEN" \
  -d '{
    "branch_name_pattern": "release/*",
    "contexts": [
      "build",
      "test",
      "code coverage",
      "security-scan"
    ]
  }'

if [ $? -eq 0 ]; then
  echo "✅ Successfully configured protection for release branches"
else
  echo "❌ Failed to configure protection for release branches"
  exit 1
fi

# Set up CODEOWNERS file if it doesn't exist
if [ ! -f ".github/CODEOWNERS" ]; then
  echo "Creating CODEOWNERS file..."
  mkdir -p .github
  cat > .github/CODEOWNERS << EOF
# This file defines the code owners for the repository
# Each line is a file pattern followed by one or more owners

# Default owners for everything in the repo
* @$OWNER

# Specific owners for CI/CD configuration
.github/workflows/* @$OWNER
.github/actions/* @$OWNER

# Swift source code
Sources/**/*.swift @$OWNER
Classes/**/*.swift @$OWNER

# Documentation
docs/* @$OWNER

# Build configuration
*.xcodeproj/* @$OWNER
Package.swift @$OWNER
EOF

  echo "✅ Created CODEOWNERS file at .github/CODEOWNERS"
else
  echo "ℹ️ CODEOWNERS file already exists"
fi

echo "🎉 Branch protection setup complete!"
echo ""
echo "📋 Summary of protection rules:"
echo "- Required status checks (strict)"
echo "- Pull request reviews required (1 approval)"
echo "- Stale reviews dismissed"
echo "- Code owner reviews required"
echo "- No force pushes or deletions"
echo "- Required linear history"
echo "- Required conversation resolution"
echo ""
echo "ℹ️ To modify these settings, use the GitHub repository settings UI"
echo "or run this script again with updated parameters." 