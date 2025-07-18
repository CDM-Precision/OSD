function Set-SetupCompleteNetFX {

    $ScriptsPath = "C:\Windows\Setup\scripts"
    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})
    $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"

    if (Test-Path -Path $PSFilePath){
        Add-Content -Path $PSFilePath "Write-Output 'Running Enable NetFX Function'"
        Add-Content -Path $PSFilePath "if (Test-WebConnection -Uri google.com){Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/CDM-Precision/OSD/master/cloud/modules/_oobe.psm1'); osdcloud-NetFX} else {Write-Host 'No Internet Connection Detected'}"
    }
    else {
    Write-Output "$PSFilePath - Not Found"
    }
}