# Set execution policy to bypass for this session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Define variables
$pythonVersion = "3.12.1"
$installerName = "python-$pythonVersion-amd64.exe"
$installerUrl = "https://www.python.org/ftp/python/$pythonVersion/$installerName"
$installerPath = "$env:USERPROFILE\Downloads"
$installerFullPath = Join-Path $installerPath $installerName
$logDir = "$env:USERPROFILE\Desktop\Python_Install_Logs"
$logFile = Join-Path $logDir "python_install_$pythonVersion.log"

# Ensure the log directory exists
if (-not (Test-Path $logDir)) {
    Write-Host "Creating log directory..."
    New-Item -Path $logDir -ItemType Directory -ErrorAction Stop | Out-Null
}

# Log start
$startTime = Get-Date
"$startTime: Starting download of Python $pythonVersion" | Out-File $logFile -Append
Write-Host "Downloading Python $pythonVersion..."

# Download the installer
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerFullPath -ErrorAction Stop
    "$startTime: Download completed." | Out-File $logFile -Append
} catch {
    Write-Host "Download failed, see log at $logFile for details."
    "$startTime: Download failed." | Out-File $logFile -Append
    Read-Host "Press Enter to exit"
    exit
}

# Install Python
Write-Host "Installing Python $pythonVersion..."
try {
    Start-Process -FilePath $installerFullPath -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0' -NoNewWindow -Wait
    "$startTime: Installation completed successfully." | Out-File $logFile -Append
} catch {
    Write-Host "Installation failed, see log at $logFile for details."
    "$startTime: Installation failed." | Out-File $logFile -Append
    Read-Host "Press Enter to exit"
    exit
}

# Verify installation
Write-Host "Verifying Python installation..."
$verification = Start-Process -FilePath "py" -ArgumentList "-3.12 -c `"import sys; print('Python version:', sys.version)`"" -NoNewWindow -Wait -PassThru
if ($verification.ExitCode -ne 0) {
    Write-Host "Verification failed. Python 3.12.1 might not have installed correctly."
    "$startTime: Verification failed." | Out-File $logFile -Append
    Read-Host "Press Enter to exit"
    exit
}

# Cleanup
Write-Host "Cleaning up installation files..."
Remove-Item -Path $installerFullPath -ErrorAction Ignore
"$startTime: Cleanup completed." | Out-File $logFile -Append

Write-Host "Installation and verification completed successfully."
"$startTime: Python $pythonVersion installation and verification completed successfully." | Out-File $logFile -Append

Read-Host "Installation complete. Press Enter to exit"
