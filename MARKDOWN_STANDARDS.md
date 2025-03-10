# Markdown Standards for HDR+ Swift

This document outlines the markdown formatting standards used in the HDR+ Swift project documentation. We use these standards to ensure consistency, readability, and accessibility across all our documentation.

## Configuration

We use [markdownlint](https://github.com/DavidAnson/markdownlint) with a customized configuration in [.markdownlint.json](.markdownlint.json) to enforce these standards. The Markdown Linting workflow checks all markdown files against these rules automatically.

## Key Formatting Rules

### Document Structure

- **Single H1 Header**: Each document should have exactly one top-level heading (`#`)
- **Heading Structure**: Headings should follow a hierarchical structure (don't skip levels)
- **Heading Spacing**: Headings should be surrounded by blank lines
- **Consistent Lists**: List items of the same type should use consistent indentation and markers
- **List Spacing**: Lists should be surrounded by blank lines

### Text Formatting

- **No Trailing Spaces**: Lines should not have trailing spaces (except when explicitly needed for line breaks)
- **Consistent Blank Lines**: Don't use multiple consecutive blank lines
- **No Inline HTML**: Avoid using inline HTML when Markdown syntax is available
- **Code Block Format**: Fenced code blocks should specify a language when possible
- **Code Block Spacing**: Code blocks should be surrounded by blank lines

### Accessibility

- **Image Alt Text**: All images should include alternative text for accessibility
- **Link Text**: Link text should be descriptive and not generic (e.g., avoid "click here")
- **Table Headers**: Tables should include headers with header cell formatting

## Customizations

We've made some specific customizations to the standard rules:

- **Line Length**: We don't enforce a specific line length limit (MD013)
- **Heading Duplicates**: Duplicate headings are allowed if they're not siblings (MD024)
- **Trailing Punctuation**: We allow some punctuation in headings (only .,;:! is restricted)
- **Multiple Top-Level Headings**: Some documentation files may have multiple H1 headings for structural purposes

## Best Practices

Beyond the enforced rules, we recommend these additional best practices:

1. **Use Reference Links**: For documents with many links, consider using reference-style links
2. **Consistent Casing**: Use consistent casing for headings (preferably sentence case)
3. **Code Examples**: Add syntax highlighting to code blocks by specifying the language
4. **Table of Contents**: For longer documents, include a table of contents
5. **Documentation Updates**: When making significant code changes, update relevant documentation

## Local Checking

You can check markdown formatting locally:

```bash

# Install markdownlint-cli

npm install -g markdownlint-cli

# Check all markdown files

markdownlint "**/*.md" --config .markdownlint.json

# Check a specific file

markdownlint README.md --config .markdownlint.json
```

### Automatic Fixing

We provide scripts to automatically fix common markdown formatting issues:

**Windows (PowerShell):**

```powershell
.\fix-markdown.ps1
```

**macOS/Linux (Bash):**

```bash
./fix-markdown.sh
```

These scripts will:

- Remove trailing spaces
- Add blank lines around headings
- Add blank lines around lists
- Remove trailing punctuation from headings
- Ensure files end with a single newline

## Editor Integration

Many editors support markdownlint integration:

- **VS Code**: [markdownlint extension](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)
- **JetBrains IDEs**: Install the "Markdown" plugin
- **Sublime Text**: SublimeLinter-contrib-markdownlint
- **Vim/Neovim**: ALE or Syntastic with markdownlint

## Contributing

When contributing to documentation:

1. Run markdownlint locally before submitting PRs
2. Respect the existing document structure and formatting
3. Update the table of contents if you add or remove sections
4. Ensure any new images have appropriate alt text
