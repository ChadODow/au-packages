import-module au

. .\Get-IniContent.ps1

function global:au_SearchReplace {
    @{
         ".\tools\chocolateyInstall.ps1" = @{
             "(^[$]url\s*=\s*)('.*')"      = "`$1'$($Latest.URL32)'"
             "(^[$]checksum\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
         }
     }
 }

function GetReleaseNotes($ini) {
    $releaseFeatureCount = [int] $ini.DATA.release_feature_count

    for ($i = 1; $i -le $releaseFeatureCount; $i++) {
        ("- " + $ini.DATA["release_feature_$i"].Trim('"'))
    }    
}

function global:au_GetLatest {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $response = Invoke-RestMethod -Uri "https://upgrades.counterpath.com/xlite4/upgrade.php?build=76589"

    Write-Warning $response 
    
    $iniFile = [IO.Path]::GetTempFileName()

    Set-Content -Path $iniFile -Value $response
    $ini = Get-IniContent $iniFile

    Remove-Item $iniFile

    $url = $ini.DATA.url

    if ($url -match ".*X-Lite-(\d+\.\d+\.\d+\.\d+)") {
        $version = $Matches[1]

        if (-not ($url.EndsWith(".exe"))) {
            # http://counterpath.s3.amazonaws.com/downloads/X-Lite_5.3.1_92361.exe
            $v = [version] $version
            $versionFormat = "$($v.Major).$($v.Minor).$($v.Build)_$($v.Revision)"
            $url = "https://counterpath.s3.amazonaws.com/downloads/X-Lite_$($versionFormat).exe"
        }

        $releaseNotes = (GetReleaseNotes $ini) -join [Environment]::NewLine

        @{
            URL32 = $url
            Version = $version
            ReleaseNotes = $releaseNotes
        }
    } else {
        return @{}
    }
}

function global:au_AfterUpdate
{ 
    $nuspecFileName = $Latest.PackageName + ".nuspec"
    $nu = Get-Content $nuspecFileName -Raw -Encoding UTF8
    $nu = $nu -replace "(?smi)(\<releaseNotes\>).*?(\</releaseNotes\>)", "`${1}$($Latest.ReleaseNotes)`$2"
    
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
    $NuPath = (Resolve-Path $NuspecFileName)
    [System.IO.File]::WriteAllText($NuPath, $nu, $Utf8NoBomEncoding)
}

update -ChecksumFor 32