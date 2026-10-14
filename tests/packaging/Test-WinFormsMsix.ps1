<#
.SYNOPSIS
Verifies that an MSIX contains the versioned WinForms application and update metadata.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$UpdatesUrl
)

$ErrorActionPreference = 'Stop'
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
try {
    function Read-PackageText([string]$Name) {
        $entry = $archive.GetEntry($Name)
        if ($null -eq $entry) { throw "MSIX entry is missing: $Name" }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { return $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }

    [xml]$manifest = Read-PackageText 'AppxManifest.xml'
    if ($manifest.Package.Identity.Version -ne $Version) { throw 'MSIX identity version does not match the release.' }
    if ($manifest.Package.Identity.ProcessorArchitecture -ne 'x64') { throw 'MSIX must target x64.' }
    $executable = $manifest.Package.Applications.Application.Executable.Replace('\', '/')
    if ($executable -match '\$' -or $null -eq $archive.GetEntry($executable)) {
        throw 'MSIX manifest does not point to a packaged executable.'
    }
    foreach ($name in @('GuacamoleClient-WinForms.dll', 'GuacamoleCommon.dll', 'coreclr.dll')) {
        $entry = $archive.GetEntry($name)
        if ($null -eq $entry -or $entry.Length -eq 0) { throw "MSIX application/runtime payload is missing: $name" }
    }
    $info = Read-PackageText 'app-info.json' | ConvertFrom-Json
    if ($info.version -ne $Version -or $info.updatesUrl -ne $UpdatesUrl -or $info.deploymentType -ne 'msix') {
        throw 'MSIX update metadata does not match the release.'
    }
    Write-Host "MSIX verification passed: version $Version, executable $executable, self-contained runtime, and update feed."
}
finally { $archive.Dispose() }
