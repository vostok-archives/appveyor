Write-Host Cement: Dowloading latest release
Invoke-WebRequest "https://github.com/vostok/cement/releases/download/v1.0.21-vostok/cement.zip" -Out "cement.zip"

Write-Host Cement: Extracting release files
Expand-Archive "cement.zip" -Force -DestinationPath "cement"

New-Item -ItemType directory -Path "$env:USERPROFILE\bin\dotnet" > null

Write-Host Cement: Dowloading settings
Invoke-WebRequest "https://raw.githubusercontent.com/vostok/cement-modules/master/settings" -OutFile "$env:USERPROFILE\bin\dotnet\defaultSettings.json"

Write-Host Cement: Add default log.config
New-Item -Path "$env:USERPROFILE\bin\dotnet" -Name 'log.config.xml' -Value '<?xml version="1.0" encoding="utf-8"?><log4net/>' > null

$cmpath = "$env:appveyor_build_folder\cement\dotnet\cm.exe"
[Environment]::SetEnvironmentVariable("cm", $cmpath, "User")
$env:cm = $cmpath
Write-Host Cement: Instalation completed