Import-Module Influx
function Get-SystemMetrics {

    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $totalMemoryMB = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1MB
    $availableMemoryMB = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1KB

    $usedMemoryMB = $totalMemoryMB - $availableMemoryMB

    return @{
        CPU_Usage_Percent = [math]::Round($cpuUsage, 2)
        Memory_Used_MB    = [math]::Round($usedMemoryMB, 2)
    }
}

function Write-MetricsToInflux {
    param (
        [hashtable]$Metrics
    )

    $influxParams = @{
        Measure      = 'SystemMetrics'
        Tags         = @{ Host = $env:COMPUTERNAME }
        Metrics      = $Metrics
        Bucket       = 'Hyper_V'                  
        Server       = 'http://localhost:8086'
        Token        = 'QgVqXUdAnblkjmTtPvr7T_62naiXJ3uDPfouIZorWVWfLzWGRBPfIhP-DxcsqGZRFg20UwQbfBEDqpHd3Utu4A=='  
        Organisation = 'BjoCorp'     
    }

    Write-Influx @influxParams
}

$metrics = Get-SystemMetrics
Write-MetricsToInflux -Metrics $metrics
