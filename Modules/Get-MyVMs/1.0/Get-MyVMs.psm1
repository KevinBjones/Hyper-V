﻿<#

DISCLAIMER: ChatGPT is gebruikt voor troubleshooting van logica, foutafhandeling, parsing en algemene coding sparring partner. 

#>

function Get-MyVMs {
    param(
        [string]$Name
    )

    $vms = Get-VM

    if ($Name) {
        $vms = $vms | Where-Object { $_.Name -eq $Name }
    }

    $vms |
    Select-Object -Property Name, State, @{
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
