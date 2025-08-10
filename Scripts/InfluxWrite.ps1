<#

DISCLAIMER: ChatGPT is gebruikt voor troubleshooting van logica, foutafhandeling, parsing en algemene coding sparring partner. 

#>

# Write metrics to InfluxDB using Write-Influx from the Influx module
Import-Module Influx
Import-Module Get-MyVMs

# Collect host CPU% and Memory Used
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

# Collect CPU% and Memory Used (MB) via Get-MyVMs
function Get-VMSystemMetrics {
    $vmMetricsList = @()

    $vms = Get-MyVMs

    foreach ($vm in $vms) {

        # Default numeric initialization
        [double]$cpuUsage = 0
        [double]$memoryUsed = 0
        
        # Pull numeric CPU% and memory used (MB)
        $cpuUsage = [math]::Round([double]$vm.'CPUUsage(%)', 2)
        $memoryUsed = [math]::Round([double]$vm.MemoryUsed, 2)
   
        # Shape to hashtable per VM
        $metrics = @{
            VM_Name        = $vm.Name
            CPU_Usage      = $cpuUsage
            Memory_Used_MB = $memoryUsed
        }

        $vmMetricsList += $metrics
    }

    return $vmMetricsList
}

# Influx write wrapper 
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
        Bucket       = $Secret:influxBucket
        Server       = $Secret:influxServer
        Token        = $Secret:influxToken
        Organisation = $Secret:influxOrg
    }

    Write-Influx @influxParams
}

# Push host metrics (tagged by hypervisor name)
$hostMetrics = Get-SystemMetrics
Write-MetricsToInflux -Metrics $hostMetrics -Measure 'SystemMetrics' -HostTag $env:COMPUTERNAME

# Push VM metrics (tagged by VM name)
$vmMetricsList = Get-VMSystemMetrics
foreach ($vmMetrics in $vmMetricsList) {
    $hostTag = $vmMetrics.VM_Name
    $vmMetrics.Remove('VM_Name') 

    Write-MetricsToInflux -Metrics $vmMetrics -Measure 'VMSystemMetrics' -HostTag $hostTag
}
