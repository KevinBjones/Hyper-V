<#

DISCLAIMER: ChatGPT is gebruikt voor troubleshooting van logica, foutafhandeling, parsing en algemene coding sparring partner. 

#>

# Helper: returns VMs with computed/readable properties (optionally filter by exact name)
function Get-MyVMs {
    param(
        [string]$Name
    )

    # Base VM list
    $vms = Get-VM

    # Optional exact-name filter
    if ($Name) {
        $vms = $vms | Where-Object { $_.Name -eq $Name }
    }

    # Project a view with derived fields
    $vms |
    Select-Object -Property Name, State, @{
        # Parsed uptime
        Name       = 'Uptime'
        Expression = {
            if ($_.State -eq 'Running') {
                $uptime = $_.Uptime
                "{0}d {1}h {2}m {3}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
            }
            else {
                'N/A'
            }
        }
    }, @{
        # Memory demand vs assigned
        Name       = 'MemoryUsage'
        Expression = {
            if ($_.State -eq 'Running') {
                $memoryAssigned = [math]::Round($_.MemoryAssigned / 1MB, 2)
                $memoryDemand = [math]::Round($_.MemoryDemand / 1MB, 2)
                "$memoryDemand MB / $memoryAssigned MB"
            }
            else {
                'N/A'
            }
        }
    }, @{
        # Assigned memory in MB
        Name       = 'MemoryAssigned'
        Expression = {
            if ($_.State -eq 'Running') {
                [math]::Round($_.MemoryAssigned / 1MB, 2)
            }
            else {
                'N/A'
            }
        }
    },
    @{
        # Used memory in MB based on demand
        Name       = 'MemoryUsed'
        Expression = {
            if ($_.State -eq 'Running') {
                [math]::Round($_.MemoryDemand / 1MB, 2)
            }
            else {
                'N/A'
            }
        }
    },
    @{
        # Average CPU usage in MHz 
        Name       = 'AverageCPUUsageMHz'
        Expression = {
            if ($_.State -eq 'Running') {
                $metrics = Measure-VM -VM $_
                $metrics.AverageProcessorUsage
            }
            else {
                'N/A'
            }
        }
    }, @{
        # CPU usage in percentage
        Name       = 'CPUUsage(%)'
        Expression = {
            if ($_.State -eq 'Running') {
                $_.CPUUsage
            }
            else {
                'N/A'
            }
        }
    },
    @{
        # Extract IP addresses
        Name       = 'IPAddress'
        Expression = {
            if ($_.State -eq 'Running') {
                $ip = ($_ | Get-VMNetworkAdapter).IPAddresses | Where-Object { $_ -match '\d{1,3}(\.\d{1,3}){3}' }
                if ($ip) { $ip -join ', ' } else { 'N/A' }
            }
            else {
                'N/A'
            }
        }
    
    }
}
