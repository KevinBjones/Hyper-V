Import-Module InfluxFetchHost
Import-Module InfluxFetchVM
Import-Module Get-MyVms

$isoFiles = Get-ChildItem -Path 'C:\Hyper-V\ISO' -Filter '*.iso' -File |
Select-Object -ExpandProperty Name

#----------------------------------------------------------------------------------
# Host Monitor Page
#----------------------------------------------------------------------------------

$HostMonitorPage = New-UDPage -Name 'Host Monitor' -Url '/monitor/host' -Content {


    $uptime = Get-Uptime
    $formattedUptime = "{0}d {1}h {2}m {3}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

    $totalMemoryMB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskTotal = $disk.Size / 1GB
    $diskTotalRounded = [math]::Round($diskTotal)
    $diskFree = $disk.FreeSpace / 1GB
    $diskUsed = $diskTotal - $diskFree

    $influxData = InfluxFetchHost
    $parsedData = $influxData | ConvertFrom-Csv

    $cpuData = $parsedData | Where-Object { $_._field -eq 'CPU_Usage' } | Sort-Object { [datetime]$_._time }
    $cpuChartData = $cpuData | ForEach-Object {
        [PSCustomObject]@{
            Time  = [datetime]$_._time
            Value = [double]$_._value
        }
    }

    $memoryData = $parsedData | Where-Object { $_._field -eq 'Memory_Used_MB' } | Sort-Object { [datetime]$_._time }
    $memoryChartData = $memoryData | ForEach-Object {
        [PSCustomObject]@{
            Time  = [datetime]$_._time
            Value = [double]$_._value
        }
    }

    $diskChartData = @(
        [PSCustomObject]@{
            Label = 'Used Disk (GB)'
            Value = [Math]::Round($diskUsed, 2)
        }
        [PSCustomObject]@{
            Label = 'Free Disk (GB)'
            Value = [Math]::Round($diskFree, 2)
        }
    )

    

    $cpuChartOptions = @{
        plugins = @{
            title = @{
                display = $true
                text    = 'Hypervisor CPU Usage'
                font    = @{
                    size   = 24
                    weight = 'bold'
                }
            }
        }
        scales  = @{
            x = @{
                type  = 'time'
                time  = @{
                    unit = 'minute'
                }
                title = @{
                    display = $true
                    text    = 'Time'
                }
            }
            y = @{
                title = @{
                    display = $true
                    text    = 'Percentage CPU Used'
                }
            }
        }
    }
        
    $memoryChartOptions = @{
        plugins = @{
            title = @{
                display = $true
                text    = 'Hypervisor Memory Usage'
                font    = @{
                    size   = 24
                    weight = 'bold'
                }
            }
        }
        scales  = @{
            x = @{
                type  = 'time'
                time  = @{
                    unit = 'minute'
                }
                title = @{
                    display = $true
                    text    = 'Time'
                }
            }
            y = @{
                title = @{
                    display = $true
                    text    = 'MB'
                }
            }
        }
    }

    $pieChartOptions = @{
        plugins = @{
            title = @{
                display = $true
                text    = 'Disk Usage - C:'
                font    = @{
                    size   = 24
                    weight = 'bold'
                }
            }
        }
    }
    
    $layout = '{
    "lg": [
      {
        "w": 3,
        "h": 10,
        "x": 0,
        "y": 0,
        "i": "grid-element-hostInfo",
        "moved": false,
        "static": false
      },
      {
        "w": 4,
        "h": 11,
        "x": 3,
        "y": 0,
        "i": "grid-element-cpuChart",
        "moved": false,
        "static": false
      },
      {
        "w": 4,
        "h": 13,
        "x": 7,
        "y": 0,
        "i": "grid-element-memoryChart",
        "moved": false,
        "static": false
      },
      {
        "w": 2,
        "h": 3,
        "x": 6,
        "y": 13,
        "i": "grid-element-diskChart",
        "moved": false,
        "static": false
      }
    ]
  }'
  
    New-UDGridLayout -Layout $layout -Content {
    
        New-UDCard -Id 'hostInfo' -Style @{
            'text-align'  = 'center'
            'padding-top' = '10px'
        } -Content {
            New-UDTypography -Text "Host Information" -Variant "h3" -GutterBottom
            New-UDTypography -Text "Hostname: $env:computername" -Variant "h5" -GutterBottom
            New-UDTypography -Text "Runtime: $formattedUptime" -Variant "h5" -GutterBottom
            New-UDTypography -Text "Total Memory: $totalMemoryMB MB" -Variant "h5" -GutterBottom
            New-UDTypography -Text "Total Disk Space: $diskTotalRounded GB" -Variant "h5" -GutterBottom
            
       
        }
      
        New-UDChartJS -Id 'cpuChart' -Type 'line' -Data $cpuChartData -LabelProperty 'Time' -DataProperty 'Value' -Options $cpuChartOptions 
        New-UDChartJS -Id 'memoryChart' -Type 'line' -Data $memoryChartData -LabelProperty 'Time' -DataProperty 'Value' -Options $memoryChartOptions 
        New-UDChartJS -Id 'diskChart' -Type 'pie' `
            -Data           $diskChartData `
            -LabelProperty  'Label' `
            -DataProperty   'Value' `
            -Options        $pieChartOptions `
            -BackgroundColor @(
            'rgba(255, 99, 132, 0.2)',
            'rgba(54, 162, 235, 0.2)'
        ) `
            -BorderColor @(
            'rgba(255, 99, 132, 1)',
            'rgba(54, 162, 235, 1)'
        ) `
            -BorderWidth 1

        New-UDButton -Text "Home" -OnClick {
            Invoke-UDRedirect -Url "/"
        }
    }
}

#----------------------------------------------------------------------------------
# VM Monitor Page
#----------------------------------------------------------------------------------

$VMMonitorPage = New-UDPage -Name 'Monitor' -Url '/monitor/:vmName' -Content {
    $vm = Get-MyVMs -Name $vmName
    $uptime = $vm.uptime
    $assignedMemory = $vm.memoryAssigned
    $vhd = (Get-VM -Name $vmName).HardDrives | Get-VHD
    $vmDiskUsed = $vhd.FileSize / 1GB
    $vmDiskMax = $vhd.Size / 1GB
    $vmDiskFree = $vmDiskMax - $vmDiskUsed
    # New-UDTypography -Text $vm
    $influxData = InfluxFetchVM -VMName $vmName
    $parsedData = $influxData | ConvertFrom-Csv
    #New-UDTypography -Text $influxData

    $cpuData = $parsedData | Where-Object { $_._field -eq 'CPU_Usage' } | Sort-Object { [datetime]$_._time }
    #New-UDTypography -Text "cpu data: $cpuData"
    #New-UDTypography -Text "all data: $influxData"
    $cpuChartData = $cpuData | ForEach-Object {
        [PSCustomObject]@{
            Time  = [datetime]$_._time
            Value = [double]$_._value
        }
    }

    $memoryData = $parsedData | Where-Object { $_._field -eq 'Memory_Used_MB' } | Sort-Object { [datetime]$_._time }
    $memoryChartData = $memoryData | ForEach-Object {
        [PSCustomObject]@{
            Time  = [datetime]$_._time
            Value = [double]$_._value
        }
    }

    $diskChartData = @(
        [PSCustomObject]@{
            Label = 'Used Disk (GB)'
            Value = [Math]::Round($vmDiskUsed, 2)
        }
        [PSCustomObject]@{
            Label = 'Free Disk (GB)'
            Value = [Math]::Round($vmDiskFree, 2)
        }
    )

    

    $cpuChartOptions = @{
        plugins = @{
            title = @{
                display = $true
                text    = 'CPU Usage'
                font    = @{
                    size   = 24
                    weight = 'bold'
                }
            }
        }
        scales  = @{
            x = @{
                type  = 'time'
                time  = @{
                    unit = 'minute'
                }
                title = @{
                    display = $true
                    text    = 'Time'
                }
            }
            y = @{
                title = @{
                    display = $true
                    text    = 'Percentage CPU Used'
                }
            }
        }
    }
        
    $memoryChartOptions = @{
        plugins = @{
            title = @{
                display = $true
                text    = 'Memory Usage'
                font    = @{
                    size   = 24
                    weight = 'bold'
                }
            }
        }
        scales  = @{
            x = @{
                type  = 'time'
                time  = @{
                    unit = 'minute'
                }
                title = @{
                    display = $true
                    text    = 'Time'
                }
            }
            y = @{
                title = @{
                    display = $true
                    text    = 'MB'
                }
            }
        }
    }

    $pieChartOptions = @{
        plugins = @{
            title = @{
                display = $true
                text    = 'Disk Usage - Virtual Disk'
                font    = @{
                    size   = 24
                    weight = 'bold'
                }
            }
        }
    }
    
    $layout = '{
    "lg": [
      {
        "w": 3,
        "h": 10,
        "x": 0,
        "y": 0,
        "i": "grid-element-hostInfo",
        "moved": false,
        "static": false
      },
      {
        "w": 4,
        "h": 11,
        "x": 3,
        "y": 0,
        "i": "grid-element-cpuChart",
        "moved": false,
        "static": false
      },
      {
        "w": 4,
        "h": 13,
        "x": 7,
        "y": 0,
        "i": "grid-element-memoryChart",
        "moved": false,
        "static": false
      },
      {
        "w": 2,
        "h": 3,
        "x": 6,
        "y": 13,
        "i": "grid-element-diskChart",
        "moved": false,
        "static": false
      }
    ]
  }'
  
    New-UDGridLayout -Layout $layout -Content {
    
        New-UDCard -Id 'hostInfo' -Style @{
            'text-align'  = 'center'
            'padding-top' = '10px'
        } -Content {
            New-UDTypography -Text "Host Information" -Variant "h3" -GutterBottom
            New-UDTypography -Text "Hostname: $vmname" -Variant "h5" -GutterBottom
            New-UDTypography -Text "Runtime: $uptime" -Variant "h5" -GutterBottom
            New-UDTypography -Text "Total Memory: $assignedMemory MB" -Variant "h5" -GutterBottom
            New-UDTypography -Text "Total Disk Space: $vmDiskMax GB" -Variant "h5" -GutterBottom
            
       
        }
      
        New-UDChartJS -Id 'cpuChart' -Type 'line' -Data $cpuChartData -LabelProperty 'Time' -DataProperty 'Value' -Options $cpuChartOptions 
        New-UDChartJS -Id 'memoryChart' -Type 'line' -Data $memoryChartData -LabelProperty 'Time' -DataProperty 'Value' -Options $memoryChartOptions 
        New-UDChartJS -Id 'diskChart' -Type 'pie' `
            -Data           $diskChartData `
            -LabelProperty  'Label' `
            -DataProperty   'Value' `
            -Options        $pieChartOptions `
            -BackgroundColor @(
            'rgba(255, 99, 132, 0.2)',
            'rgba(54, 162, 235, 0.2)'
        ) `
            -BorderColor @(
            'rgba(255, 99, 132, 1)',
            'rgba(54, 162, 235, 1)'
        ) `
            -BorderWidth 1

        New-UDButton -Text "Home" -OnClick {
            Invoke-UDRedirect -Url "/"
        }
    }
}

