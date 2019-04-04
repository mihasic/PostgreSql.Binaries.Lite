# PostgreSQL binaries for win64 & linux64 lite

Minimum set of binaries of the PostgreSQL database.

The one in this file contains postgresql-10.6-1-windows-x64.zip, and postgresql-10.6-1-linux-x64.zip without doc, include, pgAdmin 4, StackBuilder and symbols.
So, this package can be consumed from the unit tests.
Sample commands to setup a database cluster would be:

    - extract
    - cd {extractfolder}\pgsql\bin
    - initdb -D ..\data
    - pg_ctl -D ..\data -o "-p {port}" start
    - perform tests
    - pg_ctl -D ..\data stop

By default, this will start a database (postgres) and allow postgres user accessing it locally with any password (auth_method = trust).

### NuGet
    https://www.nuget.org/packages/PostgreSql.Binaries.Lite/
    https://www.nuget.org/packages/PostgreSql.Binaries.Lite.Plv8/

    nuget install PostgreSql.Binaries.Lite

    Install-Package PostgreSql.Binaries.Lite

### Example from one of my projects

``` PowerShell
task RunTests -depends Compile {
    New-Item -ItemType Directory -Force -Path "$artifacts_directory"

    $temp_path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($postgres_binaries, $temp_path)

    $port = 1000
    Write-Host "Extracted PostgreSQL to $temp_path" -foreground Green
    pushd "$temp_path\pgsql\bin"
    .\initdb -D ..\data -E UTF8
    For($i = 0; $i -le 100; $i++)
    {
        $port = 1000 + $i
        # $res = .\pg_ctl -D ..\data -o "-p $port" -w -s start
        $j = start-job { cd $args[0]; .\pg_ctl -D ..\data -o "-p $($args[1])" -w -s start } -ArgumentList $PWD,$port
        Write-Host "Waiting for process to start" -Foreground Green
        # Start-Sleep 5
        Wait-Job -State NotStarted -Timeout 10
        Write-Host $j.JobStateInfo.State -Foreground Yellow
        if ($j.JobStateInfo.State -eq "Running") {
            $res = .\pg_ctl.exe -D "..\data" status
            Write-Host $res -foreground Green
            if ($res -ne "pg_ctl: no server running") {
                Break;
            }
            For($retry = 0; $retry -lt 10; $retry++) {
                if ($j.JobStateInfo.State -eq "Completed") {
                    Break;
                }
                Start-Sleep 3
                $res = .\pg_ctl.exe -D "..\data" status
                Write-Host $res -foreground Yellow
                if ($res -ne "pg_ctl: no server running") {
                    Break;
                }
            }
            if ($j.JobStateInfo.State -eq "Running") {
                Break;
            }
        }
        if ($j.JobStateInfo.State -eq "Completed") {
            Remove-Job $j
            Continue;
        }
        Stop-Job $j
        Remove-Job $j
    }
    popd

    $connection_string = "Server=127.0.0.1;Port=$port;Database=postgres;User Id=$([Environment]::UserName);password=postgres"
    Write-Host "connection_string = $connection_string" -foreground Green
    $connection_string | out-file "$src_directory\$project_name.Tests\bin\Release\connection_string.txt"

    Try
    {
        .$xunit_path "$src_directory\$project_name.Tests\bin\Release\$project_name.Tests.dll" `
            -noshadow -html "$artifacts_directory\$project_name.html"
    }
    Finally
    {
        Write-Host "Stopping PostgreSQL" -foreground Green
        pushd "$temp_path\pgsql\bin"
        .\pg_ctl -D ..\data stop
        Get-Job | Stop-Job
        Get-Job | Remove-Job
        popd
        rm $temp_path -Recurse -Force
    }
}
```

## License
Scripts in this repository are subject to MIT license, PostgreSQL is licensed under: https://www.postgresql.org/about/licence/
