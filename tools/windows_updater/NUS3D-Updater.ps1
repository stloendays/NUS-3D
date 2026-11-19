# NUS-3D official Windows portable updater. Ships with the game; not downloaded as code.
# Run from a temporary COPY of this script after the game exits.
# Requires stock Windows PowerShell 5.1 and .NET Framework compression support.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Package,
    [Parameter(Mandatory=$true)][string]$ExpectedSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [string]$InstallDir = "",
    [int]$WaitPid = 0,
    [switch]$VerifyOnly,
    [switch]$NoLaunch,
    [string]$StatusFile = ""
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ExeName = "NUS3D-UTown.exe"
$PackName = "NUS3D-UTown.pck"
$HelperName = "NUS3D-Updater.ps1"
$ManifestName = "BUILD_MANIFEST.json"
$ReadmeName = "READ_ME_FIRST.txt"
$Names = @($ExeName, $PackName, $HelperName, $ManifestName, $ReadmeName)
$Staging = ""
$Backup = ""
$OldMoved = $false

function Assert-Input($condition, [string]$reason) {
    if (-not $condition) { throw $reason }
}
function Write-UpdateStatus([string]$status, [string]$description) {
    if ([string]::IsNullOrWhiteSpace($StatusFile)) { return }
    try {
        $parent = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($StatusFile))
        if (-not [System.IO.Directory]::Exists($parent)) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        $json = @{ result=$status; message=$description; version=$ExpectedVersion } | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($StatusFile, $json, [System.Text.Encoding]::UTF8)
    } catch { Write-Warning "Could not write updater status: $_" }
}
function Sha256([string]$path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Validate-Package([string]$zipPath) {
    Assert-Input ($ExpectedSha256 -cmatch '^[0-9a-f]{64}$') "Expected package SHA-256 must be lowercase hexadecimal."
    Assert-Input ($ExpectedVersion -cmatch '^[0-9]+\.[0-9]+\.[0-9]+$') "Expected version must be stable SemVer without prefix."
    Assert-Input ([System.IO.File]::Exists($zipPath)) "Release ZIP does not exist."
    $length = (Get-Item -LiteralPath $zipPath).Length
    Assert-Input ($length -gt 1000000 -and $length -le 400000000) "Release ZIP outside safe size limit."
    Assert-Input ((Sha256 $zipPath) -ceq $ExpectedSha256) "Downloaded release archive SHA-256 mismatch."
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $members = @($zip.Entries)
        Assert-Input ($members.Count -eq $Names.Count) "Unexpected archive member count."
        $namesSeen = @{}
        $totalSize = [long]0
        foreach ($entry in $members) {
            $name = $entry.FullName
            Assert-Input ($Names -ccontains $name) "Archive contains unknown or nested file: $name"
            Assert-Input (-not $namesSeen.ContainsKey($name)) "Archive contains duplicate member: $name"
            $namesSeen[$name] = $true
            Assert-Input ($entry.Length -gt 0 -and $entry.Length -lt 350000000) "Archive member exceeds size limit: $name"
            $totalSize += $entry.Length
        }
        Assert-Input ($totalSize -le 500000000) "Uncompressed archive exceeds safe limit."
        $manifestEntry = $zip.GetEntry($ManifestName)
        Assert-Input ($null -ne $manifestEntry) "Build manifest is missing."
        $reader = [System.IO.StreamReader]::new($manifestEntry.Open(), [System.Text.Encoding]::UTF8)
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
        finally { $reader.Dispose() }
        Assert-Input ($manifest.schema_version -eq 2) "Unsupported manifest schema."
        Assert-Input ($manifest.platform -ceq "Windows x86_64") "Wrong release platform."
        Assert-Input ($manifest.repository -ceq "https://github.com/stloendays/NUS-3D") "Wrong release repository."
        Assert-Input ($manifest.release_version -ceq $ExpectedVersion) "Release version and manifest mismatch."
        foreach ($name in @($ExeName,$PackName,$HelperName)) {
            $entry = $zip.GetEntry($name)
            $record = $manifest.files.PSObject.Properties[$name].Value
            Assert-Input ($null -ne $record) "Missing build manifest record: $name"
            Assert-Input ([long]$record.bytes -eq [long]$entry.Length) "File length mismatch for $name"
            Assert-Input ([string]$record.sha256 -cmatch '^[0-9a-f]{64}$') "Bad SHA256 in manifest for $name"
        }
        return $manifest
    } finally { $zip.Dispose() }
}
function Extract-Verified([string]$zipPath, [string]$destination, $manifest) {
    [System.IO.Directory]::CreateDirectory($destination) | Out-Null
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($name in @($ExeName,$PackName,$HelperName)) {
            $entry = $zip.GetEntry($name)
            $target = Join-Path $destination $name
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
            Assert-Input ((Sha256 $target) -ceq $manifest.files.PSObject.Properties[$name].Value.sha256) "Payload SHA-256 mismatch: $name"
        }
    } finally { $zip.Dispose() }
    $exe = Join-Path $destination $ExeName
    $pck = Join-Path $destination $PackName
    Assert-Input ((Get-Item -LiteralPath $exe).Length -ge 1000000) "Executable is implausibly small."
    $exeHandle = [System.IO.File]::OpenRead($exe)
    try {
        $exeHeader = New-Object byte[] 2
        Assert-Input ($exeHandle.Read($exeHeader,0,2) -eq 2 -and $exeHeader[0] -eq 77 -and $exeHeader[1] -eq 90) "Executable PE signature is invalid."
    } finally { $exeHandle.Dispose() }
    $fs = [System.IO.File]::OpenRead($pck)
    try {
        $header = New-Object byte[] 4
        Assert-Input ($fs.Read($header,0,4) -eq 4 -and [System.Text.Encoding]::ASCII.GetString($header) -ceq "GDPC") "Godot PCK signature is invalid."
    } finally { $fs.Dispose() }
}
function Smoke-Stage([string]$stage) {
    $exe = Join-Path $stage $ExeName
    $report = Join-Path $stage "update-smoke.json"
    $argsText = '--headless -- --nus3d-self-test --nus3d-self-test-report="' + ($report -replace '\\','/') + '"'
    $process = Start-Process -FilePath $exe -ArgumentList $argsText -WorkingDirectory $stage -PassThru
    if (-not $process.WaitForExit(90000)) {
        try { $process.Kill() } catch {}
        throw "Candidate build self-test timed out."
    }
    $process.Refresh()
    Assert-Input ($process.ExitCode -eq 0) "Candidate build self-test failed."
    Assert-Input ([System.IO.File]::Exists($report)) "Candidate build produced no self-test report."
    $selfTest = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Assert-Input ($selfTest.result -ceq "pass") "Candidate self-test report did not pass."
}

