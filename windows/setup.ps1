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
#      Only apps.json is fetched up front; an installer file is downloaded
#      only if that app actually needs its bundled fallback.
$ProgressPreference = 'SilentlyContinue'       # makes Invoke-WebRequest much faster
$BaseUrl = "https://raw.githubusercontent.com/$GitHubUser/$RepoName/$Branch/windows"

if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'apps.json'))) {
    $IsLocal      = $true                      # running from local folder / pendrive
    $InstallerDir = Join-Path $PSScriptRoot 'installers'
    $apps = Get-Content (Join-Path $PSScriptRoot 'apps.json') -Raw | ConvertFrom-Json
} else {
    $IsLocal      = $false
    $InstallerDir = Join-Path $env:TEMP "$RepoName-installers"
    New-Item -ItemType Directory -Force $InstallerDir | Out-Null
    Write-Host "Fetching app list from GitHub ($GitHubUser/$RepoName)..." -ForegroundColor Cyan
    $apps = Invoke-RestMethod -Uri "$BaseUrl/apps.json" -UseBasicParsing
}

function Get-InstallerFile($name) {
    $file = Join-Path $InstallerDir $name
    if (-not (Test-Path $file) -and -not $IsLocal) {
        Write-Host "  Downloading $name from GitHub..."
        try { Invoke-WebRequest -Uri "$BaseUrl/installers/$([uri]::EscapeDataString($name))" -OutFile $file -UseBasicParsing }
        catch { Write-Host "  Download failed: $_" -ForegroundColor Red }
    }
    if (Test-Path $file) { return $file }
    return $null
}

# ---- 2b. Let the user choose which apps to install ---------------------
#      Apps with "enabled": true in apps.json are ticked by default.
function Select-AppsWindow($apps) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object Windows.Forms.Form
    $form.Text = 'Bigstep PC Setup - choose software'
    $form.Size = New-Object Drawing.Size(420, 520)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.TopMost = $true

    $label = New-Object Windows.Forms.Label
    $label.Text = "Tick the software to install on this PC, then click Install."
    $label.Location = New-Object Drawing.Point(12, 12)
    $label.Size = New-Object Drawing.Size(380, 20)
    $form.Controls.Add($label)

    $list = New-Object Windows.Forms.CheckedListBox
    $list.Location = New-Object Drawing.Point(12, 38)
    $list.Size = New-Object Drawing.Size(380, 370)
    $list.CheckOnClick = $true
    $list.Font = New-Object Drawing.Font('Segoe UI', 10)
    foreach ($app in $apps) { [void]$list.Items.Add($app.name, [bool]$app.enabled) }
    $form.Controls.Add($list)

    $btnAll = New-Object Windows.Forms.Button
    $btnAll.Text = 'Select all'
    $btnAll.Location = New-Object Drawing.Point(12, 420)
    $btnAll.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })
    $form.Controls.Add($btnAll)

    $btnNone = New-Object Windows.Forms.Button
    $btnNone.Text = 'Select none'
    $btnNone.Location = New-Object Drawing.Point(95, 420)
    $btnNone.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $false) } })
    $form.Controls.Add($btnNone)

    $btnOk = New-Object Windows.Forms.Button
    $btnOk.Text = 'Install'
    $btnOk.Location = New-Object Drawing.Point(236, 420)
    $btnOk.DialogResult = 'OK'
    $form.AcceptButton = $btnOk
    $form.Controls.Add($btnOk)

    $btnCancel = New-Object Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.Location = New-Object Drawing.Point(317, 420)
    $btnCancel.DialogResult = 'Cancel'
    $form.CancelButton = $btnCancel
    $form.Controls.Add($btnCancel)

    if ($form.ShowDialog() -ne 'OK') { return $null }
    $chosen = @($list.CheckedItems)
    return @($apps | Where-Object { $chosen -contains $_.name })
}

function Select-AppsConsole($apps) {
    # Fallback text menu if the window can't be shown
    $picked = @{}
    foreach ($app in $apps) { $picked[$app.name] = [bool]$app.enabled }
    while ($true) {
        Write-Host "`nChoose software to install (number = tick/untick, A = all, N = none, Enter = install, Q = quit):" -ForegroundColor Cyan
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $mark = if ($picked[$apps[$i].name]) { '[X]' } else { '[ ]' }
            Write-Host ("  {0,2}. {1} {2}" -f ($i + 1), $mark, $apps[$i].name)
        }
        $in = (Read-Host 'Your choice').Trim()
        if ($in -eq '')  { break }
        if ($in -eq 'Q') { return $null }
        if ($in -eq 'A') { $apps | ForEach-Object { $picked[$_.name] = $true };  continue }
        if ($in -eq 'N') { $apps | ForEach-Object { $picked[$_.name] = $false }; continue }
        foreach ($n in ($in -split '[ ,]+')) {
            if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $apps.Count) {
                $name = $apps[[int]$n - 1].name
                $picked[$name] = -not $picked[$name]
            }
        }
    }
    return @($apps | Where-Object { $picked[$_.name] })
}

