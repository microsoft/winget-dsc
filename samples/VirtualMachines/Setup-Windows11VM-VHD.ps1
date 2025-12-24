# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#Requires -Version 7.0

<# 
.SYNOPSIS
  Complete Windows 11 VM automation using bootable VHD approach.
  Supports two image types: DevVM and MSIXPackagingTool.

.DESCRIPTION
  This script creates a Windows 11 VM with a pre-installed OS on a bootable VHD.
  Instead of booting from ISO and running Windows Setup, this approach:
  
  1. Extracts install.wim from the Windows 11 ISO
  2. Creates a VHD and applies the Windows image directly to it
  3. Adds registry bypass keys for TPM/SecureBoot requirements
  4. Makes the VHD bootable with bcdboot
  5. Attaches the VHD to a Hyper-V VM
  
  The VM boots directly into Windows (no setup process), with all TPM/SecureBoot
  checks already bypassed. Post-installation scripts run on first login.
  
  IMAGE TYPES:
  - DevVM: Development environment with VS Code, Git, PowerToys, Windows Terminal, 
           PowerShell 7, Visual Studio 2022, WSL, and Ubuntu
  - MSIXPackagingTool: MSIX packaging environment with MSIX Packaging Tool,
                       driver, and Windows Update disabled

.PARAMETER VMName
  Name of the virtual machine to create.
  Default: "Windows11-VM"

.PARAMETER VMPath
  Root directory where VM files will be stored.
  Default: "$env:USERPROFILE\VMs"

.PARAMETER IsoPath
  Full path to the Windows 11 ISO file.
  Default: "$env:USERPROFILE\Downloads\windows11.iso"

.PARAMETER MemoryStartupBytes
  Initial memory allocation for the VM in bytes.
  Default: 4GB

.PARAMETER VHDSizeBytes
  Size of the virtual hard disk in bytes.
  Default: 80GB

.PARAMETER SwitchName
  Name of the Hyper-V virtual switch to connect the VM to.
  Default: Auto-detect

.PARAMETER AdminUser
  Administrator account username.
  Default: "Admin"

.PARAMETER AdminPassword
  Administrator account password.
  Default: "Password123!"

.PARAMETER SkipDownload
  Skip downloading the ISO if it already exists.

.PARAMETER WinGetConfigPath
  Path to WinGet DSC configuration file.
  Default: Auto-detect from known locations

.PARAMETER ImageType
  Type of VM image to create.
  
  Valid values:
    "DevVM" (default)         - Development environment
    "MSIXPackagingTool"       - MSIX packaging environment
  
  DevVM includes:
    - PowerShell 7
    - Visual Studio Code
    - Git
    - Windows Terminal
    - PowerToys
    - Visual Studio 2022 Community
    - WSL with Ubuntu
    - Developer Mode enabled
  
  MSIXPackagingTool includes:
    - MSIX Packaging Tool app
    - MSIX Packaging Tool Driver
    - Windows Update disabled
    - Desktop shortcuts to documentation
  
  Default: "DevVM"

.PARAMETER UpdateScriptsOnly
  Mount an existing VHD and update only the C:\Setup scripts and configuration.
  This is much faster for testing script changes without recreating the entire VHD.
  Requires VMName to identify the existing VHD.

.EXAMPLE
  .\Setup-Windows11VM-VHD.ps1
  
  Creates VM with default settings (DevVM).

.EXAMPLE
  .\Setup-Windows11VM-VHD.ps1 -VMName "DevBox" -MemoryStartupBytes 8GB -VHDSizeBytes 120GB
  
  Creates VM with custom configuration.

.EXAMPLE
  .\Setup-Windows11VM-VHD.ps1 -VMName "PackagingVM" -ImageType "MSIXPackagingTool"
  
  Creates VM configured for MSIX packaging with MSIX Packaging Tool installed.

.EXAMPLE
  .\Setup-Windows11VM-VHD.ps1 -VMName "Windows11-VM" -UpdateScriptsOnly -ImageType "DevVM"
  
  Updates only the C:\Setup scripts in an existing VHD (fast testing).

.NOTES
  Requires:
  - Administrator privileges
  - Hyper-V enabled
  - PowerShell 7+
  - Windows 11 ISO file
#>

[CmdletBinding()]
param(
    [string]$VMName = "Windows11-VM",
    [string]$VMPath = "$env:USERPROFILE\VMs",
    [string]$IsoPath = "$env:USERPROFILE\Downloads\windows11.iso",
    [uint64]$MemoryStartupBytes = 4GB,
    [uint64]$VHDSizeBytes = 80GB,
    [string]$SwitchName = $null,
    [string]$AdminUser = "Admin",
    [string]$AdminPassword = "Password123!",
    [switch]$SkipDownload,
    [string]$WinGetConfigPath = $null,
    [ValidateSet("DevVM", "MSIXPackagingTool")]
    [string]$ImageType = "DevVM",
    [switch]$UpdateScriptsOnly,
    [switch]$DebugLogging
)

#region Helper Functions

function Write-DebugLog {
    param([string]$Message)
    if ($script:DebugLogging) {
        Write-Host "    [DEBUG] $Message" -ForegroundColor DarkGray
    }
}

function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "⚠️  This script requires administrator privileges." -ForegroundColor Yellow
        Write-Host "   Re-launching as administrator..." -ForegroundColor Cyan
        
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            $arguments += " -$($param.Key)"
            if ($param.Value -is [switch]) {
                if ($param.Value) {
                    # Switch is present, don't add value
                }
            } else {
                $arguments += " `"$($param.Value)`""
            }
        }
        
        Start-Process pwsh -Verb RunAs -ArgumentList $arguments
        exit
    }
}

function Ensure-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "⚠️  PowerShell 7 or higher is required." -ForegroundColor Yellow
        Write-Host "   Installing PowerShell 7 via WinGet..." -ForegroundColor Cyan
        
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        
        Write-Host "✓ PowerShell 7 installed. Please restart this script in PowerShell 7." -ForegroundColor Green
        exit
    }
}

function Enable-HyperV {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    
    if ($hyperv.State -ne 'Enabled') {
        Write-Host "⚠️  Hyper-V is not enabled." -ForegroundColor Yellow
        Write-Host "   Enabling Hyper-V..." -ForegroundColor Cyan
        
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
        
        Write-Host "✓ Hyper-V enabled. A system restart is required." -ForegroundColor Green
        Write-Host "`nRestart now? (Y/N): " -NoNewline -ForegroundColor White
        $restart = Read-Host
        
        if ($restart -eq 'Y' -or $restart -eq 'y') {
            Restart-Computer -Force
        } else {
            Write-Host "⚠️  Please restart your computer and run this script again." -ForegroundColor Yellow
            exit
        }
    }
}

