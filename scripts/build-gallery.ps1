# Build headless gallery for local smoke / installer staging
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
dub build -c headless --compiler=ldc2 --build=release
Set-Location examples/gallery
dub build --compiler=ldc2 --build=release
Write-Host "OK: examples/gallery/rmgui-gallery(.exe)"
