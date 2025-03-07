﻿<#

DISCLAIMER: ChatGPT is gebruikt voor troubleshooting van logica, foutafhandeling, parsing en algemene coding sparring partner. 

#>

function InfluxFetchHost {
    param (
        [string]$Query = @"
from(bucket: "Hyper_V")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "SystemMetrics")
  |> filter(fn: (r) => r._field == "CPU_Usage" or r._field == "Memory_Used_MB")
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: 100)
"@,
        [string]$Bucket = $Secret:influxBucket,
        [string]$Org = $Secret:influxOrg,
        [string]$Server = $Secret:influxServer,
        [string]$Token = $Secret:influxToken
    )

    $url = "$Server/api/v2/query?org=$Org"

    $body = @{
        query = $Query
    } | ConvertTo-Json

    $headers = @{
        'Authorization' = "Token $Token"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/csv'
    }

    try {
        $response = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Failed to query InfluxDB: $_"
    }


    
}