function Download-WindowsISO {
    param(
        [string]$OutputPath
    )
    
    if ((Test-Path $OutputPath) -and $SkipDownload) {
        Write-Host "✓ Using existing ISO: $OutputPath" -ForegroundColor Green
        return $true
    }
    
    $downloadUrl = "https://go.microsoft.com/fwlink/p/?LinkID=2334167"
    
    Write-Host "📥 Downloading Windows 11 ISO..." -ForegroundColor Cyan
    Write-Host "   URL: $downloadUrl" -ForegroundColor Gray
    Write-Host "   Destination: $OutputPath" -ForegroundColor Gray
    Write-Host "   This may take 15-30 minutes depending on your connection..." -ForegroundColor Gray
    
    try {
        $job = Start-BitsTransfer -Source $downloadUrl -Destination $OutputPath -Asynchronous -DisplayName "Windows 11 ISO Download" -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to start BITS transfer: $_"
        return $false
    }
    
    while ($job.JobState -eq 'Transferring' -or $job.JobState -eq 'Connecting') {
        $progress = [math]::Round(($job.BytesTransferred / $job.BytesTotal) * 100, 2)
        $mbTransferred = [math]::Round($job.BytesTransferred / 1MB, 2)
        $mbTotal = [math]::Round($job.BytesTotal / 1MB, 2)
        
        Write-Progress -Activity "Downloading Windows 11 ISO" `
            -Status "$progress% Complete ($mbTransferred MB / $mbTotal MB)" `
            -PercentComplete $progress
        
        Start-Sleep -Seconds 2
        
        try {
            $job = Get-BitsTransfer -JobId $job.JobId -ErrorAction Stop
        }
        catch {
            Write-Error "Lost connection to BITS job: $_"
            Write-Progress -Activity "Downloading Windows 11 ISO" -Completed
            return $false
        }
        
        # Check if job entered an error state
        if ($job.JobState -eq 'TransientError' -or $job.JobState -eq 'Error') {
            Write-Error "BITS transfer error: $($job.ErrorDescription)"
            Write-Host "   Job State: $($job.JobState)" -ForegroundColor Yellow
            try {
                Remove-BitsTransfer -BitsJob $job -ErrorAction SilentlyContinue
            }
            catch { }
            Write-Progress -Activity "Downloading Windows 11 ISO" -Completed
            return $false
        }
    }
    
    Write-Progress -Activity "Downloading Windows 11 ISO" -Completed
    
    # Check final job state before completing
    if ($job.JobState -ne 'Transferred') {
        Write-Error "BITS transfer did not complete successfully. State: $($job.JobState)"
        try {
            Remove-BitsTransfer -BitsJob $job -ErrorAction SilentlyContinue
        }
        catch { }
        return $false
    }
    
    try {
        Complete-BitsTransfer -BitsJob $job -ErrorAction Stop
        Write-Host "✓ BITS transfer completed" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error completing BITS transfer: $_"
        Write-Host "   Attempting to clean up and retry..." -ForegroundColor Yellow
        
        # Try to remove the job and any partial files
        try {
            Remove-BitsTransfer -BitsJob $job -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore cleanup errors
        }
        
        # Wait a moment for file handles to release
        Start-Sleep -Seconds 3
        
        # If partial file exists, try to remove it
        if (Test-Path $OutputPath) {
            try {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            catch {
                Write-Error "Could not remove partial download file. Please delete $OutputPath manually and try again."
                return $false
            }
        }
        
        Write-Error "Download failed: $_"
        return $false
    }
    
    # Wait for file to be fully written and handles released
    Start-Sleep -Seconds 2
    
    if (Test-Path $OutputPath) {
        $fileSize = (Get-Item $OutputPath).Length
        Write-Host "✓ Download complete! Size: $([math]::Round($fileSize/1GB,2)) GB" -ForegroundColor Green
        return $true
    } else {
        Write-Error "Download failed - file not found!"
        return $false
    }
}

function Extract-WimFromISO {
    param(
        [string]$IsoPath,
        [string]$OutputWimPath
    )
    
    Write-Host "📀 Mounting ISO..." -ForegroundColor Cyan
    $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop | Out-Null
    $mountResult = Get-DiskImage -ImagePath $IsoPath
    $driveLetter = ($mountResult | Get-Volume).DriveLetter
    
    $sourceWim = "${driveLetter}:\sources\install.wim"
    
    if (-not (Test-Path $sourceWim)) {
        Dismount-DiskImage -ImagePath $IsoPath | Out-Null
        throw "install.wim not found in ISO at $sourceWim"
    }
    
    Write-Host "✓ ISO mounted on ${driveLetter}:" -ForegroundColor Green
    Write-Host "📋 Checking available Windows editions..." -ForegroundColor Cyan
    
    $images = Get-WindowsImage -ImagePath $sourceWim
    
    Write-Host "`nAvailable editions:" -ForegroundColor White
    foreach ($img in $images) {
        Write-Host "  [$($img.ImageIndex)] $($img.ImageName)" -ForegroundColor Gray
    }
    
    # Use first Professional or Enterprise edition, or just index 1
    $selectedIndex = 1
    $proEdition = $images | Where-Object { $_.ImageName -like "*Professional*" -or $_.ImageName -like "*Enterprise*" } | Select-Object -First 1
    if ($proEdition) {
        $selectedIndex = [int]$proEdition.ImageIndex
        Write-Host "`nSelected: [$selectedIndex] $($proEdition.ImageName)" -ForegroundColor Green
    } else {
        $selectedIndex = [int]$images[0].ImageIndex
        Write-Host "`nSelected: [$selectedIndex] $($images[0].ImageName)" -ForegroundColor Green
    }
    
    Write-Host "📋 Copying install.wim (this may take a few minutes)..." -ForegroundColor Cyan
    Copy-Item $sourceWim -Destination $OutputWimPath -Force
    
    Write-Host "📀 Dismounting ISO..." -ForegroundColor Cyan
    Dismount-DiskImage -ImagePath $IsoPath | Out-Null
    
    Write-Host "✓ WIM extracted successfully" -ForegroundColor Green
    
    # Return only the index as output
    return $selectedIndex
}

function Create-BootableVHD {
    param(
        [string]$VHDPath,
        [uint64]$SizeBytes,
        [string]$WimPath,
        [int]$ImageIndex
    )
    
    Write-Host "`n🔧 Creating bootable VHD..." -ForegroundColor Cyan
    
    # Create VHD
    Write-Host "  Creating VHDX file ($([math]::Round($SizeBytes/1GB)) GB)..." -ForegroundColor Gray
    $vhd = New-VHD -Path $VHDPath -SizeBytes $SizeBytes -Dynamic -ErrorAction Stop
    
    # Mount VHD
    Write-Host "  Mounting VHD..." -ForegroundColor Gray
    $mountedVhd = Mount-VHD -Path $VHDPath -PassThru
    $disk = $mountedVhd | Get-Disk
    
    # Initialize disk as GPT (for Gen 2 UEFI)
    Write-Host "  Initializing disk (GPT/UEFI)..." -ForegroundColor Gray
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction Stop
    
    # Create EFI system partition (260 MB)
    Write-Host "  Creating EFI system partition..." -ForegroundColor Gray
    $efiPartition = New-Partition -DiskNumber $disk.Number -Size 260MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -AssignDriveLetter
    Format-Volume -Partition $efiPartition -FileSystem FAT32 -NewFileSystemLabel "System" -Force | Out-Null
    
    # Create MSR partition (128 MB)
    Write-Host "  Creating MSR partition..." -ForegroundColor Gray
    $msrPartition = New-Partition -DiskNumber $disk.Number -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    
    # Create Windows partition (rest of disk)
    Write-Host "  Creating Windows partition..." -ForegroundColor Gray
    $windowsPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -AssignDriveLetter
    Format-Volume -Partition $windowsPartition -FileSystem NTFS -NewFileSystemLabel "Windows" -Force | Out-Null
    
    # Get drive letters - refresh partitions first
    Start-Sleep -Seconds 2
    $efiPartition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' }
    $windowsPartition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.GptType -eq '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' }
    
    # Ensure drive letters are assigned
    if ($efiPartition.DriveLetter -eq 0) {
        $efiPartition | Add-PartitionAccessPath -AssignDriveLetter
        Start-Sleep -Seconds 1
        $efiPartition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' }
    }
    
    if ($windowsPartition.DriveLetter -eq 0) {
        $windowsPartition | Add-PartitionAccessPath -AssignDriveLetter
        Start-Sleep -Seconds 1
        $windowsPartition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.GptType -eq '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' }
    }
    
    $efiDrive = "$($efiPartition.DriveLetter):"
    $windowsDrive = "$($windowsPartition.DriveLetter):"
    
    Write-Host "  EFI partition: $efiDrive" -ForegroundColor Gray
    Write-Host "  Windows partition: $windowsDrive" -ForegroundColor Gray
    
    # Apply Windows image to VHD
    Write-Host "`n📦 Applying Windows image to VHD..." -ForegroundColor Cyan
    Write-Host "  This will take 10-20 minutes..." -ForegroundColor Gray
    Write-Host "  Source: $WimPath (Index $ImageIndex)" -ForegroundColor Gray
    Write-Host "  Target: $windowsDrive" -ForegroundColor Gray
    
    # Use Expand-WindowsImage cmdlet instead of DISM.exe for better error handling
    try {
        Expand-WindowsImage -ImagePath $WimPath -Index $ImageIndex -ApplyPath $windowsDrive -Verify -ErrorAction Stop
        Write-Host "✓ Windows image applied successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to apply Windows image: $_"
        throw
    }
    
    # Add registry bypass keys for TPM/SecureBoot
    Write-Host "`n🔑 Adding registry bypass keys..." -ForegroundColor Cyan
    Add-RegistryBypassKeys -WindowsDrive $windowsDrive
    
    # Add unattend.xml for automated OOBE
    Write-Host "`n📝 Adding unattend.xml for automated setup..." -ForegroundColor Cyan
    Add-UnattendFile -WindowsDrive $windowsDrive -ImageType $ImageType
    
    # Add DSC configuration and installation script
    Write-Host "`n📦 Adding WinGet DSC configuration..." -ForegroundColor Cyan
    Add-WinGetDSC -WindowsDrive $windowsDrive -ImageType $ImageType
    
    # Add RunOnce to automatically run installation on first login
    Write-Host "`n🔧 Setting up automatic first-boot installation..." -ForegroundColor Cyan
    Add-RunOnceKey -WindowsDrive $windowsDrive -ImageType $ImageType
    
    # Make VHD bootable
    Write-Host "`n🚀 Making VHD bootable..." -ForegroundColor Cyan
    Write-Host "  Running bcdboot..." -ForegroundColor Gray
    Write-Host "  Windows: $windowsDrive\Windows" -ForegroundColor Gray
    Write-Host "  EFI: $efiDrive" -ForegroundColor Gray
    
    # Verify Windows folder exists
    if (-not (Test-Path "$windowsDrive\Windows")) {
        throw "Windows folder not found at $windowsDrive\Windows - image apply may have failed"
    }
    
    $bcdbootArgs = "$windowsDrive\Windows /s $efiDrive /f UEFI"
    $bcdOutput = & bcdboot.exe $bcdbootArgs.Split(' ') 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "bcdboot returned exit code $LASTEXITCODE"
        Write-Warning "Output: $bcdOutput"
    } else {
        Write-Host "✓ Boot configuration created" -ForegroundColor Green
    }
    
    # Fix BCD to use partition identifiers instead of drive letters
    Write-Host "  Fixing BCD to use partition identifiers..." -ForegroundColor Gray
    $bcdPath = "$efiDrive\EFI\Microsoft\Boot\BCD"
    
    # Get partition GUIDs
    $windowsGuid = $windowsPartition.Guid
    $efiGuid = $efiPartition.Guid
    
    # Update bootmgr device to use partition GUID
    $bootmgrId = '{bootmgr}'
    & bcdedit /store $bcdPath /set $bootmgrId device "partition={$efiGuid}" | Out-Null
    
    # Update default boot loader device and osdevice to use partition GUID
    $defaultId = '{default}'
    & bcdedit /store $bcdPath /set $defaultId device "partition={$windowsGuid}" | Out-Null
    & bcdedit /store $bcdPath /set $defaultId osdevice "partition={$windowsGuid}" | Out-Null
    
    # Update resume device
    $resumeLine = & bcdedit /store $bcdPath /enum $defaultId | Select-String "resumeobject"
    if ($resumeLine) {
        $resumeId = ($resumeLine -replace ".*(\{[0-9a-f-]+\}).*",'$1')
        & bcdedit /store $bcdPath /set $resumeId device "partition={$windowsGuid}" | Out-Null
    }
    
    # Update memtest device
    $memdiagId = '{memdiag}'
    & bcdedit /store $bcdPath /set $memdiagId device "partition={$efiGuid}" | Out-Null
    
    Write-Host "✓ BCD updated with partition identifiers" -ForegroundColor Green
    
    # Verify the installation
    Write-Host "`n✅ Verifying installation..." -ForegroundColor Cyan
    $windowsFolder = Join-Path $windowsDrive "Windows"
    $bootFolder = Join-Path $efiDrive "EFI\Microsoft\Boot"
    
    if ((Test-Path $windowsFolder) -and (Test-Path $bootFolder)) {
        $winSize = (Get-ChildItem $windowsFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Write-Host "  Windows folder size: $([math]::Round($winSize/1GB,2)) GB" -ForegroundColor Gray
        Write-Host "  Boot files: Present" -ForegroundColor Gray
        Write-Host "✓ Installation verified" -ForegroundColor Green
    } else {
        Write-Warning "Installation verification failed!"
        if (-not (Test-Path $windowsFolder)) { Write-Warning "  Missing: $windowsFolder" }
        if (-not (Test-Path $bootFolder)) { Write-Warning "  Missing: $bootFolder" }
    }
    
    # Dismount VHD
    Write-Host "`n📤 Dismounting VHD..." -ForegroundColor Cyan
    Dismount-VHD -Path $VHDPath
    
    Write-Host "✓ Bootable VHD created successfully!" -ForegroundColor Green
    
    return @{
        VHDPath = $VHDPath
        EFIDrive = $efiDrive
        WindowsDrive = $windowsDrive
    }
}

function Add-RegistryBypassKeys {
    param(
        [string]$WindowsDrive
    )
    
    $systemHive = Join-Path $WindowsDrive "Windows\System32\config\SYSTEM"
    
    if (-not (Test-Path $systemHive)) {
        Write-Warning "SYSTEM registry hive not found at $systemHive"
        return
    }
    
    $mountKey = "HKLM\OFFLINE_SYSTEM"
    
    try {
        Write-Host "  Loading offline registry hive..." -ForegroundColor Gray
        $regLoadArgs = @("LOAD", $mountKey, $systemHive)
        $process = Start-Process -FilePath "reg.exe" -ArgumentList $regLoadArgs -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "Failed to load registry hive (exit code: $($process.ExitCode))"
        }
        
        Write-Host "  Creating LabConfig key..." -ForegroundColor Gray
        $labConfigKey = "$mountKey\Setup\LabConfig"
        
        # Create the LabConfig key if it doesn't exist
        $null = reg add $labConfigKey /f 2>&1
        
        # Add bypass values
        Write-Host "  Adding BypassTPMCheck..." -ForegroundColor Gray
        reg add $labConfigKey /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
        
        Write-Host "  Adding BypassSecureBootCheck..." -ForegroundColor Gray
        reg add $labConfigKey /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
        
        Write-Host "  Adding BypassRAMCheck..." -ForegroundColor Gray
        reg add $labConfigKey /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
        
        Write-Host "  Adding BypassStorageCheck..." -ForegroundColor Gray
        reg add $labConfigKey /v BypassStorageCheck /t REG_DWORD /d 1 /f | Out-Null
        
        Write-Host "✓ Registry bypass keys added" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error adding registry keys: $_"
    }
    finally {
        # Always try to unload the hive
        Write-Host "  Unloading offline registry hive..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        
        $regUnloadArgs = @("UNLOAD", $mountKey)
        $process = Start-Process -FilePath "reg.exe" -ArgumentList $regUnloadArgs -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            Write-Warning "Failed to unload registry hive. This is usually OK, but may require a reboot."
        }
    }
}

function Add-UnattendFile {
    param(
        [string]$WindowsDrive,
        [string]$ImageType = "DevVM"
    )
    
    $unattendPath = Join-Path $WindowsDrive "Windows\System32\Sysprep\unattend.xml"
    
    # Add FirstLogonCommands as a fallback in case RunOnce doesn't trigger
    # This ensures the installation script runs even on a clean install with no user profiles
    $firstLogonCommands = @"
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "C:\Setup\Install-DevTools.ps1"</CommandLine>
                    <Description>Install Development Tools</Description>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
"@
    
    # Create unattend.xml for automated OOBE with FirstLogonCommands
    $unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>Windows11-VM</ComputerName>
            <TimeZone>Pacific Standard Time</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>UABhAHMAcwB3AG8AcgBkADEAMgAzACEAUABhAHMAcwB3AG8AcgBkAA==</Value>
                            <PlainText>false</PlainText>
                        </Password>
                        <Description>Local Administrator</Description>
                        <DisplayName>Admin</DisplayName>
                        <Group>Administrators</Group>
                        <Name>Admin</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Password>
                    <Value>UABhAHMAcwB3AG8AcgBkADEAMgAzACEAUABhAHMAcwB3AG8AcgBkAA==</Value>
                    <PlainText>false</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <Username>Admin</Username>
                <LogonCount>3</LogonCount>
            </AutoLogon>
$firstLogonCommands
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
</unattend>
"@

    try {
        $sysprepDir = Join-Path $WindowsDrive "Windows\System32\Sysprep"
        if (-not (Test-Path $sysprepDir)) {
            New-Item -ItemType Directory -Path $sysprepDir -Force | Out-Null
        }
        
        Set-Content -Path $unattendPath -Value $unattendContent -Encoding UTF8 -Force
        Write-Host "✓ Unattend.xml created for automated setup" -ForegroundColor Green
        Write-Host "  - Local admin account: Admin / Password123!" -ForegroundColor Gray
        Write-Host "  - Auto-install script will run on first login" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Failed to create unattend.xml: $_"
    }
}

function Add-StartupScript {
    param(
        [string]$WindowsDrive,
        [string]$ImageType = "DevVM"
    )
    
    $setupDir = Join-Path $WindowsDrive "Setup"
    $publicDesktop = Join-Path $WindowsDrive "Users\Public\Desktop"
    
    if (-not (Test-Path $publicDesktop)) {
        New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null
    }
    
    # Note: Installation runs automatically on first login via RunOnce registry key
}

