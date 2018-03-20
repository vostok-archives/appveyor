$curPath = $MyInvocation.MyCommand.Path
$curDir = Split-Path $curPath
$ErrorActionPreference = "Stop"

"$curDir\.." | Get-ChildItem | Where-Object { $_.PSIsContainer -and ($_.FullName -ne $curDir) -and !$_.Name.StartsWith(".") }  | ForEach-Object { #
    $repDir = $_.FullName
    if (Test-Path "$repDir\appveyor.yml") {
        Write-Output $repDir
        Push-Location -Path $repDir
        git diff --exit-code
        if (!$?) {
            Write-Output "Error. There are local changes at $repDir"
            exit 1
        }
        git checkout -B master origin/master
        if (!$?) {
            Write-Output "Error while checkout master at $repDir"
            exit 1
        }
        Copy-Item "$curDir\appveyor.yml" -Destination $repDir
        $diff = (git diff) | Out-String
        if ($diff) {
            git add .
            if (!$?) {
                Write-Output "Error while commit at $repDir"
                exit 1
            }
            git commit -m "Update appveyor.yml"
            if (!$?) {
                Write-Output "Error while commit at $repDir"
                exit 1
            }
            # & git push origin
            # if (!$?) {
            #     Write-Output "Error while push changes at $repDir"
            #     exit 1
            # }
        } else {
            Write-Output "appveyor.yml already updated"
        }
        Pop-Location
#        Write-Output "!!"
#        exit 0
    }
}
