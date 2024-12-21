$DebugPreference = 'Continue'

Get-VM | Enable-VMResourceMetering

function Get-MyVMs {
    Get-VM | Select-Object -Property Name, State, @{Name='Uptime';Expression={
        if ($_.State -eq 'Running') {
            $uptime = $_.Uptime
            "{0}d {1}h {2}m {3}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
        } else {
            'N/A'
        }
    }}, @{Name='MemoryUsage';Expression={
        if ($_.State -eq 'Running') {
            $memoryAssigned = [math]::Round($_.MemoryAssigned / 1MB, 2)
            $memoryDemand = [math]::Round($_.MemoryDemand / 1MB, 2)
            "$memoryDemand MB / $memoryAssigned MB"
        } else {
            'N/A'
        }
    }}, @{Name='AverageCPUUsageMHz';Expression={
        if ($_.State -eq 'Running') {
            $metrics = Measure-VM -VM $_
            $metrics.AverageProcessorUsage
        } else {
            'N/A'
        }
    }}, @{Name='IPAddress';Expression={
        if ($_.State -eq 'Running') {
            $ip = ($_ | Get-VMNetworkAdapter).IPAddresses | Where-Object { $_ -match '\d{1,3}(\.\d{1,3}){3}' }
            if ($ip) { $ip -join ', ' } else { 'N/A' }
        } else {
            'N/A'
        }
    }}
}

New-UDApp -Title "Hyper-V Manager" -Content {
    New-UDTypography -Text "Hyper-V Manager" -Variant "h4"

    New-UDButton -Text "Refresh" -OnClick {
        Sync-UDElement -Id "vmTable"
    }

    New-UDDynamic -Id "vmTable" -Content {
        $vms = Get-MyVMs
        $vms | Out-String | Write-Debug

        if ($null -eq $vms -or $vms.Count -eq 0) {
            New-UDTypography -Text "No VMs created." -Variant "subtitle1"
        } else {
            New-UDTable -Data $vms -Columns @(
                New-UDTableColumn -Property "Name" -Title "Name"
                New-UDTableColumn -Property "State" -Title "State"
                New-UDTableColumn -Property "Uptime" -Title "Uptime"
                New-UDTableColumn -Property "MemoryUsage" -Title "Average Memory Usage"
                New-UDTableColumn -Property "AverageCPUUsageMHz" -Title "Average CPU Usage (MHz)"
                New-UDTableColumn -Property "IPAddress" -Title "IP Address"
            )
        }
    }
}
