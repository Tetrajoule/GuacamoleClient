<#
.SYNOPSIS
Creates an unsigned MSIX package from a published WinForms application.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PublishDirectory,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$Version,
    [string]$PackageName,
    [string]$Publisher,
    [string]$PublisherDisplayName,
    [string]$MakeAppxPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$publishRoot = (Resolve-Path -LiteralPath $PublishDirectory).Path
$output = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $output
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Output directory does not exist: $outputDirectory"
}
if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Version must contain four numeric parts.' }
[void][version]::Parse($Version)
foreach ($file in @('GuacamoleClient-WinForms.exe', 'GuacamoleClient-WinForms.dll', 'app-info.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $publishRoot $file) -PathType Leaf)) {
        throw "Published application file is missing: $file"
    }
}
$appInfo = Get-Content -LiteralPath (Join-Path $publishRoot 'app-info.json') -Raw | ConvertFrom-Json
if ($appInfo.version -ne $Version) { throw 'Published application metadata has a different version.' }

if ([string]::IsNullOrWhiteSpace($MakeAppxPath)) {
    $sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    $tools = Get-ChildItem -LiteralPath $sdkRoot -Directory |
        Where-Object Name -Match '^\d+\.\d+\.\d+\.\d+$' |
        Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object { Join-Path $_.FullName 'x64\makeappx.exe' } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    $MakeAppxPath = @($tools)[0]
}
if ([string]::IsNullOrWhiteSpace($MakeAppxPath) -or -not (Test-Path -LiteralPath $MakeAppxPath -PathType Leaf)) {
    throw 'The Windows SDK MakeAppx tool is required.'
}

$stage = Join-Path $outputDirectory ('.msix-stage-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $stage)
try {
    Copy-Item -Path (Join-Path $publishRoot '*') -Destination $stage -Recurse
    $images = Join-Path $stage 'Images'
    [void](New-Item -ItemType Directory -Path $images -Force)
    $sourceImages = Join-Path $root 'WinAppPackagingMsixGuacamoleClientWinForms\Images'
    foreach ($name in @('StoreLogo', 'Square150x150Logo', 'Square44x44Logo', 'Wide310x150Logo', 'SmallTile', 'LargeTile', 'SplashScreen', 'BadgeLogo')) {
        $source = Join-Path $sourceImages "$name.scale-100.png"
        if (-not (Test-Path -LiteralPath $source)) { $source = Join-Path $sourceImages "$name.scale-200.png" }
        Copy-Item -LiteralPath $source -Destination (Join-Path $images "$name.png")
    }

    [xml]$manifest = Get-Content -LiteralPath (Join-Path $root 'WinAppPackagingMsixGuacamoleClientWinForms\Package.appxmanifest') -Raw
    $identity = $manifest.Package.Identity
    $identity.SetAttribute('Version', $Version)
    $identity.SetAttribute('ProcessorArchitecture', 'x64')
    if ($PackageName) { $identity.SetAttribute('Name', $PackageName) }
    if ($Publisher) { $identity.SetAttribute('Publisher', $Publisher) }
    if ($PublisherDisplayName) { $manifest.Package.Properties.PublisherDisplayName = $PublisherDisplayName }
    $manifest.Package.Resources.Resource.SetAttribute('Language', 'en-US')

    foreach ($family in @($manifest.Package.Dependencies.TargetDeviceFamily)) {
        if ($family.GetAttribute('Name') -ne 'Windows.Desktop') {
            [void]$family.ParentNode.RemoveChild($family)
        }
        else {
            $family.SetAttribute('MinVersion', '10.0.17763.0')
            $family.SetAttribute('MaxVersionTested', '10.0.26100.0')
        }
    }
    $application = $manifest.Package.Applications.Application
    $application.SetAttribute('Executable', 'GuacamoleClient-WinForms.exe')
    $application.SetAttribute('EntryPoint', 'Windows.FullTrustApplication')
    $application.RemoveAttribute('TrustLevel', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/18')
    $application.RemoveAttribute('RuntimeBehavior', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/18')
    $manifest.Save((Join-Path $stage 'AppxManifest.xml'))

    & $MakeAppxPath pack /d $stage /p $output /o
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx failed with exit code $LASTEXITCODE." }
    Write-Host "Created unsigned MSIX package: $output"
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
