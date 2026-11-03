param(
  [switch]$SetupTeacher,
  [switch]$OpenBrowser,
  [string]$TeacherUsername,
  [string]$TeacherName,
  [string]$TeacherStaffId,
  [ValidateRange(1024, 65535)]
  [int]$Port = 8080,
  [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'BusujjuSecondarySchool')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:SiteRoot = $PSScriptRoot
$script:DataDirectory = [System.IO.Path]::GetFullPath($DataDirectory)
$script:DataPath = Join-Path $script:DataDirectory 'school-data.json'
$script:PasswordIterations = 210000
$script:Sessions = @{}
$script:LoginAttempts = @{}
$script:Days = @('S1', 'S2', 'S3', 'S4', 'S5', 'S6')

function Save-Database {
  if (-not (Test-Path $script:DataDirectory)) {
    New-Item -ItemType Directory -Path $script:DataDirectory -Force | Out-Null
  }
  $json = [ordered]@{
    users = @($script:Database.users)
    results = @($script:Database.results)
    teacherRequests = @($script:Database.teacherRequests)
  } | ConvertTo-Json -Depth 8
  $temporaryPath = "$($script:DataPath).tmp"
  [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $temporaryPath -Destination $script:DataPath -Force
}

function Initialize-Database {
  if (Test-Path $script:DataPath) {
    try {
      $loaded = Get-Content -LiteralPath $script:DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $script:Database = @{
        users = @($loaded.users)
        results = @($loaded.results)
        teacherRequests = @()
      }
      if ($loaded.PSObject.Properties['teacherRequests']) {
        $script:Database.teacherRequests = @($loaded.teacherRequests)
      }
      if ($null -eq $script:Database.users) { $script:Database.users = @() }
      if ($null -eq $script:Database.results) { $script:Database.results = @() }
      if ($null -eq $script:Database.teacherRequests) { $script:Database.teacherRequests = @() }
    }
    catch {
      throw "The school data file could not be read. It has not been overwritten: $($script:DataPath)"
    }
  }
  else {
    $script:Database = @{ users = @(); results = @(); teacherRequests = @() }
    Save-Database
  }
}

function ConvertTo-PlainText {
  param([System.Security.SecureString]$SecureValue)
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function New-PasswordFields {
  param([string]$Password)
  $salt = New-Object byte[] 16
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
  $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
    $Password,
    $salt,
    $script:PasswordIterations,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256
  )
  try {
    return @{
      salt = [Convert]::ToBase64String($salt)
      passwordHash = [Convert]::ToBase64String($derive.GetBytes(32))
      passwordIterations = $script:PasswordIterations
    }
  }
  finally { $derive.Dispose() }
}

function Test-Password {
  param($User, [string]$Password)
  $salt = [Convert]::FromBase64String([string]$User.salt)
  $expected = [Convert]::FromBase64String([string]$User.passwordHash)
  $iterations = [int]$User.passwordIterations
  $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
    $Password,
    $salt,
    $iterations,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256
  )
  try {
    $actual = $derive.GetBytes($expected.Length)
    $difference = 0
    for ($index = 0; $index -lt $expected.Length; $index++) {
      $difference = $difference -bor ($expected[$index] -bxor $actual[$index])
    }
    return ($difference -eq 0)
  }
  finally { $derive.Dispose() }
}

function New-UserRecord {
  param(
    [string]$Username,
    [string]$Name,
    [string]$Role,
    [string]$Password,
    [string]$ClassName = '',
    [string]$StudentCode = '',
    [string]$StaffId = ''
  )
  $passwordFields = New-PasswordFields -Password $Password
  return [pscustomobject]@{
    id = [guid]::NewGuid().ToString('N')
    username = $Username
    name = $Name
    role = $Role
    className = $ClassName
    studentCode = $StudentCode
    staffId = $StaffId
    salt = $passwordFields.salt
    passwordHash = $passwordFields.passwordHash
    passwordIterations = $passwordFields.passwordIterations
    createdAt = [DateTimeOffset]::UtcNow.ToString('o')
  }
}

function Get-PublicUser {
  param($User)
  return [ordered]@{
    id = $User.id
    username = $User.username
    name = $User.name
    role = $User.role
    className = $User.className
    studentCode = $User.studentCode
  }
}

function Set-UpTeacher {
  param(
    [string]$Username,
    [string]$Name,
    [string]$StaffId
  )
  if (@($script:Database.users | Where-Object { $_.role -eq 'teacher' }).Count -gt 0) {
    Write-Host 'A teacher account already exists. Setup was not changed.' -ForegroundColor Yellow
    return
  }
  Write-Host 'Create the first teacher account. Use a unique password of at least 10 characters.' -ForegroundColor Cyan
  if ([string]::IsNullOrWhiteSpace($Username)) { $Username = Read-Host 'Teacher username' }
  if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Read-Host 'Teacher display name' }
  if ([string]::IsNullOrWhiteSpace($StaffId)) { $StaffId = Read-Host 'Teacher staff ID' }
  $username = $Username.Trim().ToLowerInvariant()
  $name = $Name.Trim()
  $staffId = $StaffId.Trim()
  if ($username -notmatch '^[a-z0-9][a-z0-9 ._-]{1,28}[a-z0-9]$' -or $name.Length -lt 2 -or $name.Length -gt 80 -or $staffId.Length -lt 2 -or $staffId.Length -gt 40) {
    throw 'Use a 3-30 character username and a 2-40 character staff ID; display name must be 2-80 characters.'
  }
  $firstSecure = Read-Host 'Teacher password' -AsSecureString
  $secondSecure = Read-Host 'Confirm password' -AsSecureString
  $password = ConvertTo-PlainText $firstSecure
  $confirmation = ConvertTo-PlainText $secondSecure
  if ($password.Length -lt 10 -or $password -cne $confirmation) {
    $password = $null
    $confirmation = $null
    throw 'Passwords must match and contain at least 10 characters.'
  }
  $teacher = New-UserRecord -Username $username -Name $name -Role 'teacher' -Password $password -StaffId $staffId
  $script:Database.users = @($script:Database.users) + $teacher
  Save-Database
  $password = $null
  $confirmation = $null
  Write-Host "Teacher account '$username' created in $($script:DataPath)." -ForegroundColor Green
}

