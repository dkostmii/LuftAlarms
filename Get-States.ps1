<#

.SYNOPSIS
Fetch states, cities and districts.

.DESCRIPTION
Script to fetch states, cities and districts from API.

.PARAMETER JSON
Output result as JSON data?

.PARAMETER Write
Write JSON result to "states.json"? Usable only with -JSON parameter.

.EXAMPLE
PS> .\Get-States

.EXAMPLE
PS> .\Get-States -JSON

.EXAMPLE
PS> .\Get-States -JSON -Write

#>

param(
    [switch] $JSON = $false,
    [switch] $Write = $false
)

$unixMillis = ([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds());
$url = "https://map-static.vadimklimenko.com/statuses.json?t=$unixMillis";

try {
    $response = Invoke-RestMethod $url -Method GET -ContentType "application/json";
}
catch {
    throw "Помилка при завантаженні ";
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

if ($json -and $write) {
    if (-not (Test-Path ".\states.json" -PathType Leaf)) {
        New-Item -ItemType File -Path ".\states.json";
    }
    Set-Content -Path ".\states.json" -Value $jsonResponseArray;
    Write-Output "Output written to states.json";
}
elseif ($json) {
    return $jsonResponseArray;
}
else {
    return $responseArray;
}
