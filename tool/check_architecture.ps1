$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$allDartFiles = Get-ChildItem lib -Recurse -File -Filter *.dart
$violations = @()

function Add-Violation {
  param(
    [string]$File,
    [int]$LineNumber,
    [string]$Message
  )
  $violations += "${File}:${LineNumber}: $Message"
}

foreach ($file in $allDartFiles) {
  $relativePath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  $isPresentation = $relativePath -match '^lib/features/[^/]+/presentation/' -or $relativePath -match '^lib/core/providers/'
  $isDomain = $relativePath -match '^lib/features/[^/]+/domain/'

  if (-not $isPresentation -and -not $isDomain) {
    continue
  }

  $lines = Get-Content $file.FullName
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]

    if ($line -match "^\s*import\s+'([^']+)';") {
      $importPath = $matches[1]

      if ($importPath -match 'core/services/database_service\.dart') {
        Add-Violation -File $relativePath -LineNumber ($i + 1) -Message 'Direct DatabaseService import is forbidden in presentation/domain.'
      }

      if ($importPath -match '^package:sqflite' -or $importPath -match '^package:sqflite_common_ffi') {
        Add-Violation -File $relativePath -LineNumber ($i + 1) -Message 'Direct sqflite import is forbidden in presentation/domain.'
      }

      if ($importPath -match '^package:shared_preferences/shared_preferences\.dart') {
        Add-Violation -File $relativePath -LineNumber ($i + 1) -Message 'Direct SharedPreferences import is forbidden in presentation/domain.'
      }
    }

    if ($line -match 'DatabaseService\s*\(') {
      Add-Violation -File $relativePath -LineNumber ($i + 1) -Message 'Direct DatabaseService construction is forbidden in presentation/domain.'
    }

    if ($line -match 'SharedPreferences\s*\.') {
      Add-Violation -File $relativePath -LineNumber ($i + 1) -Message 'Direct SharedPreferences usage is forbidden in presentation/domain.'
    }
  }
}

if ($violations.Count -gt 0) {
  Write-Host 'Architecture guard failed. Clean Architecture violations detected:' -ForegroundColor Red
  $violations | ForEach-Object { Write-Host $_ }
  exit 1
}

Write-Host 'Architecture guard passed.' -ForegroundColor Green
exit 0
