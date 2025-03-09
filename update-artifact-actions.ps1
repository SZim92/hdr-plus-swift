# PowerShell script to update all v3 artifact actions to v4
# This script will find all YAML files in the .github directory and update any v3 artifact actions to v4

Write-Host "Searching for YAML files with deprecated artifact actions..."

# Find all YAML files in the .github directory
$yamlFiles = Get-ChildItem -Path ".github" -Filter "*.yml" -Recurse

$totalUpdated = 0

# Patterns to search for (including potential variations)
$patterns = @(
    'actions/upload-artifact@v3'
    'actions/download-artifact@v3'
    'actions/upload-pages-artifact@v3'
    'uses:[ ]*actions/upload-artifact@v3'
    'uses:[ ]*actions/download-artifact@v3'
    'uses:[ ]*actions/upload-pages-artifact@v3'
    'actions\/upload-artifact@v3'
    'actions\/download-artifact@v3'
    'actions\/upload-pages-artifact@v3'
)

foreach ($file in $yamlFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    $updated = $false
    
    # Check and replace each pattern
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            Write-Host "Found deprecated action in $($file.FullName) - Pattern: $pattern"
            $updated = $true
        }
    }
    
    # Replace deprecated actions with v4
    $updatedContent = $content -replace 'actions/upload-artifact@v3', 'actions/upload-artifact@v4'
    $updatedContent = $updatedContent -replace 'actions/download-artifact@v3', 'actions/download-artifact@v4'
    # IMPORTANT: Upload-pages-artifact should be updated to v2 (not v4)
    $updatedContent = $updatedContent -replace 'actions/upload-pages-artifact@v3', 'actions/upload-pages-artifact@v2'
    
    # If content was modified, write it back to the file
    if ($originalContent -ne $updatedContent) {
        Write-Host "Updating $($file.FullName)..."
        Set-Content -Path $file.FullName -Value $updatedContent
        $totalUpdated++
    } elseif ($updated) {
        Write-Host "Pattern detected but no changes made to $($file.FullName). Manual inspection recommended."
    }
}

Write-Host "Update complete. Updated $totalUpdated files."

# Additional check for any missed instances
Write-Host "Performing a final search for any remaining v3 references..."
$remainingFiles = @()

foreach ($file in $yamlFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    if ($content -match "artifact@v3") {
        $remainingFiles += $file.FullName
    }
}

if ($remainingFiles.Count -gt 0) {
    Write-Host "Warning: Found $($remainingFiles.Count) files that may still have v3 references. Please review these files manually:" -ForegroundColor Yellow
    foreach ($file in $remainingFiles) {
        Write-Host " - $file" -ForegroundColor Yellow
    }
} else {
    Write-Host "No remaining v3 references found."
} 