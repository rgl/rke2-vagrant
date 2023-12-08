param(
    [Parameter(Mandatory=$true)]
    [string]$rke2Channel = 'latest',

    [Parameter(Mandatory=$true)]
    [string]$rke2Version = 'v1.26.11+rke2r1',

    [Parameter(Mandatory=$true)]
    [string]$rke2ServerUrl = 'https://server.rke2.test:9345',

    [Parameter(Mandatory=$true)]
    [string]$ipAddress = '10.11.0.211',

    [Parameter(Mandatory=$true)]
    [string]$useNssm = '1'
)

# install the rke2 agent binaries.
# see https://docs.rke2.io/install/quickstart#windows-agent-worker-node-installation
# see https://docs.rke2.io/install/configuration
# see https://docs.rke2.io/reference/windows_agent_config
New-Item -Type Directory c:/etc/rancher/rke2 -Force | Out-Null
Disable-CAclInheritance c:/etc/rancher/rke2
Grant-CPermission c:/etc/rancher/rke2 SYSTEM FullControl
Grant-CPermission c:/etc/rancher/rke2 Administrators FullControl
Grant-CPermission c:/etc/rancher/rke2 $env:USERNAME FullControl
Set-Content -Path c:/etc/rancher/rke2/config.yaml -Value @"
server: $rke2ServerUrl
token: $(Get-Content -Raw c:/vagrant/tmp/node-token)
node-ip: $ipAddress
"@
$tempInstall = "$env:TMP\install-rke2-agent.ps1"
Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/rancher/rke2/$rke2Version/install.ps1" `
    -Outfile $tempInstall
PowerShell `
    -File $tempInstall `
    -Channel $rke2Channel `
    -Version $rke2Version `
    -Type agent

# add rke2 to the machine PATH.
$rke2Path = 'c:\var\lib\rancher\rke2\bin;c:\usr\local\bin'
$env:PATH += ";$rke2Path"
[Environment]::SetEnvironmentVariable(
    'PATH',
    [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ";$rke2Path",
    'Machine')

# install and start the rke2 service.
if ($useNssm -eq '1') {
    # NB the rke2 built-in service (installed as rke2 agent service --add) does
    #    not send all the logs to the windows event log (e.g. kube-proxy only logs
    #    to stdout/err). as such, we use nssm instead.
    # see https://github.com/rancher/rke2/issues/1807
    Write-Title 'Installing and starting the rke2 nssm service'
    New-Item -Type Directory c:/var/log -Force | Out-Null
    Disable-CAclInheritance c:/var/log
    Grant-CPermission c:/var/log SYSTEM FullControl
    Grant-CPermission c:/var/log Administrators FullControl
    Grant-CPermission c:/var/log $env:USERNAME FullControl
    nssm install rke2 c:/usr/local/bin/rke2.exe
    nssm set rke2 AppParameters agent
    nssm set rke2 Start SERVICE_AUTO_START
    nssm set rke2 AppRotateFiles 1
    nssm set rke2 AppRotateOnline 1
    nssm set rke2 AppRotateSeconds 86400
    nssm set rke2 AppRotateBytes 1048576
    nssm set rke2 AppStdout c:/var/log/rke2-stdout.log
    nssm set rke2 AppStderr c:/var/log/rke2-stderr.log
    $result = sc.exe failure rke2 reset= 0 actions= restart/60000
    if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
        throw "sc.exe failure failed with $result"
    }
    Start-Service rke2
} else {
    # NB logs can be seen with event viewer under the rke2 event source.
    Write-Title 'Installing and starting the rke2 service'
    rke2 agent service --add
    if ($LASTEXITCODE) {
        throw "failed with exit code $LASTEXITCODE"
    }
    Start-Service rke2
}