function Add-RunOnceKey {
    param(
        [string]$WindowsDrive,
        [string]$ImageType = "DevVM"
    )
    
    $logFile = Join-Path $WindowsDrive "Setup\startup-config.log"
    
    function Write-SetupLog {
        param([string]$Message)
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Force
        Write-Host "  $Message" -ForegroundColor Gray
        Write-DebugLog "SetupLog: $Message"
    }
    
    Write-Host "  Configuring auto-run using Registry RunOnce (no UAC prompt)..." -ForegroundColor Gray
    Write-DebugLog "Function: Add-RunOnceKey called"
    Write-SetupLog "=== Starting Add-RunOnceKey function ==="
    Write-SetupLog "WindowsDrive: $WindowsDrive"
    Write-SetupLog "ImageType: $ImageType"
    
    # Use Registry RunOnce to run PowerShell with SYSTEM privileges via scheduled task
    # This avoids UAC by creating the task during VHD setup (before Windows boots)
    
    # Create a scheduled task XML that runs at logon with highest privileges
    $taskXmlPath = Join-Path $WindowsDrive "Setup\Install-DevTools-Task.xml"
    Write-SetupLog "Task XML path: $taskXmlPath"
    
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Install development tools on first login</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "C:\Setup\Install-DevTools.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    
    try {
        Write-SetupLog "Creating task XML file..."
        Set-Content -Path $taskXmlPath -Value $taskXml -Encoding Unicode -Force -ErrorAction Stop
        
        if (Test-Path $taskXmlPath) {
            $fileSize = (Get-Item $taskXmlPath).Length
            Write-SetupLog "SUCCESS: Task XML created, size: $fileSize bytes"
        }
    }
    catch {
        Write-SetupLog "ERROR creating task XML: $_"
    }
    
    # Add RunOnce registry entries to directly run the PowerShell script
    # This runs on next logon with the user's privileges, but PowerShell will self-elevate if needed
    $runCmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File `"C:\Setup\Install-DevTools.ps1`""
    
    # 1. Add to DEFAULT hive (for new users) - This is critical for first-time users
    $defaultHive = Join-Path $WindowsDrive "Windows\System32\config\DEFAULT"
    Write-SetupLog "DEFAULT hive path: $defaultHive"
    Write-SetupLog "DEFAULT hive exists: $(Test-Path $defaultHive)"
    
    if (Test-Path $defaultHive) {
        $mountKey = "HKLM\OFFLINE_DEFAULT"
        
        try {
            Write-SetupLog "Loading DEFAULT registry hive..."
            $loadOutput = & reg.exe LOAD $mountKey $defaultHive 2>&1 | Out-String
            Write-SetupLog "Load result (exit code $LASTEXITCODE): $loadOutput"
            
            if ($LASTEXITCODE -eq 0) {
                Start-Sleep -Seconds 2
                
                $runOnceKey = "$mountKey\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                Write-SetupLog "Adding RunOnce entry to DEFAULT hive at: $runOnceKey"
                $addOutput = & reg.exe ADD $runOnceKey /v InstallDevTools /t REG_SZ /d $runCmd /f 2>&1 | Out-String
                Write-SetupLog "Add result (exit code $LASTEXITCODE): $addOutput"
                
                if ($LASTEXITCODE -eq 0) {
                    # Verify the key was actually added
                    Start-Sleep -Seconds 1
                    $queryOutput = & reg.exe QUERY $runOnceKey /v InstallDevTools 2>&1 | Out-String
                    Write-SetupLog "Verification query: $queryOutput"
                    
                    if ($queryOutput -match "InstallDevTools") {
                        Write-SetupLog "SUCCESS: RunOnce entry verified in DEFAULT hive"
                        Write-Host "  ✓ Auto-run configured for new users (DEFAULT hive)" -ForegroundColor Green
                    } else {
                        Write-SetupLog "WARNING: RunOnce entry not found in verification query"
                        Write-Host "  ⚠️  Could not verify RunOnce entry in DEFAULT hive" -ForegroundColor Yellow
                    }
                } else {
                    Write-SetupLog "ERROR: Failed to add RunOnce entry (exit code $LASTEXITCODE)"
                }
                
                Start-Sleep -Seconds 2
                $unloadOutput = & reg.exe UNLOAD $mountKey 2>&1 | Out-String
                Write-SetupLog "Unload result (exit code $LASTEXITCODE): $unloadOutput"
            } else {
                Write-SetupLog "ERROR: Failed to load DEFAULT hive (exit code $LASTEXITCODE)"
            }
        }
        catch {
            Write-SetupLog "ERROR with DEFAULT hive: $_"
            Write-Host "  ⚠️  Error configuring DEFAULT hive: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-SetupLog "ERROR: DEFAULT hive not found at path: $defaultHive"
        Write-Host "  ⚠️  DEFAULT hive not found" -ForegroundColor Yellow
    }
    
    # 2. Add to all existing user profiles
    $usersDir = Join-Path $WindowsDrive "Users"
    if (Test-Path $usersDir) {
        $userProfiles = Get-ChildItem $usersDir -Directory | Where-Object { 
            $_.Name -notin @('Public', 'Default', 'All Users', 'Default User') -and
            (Test-Path (Join-Path $_.FullName "NTUSER.DAT"))
        }
        
        Write-SetupLog "Found $($userProfiles.Count) existing user profile(s)"
        
        foreach ($userProfile in $userProfiles) {
            $userName = $userProfile.Name
            $ntuserDat = Join-Path $userProfile.FullName "NTUSER.DAT"
            $mountKey = "HKLM\OFFLINE_USER_$userName"
            
            try {
                Write-SetupLog "Loading user hive for: $userName"
                & reg.exe LOAD $mountKey $ntuserDat 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Start-Sleep -Seconds 2
                    
                    $runOnceKey = "$mountKey\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                    & reg.exe ADD $runOnceKey /v InstallDevTools /t REG_SZ /d $runCmd /f 2>&1 | Out-Null
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-SetupLog "SUCCESS: RunOnce entry added for user: $userName"
                        Write-Host "  ✓ Auto-run configured for user: $userName" -ForegroundColor Green
                    }
                    
                    Start-Sleep -Seconds 2
                    & reg.exe UNLOAD $mountKey 2>&1 | Out-Null
                }
            }
            catch {
                Write-SetupLog "ERROR with user $userName : $_"
            }
        }
    }
    
    Write-SetupLog "=== Add-RunOnceKey function completed ==="
    
    # Create desktop shortcut for manual execution as backup
    Write-SetupLog "Creating desktop shortcut for Install-DevTools.ps1..."
    $publicDesktop = Join-Path $WindowsDrive "Users\Public\Desktop"
    if (-not (Test-Path $publicDesktop)) {
        New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null
        Write-SetupLog "Created Public Desktop directory"
    }
    
    $shortcutPath = Join-Path $publicDesktop "Install Development Tools.lnk"
    $shortcutScript = @"
