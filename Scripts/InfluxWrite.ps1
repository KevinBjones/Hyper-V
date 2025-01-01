Import-Module Influx
Import-Module Get-MyVMs

function Get-SystemMetrics {
    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $totalMemoryMB = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1MB
    $availableMemoryMB = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1KB

    $usedMemoryMB = $totalMemoryMB - $availableMemoryMB

    return @{
        CPU_Usage      = [math]::Round($cpuUsage, 2)
        Memory_Used_MB = [math]::Round($usedMemoryMB, 2)
    }
}

function Get-VMSystemMetrics {
    $vmMetricsList = @()
    $vms = Get-VM
    foreach ($vm in $vms) {
        
        $measure = Measure-VM -VM $vm

        $metrics = @{
            CPU_Usage      = [math]::Round($measure.AverageProcessorUsage, 2)
            Memory_Used_MB = [math]::Round($vm.MemoryDemand / 1MB, 2)
            VM_Name        = $vm.Name
        }

        $vmMetricsList += $metrics
    }
    

    return $vmMetricsList
}

function Write-MetricsToInflux {
    param (
        [hashtable]$Metrics,
        [string]$Measure,
        [string]$HostTag
    )

    $influxParams = @{
        Measure      = $Measure
        Tags         = @{ Host = $HostTag }
        Metrics      = $Metrics
        Bucket       = 'Hyper_V'
        Server       = 'http://localhost:8086'
        Token        = 'QgVqXUdAnblkjmTtPvr7T_62naiXJ3uDPfouIZorWVWfLzWGRBPfIhP-DxcsqGZRFg20UwQbfBEDqpHd3Utu4A=='
        Organisation = 'BjoCorp'
    }

    Write-Influx @influxParams
}

$hostMetrics = Get-SystemMetrics
Write-MetricsToInflux -Metrics $hostMetrics -Measure 'SystemMetrics' -HostTag $env:COMPUTERNAME

$vmMetricsList = Get-VMSystemMetrics
foreach ($vmMetrics in $vmMetricsList) {
    $hostTag = $vmMetrics.VM_Name
    $vmMetrics.Remove('VM_Name') 

    Write-MetricsToInflux -Metrics $vmMetrics -Measure 'VMSystemMetrics' -HostTag $hostTag
}
