<#
.SYNOPSIS
  Build a server scenario, start it in the background, hit an endpoint,
  and persist the response body to a file.

.DESCRIPTION
  Companion to tests/_harness/run-flow.ps1 for scenario flows that ship a
  real Web API as their hello-world (web-api-csharp, web-api-ts,
  web-api-python, web-api-java).

  Designed to be the manifest's `build` step. The matching `run` step is
  a simple `type <OutputFile>` (or `cmd /c type ...`) that emits the
  persisted body for run-flow.ps1 to diff against expected.txt.

  Why the split: when pwsh runs as `pwsh -File ...` under cmd.exe, its
  Write-Host / "host display" output is folded into the process's stdout
  (there is no interactive console host to capture it separately). The
  outer harness merges stderr into stdout via `2>&1` and diffs the lot.
  So we cannot route diagnostics around the diff at runtime. Persisting
  the body to disk and emitting only the file contents in the run step
  keeps the diff clean and lets diagnostics flow freely through the
  build step's normal stdout.

  Lifecycle on each invocation:
    1. (Optional) run a synchronous build command (e.g. `dotnet build` or
       `mvn package`).
    2. Start the server command in a hidden child process. Server stdout
       and stderr are redirected to log files in a per-run temp dir.
    3. Poll HealthUrl until any 2xx/3xx response, or HealthTimeoutSeconds
       elapses. If the server process exits during polling the script
       fails immediately and surfaces the exit code.
    4. Issue a GET to RequestUrl (defaults to HealthUrl) and capture the
       response body.
    5. Always: kill the server process tree via `taskkill /F /T /PID`.
       This handles `dotnet run`, `mvnw spring-boot:run`, `node`, and
       `uvicorn`, which all spawn child processes that Stop-Process
       alone leaves running.
    6. Write the response body verbatim to OutputFile.
    7. On any failure, dump the captured server log files to stdout so
       they show up in the harness's build-step output.

.PARAMETER Id
  Flow id, used in log prefixes only.

.PARAMETER Build
  Optional shell command (run via cmd.exe /d /c) to build the scenario
  before starting the server. Empty string skips the build step.

.PARAMETER Start
  Shell command (run via cmd.exe /d /c) that starts the server in the
  foreground. Wrapped in a hidden child process by this script.

.PARAMETER HealthUrl
  URL polled until the server is ready. Any 2xx or 3xx response is
  considered ready. Polled at 500ms intervals.

.PARAMETER RequestUrl
  Optional URL whose response body is persisted. Defaults to HealthUrl.
  Use a separate URL when the health endpoint is not the endpoint you
  want to diff.

.PARAMETER OutputFile
  Path where the response body is written verbatim. Parent directory is
  created if missing. The manifest's `run` step is expected to be
  `type <this same path>` so run-flow.ps1 sees only the body.

.PARAMETER HealthTimeoutSeconds
  Maximum time to wait for HealthUrl readiness before failing. Default 60.

.PARAMETER ShutdownGraceSeconds
  Maximum time to wait for the server process tree to exit after taskkill.
  Default 10.

.NOTES
  Commands run with the repository root as the working directory, matching
  the run-flow.ps1 contract.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Id,
    [Parameter()]          [string] $Build = '',
    [Parameter(Mandatory)] [string] $Start,
    [Parameter(Mandatory)] [string] $HealthUrl,
    [Parameter()]          [string] $RequestUrl = '',
    [Parameter(Mandatory)] [string] $OutputFile,
    [Parameter()]          [int]    $HealthTimeoutSeconds = 60,
    [Parameter()]          [int]    $ShutdownGraceSeconds = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RequestUrl)) {
    $RequestUrl = $HealthUrl
}

function Write-Section {
    param([string] $Text)
    Write-Host ""
    Write-Host "==== [$Id] $Text ===="
}

function Stop-ServerTree {
    param([System.Diagnostics.Process] $Proc, [int] $GraceSeconds)
    if ($null -eq $Proc) { return }
    if ($Proc.HasExited) { return }
    # taskkill /T kills the full child tree; Stop-Process alone leaves the
    # actual server (a child of cmd.exe / dotnet / mvnw / etc.) running.
    & taskkill.exe /F /T /PID $Proc.Id 2>&1 | Out-Null
    if (-not $Proc.HasExited) {
        $Proc.WaitForExit($GraceSeconds * 1000) | Out-Null
    }
}

function Write-ServerLogs {
    param([string] $StdoutPath, [string] $StderrPath)
    Write-Host "--- server stdout ($StdoutPath) ---"
    if (Test-Path -LiteralPath $StdoutPath) {
        Get-Content -LiteralPath $StdoutPath | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "(no stdout log)"
    }
    Write-Host "--- server stderr ($StderrPath) ---"
    if (Test-Path -LiteralPath $StderrPath) {
        Get-Content -LiteralPath $StderrPath | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "(no stderr log)"
    }
    Write-Host "--- end server logs ---"
}

if (-not [string]::IsNullOrWhiteSpace($Build)) {
    Write-Section 'build'
    Write-Host "> $Build"
    & cmd.exe /d /c $Build
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
}

$logStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir   = Join-Path ([System.IO.Path]::GetTempPath()) "wdss-$Id-$logStamp"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$outLog = Join-Path $logDir 'server.out.log'
$errLog = Join-Path $logDir 'server.err.log'

Write-Section 'start server'
Write-Host "> $Start"
Write-Host "logs: $logDir"

$serverProc = Start-Process -FilePath cmd.exe `
    -ArgumentList '/d', '/c', $Start `
    -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError  $errLog
Write-Host "server pid: $($serverProc.Id)"

try {
    Write-Section "wait for $HealthUrl (timeout ${HealthTimeoutSeconds}s)"
    $deadline = (Get-Date).AddSeconds($HealthTimeoutSeconds)
    $ready = $false
    $attempts = 0
    while ((Get-Date) -lt $deadline) {
        $attempts++
        if ($serverProc.HasExited) {
            throw "Server process exited prematurely with exit code $($serverProc.ExitCode) after $attempts health attempts"
        }
        try {
            $resp = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) {
                $ready = $true
                break
            }
        } catch {
            # Server not ready yet (connection refused, 5xx, etc.); keep polling.
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) {
        throw "Server at $HealthUrl did not become ready within ${HealthTimeoutSeconds}s ($attempts attempts)"
    }
    Write-Host "server ready after $attempts health attempt(s)"

    Write-Section "GET $RequestUrl"
    $bodyResp = Invoke-WebRequest -Uri $RequestUrl -UseBasicParsing -TimeoutSec 30
    Write-Host "HTTP $($bodyResp.StatusCode) $($bodyResp.StatusDescription)"

    Write-Section "persist response body to $OutputFile"
    $outputDir = Split-Path -Parent $OutputFile
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    # WriteAllText leaves bytes verbatim; the harness normalizes CRLF on diff.
    [System.IO.File]::WriteAllText($OutputFile, $bodyResp.Content)
    Write-Host "wrote $($bodyResp.Content.Length) char(s)"
}
catch {
    Write-ServerLogs -StdoutPath $outLog -StderrPath $errLog
    throw
}
finally {
    Write-Section 'stop server'
    Stop-ServerTree -Proc $serverProc -GraceSeconds $ShutdownGraceSeconds
    if ($null -ne $serverProc -and $serverProc.HasExited) {
        Write-Host "server pid $($serverProc.Id) exited with code $($serverProc.ExitCode)"
    } elseif ($null -ne $serverProc) {
        Write-Host "warning: server pid $($serverProc.Id) did not exit cleanly within ${ShutdownGraceSeconds}s"
    }
}

