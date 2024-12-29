﻿#----------------------------------------------------------------------------------
# Get vm function
#----------------------------------------------------------------------------------

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
    }, @{
        Name       = 'Toggle'
        Expression = { $_.Name }
    }, @{
        Name       = 'Restart'
        Expression = { $_.Name }
    }, @{
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

    $vm = Get-MyVMs -Name $vmName

    New-UDTypography -Text "All VM Data: $($vm)"

    $memAssigned = $vm.MemoryAssigned
    $memUsage = $vm.MemoryUsed
    $memFree = $memAssigned - $memUsage

    $chartData = @(
        [PSCustomObject]@{ Label = 'Used Memory (MB)'; Value = $memUsage }
        [PSCustomObject]@{ Label = 'Free Memory (MB)'; Value = $memFree }
    )


    $chartOptions = @{
        aspectRatio = 0, 1
        plugins     = @{
            title = @{
                display = $true
                text    = "Assigned Memory: $memAssigned"
            }
        }
    }

    New-UDRow -Columns {
        New-UDColumn -LargeSize 6 -Content {
            New-UDChartJS -Type 'pie' -Data $chartData -LabelProperty 'Label' -DataProperty 'Value' -Options $chartOptions -BackgroundColor @('rgba(255, 99, 132, 0.2)', 'rgba(54, 162, 235, 0.2)') -BorderColor @('rgba(255, 99, 132, 1)', 'rgba(54, 162, 235, 1)') -BorderWidth 1
        }
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

                        
                        

                        Show-UDToast -Message "$vmName, $memorySize, $diskSize" -Duration 3000
                        try {
                            New-VM -Name $vmName `
                                -MemoryStartupBytes ($memorySize * 1MB) `
                                -NewVHDPath "C:\Hyper-V\Disk\$vmName.vhdx" `
                                -NewVHDSizeBytes ($diskSize * 1GB)
                            Set-VMDvdDrive -VMName $vmName -Path "C:\Hyper-V\ISO\$selectedISO"
                            Enable-VMResourceMetering -VMName $vmName
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
