
<#
    .SYNOPSIS
    Quickly finds host on a local network

    .DESCRIPTION
    Accepts an array of IP Addresses, and uses ARP requests to determine whether a host is present on a network segment. 

    As APR is a Layer 2 mechanism, the list of IP addesses need to be on the same network as the device running the script. 

    .PARAMETER IP
    Specifies one or more IP addresses to scan for. Typically this will be a list of all usable hosts on a network

    .PARAMETER DelayMS
    Optional. Specifies the interpacket delay, default is 2ms. Can be increased if scanning unreliable or high latency networks. 

    .PARAMETER ClearARPCache
    Optional. Clears the ARP cache before starting a scan. This is recommended, but may require elevated priviliges. 

    .EXAMPLE
    $IPs = 1..254 | % {"10.250.1.$_"}; Find-LANHosts -IP $IPs

    .EXAMPLE
    $IPs = 1..254 | % {"192.168.0.$_"}; Find-LANHosts $IPs

    .EXAMPLE
    1..254 | % {"192.168.1.$_"} | Find-LANHosts -ClearARPCache

    .EXAMPLE
    1..254 | % {"10.1.1.$_"} | Find-LANHosts -DelayMS 5

    .LINK
    https://github.com/mdjx/PSLANScan
#>
function Find-LANHosts {
    [Cmdletbinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 1)]
        [string[]]$IP,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateRange(0, 15000)]
        [int]$DelayMS = 2,
        
        [switch]$ClearARPCache
    )

    Begin {

        $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
        $Bytes = $ASCIIEncoding.GetBytes("a")
        $UDP = New-Object System.Net.Sockets.Udpclient

        if ($ClearARPCache) {
            $ARPClear = arp -d 2>&1
            if (($ARPClear.count -gt 0) -and ($ARPClear[0] -is [System.Management.Automation.ErrorRecord]) -and ($ARPClear[0].Exception -notmatch "The parameter is incorrect")) {
                Throw $ARPClear[0].Exception
            }
        }

        $IPList = [System.Collections.ArrayList]@()
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    }

    Process {
        $IP | ForEach-Object {
            $UDP.Connect($_, 1)
            [void]$UDP.Send($Bytes, $Bytes.length)
            [void]$IPList.Add($_)
            if ($DelayMS) {
                [System.Threading.Thread]::Sleep($DelayMS)
            }
        }
    }

    End {
    
        $Hosts = arp -a
        $Timer.Stop()

        if ($Timer.Elapsed.TotalSeconds -gt 15) {
            Write-Warning "Scan took longer than 15 seconds, ARP entries may have been flushed. Recommend lowering DelayMS parameter"
        }

        $Hosts = $Hosts | Where-Object {$_ -match "dynamic"} | % {($_.trim() -replace " {1,}", ",") | ConvertFrom-Csv -Header "IP", "MACAddress"}
        $Hosts = $Hosts | Where-Object {$_.IP -in $IPList}

        Write-Output $Hosts
    }
}