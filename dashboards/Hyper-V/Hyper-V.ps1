#----------------------------------------------------------------------------------
# Get vm function
#----------------------------------------------------------------------------------

function Get-MyVMs {
    Get-VM |
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
                $memoryDemand   = [math]::Round($_.MemoryDemand / 1MB, 2)
                "$memoryDemand MB / $memoryAssigned MB"
            }
            else {
                'N/A'
            }
        }
    }, @{
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
    }, 
    @{
        Name       = 'Toggle'
        Expression = { $_.Name }
    },
    @{
        Name       = 'Restart'
        Expression = { $_.Name }
    },
    @{
        Name       = 'Monitor'
        Expression = { $_.Name }
    }
}


$isoFiles = Get-ChildItem -Path 'C:\Hyper-V\ISO' -Filter '*.iso' -File |
Select-Object -ExpandProperty Name

#----------------------------------------------------------------------------------
# Monitor Page
#----------------------------------------------------------------------------------

$MonitorPage = New-UDPage -Name 'Monitor' -Url '/monitor/:vmName' -Content {

    New-UDTypography -Text "Monitor Page for VM: $vmName" -Variant "h4"
    
    $vm = Get-VM -Name $vmName 
    if ($vm) {
        New-UDTypography -Text "VM State: $($vm.State)"
    } else {
        New-UDTypography -Text "VM '$vmName' was not found."
    }

    New-UDButton -Text "Home" -OnClick {
        Invoke-UDRedirect -Url "/"
    }
}

#----------------------------------------------------------------------------------
#Home page
#----------------------------------------------------------------------------------

$HomePage = New-UDPage -Name 'Home' -Url '/' -Content {

    New-UDTypography -Text "Hyper-V Manager" -Variant "h4"
   
    New-UDRow -Columns {
        New-UDColumn -Content {
            New-UDButton -Text "Refresh" -OnClick {
                Sync-UDElement -Id "vmTable"
            }
        }
        New-UDColumn -Content {
            New-UDButton -Text "Create VM" -OnClick {
                Show-UDModal -Content {
                    New-UDTypography -Text "Create New VM" -Variant "h5"
                    New-UDForm -Content {
                        New-UDTextbox -Id "vmName" -Label "VM Name" 
                        New-UDTextbox -Id "memorySize" -Label "Memory Size (MB)" 
                        New-UDTextbox -Id "diskSize" -Label "Disk Size (GB)" 
                        New-UDSelect -Id "isoSelect" -Label "Select an ISO" -Option {
                            foreach ($iso in $isoFiles) {
                                New-UDSelectOption -Name $iso -Value $iso
                            }
                        }
                    } -OnSubmit {
                        $vmName = (Get-UDElement -Id "vmName").Value
                        $memorySize = [int](Get-UDElement -Id "memorySize").Value
                        $diskSize = [int](Get-UDElement -Id "diskSize").Value
                        $selectedISO = (Get-UDElement -Id "isoSelect").Value

                        New-VM -Name $vmName `
                               -MemoryStartupBytes ($memorySize * 1MB) `
                               -NewVHDPath "C:\Hyper-V\Disk\$vmName.vhdx" `
                               -NewVHDSizeBytes ($diskSize * 1GB)

                        Enable-VMResourceMetering -VMName $vmName
                        Set-VMDvdDrive -VMName $vmName -Path "C:\Hyper-V\ISO\$selectedISO"

                        Show-UDToast -Message "$vmName, $memorySize, $diskSize" -Duration 3000
                        try {
                            New-VM -Name $vmName `
                                   -MemoryStartupBytes ($memorySize * 1MB) `
                                   -NewVHDPath "C:\Hyper-V\Disk\$vmName.vhdx" `
                                   -NewVHDSizeBytes ($diskSize * 1GB)

                            Show-UDToast -Message "VM '$vmName' created successfully." -Duration 3000
                        }
                        catch {
                            Show-UDToast -Message "Error creating VM: $_" -Duration 5000 
                        }

                        Sync-UDElement -Id "vmTable"
                        Hide-UDModal
                    }
                } -Footer {
                    New-UDButton -Text "Close" -OnClick { Hide-UDModal }
                }
            }
        }
    }
#----------------------------------------------------------------------------------
#VM Tabel
#----------------------------------------------------------------------------------

    New-UDDynamic -Id "vmTable" -Content {
        
        $vms = Get-MyVMs 

        if (-not $vms -or $vms.Count -eq 0) {
            New-UDTypography -Text "No VMs created." -Variant "subtitle1"
        }
        else {
            New-UDTable -Data $vms -Columns @(
                New-UDTableColumn -Property "Name"               -Title "Name"
                New-UDTableColumn -Property "State"              -Title "State"
                New-UDTableColumn -Property "Uptime"             -Title "Uptime"
                New-UDTableColumn -Property "MemoryUsage"        -Title "Average Memory Usage"
                New-UDTableColumn -Property "AverageCPUUsageMHz" -Title "Average CPU Usage (MHz)"
                New-UDTableColumn -Property "IPAddress"          -Title "IP Address"
                New-UDTableColumn -Property "Power"              -Title "Toggle Power" -Render {
                    New-UDIconButton -Icon (New-UDIcon -Icon "PowerOff") -OnClick {
                        if ((Get-VM -Name $EventData.Name).State -eq 'Running') {
                            Stop-VM -Name $EventData.Name
                            Show-UDToast -Message "Stopped $($EventData.Name)"
                        }
                        else {
                            Start-VM -Name $EventData.Name
                            Show-UDToast -Message "Started $($EventData.Name)"
                        }
                        Sync-UDElement -Id "vmTable"
                    }
                }

                New-UDTableColumn -Property "Restart"              -Title "Restart" -Render {
                    New-UDIconButton -Icon (New-UDIcon -Icon "Sync") -OnClick {
                        if ((Get-VM -Name $EventData.Name).State -eq 'Running') {
                            Restart-VM -Name $EventData.Name
                            Show-UDToast -Message "Restarted $($EventData.Name)"
                        }
                        else {
                            Show-UDToast -Message "$($EventData.Name) is not running. Cannot restart."
                        }
                        Sync-UDElement -Id "vmTable"
                    }
                }

                New-UDTableColumn -Property "Monitoring"              -Title "Monitoring Data" -Render {
                    New-UDButton -Icon(New-UDIcon -Icon "Heartbeat") -OnClick {
                        $vmName = $EventData.Name
                        Invoke-UDRedirect -Url "/monitor/$($vmName)"
                    }
                }
            )
        }
    } -AutoRefresh -AutoRefreshInterval 10

}

#----------------------------------------------------------------------------------
#App creation
#----------------------------------------------------------------------------------

New-UDApp -Title "Hyper-V Manager" -Pages @(
    $HomePage,
    $MonitorPage
)