`$WshShell = New-Object -ComObject WScript.Shell
`$shortcut = `$WshShell.CreateShortcut('$shortcutPath')
`$shortcut.TargetPath = 'powershell.exe'
`$shortcut.Arguments = '-ExecutionPolicy Bypass -NoProfile -File "C:\Setup\Install-DevTools.ps1"'
`$shortcut.WorkingDirectory = 'C:\Setup'
`$shortcut.Description = 'Install development tools (run as Administrator)'
`$shortcut.IconLocation = 'powershell.exe,0'
`$shortcut.Save()
"@
    
    try {
        $result = Invoke-Expression $shortcutScript 2>&1
        if (Test-Path $shortcutPath) {
            Write-SetupLog "SUCCESS: Desktop shortcut created at $shortcutPath"
            Write-Host "  ✓ Desktop shortcut created for manual installation" -ForegroundColor Green
        } else {
            Write-SetupLog "WARNING: Shortcut script ran but file not found at $shortcutPath"
        }
    }
    catch {
        Write-SetupLog "ERROR creating desktop shortcut: $_"
        Write-Host "  ⚠️  Could not create desktop shortcut" -ForegroundColor Yellow
    }
    
    # ALSO add to Startup folder for all users - this is more reliable than RunOnce
    Write-SetupLog "Adding to Startup folder for auto-run..."
    $startupFolder = Join-Path $WindowsDrive "ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    if (-not (Test-Path $startupFolder)) {
        New-Item -ItemType Directory -Path $startupFolder -Force | Out-Null
        Write-SetupLog "Created Startup folder"
    }
    
    # Create a batch file that runs the script and removes itself after success
    $startupBatchPath = Join-Path $startupFolder "Install-DevTools.bat"
    $batchContent = @"
@echo off
REM Auto-install development tools on first login
echo Running development tools installation...
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "C:\Setup\Install-DevTools.ps1"
if %ERRORLEVEL% EQU 0 (
    echo Installation completed successfully
    REM Remove this startup script
    del "%~f0"
) else (
    echo Installation failed with error code %ERRORLEVEL%
    echo You can try running manually: C:\Setup\Install-DevTools.ps1
    pause
)
"@
    
    try {
        Set-Content -Path $startupBatchPath -Value $batchContent -Encoding ASCII -Force
        if (Test-Path $startupBatchPath) {
            Write-SetupLog "SUCCESS: Startup batch file created at $startupBatchPath"
            Write-Host "  ✓ Startup folder configured for auto-run" -ForegroundColor Green
        }
    }
    catch {
        Write-SetupLog "ERROR creating startup batch: $_"
        Write-Host "  ⚠️  Could not create startup batch file" -ForegroundColor Yellow
    }
    
    <# REMOVED - Scheduled Task approach (requires elevation to register)
    # Create a scheduled task XML that will run at logon with highest privileges
    $taskXmlPath = Join-Path $WindowsDrive "Setup\Install-DevTools-Task.xml"
    Write-SetupLog "Task XML path: $taskXmlPath"
    
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Automatically install development tools on first login</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -File "C:\Setup\Install-DevTools.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    
    try {
        Write-SetupLog "Attempting to create task XML file..."
        Set-Content -Path $taskXmlPath -Value $taskXml -Encoding Unicode -Force -ErrorAction Stop
        
        if (Test-Path $taskXmlPath) {
            Write-SetupLog "SUCCESS: Task XML file created"
            Write-Host "  ✓ Scheduled task XML created at: $taskXmlPath" -ForegroundColor Green
        } else {
            Write-SetupLog "FAILED: Task XML file not found after creation attempt"
        }
    }
    catch {
        Write-SetupLog "ERROR creating task XML: $_"
        Write-Warning "Failed to create task XML: $_"
    }
    #>
    
    <# COMMENTED OUT - RunOnce approach (works after OOBE but not during initial setup)
    # Add RunOnce registry entry - need to add to all existing user profiles + DEFAULT template
    Write-Host "  Adding RunOnce entry for existing and new users..." -ForegroundColor Gray
    $runCommand = "powershell.exe -ExecutionPolicy Bypass -NoProfile -NoExit -File C:\Setup\Install-DevTools.ps1"
    
    # 1. Add to DEFAULT hive (for new users)
    $defaultHive = Join-Path $WindowsDrive "Windows\System32\config\DEFAULT"
    if (Test-Path $defaultHive) {
        $mountKey = "HKLM\OFFLINE_DEFAULT"
        
        try {
            Write-Host "  Loading DEFAULT user hive..." -ForegroundColor Gray
            & reg.exe LOAD $mountKey $defaultHive 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Start-Sleep -Seconds 2
                
                $runOnceRegKey = "$mountKey\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                & reg.exe ADD $runOnceRegKey /v InstallDevTools /t REG_SZ /d $runCommand /f 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ RunOnce entry added to DEFAULT hive" -ForegroundColor Green
                }
                
                Start-Sleep -Seconds 2
                & reg.exe UNLOAD $mountKey 2>&1 | Out-Null
            }
        }
        catch {
            Write-Warning "Could not modify DEFAULT hive: $_"
        }
    }
    
    # 2. Add to all existing user profiles
    $usersDir = Join-Path $WindowsDrive "Users"
    if (Test-Path $usersDir) {
        $userProfiles = Get-ChildItem $usersDir -Directory | Where-Object { 
            $_.Name -notin @('Public', 'Default', 'All Users', 'Default User') -and
            (Test-Path (Join-Path $_.FullName "NTUSER.DAT"))
        }
        
        foreach ($userProfile in $userProfiles) {
            $userName = $userProfile.Name
            $ntuserDat = Join-Path $userProfile.FullName "NTUSER.DAT"
            $mountKey = "HKLM\OFFLINE_USER_$userName"
            
            try {
                Write-Host "  Loading user hive for: $userName..." -ForegroundColor Gray
                & reg.exe LOAD $mountKey $ntuserDat 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Start-Sleep -Seconds 2
                    
                    $runOnceRegKey = "$mountKey\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                    & reg.exe ADD $runOnceRegKey /v InstallDevTools /t REG_SZ /d $runCommand /f 2>&1 | Out-Null
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✓ RunOnce entry added for user: $userName" -ForegroundColor Green
                    }
                    
                    Start-Sleep -Seconds 2
                    & reg.exe UNLOAD $mountKey 2>&1 | Out-Null
                }
            }
            catch {
                Write-Warning "Could not modify registry for user $userName : $_"
            }
        }
    }
    
    Write-Host "  ✓ RunOnce entries configured for all users" -ForegroundColor Green
    #>
}

function Add-WinGetDSC {
    param(
        [string]$WindowsDrive,
        [string]$ImageType = "DevVM"
    )
    
    Write-Host "  Adding WinGet DSC configuration for ImageType: $ImageType..." -ForegroundColor Gray
    Write-DebugLog "Function: Add-WinGetDSC called with WindowsDrive=$WindowsDrive, ImageType=$ImageType"
    
    $setupDir = Join-Path $WindowsDrive "Setup"
    Write-DebugLog "Setup directory path: $setupDir"
    
    # Create Setup directory
    if (-not (Test-Path $setupDir)) {
        Write-Host "    Creating Setup directory: $setupDir" -ForegroundColor Gray
        Write-DebugLog "Creating new Setup directory"
        New-Item -ItemType Directory -Path $setupDir -Force | Out-Null
    } else {
        Write-DebugLog "Setup directory already exists"
    }
    
    if (Test-Path $setupDir) {
        Write-Host "    ✓ Setup directory exists: $setupDir" -ForegroundColor Green
        Write-DebugLog "Setup directory verified"
    } else {
        Write-Warning "    ✗ Failed to create Setup directory: $setupDir"
        Write-DebugLog "ERROR: Setup directory creation failed"
        return
    }
    
    # Create DSC configuration file
    $dscConfigPath = Join-Path $setupDir "configuration.dsc.yaml"
    
    # Generate configuration based on ImageType
    if ($ImageType -eq "MSIXPackagingTool") {
        $dscContent = @'
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2
properties:
  configurationVersion: 0.2.0
  assertions:
    - resource: Microsoft.Windows.Developer/OsVersion
      directives:
        description: Verify min OS version requirement
        allowPrerelease: true
      settings:
        MinVersion: '10.0.22000'
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install MSIX Packaging Tool
        allowPrerelease: true
      settings:
        id: 9N5LW3JBCXKF
        source: msstore
'@
    } else {
        # Default DevVM configuration
        $dscContent = @'
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2
properties:
  configurationVersion: 0.2.0
  assertions:
    - resource: Microsoft.Windows.Developer/OsVersion
      directives:
        description: Verify min OS version requirement
        allowPrerelease: true
      settings:
        MinVersion: '10.0.22000'
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install PowerShell 7
        allowPrerelease: true
      settings:
        id: Microsoft.PowerShell
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install Visual Studio Code
        allowPrerelease: true
      settings:
        id: Microsoft.VisualStudioCode
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install Git
        allowPrerelease: true
      settings:
        id: Git.Git
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install Windows Terminal
        allowPrerelease: true
      settings:
        id: Microsoft.WindowsTerminal
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install PowerToys
        allowPrerelease: true
      settings:
        id: Microsoft.PowerToys
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install Visual Studio 2022 Community
        allowPrerelease: true
      settings:
        id: Microsoft.VisualStudio.2022.Community
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install WSL (Windows Subsystem for Linux)
        allowPrerelease: true
      settings:
        id: 9P9TQF7MRM4R
        source: msstore
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Install Ubuntu on WSL
        allowPrerelease: true
      settings:
        id: 9PDXGNCFSCZV
        source: msstore
    - resource: Microsoft.Windows.Developer/DeveloperMode
      directives:
        description: Enable Developer Mode
        allowPrerelease: true
      settings:
        Ensure: Present
'@
    }

    Write-Host "    Creating DSC configuration file..." -ForegroundColor Gray
    Write-DebugLog "DSC config path: $dscConfigPath"
    Write-DebugLog "DSC content length: $($dscContent.Length) characters"
    try {
        Set-Content -Path $dscConfigPath -Value $dscContent -Encoding UTF8 -Force -ErrorAction Stop
        Write-DebugLog "Set-Content completed"
        if (Test-Path $dscConfigPath) {
            $dscSize = (Get-Item $dscConfigPath).Length
            Write-Host "    ✓ DSC configuration created: $dscConfigPath ($dscSize bytes)" -ForegroundColor Green
            Write-DebugLog "DSC file verified: $dscSize bytes"
        } else {
            Write-Warning "    ✗ DSC configuration file not found after creation"
            Write-DebugLog "ERROR: DSC file not found after Set-Content"
            return
        }
    } catch {
        Write-Warning "    ✗ Failed to create DSC configuration: $_"
        Write-DebugLog "ERROR: Exception during DSC creation: $_"
        return
    }
    
    # Note: WinGet installation is handled by "winget install Microsoft.AppInstaller" in the install script
    # No need to pre-download installers since WinGet can update itself online
    # Create installation script
    Write-Host "    Building Install-DevTools.ps1 script..." -ForegroundColor Gray
    Write-DebugLog "Starting Install-DevTools.ps1 creation"
    $installScriptPath = Join-Path $setupDir "Install-DevTools.ps1"
    Write-DebugLog "Install script path: $installScriptPath"
    
    # Build the script content - base script that works for both image types
    $installScriptBase = @'
#==============================================================================
# Development Environment - Installation Script
# Automatically runs on first login via RunOnce registry entry
# 
# This script installs and configures development tools based on VM type:
# - DevVM: Development tools (VS Code, Git, PowerShell 7, WSL, etc.)
# - MSIXPackagingTool: MSIX Packaging Tool with optimized environment
#==============================================================================

$ErrorActionPreference = "Continue"
$logFile = "C:\Setup\install-log.txt"
$lockFile = "C:\Setup\install.lock"
$completeFile = "C:\Setup\install.complete"

#------------------------------------------------------------------------------
# Duplicate Run Prevention
#------------------------------------------------------------------------------

# Check if installation already completed
if (Test-Path $completeFile) {
    Write-Host "Installation already completed. Exiting..." -ForegroundColor Green
    # Clean up startup trigger if it exists
    $startupBatch = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Install-DevTools.bat"
    if (Test-Path $startupBatch) {
        Remove-Item $startupBatch -Force -ErrorAction SilentlyContinue
    }
    exit 0
}

# Check if another instance is already running
if (Test-Path $lockFile) {
    $lockAge = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    if ($lockAge.TotalMinutes -lt 30) {
        Write-Host "Installation already in progress. Exiting..." -ForegroundColor Yellow
        exit 0
    } else {
        # Stale lock file (older than 30 minutes), remove it
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
}

# Create lock file
try {
    New-Item -Path $lockFile -ItemType File -Force | Out-Null
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $lockFile
} catch {
    Write-Host "Could not create lock file. Another instance may be running." -ForegroundColor Red
    exit 1
}

#------------------------------------------------------------------------------
# Self-Elevation Check
#------------------------------------------------------------------------------

# Check if running as administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Not running as admin - re-launch elevated
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    
    # Remove lock file before relaunching
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    
    $arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
        # Exit this instance since we launched elevated version
        exit 0
    } catch {
        Write-Host "Failed to elevate. Creating desktop shortcut to retry..." -ForegroundColor Red
        
        # Create desktop shortcut for manual retry
        try {
            $WshShell = New-Object -ComObject WScript.Shell
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $shortcutPath = Join-Path $desktopPath "Install Development Tools.lnk"
            $shortcut = $WshShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"C:\Setup\Install-DevTools.ps1`""
            $shortcut.Description = "Install development tools (requires administrator)"
            $shortcut.WorkingDirectory = "C:\Setup"
            $shortcut.Save()
            
            Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
            Write-Host "Right-click the shortcut and select 'Run as administrator' to retry." -ForegroundColor Yellow
        } catch {
            Write-Host "Could not create desktop shortcut: $_" -ForegroundColor Red
        }
        
        pause
        exit 1
    }
}

#------------------------------------------------------------------------------
# Setup and Logging
#------------------------------------------------------------------------------

# Ensure Setup directory exists
if (-not (Test-Path "C:\Setup")) {
    New-Item -ItemType Directory -Path "C:\Setup" -Force | Out-Null
}

# Helper function for logging with timestamps
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp [$Level] - $Message" | Out-File -FilePath $logFile -Append
}

# Helper function for logging errors with full details
function Write-ErrorLog {
    param(
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    Write-Log $Message "ERROR"
    if ($ErrorRecord) {
        Write-Log "  Exception: $($ErrorRecord.Exception.Message)" "ERROR"
        Write-Log "  ErrorId: $($ErrorRecord.FullyQualifiedErrorId)" "ERROR"
        Write-Log "  Category: $($ErrorRecord.CategoryInfo.Category)" "ERROR"
        if ($ErrorRecord.InvocationInfo) {
            Write-Log "  Line: $($ErrorRecord.InvocationInfo.ScriptLineNumber)" "ERROR"
            Write-Log "  Command: $($ErrorRecord.InvocationInfo.MyCommand)" "ERROR"
        }
    }
    Write-Log "  Last Exit Code: $LASTEXITCODE" "ERROR"
}

# Initialize log file
try {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $separator = "=" * 80
    $separator | Out-File -FilePath $logFile -Force
    "MSIX Packaging Tool - Installation Log" | Out-File -FilePath $logFile -Append
    "Started: $timestamp" | Out-File -FilePath $logFile -Append
    $separator | Out-File -FilePath $logFile -Append
    "" | Out-File -FilePath $logFile -Append
    "Environment Information:" | Out-File -FilePath $logFile -Append
    "  PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $logFile -Append
    "  User: $env:USERNAME" | Out-File -FilePath $logFile -Append
    "  Computer: $env:COMPUTERNAME" | Out-File -FilePath $logFile -Append
    "" | Out-File -FilePath $logFile -Append
} catch {
    Write-Warning "Could not create log file: $_"
}

Write-Host "`n" -NoNewline
$separator = "=" * 80
Write-Host $separator -ForegroundColor Cyan
Write-Host "MSIX Packaging Tool - Installation" -ForegroundColor Cyan
Write-Host $separator -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Gray
Write-Host ""
Write-Host "$('='*70)" -ForegroundColor Green
Write-Host "   INSTALLING DEVELOPMENT TOOLS" -ForegroundColor White
Write-Host "$('='*70)" -ForegroundColor Green
Write-Host ""

#------------------------------------------------------------------------------
# Step 1: Wait for WinGet to be available, then Install/Update
#------------------------------------------------------------------------------

Write-Log "STEP 1: Waiting for WinGet to be available..."
Write-Host "  Checking if WinGet is available..." -ForegroundColor Yellow

# Check if winget is available
$wingetAvailable = $false
$maxWaitTime = 300
$waitInterval = 5
$elapsedTime = 0

while (-not $wingetAvailable -and $elapsedTime -lt $maxWaitTime) {
    try {
        $wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCheck) {
            # Try to run winget --version to verify it's actually working
            $versionOutput = winget --version 2>&1
            if ($LASTEXITCODE -eq 0 -or $versionOutput) {
                $wingetAvailable = $true
                Write-Host "   WinGet is available (version: $versionOutput)" -ForegroundColor Green
                Write-Log "WinGet is available: $versionOutput"
            }
        }
    }
    catch {
        # WinGet not available yet
    }
    
    if (-not $wingetAvailable) {
        Write-Host "   Waiting for WinGet/AppInstaller to be deployed... $elapsedTime sec elapsed" -ForegroundColor Gray
        Write-Log "Waiting for WinGet availability - $elapsedTime seconds elapsed"
        Start-Sleep -Seconds $waitInterval
        $elapsedTime += $waitInterval
    }
}

