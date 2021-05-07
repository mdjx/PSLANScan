BeforeAll { 
    . "$PSScriptRoot\..\src\Find-LANHosts.ps1"

    $AssumedNetworkId = (Get-NetRoute -DestinationPrefix '0.0.0.0/0').NextHop.Split(".")[0..2] -join "."
    $IPs = 1..254 | % {"$AssumedNetworkId.$_"}
}

# The following tests assume the user is on a /24 LAN with at least one other reachable host.
Describe 'Tests' {
    
    Context 'Output and Paramater Validation' {
        It 'Validates Automatic Calculation of Local Hosts' {
            $LANHosts = Find-LANHosts
            $LANHosts.count | Should -BeGreaterThan 0
            $LANHosts.IP | Should -BeGreaterThan 0
            $LANHosts.MACAddress | Should -BeGreaterThan 0
        }

        It 'Validates Parmeter' {        
            $LANHosts = Find-LANHosts -IP $IPs
            $LANHosts.count | Should -BeGreaterThan 0
            $LANHosts.IP | Should -BeGreaterThan 0
            $LANHosts.MACAddress | Should -BeGreaterThan 0
        }

        It 'Validates Pipeline Input' {
            $LANHosts = $IPs | Find-LANHosts
            $LANHosts.count | Should -BeGreaterThan 0
            $LANHosts.IP | Should -BeGreaterThan 0
            $LANHosts.MACAddress | Should -BeGreaterThan 0
        }

        It 'Validates Pipeline Input #2' {        
            $LANHosts = 1..254 | % {"$AssumedNetworkId.$_"} | Find-LANHosts -DelayMS 5
            $LANHosts.count | Should -BeGreaterThan 0
            $LANHosts.IP | Should -BeGreaterThan 0
            $LANHosts.MACAddress | Should -BeGreaterThan 0
        }

        It 'Throws exception when ClearARPCache is used without rights' {
            {Find-LANHosts -IP $IPs -ClearARPCache} | Should -Throw
        }
    }
}