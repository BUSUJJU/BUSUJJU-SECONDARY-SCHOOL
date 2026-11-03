$ErrorActionPreference = 'Stop'
$serverPath = Join-Path $PSScriptRoot 'server.ps1'
$dataPath = Join-Path (Join-Path $env:LOCALAPPDATA 'BusujjuSecondarySchool') 'school-data.json'

if (-not (Test-Path -LiteralPath $serverPath)) {
  throw "Could not find the school server: $serverPath"
}

$teacherCount = 0
if (Test-Path -LiteralPath $dataPath) {
  $database = Get-Content -LiteralPath $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $teacherCount = @($database.users | Where-Object { $_.role -eq 'teacher' }).Count
}

$powerShellPath = Join-Path $PSHOME 'powershell.exe'
if ($teacherCount -eq 0) {
  Write-Host 'No teacher account exists yet. Create the first one now.' -ForegroundColor Yellow
  & $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $serverPath -SetupTeacher -TeacherUsername 'Tr. Francis Sengendo' -TeacherName 'Tr. Francis Sengendo' -TeacherStaffId '12345'
  if ($LASTEXITCODE -ne 0) {
    throw 'Teacher setup did not complete. The school portal was not started.'
  }
}

& $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $serverPath -OpenBrowser
if ($LASTEXITCODE -ne 0) {
  throw 'The school server could not start. Check whether port 8080 is already in use.'
}
