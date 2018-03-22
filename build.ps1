param(
    [int] $build_number = 0,
    [string] $version = '10.3-1',
    [string]$nugetApiKey = $null
)
$ErrorActionPreference = "Stop"

$baseDir = Split-Path $MyInvocation.MyCommand.Path

$nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

$filename = "postgresql-$($version)-windows-x64-binaries.zip"
$download_url = "http://get.enterprisedb.com/postgresql/$filename"

$plv8_filename = "pg10plv8jsbin_w64.zip"
$plv8_url = "http://www.postgresonline.com/downloads/$($plv8_filename)"

$base_package = "postgresql-$($version)-windows-x64-binaries-lite.zip"
$plv8_package = "postgresql-$($version)-windows-x64-binaries-lite-plv8.zip"

# clean
Write-Host "Cleaning..."
if (Test-Path .\pgsql) { Remove-Item .\pgsql -Recurse -Force }
if (Test-Path .\pg10plv8jsbin_w64) { Remove-Item .\pg10plv8jsbin_w64 -Recurse -Force }
Remove-Item *.nupkg,*.exe,*.zip

# download
Write-Output "Downloading nuget.exe..."
Invoke-WebRequest -Uri $nugetUrl -OutFile "nuget.exe"

Write-Output "Downloading $filename..."
Invoke-WebRequest -Uri $download_url -OutFile $filename
Write-Output "Downloading $plv8_filename..."
Invoke-WebRequest -Uri $plv8_url -OutFile $plv8_filename

# unpack
Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Output "Extracting $filename..."
[System.IO.Compression.ZipFile]::ExtractToDirectory("$baseDir\$filename", "$baseDir\")

Write-Output "Extracting $plv8_filename..."
[System.IO.Compression.ZipFile]::ExtractToDirectory("$baseDir\$plv8_filename", "$baseDir\")

# clean
Write-Host "Cleaning pgsql..."
Get-ChildItem .\pgsql -Exclude bin,lib,share | Remove-Item -Recurse -Force

# packing archives
Write-Output "Archiving $base_package"
[System.IO.Compression.ZipFile]::CreateFromDirectory("$baseDir\pgsql", $base_package, `
    [System.IO.Compression.CompressionLevel]::Optimal, $true)

Write-Output "Copying plv8 into pgsql..."
Copy-Item .\pg10plv8jsbin_w64\* .\pgsql -Recurse -Force

Write-Output "Archiving $plv8_package"
[System.IO.Compression.ZipFile]::CreateFromDirectory("$baseDir\pgsql", $plv8_package, `
    [System.IO.Compression.CompressionLevel]::Optimal, $true)

# packaging
$packageVersion = $version.Replace('-', '.')
if ($build_number -ne 0) {
    $packageVersion = $packageVersion + "-build" + $build_number.ToString().PadLeft(5,'0')
}

Write-Output "Creating nuget packages..."
.\nuget.exe pack .\postgresql.binaries.lite.nuspec -version $packageVersion
.\nuget.exe pack .\postgresql.binaries.lite.plv8.nuspec -version $packageVersion

if ($nugetApiKey) {
    Write-Output "Publishing nuget packages..."
    .\nuget.exe push "postgresql.binaries.lite.$packageVersion.nupkg" $nugetApiKey -source https://api.nuget.org/v3/index.json
    .\nuget.exe push "postgresql.binaries.lite.plv8.$packageVersion.nupkg" $nugetApiKey -source https://api.nuget.org/v3/index.json
}