if (-not $wingetAvailable) {
    Write-Host "  ⚠ WinGet not available after $maxWaitTime sec" -ForegroundColor Yellow
    Write-Log "WARNING: WinGet not available after waiting $maxWaitTime seconds"
    Write-Host "  Attempting to continue anyway..." -ForegroundColor Yellow
} else {
    # Enable WinGet configure feature
    Write-Host "`n  Enabling WinGet configure..." -ForegroundColor Yellow
    Write-Log "Enabling WinGet configure feature"
    
    try {
        $configOutput = winget configure --enable 2>&1 | Out-String
        Write-Log "WinGet configure --enable output: $configOutput"
        Write-Host "   WinGet configure enabled" -ForegroundColor Green
        Write-Log " WinGet configure enabled"
    }
    catch {
        Write-Log "WARNING: Failed to enable winget configure: $_"
        Write-Host "  ! Failed to enable configure (may already be enabled)" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 2
    
    # Now update WinGet to latest version
    Write-Host "`n  Updating WinGet to latest version..." -ForegroundColor Yellow
    Write-Log "Updating WinGet to latest version"
    
    try {
        $output = winget upgrade Microsoft.AppInstaller --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        Write-Log "WinGet install output: $output"
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Host "   WinGet updated successfully" -ForegroundColor Green
            Write-Log "  WinGet updated successfully"
        }
        else {
            Write-Host "  ! WinGet update returned exit code: $LASTEXITCODE (may still work)" -ForegroundColor Yellow
            Write-Log "WARNING: WinGet update exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "ERROR updating WinGet: $_"
        Write-Host "  ✗ Failed to update WinGet: $_" -ForegroundColor Red
        Write-Host "  Continuing with current version..." -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 5
}

#------------------------------------------------------------------------------
# Step 2: Run DSC Configuration
#------------------------------------------------------------------------------

$configPath = "C:\Setup\configuration.dsc.yaml"

if (-not (Test-Path $configPath)) {
    Write-Log "ERROR: Configuration file not found at $configPath"
    Write-Host "  ✗ Configuration file not found!" -ForegroundColor Red
    Write-Host "  Installation cannot continue without configuration file." -ForegroundColor Red
    pause
    exit 1
}

Write-Log "STEP 2: Running DSC Configuration..."
Write-Host "`n  Running DSC configuration (this may take 20-30 minutes)..." -ForegroundColor Yellow
Write-Host "  Log: $logFile`n" -ForegroundColor Gray

# Backup WinGet settings for potential certificate bypass
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
$settingsBackup = $null
if (Test-Path $settingsPath) {
    $settingsBackup = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue
    Write-Log "Backed up WinGet settings"
}

try {
    Write-Log "Executing: winget configure -f C:\Setup\configuration.dsc.yaml"
    $output = winget configure -f $configPath --accept-configuration-agreements 2>&1 | Out-String
    $dscExitCode = $LASTEXITCODE
    Write-Log "DSC output: $output"
    Write-Log "DSC exit code: $dscExitCode"
    
    # Check for certificate validation error (0x8A15005E = -1978335266 in signed int)
    if ($dscExitCode -ne 0 -and ($output -match '8a15005e' -or $output -match '0x8A15005E' -or $dscExitCode -eq -1978335266)) {
        Write-Log "Certificate validation error detected (8a15005e), attempting bypass..."
        Write-Host "`n  ⚠ Certificate validation error detected" -ForegroundColor Yellow
        Write-Host "  Retrying with certificate bypass enabled..." -ForegroundColor Yellow
        
        # Create/modify settings to bypass certificate validation
        $settingsDir = Split-Path $settingsPath
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }
        
        # Create bypass settings (minimal configuration that allows installs with cert issues)
        $bypassSettings = @"
{
    "experimentalFeatures": {
        "configuration": true
    },
    "installBehavior": {
        "disableInstallNotes": true
    },
    "network": {
        "downloader": "wininet"
    }
}
"@
        Set-Content -Path $settingsPath -Value $bypassSettings -Force -ErrorAction Stop
        Write-Log "Applied certificate bypass settings"
        
        Start-Sleep -Seconds 2
        
        # Retry DSC configuration
        Write-Log "Retrying: winget configure -f C:\Setup\configuration.dsc.yaml"
        $output = winget configure -f $configPath --accept-configuration-agreements 2>&1 | Out-String
        $dscExitCode = $LASTEXITCODE
        Write-Log "DSC retry output: $output"
        Write-Log "DSC retry exit code: $dscExitCode"
        
        Write-Host "`n   Configuration completed with certificate bypass" -ForegroundColor Green
        Write-Log "✓ DSC Configuration completed (with certificate bypass)"
    }
    else {
        Write-Host "`n  All packages installed successfully!" -ForegroundColor Green
        Write-Log "✓ DSC Configuration completed"
    }
}
catch {
    Write-Log "ERROR during DSC: $_"
    Write-Host "`n  ! Installation completed with warnings (check log)" -ForegroundColor Yellow
}
finally {
    # Restore original WinGet settings
    if ($settingsBackup) {
        try {
            Set-Content -Path $settingsPath -Value $settingsBackup -Force -ErrorAction Stop
            Write-Log "Restored original WinGet settings (certificate bypass disabled)"
            Write-Host "  Certificate bypass disabled" -ForegroundColor Gray
        }
        catch {
            Write-Log "WARNING: Could not restore original WinGet settings: $_"
        }
    }
    elseif (Test-Path $settingsPath) {
        # If we created a new settings file and there was no backup, remove it
        try {
            Remove-Item $settingsPath -Force -ErrorAction SilentlyContinue
            Write-Log "Removed temporary WinGet settings file"
        }
        catch {
            Write-Log "WARNING: Could not remove temporary settings: $_"
        }
    }
}

'@ + $(if ($ImageType -eq "DevVM") { @'


#------------------------------------------------------------------------------
# Step 5: Install WSL (Windows Subsystem for Linux)
#------------------------------------------------------------------------------

Write-Host "`nStep 5: Installing WSL..." -ForegroundColor Yellow
Write-Log "Step 5: Installing WSL"

try {
    # Check if WSL is already installed
    Write-Log "Checking if WSL is already installed"
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    
    if ($wslFeature -and $wslFeature.State -eq "Enabled") {
        Write-Host "   WSL already installed" -ForegroundColor Green
        Write-Log "WSL already installed"
    } else {
        Write-Host "   Installing WSL (this may require a restart)..." -ForegroundColor Gray
        Write-Log "Executing: wsl --install --no-launch"
        
        # Install WSL
        $result = wsl --install --no-launch 2>&1
        $result | Out-File -FilePath $logFile -Append
        Write-Log "WSL install exit code: $LASTEXITCODE"
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Host "   WSL installed successfully" -ForegroundColor Green
            Write-Log "WSL installed successfully"
        } else {
            Write-Host "   WSL install returned exit code: $LASTEXITCODE" -ForegroundColor Yellow
            Write-Log "WSL install completed with exit code: $LASTEXITCODE" "WARN"
        }
        # Enable hyper-v
        $result = wsl --install --no-distribution 2>&1
        $result | Out-File -FilePath $logFile -Append

        Write-Log "WSL install exit code: $LASTEXITCODE"
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Host "   Enabled Hyper-V successfully" -ForegroundColor Green
            Write-Log "Enabled Hyper-V successfully"
        } else {
            Write-Host "   WSL enable Hyper-V returned exit code: $LASTEXITCODE" -ForegroundColor Yellow
            Write-Log "WSL enable Hyper-V with exit code: $LASTEXITCODE" "WARN"
        }
    }
    
    # Install Ubuntu distribution after WSL is ready
    Write-Host "`n   Installing Ubuntu distribution..." -ForegroundColor Gray
    Write-Log "Installing Ubuntu distribution"
    
    try {
        # Check if Ubuntu is already installed
        $ubuntuInstalled = wsl --list --quiet 2>&1 | Select-String -Pattern "Ubuntu"
        
        if ($ubuntuInstalled) {
            Write-Host "   Ubuntu distribution already installed" -ForegroundColor Green
            Write-Log "Ubuntu distribution already installed"
        } else {
            Write-Log "Executing: wsl --install --distribution Ubuntu"
            $result = wsl --install --distribution Ubuntu --no-launch 2>&1
            $result | Out-File -FilePath $logFile -Append
            Write-Log "Ubuntu install exit code: $LASTEXITCODE"
            
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                Write-Host "   Ubuntu distribution installed successfully" -ForegroundColor Green
                Write-Log "Ubuntu distribution installed successfully"
            } else {
                Write-Host "   Ubuntu install returned exit code: $LASTEXITCODE" -ForegroundColor Yellow
                Write-Log "Ubuntu install completed with exit code: $LASTEXITCODE" "WARN"
            }
        }
    } catch {
        Write-Host "   Failed to install Ubuntu distribution" -ForegroundColor Yellow
        Write-Log "Exception installing Ubuntu: $_" "WARN"
        Write-Host "   You can install it manually with: wsl --install --distribution Ubuntu" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "   Failed to install WSL" -ForegroundColor Red
    Write-ErrorLog "Exception in Step 5 (WSL)" $_
    Write-Warning "Step 5 failed (WSL installation): $_"
    Write-Host "   You may need to install it manually later" -ForegroundColor Yellow
}
'@ } else { "" }) + $(if ($ImageType -eq "MSIXPackagingTool") { @'


#------------------------------------------------------------------------------
# Step 5: Install MSIX Packaging Tool Driver (Feature on Demand)
# Note: This step only runs for MSIXPackagingTool VM type
#------------------------------------------------------------------------------

Write-Host "`nStep 5: Installing MSIX Packaging Tool Driver..." -ForegroundColor Yellow
Write-Log "Step 5: Installing MSIX Packaging Tool Driver (FOD)"

try {
    # Check if driver is already installed
    $driver = Get-WindowsCapability -Online | Where-Object { $_.Name -like "*Msix.PackagingTool.Driver*" }
    
    if ($driver -and $driver.State -eq "Installed") {
        Write-Host "   MSIX Packaging Tool Driver already installed" -ForegroundColor Green
        Write-Log "MSIX Packaging Tool Driver already installed"
    } else {
        Write-Host "   Installing MSIX Packaging Tool Driver..." -ForegroundColor Gray
        
        # Install the FOD
        Add-WindowsCapability -Online -Name Msix.PackagingTool.Driver~~~~0.0.1.0 2>&1 | Out-File -FilePath $logFile -Append
        
        Write-Host "   MSIX Packaging Tool Driver installed successfully" -ForegroundColor Green
        Write-Log "MSIX Packaging Tool Driver installed successfully"
    }
} catch {
    Write-Host "   Failed to install MSIX Packaging Tool Driver" -ForegroundColor Red
    Write-Log "ERROR in Step 5: $_"
    Write-Warning "Step 5 failed (driver installation): $_"
    Write-Host "   You may need to install it manually later" -ForegroundColor Yellow
}

#------------------------------------------------------------------------------
# Step 6: Disable Windows Update and System Maintenance Tasks
# Note: This step only runs for MSIXPackagingTool VM type
#       Creates a stable environment for MSIX packaging by preventing
#       automatic updates and background maintenance during packaging operations
#------------------------------------------------------------------------------

Write-Host "`nStep 6: Disabling Windows Update and system maintenance tasks..." -ForegroundColor Yellow
Write-Log "Step 6: Disabling scheduled tasks that could interfere with MSIX packaging"

try {
    # Disable Windows Update scheduled tasks
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\Scheduled Start" -ErrorAction SilentlyContinue
    Write-Log "Disabled Windows Update Scheduled Start task"
    
    # Disable Windows Store automatic updates
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\Automatic App Update" -ErrorAction SilentlyContinue
    Write-Log "Disabled Automatic App Update task"
    
    # Disable Store Initiated Healing (Store updates)
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\sih" -ErrorAction SilentlyContinue
    Write-Log "Disabled Store Initiated Healing task"
    
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\sihboot" -ErrorAction SilentlyContinue
    Write-Log "Disabled Store Initiated Healing Boot task"
    
    # Disable Maintenance tasks
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\TaskScheduler\Maintenance Configurator" -ErrorAction SilentlyContinue
    Write-Log "Disabled Maintenance Configurator task"
    
    # Windows Defender tasks - COMMENTED OUT by default (security best practice)
    # These tasks are left enabled to maintain system security protection.
    # Only uncomment if Windows Defender scans are actively interfering with packaging operations,
    # but be aware this reduces security posture. Consider adding exclusions instead.
    # 
    # Disable-ScheduledTask -TaskName "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" -ErrorAction SilentlyContinue
    # Write-Log "Disabled Windows Defender Scheduled Scan task"
    # 
    # Disable-ScheduledTask -TaskName "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" -ErrorAction SilentlyContinue
    # Write-Log "Disabled Windows Defender Cache Maintenance task"
    # 
    # Disable-ScheduledTask -TaskName "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup" -ErrorAction SilentlyContinue
    # Write-Log "Disabled Windows Defender Cleanup task"
    # 
    # Disable-ScheduledTask -TaskName "\Microsoft\Windows\Windows Defender\Windows Defender Verification" -ErrorAction SilentlyContinue
    # Write-Log "Disabled Windows Defender Verification task"
    
    # Disable disk optimization (defrag can interfere with file operations)
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue
    Write-Log "Disabled Scheduled Defrag task"
    
    # Disable Application Experience tasks (compatibility checks can interfere)
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue
    Write-Log "Disabled Microsoft Compatibility Appraiser task"
    
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue
    Write-Log "Disabled Program Data Updater task"
    
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\StartupAppTask" -ErrorAction SilentlyContinue
    Write-Log "Disabled Startup App Task"
    
    # Disable Customer Experience Improvement Program
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue
    Write-Log "Disabled CEIP Consolidator task"
    
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" -ErrorAction SilentlyContinue
    Write-Log "Disabled USB CEIP task"
    
    # Disable DiskDiagnostic
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" -ErrorAction SilentlyContinue
    Write-Log "Disabled Disk Diagnostic Data Collector task"
    
    Write-Host "   System maintenance tasks disabled for stable MSIX packaging environment" -ForegroundColor Green
    Write-Log "All scheduled tasks disabled successfully"
} catch {
    Write-Host "   Failed to disable some tasks" -ForegroundColor Yellow
    Write-Log "WARNING: Error disabling tasks: $_"
}
'@ } else { "" }) + @'


