param(
    [Parameter(Mandatory=$true)]
    [string]$script,

    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$scriptArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Exit 1
}

function Write-Title($title) {
    Write-Host "#`n# $title`n#"
}

# see https://github.com/microsoft/Windows-Containers
# see https://techcommunity.microsoft.com/t5/containers/announcing-a-new-windows-server-container-image-preview/ba-p/2304897
# see https://blogs.technet.microsoft.com/virtualization/2018/10/01/incoming-tag-changes-for-containers-in-windows-server-2019/
# see https://hub.docker.com/_/microsoft-windows-nanoserver
# see https://hub.docker.com/_/microsoft-windows-servercore
# see https://hub.docker.com/_/microsoft-windows-server
# see https://hub.docker.com/_/microsoft-windows
# see https://mcr.microsoft.com/v2/windows/nanoserver/tags/list
# see https://mcr.microsoft.com/v2/windows/servercore/tags/list
# see https://mcr.microsoft.com/v2/windows/server/tags/list
# see https://mcr.microsoft.com/v2/windows/tags/list
# see https://mcr.microsoft.com/v2/powershell/tags/list
# see https://mcr.microsoft.com/v2/dotnet/sdk/tags/list
# see https://mcr.microsoft.com/v2/dotnet/runtime/tags/list
# see https://hub.docker.com/_/golang/
# see https://docs.microsoft.com/en-us/windows/release-information/
# see https://docs.microsoft.com/en-us/windows/release-health/windows-server-release-info
# see Get-WindowsVersion at https://github.com/rgl/windows-vagrant/blob/master/example/summary.ps1
function Get-WindowsContainers {
    $currentVersionKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $windowsBuildNumber = $currentVersionKey.CurrentBuildNumber
    $windowsVersionTag = @{
        '20348' = 'ltsc2022'    # Windows Server 2022 (21H2).
        '17763' = '1809'        # Windows Server 2019 (1809).
    }[$windowsBuildNumber]
    @{
        tag = $windowsVersionTag
        nanoserver = "mcr.microsoft.com/windows/nanoserver`:$windowsVersionTag"
        servercore = "mcr.microsoft.com/windows/servercore`:$windowsVersionTag"
        server = if ($windowsBuildNumber -ge 20348) {
            "mcr.microsoft.com/windows/server`:$windowsVersionTag"
        } else {
            "mcr.microsoft.com/windows`:$windowsVersionTag"
        }
    }
}

# wrap the choco command (to make sure this script aborts when it fails).
function Start-Choco([string[]]$Arguments, [int[]]$SuccessExitCodes=@(0)) {
    $command, $commandArguments = $Arguments
    if ($command -eq 'install') {
        $Arguments = @($command, '--no-progress') + $commandArguments
    }
    for ($n = 0; $n -lt 10; ++$n) {
        if ($n) {
            # NB sometimes choco fails with "The package was not found with the source(s) listed."
            #    but normally its just really a transient "network" error.
            Write-Host "Retrying choco install..."
            Start-Sleep -Seconds 3
        }
        &C:\ProgramData\chocolatey\bin\choco.exe @Arguments
        if ($SuccessExitCodes -Contains $LASTEXITCODE) {
            return
        }
    }
    throw "$(@('choco')+$Arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
}
function choco {
    Start-Choco $Args
}

Set-Location c:\vagrant
$script = Resolve-Path $script
Set-Location (Split-Path -Parent $script)
Write-Host "Running $script..."
. ".\$(Split-Path -Leaf $script)" @scriptArguments
