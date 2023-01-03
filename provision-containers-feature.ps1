while ($true) {
    try {
        Write-Host 'Installing the Containers Windows feature...'
        Install-WindowsFeature Containers
        break
    } catch {
        Write-Host 'Installation failed. Retrying in 5 seconds...'
        Start-Sleep -Seconds 5
    }
}