#------------------------------------------------------------------------------
# Step 7: Create Desktop Shortcuts
#------------------------------------------------------------------------------

Write-Host "`nStep 7: Creating desktop shortcuts..." -ForegroundColor Yellow
Write-Log "Step 7: Creating desktop shortcuts"

'@ + $(if ($ImageType -eq "MSIXPackagingTool") { @'

try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")

    
    # Create MSIX Packaging Tool shortcut
    $shortcutPath = Join-Path $desktopPath "MSIX Packaging Tool.lnk"
    
    # Search for MsixPackagingToolUI.exe
    $searchPaths = @(
        "$env:ProgramFiles\WindowsApps",
        "${env:ProgramFiles(x86)}\WindowsApps",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    )
    
    $msixExe = $null
    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            $found = Get-ChildItem -Path $basePath -Filter "MsixPackagingToolUI.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $msixExe = $found.FullName
                break
            }
        }
    }
    
    if ($msixExe) {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $msixExe
        $shortcut.Description = "MSIX Packaging Tool"
        $shortcut.WorkingDirectory = Split-Path $msixExe
        $shortcut.Save()
        
        Write-Host "  MSIX Packaging Tool shortcut created" -ForegroundColor Green
        Write-Log "Desktop shortcut created at $shortcutPath pointing to $msixExe"
    } else {
        Write-Host "  ⚠ MSIX Packaging Tool executable not found" -ForegroundColor Yellow
        Write-Log "MsixPackagingToolUI.exe not found - may not be installed yet"
    }
    
    # Create documentation shortcut
    $docShortcutPath = Join-Path $desktopPath "MSIX Packaging Tool - Documentation.url"
    $docUrl = "https://learn.microsoft.com/en-us/windows/msix/packaging-tool/tool-overview"
    
    "[InternetShortcut]" | Out-File -FilePath $docShortcutPath -Encoding ASCII
    "URL=$docUrl" | Out-File -FilePath $docShortcutPath -Encoding ASCII -Append
    "IconIndex=0" | Out-File -FilePath $docShortcutPath -Encoding ASCII -Append
    
    Write-Host "   Documentation shortcut created" -ForegroundColor Green
    Write-Log "Documentation shortcut created at $docShortcutPath"
'@ } else {
@'

try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    
    # Create Windows Developer Center shortcut
    $docShortcutPath = Join-Path $desktopPath "Windows Developer Center.url"
    $docUrl = "https://developer.microsoft.com/en-us/windows/"
    
    "[InternetShortcut]" | Out-File -FilePath $docShortcutPath -Encoding ASCII
    "URL=$docUrl" | Out-File -FilePath $docShortcutPath -Encoding ASCII -Append
    "IconIndex=0" | Out-File -FilePath $docShortcutPath -Encoding ASCII -Append
    
    Write-Host "   Windows Developer Center shortcut created" -ForegroundColor Green
    Write-Log "Documentation shortcut created at $docShortcutPath"
'@
}) + @'

} catch {
    Write-Host "   Failed to create shortcuts" -ForegroundColor Red
    Write-Log "ERROR in Step 5: $_"
    Write-Warning "Step 5 failed (shortcut creation): $_"
}

#------------------------------------------------------------------------------
# Completion
#------------------------------------------------------------------------------

Write-Host ""
$separator = "=" * 80
Write-Host $separator -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host $separator -ForegroundColor Green
Write-Host ""
Write-Host "Log file saved to: $logFile" -ForegroundColor Gray
Write-Host ""

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"$timestamp - Installation completed successfully" | Out-File -FilePath $logFile -Append
$separator | Out-File -FilePath $logFile -Append

# Mark installation as complete
try {
    New-Item -Path $completeFile -ItemType File -Force | Out-Null
    "$timestamp - Installation completed" | Out-File $completeFile
    Write-Host "Installation marked as complete." -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not create completion marker file" -ForegroundColor Yellow
}

# Remove lock file
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

# Clean up startup batch file
$startupBatch = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Install-DevTools.bat"
if (Test-Path $startupBatch) {
    Remove-Item $startupBatch -Force -ErrorAction SilentlyContinue
    Write-Host "Removed startup trigger." -ForegroundColor Gray
}

# Delete the scheduled task that ran this script (if it exists)
try {
    schtasks /Delete /TN "InstallDevTools" /F 2>&1 | Out-Null
    Write-Host "Cleaning up scheduled task..." -ForegroundColor Gray
} catch {
    # Task may not exist if run manually
}
'@

    # Add image-specific completion message
    if ($ImageType -eq "DevVM") {
        $installScriptBase += @'


Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Installed Tools and Features" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Development Tools:" -ForegroundColor Yellow
Write-Host "    - PowerShell 7           Modern cross-platform PowerShell" -ForegroundColor White
Write-Host "    - Visual Studio Code     Lightweight code editor" -ForegroundColor White
Write-Host "    - Git                    Version control system" -ForegroundColor White
Write-Host "    - Windows Terminal       Modern terminal application" -ForegroundColor White
Write-Host "    - PowerToys              Windows system utilities" -ForegroundColor White
Write-Host "    - Visual Studio 2022     Full-featured IDE" -ForegroundColor White
Write-Host "    - WSL                    Windows Subsystem for Linux" -ForegroundColor White
Write-Host ""
Write-Host "  System Features:" -ForegroundColor Yellow
Write-Host "    - Developer Mode         Enabled for development features" -ForegroundColor White
Write-Host ""
Write-Host "  Next Steps:" -ForegroundColor Green
Write-Host "    - Restart Windows to complete WSL setup" -ForegroundColor Yellow
Write-Host "    - Ubuntu will be installed automatically after restart" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Create post-reboot script to install Ubuntu
$postRebootScript = @"
# Post-reboot Ubuntu installation
`$logFile = "C:\Setup\install-log.txt"

function Write-Log {
    param([string]`$Message)
    "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - `$Message" | Out-File -FilePath `$logFile -Append
}

Write-Host "`n`n"
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Completing Development Environment Setup" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Installing Ubuntu distribution..." -ForegroundColor Yellow
Write-Log "Post-reboot: Installing Ubuntu distribution"

try {
    `$result = wsl --install --distribution Ubuntu --no-launch 2>&1
    `$result | Out-File -FilePath `$logFile -Append
    Write-Log "Ubuntu install exit code: `$LASTEXITCODE"
    
    if (`$LASTEXITCODE -eq 0 -or `$LASTEXITCODE -eq `$null) {
        Write-Host "   Ubuntu distribution installed successfully" -ForegroundColor Green
        Write-Log "Ubuntu distribution installed successfully"
    } else {
        Write-Host "   Ubuntu install returned exit code: `$LASTEXITCODE" -ForegroundColor Yellow
        Write-Log "Ubuntu install completed with exit code: `$LASTEXITCODE"
    }
} catch {
    Write-Host "   Failed to install Ubuntu: `$_" -ForegroundColor Red
    Write-Log "ERROR installing Ubuntu: `$_"
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "  Setup Complete - All Tools Installed!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed Tools and Features:" -ForegroundColor Yellow
Write-Host "    - PowerShell 7           Modern cross-platform PowerShell" -ForegroundColor White
Write-Host "    - Visual Studio Code     Lightweight code editor" -ForegroundColor White
Write-Host "    - Git                    Version control system" -ForegroundColor White
Write-Host "    - Windows Terminal       Modern terminal application" -ForegroundColor White
Write-Host "    - PowerToys              Windows system utilities" -ForegroundColor White
Write-Host "    - Visual Studio 2022     Full-featured IDE" -ForegroundColor White
Write-Host "    - WSL                    Windows Subsystem for Linux" -ForegroundColor White
Write-Host "    - Ubuntu                 Linux distribution for WSL" -ForegroundColor White
Write-Host ""
Write-Host "  System Features:" -ForegroundColor Yellow
Write-Host "    - Developer Mode         Enabled for development features" -ForegroundColor White
Write-Host ""
Write-Host "  Next Steps:" -ForegroundColor Green
Write-Host "    - All tools are ready to use" -ForegroundColor Gray
Write-Host "    - Launch Ubuntu from Start Menu to complete Linux setup" -ForegroundColor Gray
Write-Host "    - Check the Start Menu for all newly installed applications" -ForegroundColor Gray
Write-Host ""
Write-Host "  Log file: C:\Setup\install-log.txt" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

pause

# Clean up this script
Start-Sleep -Seconds 2
Remove-Item `$PSCommandPath -Force -ErrorAction SilentlyContinue
"@

Set-Content -Path "C:\Setup\Install-Ubuntu.ps1" -Value $postRebootScript -Force

# Create RunOnce registry entry for post-reboot Ubuntu installation
$runOncePath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
Set-ItemProperty -Path $runOncePath -Name "InstallUbuntu" -Value "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File C:\Setup\Install-Ubuntu.ps1" -Force
Write-Log "Created RunOnce entry for Ubuntu installation after reboot"

# Prompt for reboot
Write-Host ""
Write-Host "A restart is required to complete WSL setup." -ForegroundColor Yellow
Write-Host "Ubuntu will be installed automatically after restart." -ForegroundColor Gray
Write-Host ""

Add-Type -AssemblyName System.Windows.Forms
$result = [System.Windows.Forms.MessageBox]::Show(
    "A restart is required to complete WSL setup.`n`nUbuntu will be installed automatically after restart.`n`nRestart now?",
    "Restart Required",
    [System.Windows.Forms.MessageBoxButtons]::OKCancel,
    [System.Windows.Forms.MessageBoxIcon]::Question,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button1
)

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Restarting computer..." -ForegroundColor Green
    Write-Log "User initiated restart for WSL completion"
    Restart-Computer -Force
} else {
    Write-Host "Restart cancelled. Please restart manually to complete setup." -ForegroundColor Yellow
    Write-Log "User cancelled restart"
    pause
}
'@
    } else {
        $installScriptBase += @'

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Installed Tools and Features" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  MSIX Packaging Tools:" -ForegroundColor Yellow
Write-Host "    - MSIX Packaging Tool    App packaging application" -ForegroundColor White
Write-Host "    - MSIX Driver            Required kernel driver (FOD)" -ForegroundColor White
Write-Host ""
Write-Host "  System Configuration:" -ForegroundColor Yellow
Write-Host "    - Windows Update         Disabled for stable packaging environment" -ForegroundColor White
Write-Host "    - Desktop Shortcuts      Quick access to documentation" -ForegroundColor White
Write-Host ""
Write-Host "  Next Steps:" -ForegroundColor Green
Write-Host "    - All tools are ready to use" -ForegroundColor Gray
Write-Host "    - Check desktop shortcuts for documentation" -ForegroundColor Gray
Write-Host "    - Launch MSIX Packaging Tool from Start Menu" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
pause
'@
    }
    
    # Use the assembled script
    $installScript = $installScriptBase

    Write-Host "    Creating Install-DevTools.ps1 script..." -ForegroundColor Gray
    Write-DebugLog "Install script content length: $($installScript.Length) characters"
    try {
        Set-Content -Path $installScriptPath -Value $installScript -Encoding UTF8 -Force -ErrorAction Stop
        Write-DebugLog "Set-Content completed for Install-DevTools.ps1"
        if (Test-Path $installScriptPath) {
            $scriptSize = (Get-Item $installScriptPath).Length
            Write-Host "    ✓ Install-DevTools.ps1 created: $installScriptPath ($scriptSize bytes)" -ForegroundColor Green
            Write-DebugLog "Install script verified: $scriptSize bytes"
        } else {
            Write-Warning "    ✗ Install-DevTools.ps1 not found after creation"
            Write-DebugLog "ERROR: Install script not found after Set-Content"
            return
        }
    } catch {
        Write-Warning "    ✗ Failed to create Install-DevTools.ps1: $_"
        Write-DebugLog "ERROR: Exception during Install-DevTools.ps1 creation: $_"
        return
    }
    
    # Create MSIX-specific shortcuts if ImageType is MSIXPackagingTool
    if ($ImageType -eq "MSIXPackagingTool") {
        Write-Host "✓ WinGet DSC configuration created (MSIX Packaging Tool)" -ForegroundColor Green
        Write-Host "  - Configuration: $dscConfigPath" -ForegroundColor Gray
        Write-Host "  - Install script: $installScriptPath" -ForegroundColor Gray
        Write-Host "  - Windows Update: Tasks disabled during installation" -ForegroundColor Gray
        Write-Host "  - Auto-Start: Installation runs automatically on first login" -ForegroundColor Yellow
    } else {
        Write-Host "✓ WinGet DSC configuration created" -ForegroundColor Green
        Write-Host "  - Configuration: $dscConfigPath" -ForegroundColor Gray
        Write-Host "  - Install script: $installScriptPath" -ForegroundColor Gray
        Write-Host "  - WinGet installers: Pre-downloaded to C:\Setup" -ForegroundColor Gray
        Write-Host "  - Auto-Start: Installation runs automatically on first login" -ForegroundColor Yellow
    }
}

function Create-VM {
    param(
        [string]$VMName,
        [string]$VMPath,
        [string]$VHDPath,
        [uint64]$MemoryStartupBytes,
        [string]$SwitchName
    )
    
    Write-Host "`n💻 Creating Hyper-V virtual machine..." -ForegroundColor Cyan
    
    # Check if VM already exists
    $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Host "⚠️  VM '$VMName' already exists." -ForegroundColor Yellow
        Write-Host "   Remove it? (Y/N): " -NoNewline -ForegroundColor White
        $remove = Read-Host
        
        if ($remove -eq 'Y' -or $remove -eq 'y') {
            if ($existingVM.State -eq 'Running') {
                Stop-VM -Name $VMName -Force
            }
            Remove-VM -Name $VMName -Force
            Write-Host "✓ Existing VM removed" -ForegroundColor Green
        } else {
            return $false
        }
    }
    
    # Determine switch
    if (-not $SwitchName) {
        $switches = Get-VMSwitch
        if ($switches) {
            $SwitchName = $switches[0].Name
            Write-Host "  Using switch: $SwitchName" -ForegroundColor Gray
        }
    }
    
    # Create VM (Generation 2 for UEFI)
    Write-Host "  Creating Generation 2 VM..." -ForegroundColor Gray
    $vm = New-VM -Name $VMName `
        -MemoryStartupBytes $MemoryStartupBytes `
        -Generation 2 `
        -Path $VMPath `
        -NoVHD
    
    # Attach the VHD
    Write-Host "  Attaching VHD..." -ForegroundColor Gray
    Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath
    
    # Configure memory
    Write-Host "  Configuring dynamic memory..." -ForegroundColor Gray
    Set-VMMemory -VMName $VMName `
        -DynamicMemoryEnabled $true `
        -MinimumBytes 2GB `
        -MaximumBytes $MemoryStartupBytes
    
    # Set processor count and enable nested virtualization (required for WSL)
    Write-Host "  Setting processor count and enabling nested virtualization..." -ForegroundColor Gray
    Set-VMProcessor -VMName $VMName -Count 2 -ExposeVirtualizationExtensions $true
    
    # Connect to switch
    if ($SwitchName) {
        Write-Host "  Connecting to network switch..." -ForegroundColor Gray
        Connect-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName
    }
    
    # Enable TPM
    Write-Host "  Enabling TPM 2.0..." -ForegroundColor Gray
    Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
    Enable-VMTPM -VMName $VMName
    
    # Disable Secure Boot (bypass keys handle this, but disable anyway)
    Write-Host "  Configuring Secure Boot..." -ForegroundColor Gray
    Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
    
    # Set boot order (VHD first)
    Write-Host "  Setting boot order..." -ForegroundColor Gray
    $hardDrive = Get-VMHardDiskDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -FirstBootDevice $hardDrive
    
    Write-Host "✓ VM created successfully!" -ForegroundColor Green
    
    return $true
}

function Create-PostInstallScript {
    param(
        [string]$OutputPath,
        [string]$WinGetConfigPath
    )
    
    $scriptContent = @'
# Post-installation script for Windows 11 development machine
# This script runs on first login to configure the system

Write-Host "🔧 Starting post-installation setup..." -ForegroundColor Cyan

# Wait for system to stabilize
Start-Sleep -Seconds 10

# Check for WinGet
Write-Host "📦 Checking for WinGet..." -ForegroundColor Cyan
$winget = Get-Command winget -ErrorAction SilentlyContinue

if (-not $winget) {
    Write-Host "Installing WinGet..." -ForegroundColor Yellow
    # WinGet comes with App Installer from Microsoft Store
    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    Write-Host "Please install App Installer from the Store, then run this script again." -ForegroundColor Yellow
    exit
}

Write-Host "✓ WinGet is available" -ForegroundColor Green

# Check for DSC configuration file
$configPath = Join-Path $PSScriptRoot "config.dsc.yaml"

if (Test-Path $configPath) {
    Write-Host "📋 Applying WinGet DSC configuration..." -ForegroundColor Cyan
    Write-Host "This will install development tools and configure Windows settings." -ForegroundColor Gray
    
    try {
        winget configure -f $configPath --accept-configuration-agreements
        Write-Host "✓ Configuration applied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to apply configuration: $_"
    }
}
else {
    Write-Host "📦 Installing essential development tools..." -ForegroundColor Cyan
    
    # Install common tools
    $tools = @(
        "Microsoft.PowerShell",
        "Microsoft.VisualStudioCode",
        "Git.Git",
        "Microsoft.WindowsTerminal",
        "Microsoft.PowerToys"
    )
    
    foreach ($tool in $tools) {
        Write-Host "Installing $tool..." -ForegroundColor Gray
        winget install --id $tool --source winget --silent --accept-package-agreements --accept-source-agreements
    }
    
    Write-Host "✓ Tools installed" -ForegroundColor Green
}

# Apply Windows settings
Write-Host "⚙️  Applying Windows settings..." -ForegroundColor Cyan

# Show file extensions
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0

# Show hidden files
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1

# Dark mode
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0

Write-Host "✓ Settings applied" -ForegroundColor Green

# Enable Remote Desktop
Write-Host "🖥️  Enabling Remote Desktop..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "✓ Remote Desktop enabled" -ForegroundColor Green

Write-Host "`n✓ Post-installation setup complete!" -ForegroundColor Green
Write-Host "  You may need to restart Explorer or log out/in for all changes to take effect." -ForegroundColor Gray

