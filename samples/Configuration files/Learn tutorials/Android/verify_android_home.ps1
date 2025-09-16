
# Set ANDROID_HOME environment variable for the user
$androidHomePath = "$Env:LOCALAPPDATA\Android\Sdk"
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHomePath, "User")
Write-Host "ANDROID_HOME set to $androidHomePath."

# Add platform-tools to the user PATH if not already present
$platformToolsPath = "$androidHomePath\platform-tools"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($currentPath -notlike "*${platformToolsPath}*") {
    $newPath = "$currentPath;$platformToolsPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "platform-tools path added to PATH: $newPath."
} else {
    Write-Host "platform-tools path already exists in PATH: $platformToolsPath."
}
