$DebugPreference = 'Continue'

function Get-MyVMs {
    Get-VM | Select-Object -Property Name, State, Uptime
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
            )
        }

    }
}
