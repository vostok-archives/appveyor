$ErrorActionPreference = "Stop"

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
$branchstr = $branchstr.Replace("_", "-")
$zeroPaddedBuildNumber = [convert]::ToInt32($env:appveyor_build_number, 10).ToString("000000")
$csprojs = $env:appveyor_build_folder | Get-ChildItem -Recurse -Filter "*.csproj"
$buildVersion = ""
if ($env:APPVEYOR_REPO_TAG -eq "false") {
  $buildVersion = "-beta$zeroPaddedBuildNumber";
}
$version = "0.0.0$buildVersion$branchstr"
foreach($csproj in $csprojs)
{
  $name = $csproj.BaseName
  $xmlPath = "$env:appveyor_build_folder\$name\$name.csproj"
  $xml = [xml](Get-Content $xmlPath)
  $versionNode = $xml.SelectSingleNode("//PropertyGroup/Version")
  if ($versionNode)
  {
    $version = $versionNode.InnerText
    $version = "$version$buildVersion$branchstr"
    $versionNode.InnerText = $version;
    $xml.Save($xmlPath)
  }
}
Write-Output "set version $version"
Update-AppveyorBuild -Version $version

Set-Location "$env:appveyor_build_folder\.."
#$releases = "https://api.github.com/repos/skbkontur/cement/releases"
#Write-Host Determining latest cement release
#$download = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].assets[0].browser_download_url

Write-Host Dowloading latest cement release
Invoke-WebRequest "https://github.com/skbkontur/cement/releases/download/v1.0.31/62a81460823b12b1452fba39de48673255ded50e.zip" -Out "cement.zip"

Write-Host Extracting release cement files
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
Write-Output cm update-deps
& $env:cm update-deps -v
if (!$?) {
    exit 1
}
Write-Output cm build-deps
& $env:cm build-deps -v
if (!$?) {
    exit 1
}
Write-Output cm build
& $env:cm build -v
if (!$?) {
    exit 1
}

if ($env:appveyor_repo_branch -eq "master" -and "$env:APPVEYOR_PULL_REQUEST_HEAD_REPO_BRANCH" -eq "") {
  Write-Output Pack nuget packages
  $csprojs = $env:appveyor_build_folder | Get-ChildItem -Recurse -Filter "*.csproj"
  foreach($csproj in $csprojs)
  {
    $name = $csproj.BaseName
    $xmlPath = "$env:appveyor_build_folder\$name\$name.csproj"
    $xml = [xml](Get-Content $xmlPath)
    $versionNode = $xml.SelectSingleNode("//PropertyGroup/Version")
    if ($versionNode) {
      $proj="$name.csproj"
      Write-Output Pack $proj
      & $env:cm pack $proj
      if (!$?) {
          exit 1
      }
    }

    $nupkgs = Get-ChildItem $env:appveyor_build_folder\$name\bin\Release\$name.*.nupkg
    if ($nupkgs)
    {
      $nupkgs | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
    }          
  }
}


if (Test-Path "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests.csproj")
{
  Write-Output Run tests
  dotnet test "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests.csproj" --logger "trx;LogFileName=tests.trx"
  if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
  }
  if (Test-Path "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\TestResults\tests.trx") {
    $wc = New-Object 'System.Net.WebClient'
    $wc.UploadFile("https://ci.appveyor.com/api/testresults/mstest/$($env:appveyor_job_id)", "$env:appveyor_build_folder\Vostok.$env:APPVEYOR_PROJECT_NAME.Tests\TestResults\tests.trx")
  }
}

