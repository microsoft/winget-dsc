if ($env:PSModulePath -notlike $PSScriptRoot) {
    $env:PSModulePath += ";$PSScriptRoot\Modules"
}
