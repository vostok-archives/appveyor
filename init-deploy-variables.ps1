$version = $env:APPVEYOR_BUILD_VERSION

if ($env:APPVEYOR_REPO_BRANCH -eq "master") {
  $formattedBuildNumber = [convert]::ToInt32($env:APPVEYOR_BUILD_NUMBER, 10).ToString("000000")
  Get-ChildItem -Recurse -Filter "*.nuspec" | ForEach-Object {
    $nuspec = [xml](Get-Content $_.FullName)
    $nuspecVersion = $nuspec.package.metadata.version
    $version = "$nuspecVersion-pre$formattedBuildNumber"
  }
  $env:need_deploy_to_nuget = 'true'
}
if ($env:APPVEYOR_REPO_TAG_NAME -ne $null) {
  $splits = $env:APPVEYOR_REPO_TAG_NAME.Split('/');
  if ($splits.Length -eq 2 -and $splits[0] -eq 'release' -and $splits[1] -match "^\d{1,3}\.\d{1,3}\.\d{1,3}$") {
    $version = $splits[1]
    $env:need_deploy_to_nuget = 'true'
    $env:need_deploy_to_github = 'true'
  }
}

Write-Host Update appveyor build version: $version
Update-AppveyorBuild -Version $version