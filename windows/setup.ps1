# =====================================================================
#  Bigstep new-PC setup
#
#  On a fresh PC, open PowerShell and run ONE line:
#     irm https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/windows/setup.ps1 | iex
#
#  Or from a pendrive / cloned folder: double-click install.bat
#
#  Apps to install are listed in apps.json (set "enabled" true/false).
#  Each app is installed with winget (latest version) when possible,
#  otherwise from the bundled installer in the installers\ folder.
# =====================================================================

# ---- EDIT THESE TO MATCH YOUR GITHUB REPO ---------------------------
$GitHubUser = 'akashsharma-creator'
$RepoName   = 'bigstep-setup'
$Branch     = 'main'
# ---------------------------------------------------------------------

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RawUrl = "https://raw.githubusercontent.com/$GitHubUser/$RepoName/$Branch/windows/setup.ps1"
$ZipUrl = "https://github.com/$GitHubUser/$RepoName/archive/refs/heads/$Branch.zip"

# ---- 1. Re-launch as Administrator if needed -------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host 'Not running as Administrator - relaunching elevated...' -ForegroundColor Yellow
    if ($PSCommandPath) {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } else {
        $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$RawUrl' | iex`""
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    return
}

$LogDir = 'C:\BigstepSetup'
New-Item -ItemType Directory -Force $LogDir | Out-Null
Start-Transcript -Path "$LogDir\setup-$(Get-Date -Format yyyyMMdd-HHmmss).log" | Out-Null

# ---- 2. Get the repo files (apps.json + installers) ------------------
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'apps.json'))) {
    $Root = $PSScriptRoot                      # running from local folder / pendrive
} else {
    Write-Host "Downloading setup files from GitHub ($GitHubUser/$RepoName)..." -ForegroundColor Cyan
    $zip  = Join-Path $env:TEMP "$RepoName.zip"
    $dest = Join-Path $env:TEMP "$RepoName-files"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    $ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    $Root = Join-Path $dest "$RepoName-$Branch\windows"
}

$InstallerDir = Join-Path $Root 'installers'
$apps = Get-Content (Join-Path $Root 'apps.json') -Raw | ConvertFrom-Json

# ---- 3. Make sure winget is available --------------------------------
function Get-Winget {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $p) { return $p }
    return $null
}

$winget = Get-Winget
if (-not $winget) {
    Write-Host 'winget not found - trying to register App Installer...' -ForegroundColor Yellow
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop } catch {}
    $winget = Get-Winget
}
if ($winget) {
    Write-Host "Using winget: $winget" -ForegroundColor Green
    & $winget source update --disable-interactivity | Out-Null
} else {
    Write-Host 'winget unavailable - will use bundled installers only.' -ForegroundColor Yellow
}

# winget exit codes that mean "already installed / nothing to do"
$wingetOk = @(0, -1978335189, -1978335135)

function Install-WithWinget($app) {
    if (-not $winget -or -not $app.wingetId) { return $false }
    Write-Host "  winget install $($app.wingetId)"
    & $winget install --id $app.wingetId -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
    return ($wingetOk -contains $LASTEXITCODE)
}

function Install-WithBundled($app) {
    if (-not $app.installer) { return $false }
    $file = Join-Path $InstallerDir $app.installer
    if (-not (Test-Path $file)) { Write-Host "  Bundled installer missing: $file" -ForegroundColor Red; return $false }
    Unblock-File $file -ErrorAction SilentlyContinue

    if ($app.portable) {
        # Portable app: copy to Program Files and add a Start Menu shortcut
        $target = Join-Path $env:ProgramFiles ([IO.Path]::GetFileNameWithoutExtension($app.installer))
        New-Item -ItemType Directory -Force $target | Out-Null
        Copy-Item $file $target -Force
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$($app.name).lnk")
        $lnk.TargetPath = Join-Path $target $app.installer
        $lnk.Save()
        return $true
    }

    Write-Host "  Running bundled $($app.installer) $($app.args)"
    $p = if ($app.args) { Start-Process -FilePath $file -ArgumentList $app.args -Wait -PassThru }
         else           { Start-Process -FilePath $file -Wait -PassThru }
    return (@(0, 3010) -contains $p.ExitCode)   # 3010 = success, reboot required
}

# ---- 4. Install everything -------------------------------------------
$results = @()
foreach ($app in $apps) {
    if (-not $app.enabled) { continue }
    Write-Host "`n=== $($app.name) ===" -ForegroundColor Cyan
    $ok = Install-WithWinget $app
    $via = 'winget'
    if (-not $ok) { $ok = Install-WithBundled $app; $via = 'bundled' }
    $results += [pscustomobject]@{ App = $app.name; Status = $(if ($ok) { 'OK' } else { 'FAILED' }); Via = $(if ($ok) { $via } else { '-' }) }
}

# ---- 5. Summary -------------------------------------------------------
Write-Host "`n================ SUMMARY ================" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Log saved in $LogDir" -ForegroundColor Gray
Stop-Transcript | Out-Null
Read-Host 'Done. Press Enter to close'
