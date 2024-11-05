# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
enum Ensure {
    Absent
    Present
}

$global:WindowsSandboxExePath = 'C:\Windows\System32\WindowsSandbox.exe'

if (-not(Test-Path -Path $global:WindowsSandboxExePath)) {
    throw 'Windows Sandbox feature is not enabled.'
}

#region DSCResources
[DSCResource()]
class WindowsSandbox {
    [DscProperty(Key)]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty()]
    [string]$WsbFilePath

    [DscProperty()]
    [string]$HostFolder

    [DscProperty()]
    [string]$SandboxFolder

    [DscProperty()]
    [string]$ReadOnly

    [DscProperty()]
    [string]$LogonCommand

    [DscProperty()]
    [nullable[Int64]]$MemoryInMB

    [DscProperty()]
    [nullable[bool]]$vGPU

    [DscProperty()]
    [nullable[bool]]$AudioInput

    [DscProperty()]
    [nullable[bool]]$ClipboardRedirection

    [DscProperty()]
    [nullable[bool]]$Networking

    [DscProperty()]
    [nullable[bool]]$PrinterRedirection

    [DscProperty()]
    [nullable[bool]]$ProtectedClient

    [DscProperty()]
    [nullable[bool]]$VideoInput

    [WindowsSandbox] Get() {
        $currentState = [WindowsSandbox]::new()
        $currentState.WsbFilePath = $this.WsbFilePath
        $windowsSandboxProcess = Get-Process WindowsSandbox -ErrorAction SilentlyContinue
        $currentState.Ensure = $windowsSandboxProcess ? [Ensure]::Present : [Ensure]::Absent

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        # If ensure absent, stop the current Windows Sandbox process.
        if ($this.Ensure -eq [Ensure]::Absent) {
            Stop-Process -Name 'WindowsSandboxClient' -Force
            return
        }

        # Load the existing WSB file if it exists or create a new one.
        if ($this.WsbFilePath) {
            if (-not(Test-Path -Path $this.WsbFilePath)) {
                throw 'The provided WSB file does not exist.'
            }

            $xml = [xml](Get-Content -Path $this.WsbFilePath)
            $root = $xml.Configuration
        } else {
            $xml = New-Object -TypeName System.Xml.XmlDocument
            $root = $xml.CreateElement('Configuration')
            $xml.AppendChild($root)
        }

        <# Example Windows Sandbox configuration file (xml):
            <Configuration>
            <VGpu>Disable</VGpu>
            <Networking>Disable</Networking>
            <MappedFolders>
                <MappedFolder>
                <HostFolder>C:\Users\Public\Downloads</HostFolder>
                <SandboxFolder>C:\Users\WDAGUtilityAccount\Downloads</SandboxFolder>
                <ReadOnly>true</ReadOnly>
                </MappedFolder>
            </MappedFolders>
            <LogonCommand>
                <Command>explorer.exe C:\users\WDAGUtilityAccount\Downloads</Command>
            </LogonCommand>
            <AudioInput>Enable</AudioInput>
            <VideoInput>Enable</VideoInput>
            <ProtectedClient>Enable</ProtectedClient>
            <PrinterRedirection>Disable</PrinterRedirection>
            <ClipboardRedirection>Enable</ClipboardRedirection>
            <MemoryInMB>2048</MemoryInMB>
            </Configuration>
        #>

        # Override existing configurations if exists.
        if ($this.HostFolder) {
            if (-not(Test-Path -Path $this.HostFolder)) {
                throw 'Specified host folder path does not exist.'
            }

            # Remove existing mapped folder
            if ($root.MappedFolders) {
                $existingMappedFolders = $root.SelectSingleNode('MappedFolders')
                $root.RemoveChild($existingMappedFolders)
            }

            # Create Mapped Folders element
            $mappedFoldersElement = $xml.CreateElement('MappedFolders')
            $mappedFolderElement = $xml.CreateElement('MappedFolder')
            $hostFolderElement = $xml.CreateElement('HostFolder')
            $mappedFolderElement.AppendChild($hostFolderElement)
            $mappedFoldersElement.AppendChild($mappedFolderElement)
            $root.AppendChild($mappedFoldersElement)
            $root.MappedFolders.MappedFolder.HostFolder = $this.HostFolder

            if ($this.SandboxFolder) {
                $sandboxFolderElement = $xml.CreateElement('SandboxFolder')
                $mappedFolderElement.AppendChild($sandboxFolderElement)
                $root.MappedFolders.MappedFolder.SandboxFolder = $this.SandboxFolder
            }

            if ($this.ReadOnly) {
                $readOnlyElement = $xml.CreateElement('ReadOnly')
                $mappedFolderElement.AppendChild($readOnlyElement)
                $root.MappedFolders.MappedFolder.ReadOnly = 'true'
            }
        }

        if ($this.LogonCommand) {
            if ($root.LogonCommand) {
                $existingLogonCommand = $root.SelectSingleNode('LogonCommand')
                $root.RemoveChild($existingLogonCommand)
            }

            $logonCommandElement = $xml.CreateElement('LogonCommand')
            $commandElement = $xml.CreateElement('Command')
            $logonCommandElement.AppendChild($commandElement)
            $root.AppendChild($logonCommandElement)
            $root.LogonCommand.Command = $this.LogonCommand
        }

        if ($this.MemoryInMB) {
            if ($null -eq $root.MemoryInMB) {
                $memoryElement = $xml.CreateElement('MemoryInMB')
                $root.AppendChild($memoryElement)
            }

            $root.MemoryInMB = $this.MemoryInMB
        }

        if ($null -ne $this.vGPU) {
            if ($null -eq $root.vGPU) {
                $vGPUElement = $xml.CreateElement('vGPU')
                $root.AppendChild($vGPUElement)
            }

            $root.vGPU = ConvertBoolToEnableDisable($this.vGPU)
        }

        if ($null -ne $this.AudioInput) {
            if ($null -eq $root.AudioInput) {
                $audioInputElement = $xml.CreateElement('AudioInput')
                $root.AppendChild($audioInputElement)
            }

            $root.AudioInput = ConvertBoolToEnableDisable($this.AudioInput)
        }

        if ($null -ne $this.ClipboardRedirection) {
            if ($null -eq $root.ClipboardRedirection) {
                $clipboardRedirectionElement = $xml.CreateElement('ClipboardRedirection')
                $root.AppendChild($clipboardRedirectionElement)
            }

            $root.ClipboardRedirection = ConvertBoolToEnableDisable($this.ClipboardRedirection)
        }

        if ($null -ne $this.Networking) {
            if ($null -eq $root.Networking) {
                $networkingElement = $xml.CreateElement('Networking')
                $root.AppendChild($networkingElement)
            }

            $root.Networking = ConvertBoolToEnableDisable($this.Networking)
        }

        if ($null -ne $this.PrinterRedirection) {
            if ($null -eq $root.PrinterRedirection) {
                $printerRedirectionElement = $xml.CreateElement('PrinterRedirection')
                $root.AppendChild($printerRedirectionElement)
            }

            $root.PrinterRedirection = ConvertBoolToEnableDisable($this.PrinterRedirection)
        }

        if ($null -ne $this.ProtectedClient) {
            if ($null -eq $root.ProtectedClient) {
                $protectedClientElement = $xml.CreateElement('ProtectedClient')
                $root.AppendChild($protectedClientElement)
            }

            $root.ProtectedClient = ConvertBoolToEnableDisable($this.ProtectedClient)
        }

        if ($null -ne $this.VideoInput) {
            if ($null -eq $root.VideoInput) {
                $videoInputElement = $xml.CreateElement('VideoInput')
                $root.AppendChild($videoInputElement)
            }

            $root.VideoInput = ConvertBoolToEnableDisable($this.VideoInput)
        }

        # Export WSB file and run.
        $windowsSandboxDscTempDir = "$($env:Temp)\WindowsSandboxDsc"
        if (-not (Test-Path -Path $windowsSandboxDscTempDir)) {
            New-Item -ItemType Directory -Path $windowsSandboxDscTempDir
        }

        $sandboxId = (New-Guid).ToString()
        $tempSandboxWsbFilePath = Join-Path -Path $windowsSandboxDscTempDir -ChildPath "${sandboxId}.wsb"
        $xml.save($tempSandboxWsbFilePath)
        Invoke-Item $tempSandboxWsbFilePath
    }
}

#endregion DSCResources

#region Functions

function ConvertBoolToEnableDisable() {
    param (
        [Parameter()]
        [bool]$value
    )

    return $value ? 'Enable' : 'Disable'
}

#endregion Functions
