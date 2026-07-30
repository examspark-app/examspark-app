# Stage only files you edited (modified, deleted, or new — respects .gitignore)
# Usage: .\scripts\stage-edited.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Test-Path ".git")) {
    Write-Host "Not a git repository." -ForegroundColor Red
    exit 1
}

# 1. Modified + deleted tracked files
git add -u

# 2. New untracked files (not ignored)
$untracked = @(git ls-files --others --exclude-standard)
foreach ($file in $untracked) {
    git add -- $file
}

$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
    Write-Host "No edited files to stage." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Staged $($staged.Count) file(s):" -ForegroundColor Green
git diff --cached --name-status
Write-Host ""
Write-Host "Next: git commit -m `"your message`"" -ForegroundColor Cyan
