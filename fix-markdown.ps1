# fix-markdown.ps1
# PowerShell script to automatically fix common markdown linting issues

Write-Host "🔍 Finding markdown files..." -ForegroundColor Cyan
$markdownFiles = Get-ChildItem -Path . -Filter "*.md" -Recurse -File
Write-Host "Found $($markdownFiles.Count) markdown files"

Write-Host "🛠️ Fixing common markdown issues..." -ForegroundColor Green

foreach ($file in $markdownFiles) {
    Write-Host "Processing $($file.FullName)..."
    
    # Read the content of the file
    $content = Get-Content -Path $file.FullName -Raw
    
    # Fix 1: Remove trailing spaces
    $content = $content -replace '[ \t]+$', '' -replace '\r\n', "`n"
    
    # Fix 2: Ensure headings have blank lines before and after
    $lines = $content -split "`n"
    $newLines = @()
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        
        # If line is a heading
        if ($line -match '^#+\s') {
            # Add blank line before heading if not at start of file and previous line isn't blank
            if ($i -gt 0 -and $lines[$i-1] -ne '') {
                $newLines += ''
            }
            
            # Add the heading
            $newLines += $line
            
            # Add blank line after heading if next line exists, isn't blank, and isn't another heading
            if ($i -lt $lines.Length - 1 -and $lines[$i+1] -ne '' -and $lines[$i+1] -notmatch '^#+\s') {
                $newLines += ''
            }
        }
        # If line starts a list and previous line isn't blank or part of a list
        elseif (($line -match '^\s*[\-\*\+]' -or $line -match '^\s*\d+\.') -and 
                $i -gt 0 -and $lines[$i-1] -ne '' -and 
                $lines[$i-1] -notmatch '^\s*[\-\*\+]' -and 
                $lines[$i-1] -notmatch '^\s*\d+\.') {
            # Add blank line before list
            $newLines += ''
            $newLines += $line
        }
        # If line ends a list and next line isn't blank
        elseif (($line -match '^\s*[\-\*\+]' -or $line -match '^\s*\d+\.') -and 
                $i -lt $lines.Length - 1 -and $lines[$i+1] -ne '' -and 
                $lines[$i+1] -notmatch '^\s*[\-\*\+]' -and 
                $lines[$i+1] -notmatch '^\s*\d+\.') {
            # Add the list item
            $newLines += $line
            # Add blank line after list
            $newLines += ''
        }
        else {
            # Add the line as-is
            $newLines += $line
        }
    }
    
    # Fix 3: Remove trailing punctuation from headings
    for ($i = 0; $i -lt $newLines.Count; $i++) {
        if ($newLines[$i] -match '^(#+\s+.+)[.,:;!]\s*$') {
            $newLines[$i] = $matches[1]
        }
    }
    
    # Fix 4: Ensure file ends with exactly one newline
    # Remove any blank lines at the end
    while ($newLines.Count -gt 0 -and $newLines[-1] -eq '') {
        $newLines = $newLines[0..($newLines.Count - 2)]
    }
    # Add a single blank line at the end
    $newLines += ''
    
    # Write the content back to the file
    $newContent = $newLines -join "`n"
    Set-Content -Path $file.FullName -Value $newContent -NoNewline
    Add-Content -Path $file.FullName -Value "" -NoNewline
}

Write-Host "✅ Markdown fixes complete!" -ForegroundColor Green
Write-Host "Note: Some complex formatting issues may still need manual attention."
Write-Host "Run the markdown linting workflow to check for remaining issues." 