$ErrorActionPreference = "Stop"

# Create a folder for installation logs
$logFolder = 'C:\install_logs'
if (-not (Test-Path -Path $logFolder)) {
    Write-Host "Creating log folder at $logFolder..."
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

# Mount VirtIO ISO and install drivers silently
$virtioDrive = "F:"  # Assuming the VirtIO ISO is mounted as drive E:
$virtioInstaller = Join-Path -Path $virtioDrive -ChildPath "virtio-win-gt-x64.msi"
$qemuInstaller = Join-Path -Path $virtioDrive -ChildPath "guest-agent\qemu-ga-x86_64.msi"

# Install VirtIO drivers
if (Test-Path $virtioInstaller) {
    Write-Host "Running VirtIO driver installation from $virtioInstaller..."
    try {
        # Execute the silent installation
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$virtioInstaller`" /qn ADDLOCAL=ALL /norestart" -Wait -NoNewWindow
        Write-Host "VirtIO driver installation completed successfully."
    }
    catch {
        Write-Error "Failed to run VirtIO driver installation: $_"
        exit 1
    }
}
else {
    Write-Error "VirtIO installer not found at $virtioInstaller. Exiting..."
    exit 1
}

# Install QEMU Guest Agent
if (Test-Path $qemuInstaller) {
    Write-Host "Installing QEMU Guest Agent from $qemuInstaller..."
    try {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$qemuInstaller`" /qn" -Wait -NoNewWindow
        Start-Service -Name qemu-ga
        Set-Service -Name qemu-ga -StartupType Automatic
        Write-Host "QEMU Guest Agent installed and configured successfully."
    }
    catch {
        Write-Error "Failed to install QEMU Guest Agent: $_"
        exit 1
    }
}
else {
    Write-Error "QEMU Guest Agent installer not found at $qemuInstaller. Skipping installation."
}

# Switch network connection to private mode
$profile = Get-NetConnectionProfile
Set-NetConnectionProfile -Name $profile.Name -NetworkCategory Private

$url = "https://raw.githubusercontent.com/ansible/ansible-documentation/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"
(New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
powershell.exe -ExecutionPolicy ByPass -File $file

# Reset auto logon count
Write-Host "Resetting auto logon count..."
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0

# WinRM Configuration
Write-Host "Configuring WinRM..."
winrm quickconfig -quiet