param([int]$build_number = 0)


rm *.nupkg
$xml = [xml](gc .\postgresql.binaries.lite.nuspec)
$versionString = $xml.package.metadata.version

$packageVersion = $versionString + "-build" + $build_number.ToString().PadLeft(5,'0')
if ($build_number -eq 0) {
    $packageVersion = $versionString
}

.\nuget.exe pack .\postgresql.binaries.lite.nuspec -version $packageVersion
