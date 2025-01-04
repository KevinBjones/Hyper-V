function InfluxFetchVM {
    param (
        [string]$VMName,
        [string]$Query = @"
  from(bucket: "Hyper_V")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "VMSystemMetrics")
  |> filter(fn: (r) => r["Host"] == `"$VMName"`)
  |> filter(fn: (r) => r["_field"] == "CPU_Usage" or r["_field"] == "Memory_Used_MB")
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: 100)
"@,
        [string]$Bucket = 'Hyper_V',
        [string]$Org = 'BjoCorp',
        [string]$Server = 'http://localhost:8086',
        [string]$Token = 'QgVqXUdAnblkjmTtPvr7T_62naiXJ3uDPfouIZorWVWfLzWGRBPfIhP-DxcsqGZRFg20UwQbfBEDqpHd3Utu4A=='
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
