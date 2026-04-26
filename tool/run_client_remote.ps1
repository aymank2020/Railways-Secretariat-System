param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl,
  [string]$Device = "windows"
)

$ErrorActionPreference = "Stop"

$url = $ApiBaseUrl.Trim().TrimEnd("/")
if ($url.Length -eq 0) {
  throw "ApiBaseUrl is required."
}

Write-Host "Starting client in remote mode..."
Write-Host "Device: $Device"
Write-Host "API_BASE_URL: $url"

flutter run -d $Device --dart-define=API_BASE_URL=$url