try {
    $zipPath = [System.IO.Path]::GetFullPath($Package)
    $manifest = Validate-Package $zipPath
    if ($VerifyOnly) {
        Write-UpdateStatus "verified" "Release archive checksum and inventory verified."
        Write-Output "NUS3D_UPDATE_VERIFIED $ExpectedVersion"
        exit 0
    }
    Assert-Input (-not [string]::IsNullOrWhiteSpace($InstallDir)) "InstallDir is required to install."
    $root = [System.IO.Path]::GetFullPath($InstallDir)
    Assert-Input ([System.IO.Directory]::Exists($root)) "Game install directory does not exist."
    Assert-Input ([System.IO.File]::Exists((Join-Path $root $ExeName))) "Current game EXE is missing."
    Assert-Input ([System.IO.File]::Exists((Join-Path $root $PackName))) "Current game PCK is missing."
    if ($WaitPid -gt 0) {
        try { Wait-Process -Id $WaitPid -Timeout 60 -ErrorAction Stop }
        catch {
            if ($null -ne (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue)) {
                throw "The previous game process is still running."
            }
        }
    }
    $token = [Guid]::NewGuid().ToString("N")
    $Staging = Join-Path $root (".nus3d-stage-" + $token)
    $Backup = Join-Path $root (".nus3d-backup-" + $token)
    Extract-Verified $zipPath $Staging $manifest
    Smoke-Stage $Staging
    [System.IO.Directory]::CreateDirectory($Backup) | Out-Null
    # Preserve the previous version until both payload files and the update
    # helper have been replaced successfully. Never touch user:// saves.
    foreach ($name in @($ExeName,$PackName,$HelperName)) {
        $old = Join-Path $root $name
        if ([System.IO.File]::Exists($old)) {
            Copy-Item -LiteralPath $old -Destination (Join-Path $Backup $name) -Force
        }
    }
    $OldMoved = $true
    foreach ($name in @($ExeName,$PackName,$HelperName)) {
        Move-Item -LiteralPath (Join-Path $Staging $name) -Destination (Join-Path $root $name) -Force
    }
    # If relaunch fails, the previous files can still be restored from Backup.
    # -NoLaunch is a CI-only acceptance test; the game updater never uses it.
    if (-not $NoLaunch) {
        Start-Process -FilePath (Join-Path $root $ExeName) -WorkingDirectory $root -ErrorAction Stop
    }
    $OldMoved = $false
    $previousBackup = Join-Path $root ".nus3d-previous"
    try {
        if (Test-Path -LiteralPath $previousBackup) {
            Remove-Item -LiteralPath $previousBackup -Recurse -Force
        }
        Move-Item -LiteralPath $Backup -Destination $previousBackup -Force
        $Backup = ""
    } catch {
        Write-Warning "Update installed, but the prior backup could not be rotated: $_"
    }
    Write-UpdateStatus "installed" "Updated to version $ExpectedVersion. Previous files retained for manual rollback."
    Write-Output "NUS3D_UPDATE_INSTALLED $ExpectedVersion"
    exit 0
} catch {
    $reason = [string]$_
    if ($OldMoved -and $Backup -and (Test-Path -LiteralPath $Backup)) {
        foreach ($name in @($ExeName,$PackName,$HelperName)) {
            $older = Join-Path $Backup $name
            if (Test-Path -LiteralPath $older) {
                try { Copy-Item -LiteralPath $older -Destination (Join-Path $root $name) -Force }
                catch { Write-Warning "Could not restore $name : $_" }
            }
        }
    }
    Write-UpdateStatus "failed" $reason
    Write-Error "NUS-3D update failed: $reason"
    exit 1
} finally {
    if ($Staging -and (Test-Path -LiteralPath $Staging)) {
        try { Remove-Item -LiteralPath $Staging -Recurse -Force } catch {}
    }
}
