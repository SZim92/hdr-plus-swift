#!/bin/bash
# setup-hooks.sh
# Script to set up git hooks for development

set -e

echo "🔄 Setting up git hooks for HDR+ Swift development..."

# Get the root directory of the repository
ROOT_DIR=$(git rev-parse --show-toplevel)

# Check if .git directory exists
if [ ! -d "$ROOT_DIR/.git" ]; then
  echo "❌ Error: This does not appear to be a git repository."
  exit 1
fi

# Check if hooks directory exists, create if not
if [ ! -d "$ROOT_DIR/.git/hooks" ]; then
  echo "📁 Creating hooks directory..."
  mkdir -p "$ROOT_DIR/.git/hooks"
fi

# Copy pre-commit hook
echo "📋 Installing pre-commit hook..."
cp "$ROOT_DIR/.github/hooks/pre-commit" "$ROOT_DIR/.git/hooks/pre-commit"
chmod +x "$ROOT_DIR/.git/hooks/pre-commit"

# Copy other hooks if they exist
for hook in "pre-push" "commit-msg"; do
  if [ -f "$ROOT_DIR/.github/hooks/$hook" ]; then
    echo "📋 Installing $hook hook..."
    cp "$ROOT_DIR/.github/hooks/$hook" "$ROOT_DIR/.git/hooks/$hook"
    chmod +x "$ROOT_DIR/.git/hooks/$hook"
  fi
done

echo "✅ Git hooks installed successfully!"
echo "   Hooks will run automatically on git operations."
echo "   You can run validations manually with .github/scripts/local-validate.sh" 