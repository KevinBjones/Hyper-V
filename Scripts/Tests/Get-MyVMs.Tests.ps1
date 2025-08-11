<#

DISCLAIMER: ChatGPT is gebruikt voor troubleshooting van logica, foutafhandeling, parsing en algemene coding sparring partner. 

#>
BeforeAll {
    Remove-Module Get-MyVMs
    Import-Module "C:\ProgramData\UniversalAutomation\Repository\Modules\Get-MyVMs\1.0\Get-MyVMs.psm1"
    
    Mock Get-VM
    Mock Get-VMNetworkAdapter
    Mock Measure-VM
}

Describe "Get-MyVMs" {
    
    Context "Running VMs" -Tag "Core" {
        BeforeEach {
            # Setup a mock VM in Running state with initialised metrics
            $mockRunningVM = [PSCustomObject]@{
                Name           = "VM1"
                State          = "Running"
                Uptime         = New-TimeSpan -Days 2 -Hours 3 -Minutes 15 -Seconds 30
                MemoryAssigned = 2147483648  
                MemoryDemand   = 1610612736  
                CPUUsage       = 25
            }
            
            Mock Get-VM { $mockRunningVM }
            
            Mock Get-VMNetworkAdapter {
                [PSCustomObject]@{
                    IPAddresses = @("10.10.0.5")
                }
            }
            
            Mock Measure-VM {
                [PSCustomObject]@{
                    AverageProcessorUsage = 1500
                }
            }
        }
        
        It "Should return formatted uptime" {
            # Verifies uptime is formatted correctly for running VMs
            $result = Get-MyVMs
            $result[0].Uptime | Should -Be "2d 3h 15m 30s"
        }
        
        It "Should calculate memory metrics correctly" {
            # Tests memory conversion from bytes to MB and proper formatting
            $result = Get-MyVMs
            $result[0].MemoryUsage | Should -Be "1536 MB / 2048 MB"
            $result[0].MemoryAssigned | Should -Be 2048
            $result[0].MemoryUsed | Should -Be 1536
        }

<#
        It "Should include CPU metrics" {
            $result = Get-MyVMs
            $result[0].'CPUUsage(%)' | Should -Be 25
            $result[0].AverageCPUUsageMHz | Should -Be 1500
        }
 #>       
        It "Should include IPv4 address" {
            # Confirms IPv4 addresses are properly extracted from network adapter
            $result = Get-MyVMs
            $result[0].IPAddress | Should -Be "10.10.0.5"
        }
    }
    
    Context "Stopped VMs" -Tag "Core" {
        BeforeEach {
            # Setup a mock VM in Off state
            $mockStoppedVM = [PSCustomObject]@{
                Name           = "StoppedVM"
                State          = "Off"
                Uptime         = $null
                MemoryAssigned = 0
                MemoryDemand   = 0
                CPUUsage       = 0
            }
            
            Mock Get-VM { $mockStoppedVM }
        }
        
        It "Should show N/A for all metrics when VM is stopped" {
            # All performance metrics display "N/A" for non-running VMs
            $result = Get-MyVMs
            
            $result[0].State | Should -Be "Off"
            $result[0].Uptime | Should -Be "N/A"
            $result[0].MemoryUsage | Should -Be "N/A"
            $result[0].MemoryAssigned | Should -Be "N/A"
            $result[0].MemoryUsed | Should -Be "N/A"
#            $result[0].AverageCPUUsageMHz | Should -Be "N/A"
            $result[0].'CPUUsage(%)' | Should -Be "N/A"
            $result[0].IPAddress | Should -Be "N/A"
        }
    }
    
    Context "Name Filtering" -Tag "Filtering" {
        BeforeEach {
            # Setup multiple mock VMs for testing filtering functionality
            $mockVMs = @(
                [PSCustomObject]@{
                    Name           = "VM1"
                    State          = "Running"
                    Uptime         = New-TimeSpan -Hours 1
                    MemoryAssigned = 1073741824
                    MemoryDemand   = 536870912
                    CPUUsage       = 10
                },
                [PSCustomObject]@{
                    Name           = "VM2"
                    State          = "Running"
                    Uptime         = New-TimeSpan -Hours 2
                    MemoryAssigned = 2147483648
                    MemoryDemand   = 1073741824
                    CPUUsage       = 20
                }
            )
            
            Mock Get-VM { $mockVMs }
            Mock Get-VMNetworkAdapter { [PSCustomObject]@{ IPAddresses = @("10.10.0.5") } }
            Mock Measure-VM { [PSCustomObject]@{ AverageProcessorUsage = 100 } }
        }
        
        It "Should filter by exact name when specified" {
            # Tests that -Name parameter returns only the VM with exact matching name
            $result = Get-MyVMs -Name "VM1"
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "VM1"
        }
        
        It "Should return all VMs when no name specified" {
            # Verifies all VMs are returned when no filter is applied
            $result = Get-MyVMs
            $result.Count | Should -Be 2
        }
        
        It "Should return nothing for non-existent VM name" {
            # Ensures empty result when filtering for a VM that doesn't exist
            $result = Get-MyVMs -Name "NonExistent"
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Edge Cases" -Tag "EdgeCase" {
        It "Should handle no VMs" {
            # Tests graceful handling when no VMs exist on the host
            Mock Get-VM { @() }
            $result = Get-MyVMs
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle VMs with no IP addresses" {
            # Verifies "N/A" is shown when VM has no assigned IP addresses
            $mockVM = [PSCustomObject]@{
                Name           = "NoIPVM"
                State          = "Running"
                Uptime         = New-TimeSpan -Hours 1
                MemoryAssigned = 1073741824
                MemoryDemand   = 536870912
                CPUUsage       = 5
            }
            
            Mock Get-VM { $mockVM }
            Mock Get-VMNetworkAdapter { [PSCustomObject]@{ IPAddresses = @() } }
            Mock Measure-VM { [PSCustomObject]@{ AverageProcessorUsage = 100 } }
            
            $result = Get-MyVMs
            $result[0].IPAddress | Should -Be "N/A"
        }
        
        It "Should return all expected properties" {
            # Validates that all custom properties are present in the output object
            $mockVM = [PSCustomObject]@{
                Name           = "VM"
                State          = "Running"
                Uptime         = New-TimeSpan -Hours 1
                MemoryAssigned = 1073741824
                MemoryDemand   = 536870912
                CPUUsage       = 5
            }
            
            Mock Get-VM { $mockVM }
            Mock Get-VMNetworkAdapter { [PSCustomObject]@{ IPAddresses = @("10.10.0.5") } }
            Mock Measure-VM { [PSCustomObject]@{ AverageProcessorUsage = 100 } }
            
            $result = Get-MyVMs
            $properties = $result[0].PSObject.Properties.Name
            
            # Check for presence of all expected custom properties
            @('Name', 'State', 'Uptime', 'MemoryUsage', 'MemoryAssigned', 
              'MemoryUsed', 'AverageCPUUsageMHz', 'CPUUsage(%)', 'IPAddress') | ForEach-Object {
                $properties | Should -Contain $_
            }
        }
    }
}