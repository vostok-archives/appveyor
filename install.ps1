$ErrorActionPreference = "Stop"
$branch = "$env:appveyor_repo_branch"
$prbranch = "$env:APPVEYOR_PULL_REQUEST_HEAD_REPO_BRANCH"
Write-Output "Branch: $branch; Pull request branch: $prbranch"
$branchstr = ""
if ($prbranch -ne "")
{
  $branchstr = "-pr-$prbranch"
}
else
{
  if ($branch -ne "master")
  {
    $branchstr = "-$branch"
  }
}
$zeroPaddedBuildNumber = [convert]::ToInt32($env:appveyor_build_number, 10).ToString("000000")
Update-AppveyorBuild -Version "0.0.0.$zeroPaddedBuildNumber$branchstr".Replace("_", "-")
$csprojs = $env:appveyor_build_folder | Get-ChildItem -Recurse -Filter "*.csproj"
foreach($csproj in $csprojs)
{
  $name = $csproj.BaseName
  $xmlPath = "$env:appveyor_build_folder\$name\$name.csproj"
  $xml = [xml](Get-Content $xmlPath)
  $props = $xml.SelectSingleNode("//PropertyGroup")
  if ($props)
  {
    echo "Generating version $env:appveyor_build_version for $name"
    $version = $xml.CreateElement("Version")
    $versionText = $xml.CreateTextNode($env:appveyor_build_version)
    $version.AppendChild($versionText)
    $props.AppendChild($version)
    $xml.Save($xmlPath)
  }
}
Set-Location "$env:appveyor_build_folder\.."

$releases = "https://api.github.com/repos/skbkontur/cement/releases"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host Determining latest release
$download = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].assets[0].browser_download_url

$zip = "cement.zip"
$dir = "cement"

Write-Host Dowloading latest release
Invoke-WebRequest $download -Out $zip

Write-Host Extracting release files
Expand-Archive $zip -Force -DestinationPath $dir
Set-Location "cement\dotnet"
& install.cmd
$wc = New-Object System.Net.WebClient
Invoke-WebRequest "https://raw.githubusercontent.com/vostok/cement-modules/master/settings" -OutFile "$env:USERPROFILE\.cement\settings"
$wc.DownloadFile("https://raw.githubusercontent.com/vostok/cement-modules/master/settings", "$env:USERPROFILE\.cement\settings")
[Environment]::SetEnvironmentVariable("cm", "$env:USERPROFILE\bin\cm.cmd", "User")
Set-Location $env:appveyor_build_folder\..
& $env:cm init
Set-Location $env:appveyor_build_folder
& $env:cm update-deps
& $env:cm build-deps
& dotnet restore
