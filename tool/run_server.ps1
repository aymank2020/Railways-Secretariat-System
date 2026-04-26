param(
  [string]$Host = "0.0.0.0",
  [int]$Port = 8080,
  [string]$DbPath = "",
  [string]$StorageRoot = "",
  [string]$Device = "windows"
)

$ErrorActionPreference = "Stop"

$env:SECRETARIAT_SERVER_HOST = $Host
$env:SECRETARIAT_SERVER_PORT = "$Port"

if ($DbPath.Trim().Length -gt 0) {
  $env:SECRETARIAT_DB_PATH = $DbPath
}

if ($StorageRoot.Trim().Length -gt 0) {
  $env:SECRETARIAT_STORAGE_ROOT = $StorageRoot
}

Write-Host "Starting Railway Secretariat API server..."
Write-Host "Host: $($env:SECRETARIAT_SERVER_HOST)"
Write-Host "Port: $($env:SECRETARIAT_SERVER_PORT)"
Write-Host "Device: $Device"
if ($env:SECRETARIAT_DB_PATH) {
  Write-Host "DB Path: $($env:SECRETARIAT_DB_PATH)"
}
if ($env:SECRETARIAT_STORAGE_ROOT) {
  Write-Host "Storage Root: $($env:SECRETARIAT_STORAGE_ROOT)"
}

flutter run -d $Device -t lib/server_main.dart
