<#

DISCLAIMER: ChatGPT is gebruikt voor troubleshooting van logica, foutafhandeling, parsing en algemene coding sparring partner. 

#>

BeforeAll {
 
    Import-Module "C:\ProgramData\UniversalAutomation\Repository\Modules\InfluxFetchHost\1.0\InfluxFetchHost.psm1" -Force
    Import-Module "C:\ProgramData\UniversalAutomation\Repository\Modules\InfluxFetchVM\1.0\InfluxFetchVM.psm1" -Force
    
    # Setup mock secrets for testing 
    $global:Secret = @{}
    $global:Secret.influxBucket = "Hyper_V"
    $global:Secret.influxOrg = "TestOrg"
    $global:Secret.influxServer = "http://localhost:8086"
    $global:Secret.influxToken = "test-token-12345"
}

Describe "InfluxFetchHost" {
    
    BeforeAll {
        Mock -ModuleName InfluxFetchHost Invoke-RestMethod
        Mock -ModuleName InfluxFetchHost Write-Error
    }
    
    Context "Successful Query" -Tag "Core" {
        BeforeEach {
            # Setup mock response data
            $mockCSVResponse = @"
_time,_measurement,_field,_value
2024-01-01T12:00:00Z,SystemMetrics,CPU_Usage,45.5
2024-01-01T12:00:00Z,SystemMetrics,Memory_Used_MB,8192
2024-01-01T11:59:00Z,SystemMetrics,CPU_Usage,42.3
2024-01-01T11:59:00Z,SystemMetrics,Memory_Used_MB,8100
"@
            
            Mock -ModuleName InfluxFetchHost Invoke-RestMethod { $mockCSVResponse }
        }
        
        It "Should use correct URL with organization parameter" {
            # Verifies the function constructs the proper InfluxDB API endpoint
            $params = @{
                Bucket = "Hyper_V"
                Org    = "TestOrg"
                Server = "http://localhost:8086"
                Token  = "test-token-12345"
            }
            
            InfluxFetchHost @params
            
            Should -Invoke -ModuleName InfluxFetchHost Invoke-RestMethod -ParameterFilter {
                $Uri -eq "http://localhost:8086/api/v2/query?org=TestOrg"
            }
        }
        
        It "Should send proper authorization headers" {
            # Tests that the Token authentication header is correctly formatted
            $params = @{
                Bucket = "Hyper_V"
                Org    = "TestOrg"
                Server = "http://localhost:8086"
                Token  = "test-token-12345"
            }
            
            InfluxFetchHost @params
            
            Should -Invoke -ModuleName InfluxFetchHost Invoke-RestMethod -ParameterFilter {
                $Headers['Authorization'] -eq "Token test-token-12345" -and
                $Headers['Content-Type'] -eq 'application/json' -and
                $Headers['Accept'] -eq 'application/csv'
            }
        }
        
        It "Should use hard coded Flux query when not specified" {
            # Validates the default query includes correct measurement and fields
            InfluxFetchHost
            
            Should -Invoke -ModuleName InfluxFetchHost Invoke-RestMethod -ParameterFilter {
                $bodyObj = $Body | ConvertFrom-Json
                $bodyObj.query -match "SystemMetrics" -and
                $bodyObj.query -match "CPU_Usage" -and
                $bodyObj.query -match "Memory_Used_MB" -and
                $bodyObj.query -match "range\(start: -1h\)"
            }
        }

        
        It "Should return CSV response data for host" {
            # Ensures the raw CSV response is returned unmodified
            $result = InfluxFetchHost
            
            $result | Should -Be $mockCSVResponse
        }
    }
    
}

Describe "InfluxFetchVM" {
    
    BeforeAll {
        Mock -ModuleName InfluxFetchVM Invoke-RestMethod
        Mock -ModuleName InfluxFetchVM Write-Error
    }
    
    Context "Successful VM Query" -Tag "Core" {
        BeforeEach {
            # Setup mock response data
            $mockVMCSVResponse = @"
_time,_measurement,Host,_field,_value
2024-01-01T12:00:00Z,VMSystemMetrics,TestVM,CPU_Usage,25.5
2024-01-01T12:00:00Z,VMSystemMetrics,TestVM,Memory_Used_MB,4096
2024-01-01T11:59:00Z,VMSystemMetrics,TestVM,CPU_Usage,22.3
2024-01-01T11:59:00Z,VMSystemMetrics,TestVM,Memory_Used_MB,4000
"@
            
            Mock -ModuleName InfluxFetchVM Invoke-RestMethod { $mockVMCSVResponse }
        }
        
        It "Should include VM name in query filter" {
            # Verifies the VM name is properly injected into the Flux query
            InfluxFetchVM -VMName "TestVM"
            
            Should -Invoke -ModuleName InfluxFetchVM Invoke-RestMethod -ParameterFilter {
                $bodyObj = $Body | ConvertFrom-Json
                $bodyObj.query -match 'Host.*==.*"TestVM"' -and
                $bodyObj.query -match "VMSystemMetrics"
            }
        }
             

        It "Should send authorization headers along with VMName" {
            # Tests that the Token authentication header is correctly formatted
            $params = @{
                VMName = "TestVM"
                Bucket = "Hyper_V"
                Org    = "TestOrg"
                Server = "http://localhost:8086"
                Token  = "test-token-12345"
            }
            
            InfluxFetchVM @params
            
            Should -Invoke -ModuleName InfluxFetchVM Invoke-RestMethod -ParameterFilter {
                $Headers['Authorization'] -eq "Token test-token-12345" -and
                $Headers['Content-Type'] -eq 'application/json' -and
                $Headers['Accept'] -eq 'application/csv'
            }
        }
        
        It "Should use correct URL with organization parameter for VM" {
            # Verifies the function constructs the proper InfluxDB API endpoint
            $params = @{
                VMName = "TestVM"
                Bucket = "Hyper_V"
                Org    = "TestOrg"
                Server = "http://localhost:8086"
                Token  = "test-token-12345"
            }
            
            InfluxFetchVM @params
            
            Should -Invoke -ModuleName InfluxFetchVM Invoke-RestMethod -ParameterFilter {
                $Uri -eq "http://localhost:8086/api/v2/query?org=TestOrg"
            }
        }
        
        It "Should return CSV response data for specified VM" {
            # Ensures the raw CSV response is returned unmodified
            $result = InfluxFetchVM -VMName "TestVM"
            
            $result | Should -Be $mockVMCSVResponse
        }
        

    }
    

   
}

AfterAll {
    # Clean up global variables
    Remove-Variable -Name Secret -Scope Global -ErrorAction SilentlyContinue
}