#Loads Get-MyVMs and makes sure the cmdlets being called in the module are replaced with the mocks in this test
BeforeAll {
  Import-Module "C:\ProgramData\UniversalAutomation\Repository\Modules\Get-MyVMs\1.0\Get-MyVMs.psm1" -Force
  $PSDefaultParameterValues['Mock:ModuleName'] = 'Get-MyVMs'
}

Describe "Get-MyVMs" {
  BeforeEach {

    # Creates two fake VM's with predefined data. One is turned on, the other is turned off.
    $fakeVMs = @(
      [pscustomobject]@{
        Name="WEB01"; State="Running"
        Uptime=(New-TimeSpan -Days 1 -Hours 2 -Minutes 3 -Seconds 4)
        MemoryAssigned=2GB; MemoryDemand=1.5GB; CPUUsage=7
      },
      [pscustomobject]@{
        Name="DB01"; State="Off"
        Uptime=(New-TimeSpan -Minutes 0)
        MemoryAssigned=4GB; MemoryDemand=0; CPUUsage=0
      }
    )

    # Replaces powershell cmdlets with fakes that return predefined data
    Mock Get-VM { $fakeVMs }
    Mock Measure-VM {
      param($VM)
      if ($VM.Name -eq 'WEB01') { [pscustomobject]@{ AverageProcessorUsage = 1234 } }
      else                       { [pscustomobject]@{ AverageProcessorUsage = 0 } }
    }

    Mock Get-VMNetworkAdapter {
      param($VM)
      if ($VM.Name -eq 'WEB01') { [pscustomobject]@{ IPAddresses = @('10.10.0.5') } }
      else                       { [pscustomobject]@{ IPAddresses = @() } }
    }
  }

  <# 
  Executes Get-MyVMs two times, once without name filter and once without the filter. 
  Get-MyVMs should return the 2 vm's that we created
  Get-MyVMs -Name "WEB01" should return the filtered vm and its attributes
  #>
  It "returns both VMs with computed properties" {
    $out = Get-MyVMs
    $out | Should -HaveCount 2
  }

  It "filters by exact Name when provided" {
    $out = Get-MyVMs -Name "WEB01"
    $out | Should -HaveCount 1
    $out[0].Name | Should -Be "WEB01"
  }
}