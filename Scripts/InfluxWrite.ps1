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

# Collect CPU% and Memory Used (MB) via Get-MyVMs and create consistency in fields (value returns null if the value is N/A)
function Get-VMSystemMetrics {
   
    $vmMetricsList = @()
    foreach ($vm in Get-MyVMs) {
        $cpuRaw = $vm.'CPUUsage(%)' -as [double]
        $memRaw = $vm.MemoryUsed -as [double]

        # Build an ordered record for input in InfluxDB
        $vmMetricsList += [ordered]@{
            VM_Name        = $vm.Name
            IsRunning      = ($vm.State -eq 'Running')   
            CPU_Usage      = if ($cpuRaw -ne $null) { [math]::Round($cpuRaw, 2) } else { 0 }
            Memory_Used_MB = if ($memRaw -ne $null) { [math]::Round($memRaw, 2) } else { 0 }
        }
    }
    $vmMetricsList
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
