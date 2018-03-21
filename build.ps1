$ErrorActionPreference = "Stop"
#$env:appveyor_repo_branch = "dev";
#$env:appveyor_build_number = "1";
#$env:appveyor_build_folder = "C:\Sources\Vostok\main\vostok.commons";

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
    Write-Output "Generating version $env:appveyor_build_version for $name"
    $version = $xml.CreateElement("Version")
    $versionText = $xml.CreateTextNode($env:appveyor_build_version)
    $version.AppendChild($versionText)
    $props.AppendChild($version)
    $xml.Save($xmlPath)
  }
}

Set-Location "$env:appveyor_build_folder\.."
$releases = "https://api.github.com/repos/skbkontur/cement/releases"
Write-Host Determining latest release
$download = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].assets[0].browser_download_url

Write-Host Dowloading latest release
Invoke-WebRequest $download -Out "cement.zip"

Write-Host Extracting release files
Expand-Archive "cement.zip" -Force -DestinationPath "cement"
Set-Location "cement\dotnet"
& cmd.exe /c install.cmd
$wc = New-Object System.Net.WebClient
Invoke-WebRequest "https://raw.githubusercontent.com/vostok/cement-modules/master/settings" -OutFile "$env:USERPROFILE\.cement\settings"
[Environment]::SetEnvironmentVariable("cm", "$env:USERPROFILE\bin\cm.cmd", "User")
$env:cm = "$env:USERPROFILE\bin\cm.cmd"

Set-Location $env:appveyor_build_folder\..
& $env:cm init
Set-Location $env:appveyor_build_folder
& $env:cm update-deps -v
if (!$?) {
    exit 1
}
& $env:cm build-deps -v
if (!$?) {
    exit 1
}
& $env:cm build -v
if (!$?) {
    exit 1
}

if ($env:appveyor_repo_branch -eq "master" -and "$env:APPVEYOR_PULL_REQUEST_HEAD_REPO_BRANCH" -eq "") {
  $proj="Vostok.$env:APPVEYOR_PROJECT_NAME.csproj"
  & $env:cm pack $proj
  if (!$?) {
      exit 1
  }
  $csprojs = $env:appveyor_build_folder | Get-ChildItem -Recurse -Filter "*.csproj"
  foreach($csproj in $csprojs)
  {
    $name = $csproj.BaseName
    $nupkgs = Get-ChildItem $env:appveyor_build_folder\$name\bin\Release\$name.*.nupkg
    if ($nupkgs)
    {
      $nupkgs | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
    }          
  }
}

if (Test-Path "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests.csproj")
{
  dotnet test "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests.csproj" --logger "trx;LogFileName=tests.trx"
  if (!$?) {
      exit 1
  }
  if (Test-Path "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\TestResults\tests.trx") {
    $wc = New-Object 'System.Net.WebClient'
    $wc.UploadFile("https://ci.appveyor.com/api/testresults/mstest/$($env:appveyor_job_id)", "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\TestResults\tests.trx")
  }
}

