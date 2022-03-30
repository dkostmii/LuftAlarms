<#

.SYNOPSIS
Observe air raid alerts in PowerShell terminal.

.DESCRIPTION
Script to observe air raid alerts in PowerShell terminal in states, cities and districts. Consumes two APIs. Updates information every 20 seconds.

.PARAMETER AlarmOnly
Output only places with active alerts.

.PARAMETER District
Output all districts in state too.

.EXAMPLE
.\Get-LuftAlarms

.EXAMPLE
.\Get-LuftAlarms -AlarmOnly

.EXAMPLE
.\Get-LuftAlarms -District

.EXAMPLE
.\Get-LuftAlarms -AlarmOnly -District

#>

param(
    [switch] $AlarmOnly = $false,
    [switch] $District = $false
)

$alarmStr = " ---> Тривога";
$alarmDistrStr = " ---> Тривога в районі"
$calmStr = " - Спокійно";

function Get-Info {
    if ( -not (Test-Path "states.json" -PathType Leaf)) {
        Write-Error "Інформація про області, міста та райони відсутня."
        Exit 1
    }

    $info = Get-Content "states.json" | ConvertFrom-Json

    $info = $info | ForEach-Object {
        @{ name = $_.name; enabled = $false; districts = $_.districts | ForEach-Object {
            @{ name = $_.name; enabled = $false; }
        }; }
    };

    return $info;
}

function Write-Result {
    param(
        [ValidateNotNullOrEmpty()]
        [PSObject] $data
    )

    $data | ForEach-Object {
        $districtCount = 0;
        $_.districts | ForEach-Object {
            if ($_.enabled) {
                $districtCount++;
            }
        }

        $stateMsg = $_.enabled ? $alarmStr : ($districtCount -gt 0 ? $alarmDistrStr : $calmStr);
        if ($AlarmOnly) {
            if ($_.enabled) {
                Write-Host ($_.name + $stateMsg) -ForegroundColor ($_.enabled ? "Red" : ($districtCount -gt 0 ? "Yellow" : "Green"));
            }
        }
        else {
            Write-Host ($_.name + $stateMsg) -ForegroundColor ($_.enabled ? "Red" : ($districtCount -gt 0 ? "Yellow" : "Green"));
        }

        if ($District) {
            $_.districts | ForEach-Object {
                if ($_.name.Count -gt 0) {
                    $districtMsg = $_.enabled ? $alarmStr : $calmStr;
                    if ($AlarmOnly) {
                        if ($_.enabled) {
                            Write-Host "|----$($_.name)$districtMsg" -ForegroundColor ($_.enabled ? "Red" : "Green");
                        }
                    }
                    else {
                        Write-Host "|----$($_.name)$districtMsg" -ForegroundColor ($_.enabled ? "Red" : "Green");
                    }
                }
            }
        }
    }
}

function Get-Luftalarms {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $info
    )

    $unixMillis = ([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds())
    $url = "https://map-static.vadimklimenko.com/statuses.json?t=$unixMillis"

    $response = Invoke-RestMethod $url -Method GET -ContentType "application/json"

    Write-Result($response.states.psobject.properties | ForEach-Object { 
        @{ 
            name = $_.Name;
            enabled = $_.Value.enabled;
            districts = $_.Value.districts.psobject.properties | ForEach-Object {
                @{ name = $_.Name; enabled = $_.Value.enabled; };
            }
        }
    })
}

function Get-LuftalarmsAlt {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $info
    )

    $url = "https://war-api.ukrzen.in.ua/alerts/api/alerts/active.json"

    $response = Invoke-RestMethod $url -Method GET -ContentType "application/json"

    Write-Result ($info | ForEach-Object {
        $infoItem = $_;
        $allAlarms = $response.alerts
        | Select-Object @{ Name = "name"; Expression = { $_.location_title } };

        $stateAlarms = $allAlarms
        | Where-Object { $infoItem.name -like $_.name };

        return @{
            name = $infoItem.name;
            enabled = $stateAlarms.Count -gt 0;
            districts = $infoItem.districts | ForEach-Object {
                $districtItem = $_;

                $districtAlarms = $allAlarms
                | Where-Object { $districtItem.name -like $_.name };

                return @{ 
                    name = $districtItem.name;
                    enabled = $districtAlarms.Count -gt 0;
                };
            }
        };
    })
}

function Work {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $info
    )

    try {
        Write-Host "Джерело 1: `n" -ForegroundColor Magenta
        Get-Luftalarms -info $info
        Write-Output ""
        Write-Host "Джерело 2: `n" -ForegroundColor Magenta
        Get-LuftalarmsAlt -info $info
        Write-Output ""
    }
    catch {
        Write-Error "Помилка при завантаженні інформації про тривоги!"
    }
}

function Startup {
    if (-not (Test-Path "states.json" -PathType Leaf)) {
        Write-Output "Завантажую інформацію про області, міста та райони..."
        try {
            .\Get-States.ps1 -JSON -Write
        }
        catch {
            Write-Error $_.Exception.ToString()
        }
    }

    while ($true) {
        Work (Get-Info)
        $counter = 0
        Write-Host -NoNewLine "Наступне оновлення через $(20 - $counter) секунд...  `r"
        Start-Sleep -Seconds 1
        while ($counter -lt 20) {
            $counter++;
            Write-Host -NoNewLine "Наступне оновлення через $(20 - $counter) секунд...  `r"
            Start-Sleep -Seconds 1
        }
        Write-Output ""
    }
}

Startup