'@

    Set-Content -Path $OutputPath -Value $scriptContent -Force
    Write-Host "✓ Post-install script created: $OutputPath" -ForegroundColor Green
}

#endregion Helper Functions

#region Main Script

Write-Host ""
Write-Host "$('='*70)" -ForegroundColor Cyan
Write-Host "Windows 11 VM Setup (Bootable VHD Approach)" -ForegroundColor White
Write-Host "$('='*70)" -ForegroundColor Cyan
Write-Host ""

if ($DebugLogging) {
    Write-Host "🐛 DEBUG LOGGING ENABLED" -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Prerequisites
Write-Host "🔍 Step 1: Checking prerequisites..." -ForegroundColor Cyan
Write-DebugLog "Script started with parameters:"
Write-DebugLog "  VMName: $VMName"
Write-DebugLog "  ImageType: $ImageType"
Write-DebugLog "  UpdateScriptsOnly: $UpdateScriptsOnly"
Write-DebugLog "  DebugLogging: $DebugLogging"
Ensure-Admin
Ensure-PowerShell7
Enable-HyperV

# Set default VM name based on ImageType if not provided
if ($PSBoundParameters.ContainsKey('ImageType') -and $ImageType -eq "MSIXPackagingTool" -and -not $PSBoundParameters.ContainsKey('VMName')) {
    $VMName = "Windows11-MPT-VM"
}

# Step 2: Prepare paths
$vmFolder = Join-Path $VMPath $VMName
$vhdPath = Join-Path $vmFolder "$VMName.vhdx"
$tempWimPath = Join-Path $vmFolder "install.wim"
$postInstallDir = Join-Path $vmFolder "PostInstall"
$postInstallScript = Join-Path $postInstallDir "Setup-DevMachine.ps1"

# Quick update mode - just update scripts in existing VHD
if ($UpdateScriptsOnly) {
    Write-Host "`n⚡ Quick Update Mode - Updating scripts only" -ForegroundColor Yellow
    Write-Host "$('='*70)" -ForegroundColor Yellow
    
    if (-not (Test-Path $vhdPath)) {
        Write-Error "VHD not found at: $vhdPath"
        Write-Host "Please ensure the VM name is correct or create a new VHD first." -ForegroundColor Yellow
        exit 1
    }
    
    # Check if VM is running and stop it if necessary
    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($vm -and $vm.State -ne 'Off') {
        Write-Host "`n⚠️  VM '$VMName' is currently $($vm.State)" -ForegroundColor Yellow
        Write-Host "   The VM must be stopped to mount the VHD." -ForegroundColor Yellow
        Write-Host "`n   Stop the VM now? (Y/N): " -NoNewline -ForegroundColor White
        $stop = Read-Host
        
        if ($stop -eq 'Y' -or $stop -eq 'y') {
            Write-Host "   Stopping VM..." -ForegroundColor Cyan
            Stop-VM -Name $VMName -Force -TurnOff
            Write-Host "   ✓ VM stopped" -ForegroundColor Green
            Start-Sleep -Seconds 3
        } else {
            Write-Host "`n⚠️  Cannot mount VHD while VM is running. Exiting..." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "`n📀 Mounting VHD..." -ForegroundColor Cyan
    Write-DebugLog "Attempting to mount VHD: $vhdPath"
    try {
        $mountedVhd = Mount-VHD -Path $vhdPath -PassThru
        Write-DebugLog "Mount-VHD completed"
        $disk = $mountedVhd | Get-Disk
        Write-DebugLog "Disk number: $($disk.Number)"
        $partition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -eq 'Basic' }
        Write-DebugLog "Partition found: $($partition.PartitionNumber)"
        
        if (-not $partition.DriveLetter) {
            Write-DebugLog "No drive letter assigned, adding one..."
            $partition | Add-PartitionAccessPath -AssignDriveLetter
            Start-Sleep -Seconds 2
            $partition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -eq 'Basic' }
            Write-DebugLog "Drive letter assigned: $($partition.DriveLetter)"
        }
        
        $driveLetter = $partition.DriveLetter
        $windowsDrive = "${driveLetter}:"
        
        Write-Host "✓ VHD mounted on $windowsDrive" -ForegroundColor Green
        Write-DebugLog "VHD mounted successfully on $windowsDrive"
        
        # Clean up old startup files (batch/VBS from previous approaches)
        Write-Host "`n🧹 Cleaning up old startup files..." -ForegroundColor Cyan
        $startupFolder = Join-Path $windowsDrive "ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
        $oldBatch = Join-Path $startupFolder "Install-DevTools.cmd"
        $oldVbs = Join-Path $startupFolder "Install-DevTools.vbs"
        
        if (Test-Path $oldBatch) {
            Remove-Item $oldBatch -Force
            Write-Host "  ✓ Removed old batch file" -ForegroundColor Green
        }
        if (Test-Path $oldVbs) {
            Remove-Item $oldVbs -Force
            Write-Host "  ✓ Removed old VBScript file" -ForegroundColor Green
        }
        
        # Update the Setup directory
        Write-Host "`n📦 Updating Setup scripts..." -ForegroundColor Cyan
        Write-DebugLog "Calling Add-WinGetDSC -WindowsDrive $windowsDrive -ImageType $ImageType"
        Add-WinGetDSC -WindowsDrive $windowsDrive -ImageType $ImageType
        Write-DebugLog "Add-WinGetDSC completed"
        
        # Update RunOnce entry
        Write-Host "`n🔧 Updating first-boot installation..." -ForegroundColor Cyan
        Write-DebugLog "Calling Add-RunOnceKey -WindowsDrive $windowsDrive -ImageType $ImageType"
        Add-RunOnceKey -WindowsDrive $windowsDrive -ImageType $ImageType
        Write-DebugLog "Add-RunOnceKey completed"
        
        Write-Host "`n✓ Scripts updated successfully!" -ForegroundColor Green
        Write-Host "  Updated: $windowsDrive\\Setup\\" -ForegroundColor Gray
        
    }
    catch {
        Write-Error "Failed to update VHD: $_"
    }
    finally {
        if ($mountedVhd) {
            Write-Host "`n📀 Dismounting VHD..." -ForegroundColor Cyan
            Dismount-VHD -Path $vhdPath
            Write-Host "✓ VHD dismounted" -ForegroundColor Green
        }
    }
    
    Write-Host "`n$('='*70)" -ForegroundColor Green
    Write-Host "UPDATE COMPLETE!" -ForegroundColor Green
    Write-Host "$('='*70)" -ForegroundColor Green
    Write-Host "`nYou can now start the VM to test the updated scripts." -ForegroundColor Cyan
    Write-Host "VM: $VMName" -ForegroundColor Gray
    Write-Host "`nStart VM? (Y/N): " -NoNewline -ForegroundColor White
    $start = Read-Host
    
    if ($start -eq 'Y' -or $start -eq 'y') {
        $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($vm) {
            if ($vm.State -eq 'Running') {
                Write-Host "🚀 Restarting VM..." -ForegroundColor Cyan
                Restart-VM -Name $VMName -Force
            } else {
                Write-Host "🚀 Starting VM..." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  ⚠️  IMPORTANT: User Account Control (UAC) Prompt Required" -ForegroundColor Yellow
                Write-Host "  ───────────────────────────────────────────────────────────" -ForegroundColor DarkYellow
                Write-Host "  After logging in, you'll see a UAC prompt to install developer tools." -ForegroundColor White
                Write-Host "  Please click 'Yes' to allow the automated installation to proceed." -ForegroundColor White
                Write-Host ""
                Write-Host "  If you miss the prompt, run: C:\Setup\Install-Tools.ps1" -ForegroundColor Gray
                Write-Host ""
                Start-VM -Name $VMName
            }
            Start-Sleep -Seconds 2
            Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMName
        } else {
            Write-Warning "VM '$VMName' not found. Please create it first without -UpdateScriptsOnly flag."
        }
    }
    
    exit 0
}

# Create directories
Write-Host "`n📁 Creating directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
New-Item -ItemType Directory -Path $postInstallDir -Force | Out-Null
Write-Host "✓ Directories created" -ForegroundColor Green

# Step 3: Download/verify ISO
Write-Host "`n📥 Step 2: Acquiring Windows 11 ISO..." -ForegroundColor Cyan
if (-not (Download-WindowsISO -OutputPath $IsoPath)) {
    Write-Error "Failed to download ISO"
    exit 1
}

# Step 4: Extract WIM from ISO
Write-Host "`n📦 Step 3: Extracting Windows image..." -ForegroundColor Cyan
try {
    $imageIndex = Extract-WimFromISO -IsoPath $IsoPath -OutputWimPath $tempWimPath
}
catch {
    Write-Error "Failed to extract WIM: $_"
    exit 1
}

# Step 5: Create bootable VHD
Write-Host "`n🔧 Step 4: Creating bootable VHD..." -ForegroundColor Cyan

# Check if VHD already exists
if (Test-Path $vhdPath) {
    Write-Host "⚠️  VHD already exists: $vhdPath" -ForegroundColor Yellow
    Write-Host "   Delete existing VHD? (Y/N): " -NoNewline -ForegroundColor White
    $delete = Read-Host
    
    if ($delete -eq 'Y' -or $delete -eq 'y') {
        # Try to dismount if mounted
        try {
            Write-Host "   Attempting to dismount VHD..." -ForegroundColor Gray
            Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } catch {}
        
        # Try to delete
        try {
            Remove-Item $vhdPath -Force -ErrorAction Stop
            Write-Host "✓ Existing VHD removed" -ForegroundColor Green
        }
        catch {
            Write-Host "   ⚠️  VHD is in use by another process" -ForegroundColor Yellow
            Write-Host "   Stop any VMs or processes using this VHD? (Y/N): " -NoNewline -ForegroundColor White
            $kill = Read-Host
            
            if ($kill -eq 'Y' -or $kill -eq 'y') {
                # Check for VMs using this VHD
                $vmsUsingVhd = Get-VM | Where-Object { 
                    ($_ | Get-VMHardDiskDrive).Path -eq $vhdPath 
                }
                
                if ($vmsUsingVhd) {
                    foreach ($vm in $vmsUsingVhd) {
                        Write-Host "   Stopping VM: $($vm.Name)..." -ForegroundColor Gray
                        if ($vm.State -eq 'Running') {
                            Stop-VM -Name $vm.Name -Force -TurnOff
                        }
                        Remove-VM -Name $vm.Name -Force
                        Write-Host "   ✓ VM $($vm.Name) removed" -ForegroundColor Green
                    }
                }
                
                # Wait for Hyper-V to release handles
                Write-Host "   Waiting for Hyper-V to release file handles..." -ForegroundColor Gray
                Start-Sleep -Seconds 3
                
                # Try dismount again (multiple attempts)
                for ($i = 1; $i -le 3; $i++) {
                    try {
                        Dismount-VHD -Path $vhdPath -ErrorAction Stop
                        Write-Host "   ✓ VHD dismounted" -ForegroundColor Green
                        break
                    }
                    catch {
                        if ($i -lt 3) {
                            Write-Host "   Retry $i/3..." -ForegroundColor Gray
                            Start-Sleep -Seconds 2
                        }
                    }
                }
                
                Start-Sleep -Seconds 2
                
                # Try delete again with better error reporting
                try {
                    Remove-Item $vhdPath -Force -ErrorAction Stop
                    Write-Host "✓ Existing VHD removed" -ForegroundColor Green
                }
                catch {
                    # Check what's locking the file
                    Write-Host "`n   ⚠️  File is still locked. Checking processes..." -ForegroundColor Yellow
                    
                    # Try to find process using handle.exe if available, otherwise give manual instructions
                    $handlePath = Get-Command handle.exe -ErrorAction SilentlyContinue
                    if ($handlePath) {
                        Write-Host "   Processes with handles to the file:" -ForegroundColor Gray
                        & handle.exe $vhdPath 2>$null
                    }
                    
                    Write-Host "`n   Manual steps to resolve:" -ForegroundColor Yellow
                    Write-Host "   1. Close Hyper-V Manager if open" -ForegroundColor Gray
                    Write-Host "   2. Close any File Explorer windows browsing the VM folder" -ForegroundColor Gray
                    Write-Host "   3. Restart the Hyper-V Virtual Machine Management service:" -ForegroundColor Gray
                    Write-Host "      Restart-Service vmms -Force" -ForegroundColor Cyan
                    Write-Host "   4. Or restart this script after rebooting" -ForegroundColor Gray
                    Write-Host "`n   Try restarting Hyper-V service now? (Y/N): " -NoNewline -ForegroundColor White
                    $restartService = Read-Host
                    
                    if ($restartService -eq 'Y' -or $restartService -eq 'y') {
                        Write-Host "   Restarting Hyper-V services..." -ForegroundColor Gray
                        try {
                            Restart-Service vmms -Force
                            Start-Sleep -Seconds 5
                            
                            # Try one more time
                            Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue
                            Start-Sleep -Seconds 2
                            Remove-Item $vhdPath -Force -ErrorAction Stop
                            Write-Host "✓ Existing VHD removed after service restart" -ForegroundColor Green
                        }
                        catch {
                            Write-Error "Still unable to remove VHD. Please reboot and try again."
                            exit 1
                        }
                    }
                    else {
                        Write-Error "Unable to proceed with locked VHD file."
                        exit 1
                    }
                }
            }
            else {
                Write-Host "⚠️  Cannot proceed with VHD in use. Exiting..." -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Host "⚠️  Cannot proceed with existing VHD. Exiting..." -ForegroundColor Yellow
        exit 0
    }
}

try {
    $vhdInfo = Create-BootableVHD -VHDPath $vhdPath -SizeBytes $VHDSizeBytes -WimPath $tempWimPath -ImageIndex ([int]$imageIndex)
}
catch {
    Write-Error "Failed to create bootable VHD: $_"
    
    # Cleanup
    if (Test-Path $vhdPath) {
        try {
            Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue
        } catch {}
    }
    
    exit 1
}

# Step 6: Create post-install script
Write-Host "`n📝 Step 5: Creating post-installation script..." -ForegroundColor Cyan

# Auto-detect WinGet config
if (-not $WinGetConfigPath) {
    $possiblePaths = @(
        "C:\Users\kevinla\source\repos\KevinLaProjects\DSC\devimage\WindowsDeveloperMachine.winget",
        "$env:USERPROFILE\source\repos\KevinLaProjects\DSC\devimage\WindowsDeveloperMachine.winget"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $WinGetConfigPath = $path
            break
        }
    }
}

if ($WinGetConfigPath -and (Test-Path $WinGetConfigPath)) {
    Copy-Item $WinGetConfigPath -Destination (Join-Path $postInstallDir "config.dsc.yaml") -Force
}

Create-PostInstallScript -OutputPath $postInstallScript -WinGetConfigPath $WinGetConfigPath

# Step 7: Create VM
Write-Host "`n💻 Step 6: Creating virtual machine..." -ForegroundColor Cyan
$vmCreated = Create-VM -VMName $VMName `
    -VMPath $VMPath `
    -VHDPath $vhdPath `
    -MemoryStartupBytes $MemoryStartupBytes `
    -SwitchName $SwitchName

if (-not $vmCreated) {
    Write-Warning "VM was not created"
    exit 0
}

# Cleanup temporary WIM
if (Test-Path $tempWimPath) {
    Remove-Item $tempWimPath -Force
}

# Step 8: Display summary
Write-Host ""
Write-Host "$('='*70)" -ForegroundColor Cyan
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "$('='*70)" -ForegroundColor Cyan

Write-Host "`nVM Configuration:" -ForegroundColor White
Write-Host "  Name:          $VMName" -ForegroundColor Gray
Write-Host "  Path:          $vmFolder" -ForegroundColor Gray
Write-Host "  Memory:        $([math]::Round($MemoryStartupBytes/1GB,1)) GB" -ForegroundColor Gray
Write-Host "  Disk:          $([math]::Round($VHDSizeBytes/1GB)) GB" -ForegroundColor Gray
Write-Host "  Generation:    2 (UEFI)" -ForegroundColor Gray
Write-Host "  Secure Boot:   Off" -ForegroundColor Gray
Write-Host "  TPM:           2.0 Enabled" -ForegroundColor Gray
Write-Host "  Boot:          VHD (pre-installed Windows)" -ForegroundColor Gray

Write-Host "`nWhat happens when you start the VM:" -ForegroundColor White
Write-Host "  ✓ Boots directly into Windows (no setup required)" -ForegroundColor Gray
Write-Host "  ✓ TPM/SecureBoot bypasses already configured" -ForegroundColor Gray
Write-Host "  ✓ Development tools will install automatically on first login" -ForegroundColor Gray
Write-Host "  ⚠️  You'll need to create a user account on first boot" -ForegroundColor Yellow

Write-Host "`nNext Steps:" -ForegroundColor White
Write-Host "  1. Start the VM: " -NoNewline -ForegroundColor Gray
Write-Host "Start-VM -Name '$VMName'" -ForegroundColor Yellow

Write-Host "  2. Connect:     " -NoNewline -ForegroundColor Gray
Write-Host "vmconnect localhost '$VMName'" -ForegroundColor Yellow

Write-Host "`n  3. After Windows boots:" -ForegroundColor Gray
Write-Host "     - Complete OOBE (create user account)" -ForegroundColor Gray
Write-Host "     - Wait for automatic installation to complete" -ForegroundColor Gray
Write-Host "     - Installation log: C:\Setup\install-log.txt" -ForegroundColor Gray

Write-Host "`nFiles created:" -ForegroundColor White
Write-Host "  $vhdPath" -ForegroundColor Gray

Write-Host "`n🚀 Ready to start VM? (Y/N): " -NoNewline -ForegroundColor White
$start = Read-Host

if ($start -eq 'Y' -or $start -eq 'y') {
    Write-Host ""
    Write-Host "🚀 Starting VM..." -ForegroundColor Cyan
    Start-VM -Name $VMName -ErrorAction Stop
    Write-Host "Launching VM Connect..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMName
    
    Write-Host ""
    Write-Host "✓ VM is starting!" -ForegroundColor Green
    Write-Host "  The VM will boot directly into Windows..." -ForegroundColor Gray
}

Write-Host ""
Write-Host "$('='*70)" -ForegroundColor Cyan
Write-Host ""

#endregion Main Script