function Send-Json {
  param($Context, [int]$StatusCode, $Value)
  $body = ConvertTo-Json -InputObject $Value -Depth 8 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  $Context.Response.StatusCode = $StatusCode
  $Context.Response.ContentType = 'application/json; charset=utf-8'
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.Headers['Cache-Control'] = 'no-store'
  $Context.Response.Headers['X-Content-Type-Options'] = 'nosniff'
  $Context.Response.Headers['X-Frame-Options'] = 'DENY'
  $Context.Response.Headers['Referrer-Policy'] = 'same-origin'
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.Close()
}

function Send-Text {
  param($Context, [int]$StatusCode, [string]$Text)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $Context.Response.StatusCode = $StatusCode
  $Context.Response.ContentType = 'text/plain; charset=utf-8'
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.Headers['Cache-Control'] = 'no-store'
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.Close()
}

function Get-RequestJson {
  param($Request)
  if ($Request.ContentLength64 -gt 16384) { throw 'Request is too large.' }
  $reader = [System.IO.StreamReader]::new($Request.InputStream, $Request.ContentEncoding)
  try {
    $text = $reader.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($text)) { return @{} }
    return ($text | ConvertFrom-Json)
  }
  finally { $reader.Dispose() }
}

function Get-RequestUser {
  param($Request)
  $cookie = $Request.Cookies['bss_session']
  if ($null -eq $cookie -or [string]::IsNullOrEmpty($cookie.Value)) { return $null }
  $token = $cookie.Value
  if (-not $script:Sessions.ContainsKey($token)) { return $null }
  $session = $script:Sessions[$token]
  if ($session.expires -le [DateTimeOffset]::UtcNow) {
    $script:Sessions.Remove($token)
    return $null
  }
  return ($script:Database.users | Where-Object { $_.id -eq $session.userId } | Select-Object -First 1)
}

