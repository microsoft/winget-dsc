<#
.SYNOPSIS
  Retry a script block with exponential backoff. Intended for flaky network
  operations such as `winget install` or package-registry pulls.

.EXAMPLE
  . "$PSScriptRoot/invoke-retry.ps1"
  Invoke-Retry -Name 'winget install Node.js' -ScriptBlock {
      winget install --id OpenJS.NodeJS.LTS --silent `
          --accept-package-agreements --accept-source-agreements
      if ($LASTEXITCODE -ne 0) { throw "winget exited $LASTEXITCODE" }
  }
#>

$ErrorActionPreference = 'Stop'

function Invoke-Retry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [string] $Name = 'operation',
        [int]    $MaxAttempts = 3,
        [int]    $InitialDelaySeconds = 5
    )

    $attempt = 0
    $delay = $InitialDelaySeconds
    while ($true) {
        $attempt++
        try {
            Write-Host "[invoke-retry] ${Name}: attempt $attempt/$MaxAttempts"
            & $ScriptBlock
            Write-Host "[invoke-retry] ${Name}: success on attempt $attempt"
            return
        } catch {
            if ($attempt -ge $MaxAttempts) {
                Write-Host "[invoke-retry] ${Name}: giving up after $attempt attempts"
                throw
            }
            Write-Warning "[invoke-retry] ${Name}: attempt $attempt failed: $($_.Exception.Message). Retrying in ${delay}s..."
            Start-Sleep -Seconds $delay
            $delay = $delay * 2
        }
    }
}