$apps = @($apps | ForEach-Object { $_ })   # flatten (PS 5.1 ConvertFrom-Json quirk)
try   { $selected = Select-AppsWindow $apps }
catch { Write-Host 'Selection window unavailable - using text menu.' -ForegroundColor Yellow
        $selected = Select-AppsConsole $apps }

if (-not $selected -or $selected.Count -eq 0) {
    Write-Host 'Nothing selected - exiting.' -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host 'Press Enter to close'
    return
}
Write-Host "Selected: $(($selected | ForEach-Object name) -join ', ')" -ForegroundColor Green

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
    # Refresh the package catalog so "latest" really means the newest release
    Write-Host 'Updating winget catalog...'
    & $winget source update --name winget --disable-interactivity | Out-Null
} else {
    Write-Host 'winget unavailable - will use bundled installers only.' -ForegroundColor Yellow
}

# winget exit codes that mean "already on the latest version / nothing to do"
$WINGET_NO_UPGRADE        = -1978335189   # no newer version available
$WINGET_ALREADY_INSTALLED = -1978335135   # older winget: installed, didn't upgrade
$wingetOk = @(0, $WINGET_NO_UPGRADE)

function Install-WithWinget($app) {
    if (-not $winget -or -not $app.wingetId) { return $false }
    $common = @('--id', $app.wingetId, '-e', '--source', 'winget', '--silent',
                '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    # --source winget skips the slow Microsoft Store source.
    # If the app is already installed, current winget upgrades it to the latest version.
    Write-Host "  winget install $($app.wingetId) (latest)"
    & $winget install @common | Out-Host
    $code = $LASTEXITCODE

    if ($code -eq $WINGET_ALREADY_INSTALLED) {
        # Older winget doesn't upgrade on install - do it explicitly
        Write-Host '  Already installed - upgrading to the latest version...'
        & $winget upgrade @common | Out-Host
        $code = $LASTEXITCODE
    }
    if ($code -eq $WINGET_NO_UPGRADE) { Write-Host '  Already on the latest version.' -ForegroundColor Green }
    return ($wingetOk -contains $code)
}

function Install-WithBundled($app) {
    if (-not $app.installer) { return $false }
    $file = Get-InstallerFile $app.installer
    if (-not $file) { Write-Host "  Bundled installer missing: $($app.installer)" -ForegroundColor Red; return $false }
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
    $p = if ($app.args) { Start-Process -FilePath $file -ArgumentList $app.args -PassThru }
         else           { Start-Process -FilePath $file -PassThru }

    # "background": true = don't wait; it installs alongside the other apps
    # and is checked at the end (used for the big Microsoft 365 download).
    if ($app.background) { return $p }

    $p.WaitForExit()
    return (@(0, 3010) -contains $p.ExitCode)   # 3010 = success, reboot required
}

function Add-Result($name, $ok, $via, $sw) {
    $script:results += [pscustomobject]@{
        App     = $name
        Status  = $(if ($ok) { 'OK' } else { 'FAILED' })
        Via     = $(if ($ok) { $via } else { '-' })
        Minutes = [math]::Round($sw.Elapsed.TotalMinutes, 1)
    }
}

# ---- 4. Install everything -------------------------------------------
$results    = @()
$background = @()
$total      = [Diagnostics.Stopwatch]::StartNew()
$enabled    = @($selected)
$i = 0
foreach ($app in $enabled) {
    $i++
    Write-Host "`n=== [$i/$($enabled.Count)] $($app.name) ===" -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()

    if ($app.background) {
        $p = Install-WithBundled $app
        if ($p -is [Diagnostics.Process]) {
            Write-Host '  Started in background - continuing with the other apps.' -ForegroundColor Yellow
            $background += [pscustomobject]@{ App = $app; Process = $p; Timer = $sw }
        } else {
            Add-Result $app.name $false '-' $sw
        }
        continue
    }

    $ok = Install-WithWinget $app
    $via = 'winget'
    if (-not $ok) { $ok = Install-WithBundled $app; $via = 'bundled' }
    Add-Result $app.name $ok $via $sw
    Write-Host "  $(if ($ok) {'Done'} else {'FAILED'}) in $([math]::Round($sw.Elapsed.TotalMinutes,1)) min"
}

foreach ($b in $background) {
    if (-not $b.Process.HasExited) {
        Write-Host "`nWaiting for $($b.App.name) to finish (large download, can take a while)..." -ForegroundColor Yellow
    }
    $b.Process.WaitForExit()
    Add-Result $b.App.name (@(0, 3010) -contains $b.Process.ExitCode) 'bundled' $b.Timer
}

# ---- 5. Summary -------------------------------------------------------
Write-Host "`n================ SUMMARY ($([math]::Round($total.Elapsed.TotalMinutes,1)) min total) ================" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Log saved in $LogDir" -ForegroundColor Gray
Stop-Transcript | Out-Null
Read-Host 'Done. Press Enter to close'