#----------------------------------------------------------------------------------
#Home page
#----------------------------------------------------------------------------------

$HomePage = New-UDPage -Name 'Home' -Url '/' -Content {

    New-UDTypography -Text "Hyper-V Manager" -Variant "h4"
    New-UDButtonGroup -Children {
        New-UDButtonGroupItem -Text "Create VM" -OnClick {
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
        New-UDButtonGroupItem -Text "Refresh" -OnClick {
            Sync-UDElement -Id "vmTable"
        }
        New-UDButtonGroupItem -Text "Monitor Hypervisor" -OnClick {
            Invoke-UDRedirect -Url "/monitor/host"
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
                New-UDTableColumn -Property "Edit"              -Title "Edit" -Render {
                    New-UDIconButton -Icon (New-UDIcon -Icon "Wrench") -OnClick {
                        $currentVM = Get-VM -Name $EventData.Name
                        $currentName = $currentVM.Name
                        $currentMemoryMB = [int]($currentVM.MemoryStartup / 1MB)

                        Show-UDModal -Content {
                            New-UDTypography -Text "Edit VM '$($EventData.Name)'" -Variant "h5"
                            New-UDForm -Content {
                                New-UDTextbox -Id "editVMName" -Label "VM Name" -Value $currentName
                                New-UDTextbox -Id "editMemorySize" -Label "Memory Size (MB)" -Value $currentMemoryMB
                            } -OnSubmit {
                                $newName = (Get-UDElement -Id "editVMName").Value
                                $newMemorySize = [int](Get-UDElement -Id "editMemorySize").Value
                    
                                try {
                                    if ($newName -ne $currentName) {
                                        Rename-VM -Name $currentName -NewName $newName
                                        $currentName = $newName
                                    }
                                    Set-VM -Name $currentName -MemoryStartupBytes ($newMemorySize * 1MB)
                                    Show-UDToast -Message "VM '$currentName' updated successfully." -Duration 4000
                                }
                                catch {
                                    Show-UDToast -Message "Error editing VM: $_" -Duration 5000
                                }
                    
                                Sync-UDElement -Id "vmTable"
                                Hide-UDModal
                            }
                        } -Footer {
                            New-UDButton -Text "Close" -OnClick { Hide-UDModal }
                        }


                    }
                }
                


                New-UDTableColumn -Property "Monitoring"              -Title "Monitoring Data" -Render {
                    New-UDButton -Icon(New-UDIcon -Icon "Heartbeat") -OnClick {
                        $vmName = $EventData.Name
                        Invoke-UDRedirect -Url "/monitor/$($vmName)"
                    }
                }
                New-UDTableColumn -Property "Delete"              -Title "Delete" -Render {
                    New-UDIconButton -Icon (New-UDIcon -Icon "Trash") -OnClick {
                        $vmName = $EventData.Name
                        Remove-VM $vmName

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
    $HostMonitorPage,
    $VMMonitorPage
)