function Test-TeacherRequest {
  param($Context, $User)
  if ($null -eq $User) {
    Send-Json $Context 401 @{ error = 'Sign in to continue.' }
    return $false
  }
  if ($User.role -ne 'teacher') {
    Send-Json $Context 403 @{ error = 'This action is available to teachers only.' }
    return $false
  }
  return $true
}

function Test-LocalOrigin {
  param($Context)
  $hostHeader = [string]$Context.Request.Headers['Host']
  $allowedHosts = @("127.0.0.1:$Port", "localhost:$Port")
  if ($allowedHosts -notcontains $hostHeader) { return $false }
  $origin = [string]$Context.Request.Headers['Origin']
  return ($origin -ceq "http://$hostHeader")
}

function Send-StaticFile {
  param($Context, [string]$Path)
  if ($Path -eq '/') { $Path = '/index.html' }
  if ($Path -in @('/index.html', '/styles.css', '/script.js')) {
    $filePath = Join-Path $script:SiteRoot $Path.TrimStart('/')
  }
  elseif ($Path.StartsWith('/asets/', [StringComparison]::OrdinalIgnoreCase)) {
    $assetName = $Path.Substring(7)
    if ($assetName.Contains('..') -or $assetName.Contains('\') -or $assetName.Contains(':')) {
      Send-Text $Context 404 'Not found'
      return
    }
    $assetRoot = [System.IO.Path]::GetFullPath((Join-Path $script:SiteRoot 'asets'))
    $filePath = [System.IO.Path]::GetFullPath((Join-Path $assetRoot $assetName))
    if (-not $filePath.StartsWith($assetRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      Send-Text $Context 404 'Not found'
      return
    }
  }
  else {
    Send-Text $Context 404 'Not found'
    return
  }
  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    Send-Text $Context 404 'Not found'
    return
  }
  $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
  $contentType = switch ($extension) {
    '.html' { 'text/html; charset=utf-8' }
    '.css' { 'text/css; charset=utf-8' }
    '.js' { 'text/javascript; charset=utf-8' }
    '.jpg' { 'image/jpeg' }
    '.jpeg' { 'image/jpeg' }
    '.png' { 'image/png' }
    '.webp' { 'image/webp' }
    '.gif' { 'image/gif' }
    default { 'application/octet-stream' }
  }
  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  $Context.Response.StatusCode = 200
  $Context.Response.ContentType = $contentType
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.Headers['Cache-Control'] = 'no-store'
  $Context.Response.Headers['X-Content-Type-Options'] = 'nosniff'
  $Context.Response.Headers['X-Frame-Options'] = 'DENY'
  $Context.Response.Headers['Referrer-Policy'] = 'same-origin'
  $Context.Response.Headers['Content-Security-Policy'] = "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; script-src 'self'; connect-src 'self'; base-uri 'self'; frame-ancestors 'none'"
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.Close()
}

function Handle-Request {
  param($Context)
  $request = $Context.Request
  $path = [Uri]::UnescapeDataString($request.Url.AbsolutePath)
  $method = $request.HttpMethod.ToUpperInvariant()
  if ($path.StartsWith('/api/')) {
    if ($method -eq 'POST' -and -not (Test-LocalOrigin $Context)) {
      Send-Json $Context 403 @{ error = 'Request origin was rejected.' }
      return
    }
    if ($method -eq 'GET' -and $path -eq '/api/health') {
      Send-Json $Context 200 @{ status = 'ok' }
      return
    }
    if ($method -eq 'POST' -and $path -eq '/api/teacher-signup') {
      $body = Get-RequestJson $request
      $username = ([string]$body.username).Trim().ToLowerInvariant()
      $name = ([string]$body.name).Trim()
      $staffId = ([string]$body.staffId).Trim()
      $password = [string]$body.password
      if ($username -notmatch '^[a-z0-9][a-z0-9 ._-]{1,28}[a-z0-9]$' -or $name.Length -lt 2 -or $name.Length -gt 80 -or $staffId.Length -lt 2 -or $staffId.Length -gt 40 -or $password.Length -lt 10 -or $password.Length -gt 256) {
        Send-Json $Context 400 @{ error = 'Check your details. Passwords must contain at least 10 characters.' }
        return
      }
      if (@($script:Database.users | Where-Object { $_.username -ceq $username }).Count -gt 0 -or @($script:Database.teacherRequests | Where-Object { $_.username -ceq $username }).Count -gt 0) {
        Send-Json $Context 409 @{ error = 'That username is already in use or awaiting review.' }
        return
      }
      $passwordFields = New-PasswordFields -Password $password
      $signupRequest = [pscustomobject]@{
        id = [guid]::NewGuid().ToString('N')
        username = $username
        name = $name
        staffId = $staffId
        role = 'teacher'
        salt = $passwordFields.salt
        passwordHash = $passwordFields.passwordHash
        passwordIterations = $passwordFields.passwordIterations
        submittedAt = [DateTimeOffset]::UtcNow.ToString('o')
      }
      $script:Database.teacherRequests = @($script:Database.teacherRequests) + $signupRequest
      Save-Database
      Send-Json $Context 202 @{ status = 'pending'; message = 'Your request is waiting for approval by an existing teacher.' }
      return
    }
    if ($method -eq 'POST' -and $path -eq '/api/login') {
      $body = Get-RequestJson $request
      $username = ([string]$body.username).Trim().ToLowerInvariant()
      $password = [string]$body.password
      $loginRole = [string]$body.role
      if ($username.Length -gt 40 -or $password.Length -gt 256 -or $loginRole -notin @('student', 'teacher')) {
        Send-Json $Context 400 @{ error = 'Enter a valid username and password.' }
        return
      }
      $attemptKey = "$($request.RemoteEndPoint.Address):$username"
      if ($script:LoginAttempts.ContainsKey($attemptKey) -and $script:LoginAttempts[$attemptKey].blockedUntil -gt [DateTimeOffset]::UtcNow) {
        Send-Json $Context 429 @{ error = 'Too many sign-in attempts. Try again in 15 minutes.' }
        return
      }
      if ($script:LoginAttempts.ContainsKey($attemptKey) -and $script:LoginAttempts[$attemptKey].blockedUntil -ne [DateTimeOffset]::MinValue) {
        $script:LoginAttempts.Remove($attemptKey)
      }
      $user = $script:Database.users | Where-Object { $_.username -ceq $username } | Select-Object -First 1
      if ($loginRole -eq 'student' -and ($null -eq $user -or $user.role -ne 'student')) {
        $user = $script:Database.users | Where-Object { $_.role -eq 'student' -and $_.studentCode -ieq $username } | Select-Object -First 1
      }
      if ($null -ne $user -and $user.role -ne $loginRole) { $user = $null }
      $validPassword = $false
      if ($null -ne $user -and $password.Length -gt 0) { $validPassword = Test-Password $user $password }
      if (-not $validPassword) {
        $attempts = 1
        if ($script:LoginAttempts.ContainsKey($attemptKey)) { $attempts = $script:LoginAttempts[$attemptKey].count + 1 }
        $blockedUntil = [DateTimeOffset]::MinValue
        if ($attempts -ge 5) { $blockedUntil = [DateTimeOffset]::UtcNow.AddMinutes(15) }
        $script:LoginAttempts[$attemptKey] = @{ count = $attempts; blockedUntil = $blockedUntil }
        Send-Json $Context 401 @{ error = 'Username or password is incorrect.' }
        return
      }
      $script:LoginAttempts.Remove($attemptKey)
      $randomBytes = New-Object byte[] 32
      [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
      $token = [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
      $script:Sessions[$token] = @{ userId = $user.id; expires = [DateTimeOffset]::UtcNow.AddHours(8) }
      $Context.Response.Headers.Add('Set-Cookie', "bss_session=$token; Path=/; HttpOnly; SameSite=Strict; Max-Age=28800")
      Send-Json $Context 200 @{ user = (Get-PublicUser $user) }
      return
    }
    if ($method -eq 'POST' -and $path -eq '/api/logout') {
      $cookie = $request.Cookies['bss_session']
      if ($null -ne $cookie -and $script:Sessions.ContainsKey($cookie.Value)) { $script:Sessions.Remove($cookie.Value) }
      $Context.Response.Headers.Add('Set-Cookie', 'bss_session=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0')
      Send-Json $Context 200 @{ status = 'signed-out' }
      return
    }
    $signedInUser = Get-RequestUser $request
    if ($method -eq 'GET' -and $path -eq '/api/me') {
      if ($null -eq $signedInUser) { Send-Json $Context 401 @{ error = 'Sign in to continue.' } }
      else { Send-Json $Context 200 @{ user = (Get-PublicUser $signedInUser) } }
      return
    }
    if ($method -eq 'GET' -and $path -eq '/api/results') {
      if ($null -eq $signedInUser) { Send-Json $Context 401 @{ error = 'Sign in to continue.' }; return }
      if ($signedInUser.role -ne 'student') { Send-Json $Context 403 @{ error = 'Student results are available to student accounts only.' }; return }
      $studentResults = @($script:Database.results | Where-Object { $_.studentId -eq $signedInUser.id } | Sort-Object createdAt -Descending)
      Send-Json $Context 200 @{ results = $studentResults }
      return
    }
    if ($method -eq 'GET' -and $path -eq '/api/teacher/students') {
      if (-not (Test-TeacherRequest $Context $signedInUser)) { return }
      $students = @($script:Database.users | Where-Object { $_.role -eq 'student' } | ForEach-Object { Get-PublicUser $_ })
      Send-Json $Context 200 @{ students = $students }
      return
    }
    if ($method -eq 'GET' -and $path -eq '/api/teacher/requests') {
      if (-not (Test-TeacherRequest $Context $signedInUser)) { return }
      $requests = @($script:Database.teacherRequests | ForEach-Object {
        [ordered]@{ id = $_.id; name = $_.name; username = $_.username; staffId = $_.staffId; submittedAt = $_.submittedAt }
      })
      Send-Json $Context 200 @{ requests = $requests }
      return
    }
    if ($method -eq 'POST' -and $path -match '^/api/teacher/requests/([a-f0-9]{32})/approve$') {
      if (-not (Test-TeacherRequest $Context $signedInUser)) { return }
      $requestId = $Matches[1]
      $signupRequest = $script:Database.teacherRequests | Where-Object { $_.id -eq $requestId } | Select-Object -First 1
      if ($null -eq $signupRequest) {
        Send-Json $Context 404 @{ error = 'That teacher request no longer exists.' }
        return
      }
      $approvedTeacher = [pscustomobject]@{
        id = $signupRequest.id
        username = $signupRequest.username
        name = $signupRequest.name
        role = 'teacher'
        className = ''
        studentCode = ''
        staffId = $signupRequest.staffId
        salt = $signupRequest.salt
        passwordHash = $signupRequest.passwordHash
        passwordIterations = $signupRequest.passwordIterations
        createdAt = [DateTimeOffset]::UtcNow.ToString('o')
      }
      $script:Database.users = @($script:Database.users) + $approvedTeacher
      $script:Database.teacherRequests = @($script:Database.teacherRequests | Where-Object { $_.id -ne $requestId })
      Save-Database
      Send-Json $Context 200 @{ teacher = (Get-PublicUser $approvedTeacher) }
      return
    }
    if ($method -eq 'POST' -and $path -eq '/api/teacher/students') {
      if (-not (Test-TeacherRequest $Context $signedInUser)) { return }
      $body = Get-RequestJson $request
      $username = ([string]$body.username).Trim().ToLowerInvariant()
      $name = ([string]$body.name).Trim()
      $studentCode = ([string]$body.studentCode).Trim().ToUpperInvariant()
      $className = [string]$body.className
      $password = [string]$body.password
      if ($username -notmatch '^[a-z0-9][a-z0-9 ._-]{1,28}[a-z0-9]$' -or $name.Length -lt 2 -or $name.Length -gt 80 -or $studentCode.Length -lt 2 -or $studentCode.Length -gt 30 -or $className -notin $script:Days -or $password.Length -lt 10 -or $password.Length -gt 256) {
        Send-Json $Context 400 @{ error = 'Check the student details. Passwords must contain at least 10 characters.' }
        return
      }
      if (@($script:Database.users | Where-Object { $_.username -ceq $username }).Count -gt 0) {
        Send-Json $Context 409 @{ error = 'That username is already in use.' }
        return
      }
      if (@($script:Database.users | Where-Object { $_.studentCode -ceq $studentCode }).Count -gt 0) {
        Send-Json $Context 409 @{ error = 'That student code is already in use.' }
        return
      }
      $student = New-UserRecord -Username $username -Name $name -Role 'student' -Password $password -ClassName $className -StudentCode $studentCode
      $script:Database.users = @($script:Database.users) + $student
      Save-Database
      Send-Json $Context 201 @{ student = (Get-PublicUser $student) }
      return
    }
    if ($method -eq 'POST' -and $path -eq '/api/teacher/results') {
      if (-not (Test-TeacherRequest $Context $signedInUser)) { return }
      $body = Get-RequestJson $request
      $studentId = [string]$body.studentId
      $subject = ([string]$body.subject).Trim()
      $assessment = ([string]$body.assessment).Trim()
      $score = 0.0
      $outOf = 0.0
      $numberStyle = [System.Globalization.NumberStyles]::Float
      $culture = [System.Globalization.CultureInfo]::InvariantCulture
      $scoreValid = [double]::TryParse([string]$body.score, $numberStyle, $culture, [ref]$score)
      $outOfValid = [double]::TryParse([string]$body.outOf, $numberStyle, $culture, [ref]$outOf)
      $student = $script:Database.users | Where-Object { $_.id -eq $studentId -and $_.role -eq 'student' } | Select-Object -First 1
      if ($null -eq $student -or $subject.Length -lt 1 -or $subject.Length -gt 80 -or $assessment.Length -lt 1 -or $assessment.Length -gt 100 -or -not $scoreValid -or -not $outOfValid -or $outOf -le 0 -or $outOf -gt 100 -or $score -lt 0 -or $score -gt $outOf) {
        Send-Json $Context 400 @{ error = 'Check the student, subject, assessment, and score. Scores must be between zero and the maximum.' }
        return
      }
      $result = [pscustomobject]@{
        id = [guid]::NewGuid().ToString('N')
        studentId = $student.id
        subject = $subject
        assessment = $assessment
        score = $score
        outOf = $outOf
        createdAt = [DateTimeOffset]::UtcNow.ToString('o')
      }
      $script:Database.results = @($script:Database.results) + $result
      Save-Database
      Send-Json $Context 201 @{ result = @{ id = $result.id; subject = $result.subject; assessment = $result.assessment } }
      return
    }
    Send-Json $Context 404 @{ error = 'Not found.' }
    return
  }
  if ($method -eq 'GET') { Send-StaticFile $Context $path; return }
  Send-Text $Context 405 'Method not allowed'
}

Initialize-Database
if ($SetupTeacher) {
  Set-UpTeacher -Username $TeacherUsername -Name $TeacherName -StaffId $TeacherStaffId
  return
}
if (@($script:Database.users | Where-Object { $_.role -eq 'teacher' }).Count -eq 0) {
  Write-Host 'No teacher account is configured. Run this command first:' -ForegroundColor Yellow
  Write-Host '  & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File .\server.ps1 -SetupTeacher' -ForegroundColor White
  exit 1
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try {
  $listener.Start()
}
catch {
  Write-Error "Could not start the local server on port $Port. Try another port or check local URL permissions. $($_.Exception.Message)"
  exit 1
}

if ($OpenBrowser) {
  Start-Process "http://127.0.0.1:$Port/#teacher-login"
}

Write-Host "Busujju school portal is running at http://127.0.0.1:$Port/" -ForegroundColor Green
Write-Host 'This server only accepts local connections. Press Ctrl+C to stop it.' -ForegroundColor Yellow
try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    try { Handle-Request $context }
    catch {
      Write-Warning "Request failed: $($_.Exception.Message)"
      try { Send-Json $context 500 @{ error = 'The server could not complete that request.' } } catch { }
    }
  }
}
finally {
  $listener.Stop()
  $listener.Close()
}
