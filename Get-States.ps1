<#

.SYNOPSIS
Cache states, cities and districts.

.DESCRIPTION
Script to cache states, cities and districts from API in file states.json.

.EXAMPLE
PS> .\Get-States

#>

if (-not (Test-Path ".\states.json" -PathType Leaf)) {
    $unixMillis = ([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds());
    $url = "https://vadimklimenko.com/map/statuses.json?t=$unixMillis";

    try {
        Write-Output "Завантажую інформацію про області, міста та райони..."
        $response = Invoke-RestMethod $url -Method GET -ContentType "application/json";
    }
    catch {
        throw "Помилка при завантаженні";
        exit 1;
    }

    $responseArray = $response.states.psobject.properties | Select-Object @{
        Name = "name";
        Expression = { $_.Name };
    },
    @{
        Name = "districts";
        Expression = { $_.Value.districts.psobject.properties | Select-Object @{ Name = "name"; Expression = { $_.Name }; } };
    };

    $jsonResponseArray = ($responseArray | ConvertTo-Json -Depth 3);

    New-Item -ItemType File -Path ".\states.json" | Out-Null;
    Set-Content -Path ".\states.json" -Value $jsonResponseArray | Out-Null;
    Write-Output "Інформацію записано у states.json";
}
else {
    Write-Output "Інформацію уже записано до states.json. Обробляю..."
    $responseArray = Get-Content "states.json" | ConvertFrom-Json
}

return $responseArray;
