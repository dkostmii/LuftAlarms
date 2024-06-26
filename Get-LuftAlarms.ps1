<#

.SYNOPSIS
Observe air raid alerts in PowerShell terminal.

.DESCRIPTION
Script to observe air raid alerts in PowerShell terminal in states, cities and districts.  Updates information every 20 seconds.

.PARAMETER AlarmOnly
Output only places with active alerts.

.PARAMETER District
Output all districts in state too.

.PARAMETER NoWatch
Exit script after result, instead of watching for alerts every 20 seconds. Combines with every other parameter.

.EXAMPLE
.\Get-LuftAlarms

.EXAMPLE
.\Get-LuftAlarms -AlarmOnly

.EXAMPLE
.\Get-LuftAlarms -District

.EXAMPLE
.\Get-LuftAlarms -AlarmOnly -District

.EXAMPLE
.\Get-LuftAlarms -AlarmOnly -NoWatch

#>

param(
    [switch] $AlarmOnly = $false,
    [switch] $District = $false,
    [switch] $NoWatch = $false
)

$alarmStr = " ---> Тривога";
$alarmDistrStr = " ---> Тривога в районі"
$calmStr = " - Спокійно";


function Get-Info {
    $info = ./Get-States.ps1;

    return $info | Where-Object { $_.name.Count -gt 0 } | ForEach-Object {
        @{ name = $_.name; enabled = $false; districts = $_.districts | ForEach-Object {
            @{ name = $_.name; enabled = $false; }
        }; }
    };
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
            if ($_.enabled -or ($districtCount -gt 0)) {
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
            };
        }
    };
}


function Get-Luftalarms {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $info
    )

    $unixMillis = ([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds());
    $url = "https://vadimklimenko.com/map/statuses.json?t=$unixMillis";

    $response = Invoke-RestMethod $url -Method GET -ContentType "application/json";

    Write-Result($response.states.psobject.properties | ForEach-Object {
        @{
            name = $_.Name;
            enabled = $_.Value.enabled;
            districts = $_.Value.districts.psobject.properties | ForEach-Object {
                @{ name = $_.Name; enabled = $_.Value.enabled; };
            };
        }
    });
}


function Work {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $info
    )

    Write-Host "Повітряні тривоги: `n" -ForegroundColor Magenta;
    try {
        Get-Luftalarms -info $info;
    }
    catch {
        Write-Host "Помилка при завантаженні інформації про тривоги!" -ForegroundColor Red;
    }
    Write-Output "";
}


function Startup {
    $info = Get-Info
    if (-not ($NoWatch)) {
        while ($true) {
            Work $info;
            $counter = 0;
            Write-Host -NoNewLine "Наступне оновлення через $(20 - $counter) секунд...  `r";
            Start-Sleep -Seconds 1;
            while ($counter -lt 20) {
                $counter++;
                Write-Host -NoNewLine "Наступне оновлення через $(20 - $counter) секунд...  `r";
                Start-Sleep -Seconds 1;
            }
            Write-Output "";
        }
    }
    else {
        Work $info;
    }
}

Startup;
