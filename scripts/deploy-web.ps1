$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$frontendRoot = Join-Path $repoRoot 'examspark_frontend'
$pubspecPath = Join-Path $frontendRoot 'pubspec.yaml'
$versionJsonPath = Join-Path $frontendRoot 'web\version.json'
$buildOutput = Join-Path $frontendRoot 'build\web'

Set-Location $repoRoot

function Invoke-Native {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $Command $($Arguments -join ' ')"
    }
}

if (-not (Test-Path $pubspecPath)) {
    throw "Could not find examspark_frontend/pubspec.yaml."
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter was not found on PATH."
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "Node.js/npx was not found on PATH. Install Node.js before deploying."
}

$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$match = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)\s*$')
if (-not $match.Success) {
    throw "pubspec.yaml version must use x.y.z+build format."
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value + 1
$version = "$major.$minor.$patch+$build"
$updatedPubspec = $pubspec.Substring(0, $match.Index) +
    "version: $version" +
    $pubspec.Substring($match.Index + $match.Length)
[System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, [System.Text.UTF8Encoding]::new($false))

[System.IO.File]::WriteAllText(
    $versionJsonPath,
    "{`n  `"version`": `"$version`"`n}`n",
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Deploying Sonaxia web version $version" -ForegroundColor Cyan
Write-Host "Building Flutter web release..." -ForegroundColor Cyan
Invoke-Native 'flutter' @('build', 'web', '--release')

if (-not (Test-Path (Join-Path $buildOutput 'index.html'))) {
    throw "Flutter build completed but build/web/index.html was not created."
}

Write-Host "Deploying to Cloudflare Pages project sonaxia..." -ForegroundColor Cyan
Invoke-Native 'npx' @('wrangler', 'pages', 'deploy', $buildOutput, '--project-name', 'sonaxia')

Write-Host "Deployment complete: $version" -ForegroundColor Green