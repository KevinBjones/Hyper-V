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

    $vms = Get-MyVMs

    foreach ($vm in $vms) {

        [double]$cpuUsage = 0
        [double]$memoryUsed = 0
        
        $cpuUsage = [math]::Round([double]$vm.'CPUUsage(%)', 2)
        $memoryUsed = [math]::Round([double]$vm.MemoryUsed, 2)
   
        $metrics = @{
            VM_Name        = $vm.Name
            CPU_Usage      = $cpuUsage
            Memory_Used_MB = $memoryUsed
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
        Token        = $Secret:influxToken
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
