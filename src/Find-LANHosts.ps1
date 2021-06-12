
<#
    .SYNOPSIS
    Quickly finds host on a local network using ARP for discovery

    .DESCRIPTION
    Uses ARP requests to determine whether a host is present on a network segment. 

    As APR is a Layer 2 mechanism, the list of IP addesses need to be on the same network as the device running the script. 

    .PARAMETER IP
    Optional. Specifies one or more IP addresses to scan for. Typically this will be a list of all usable hosts on a network. 
    If omitted, it will enumerate local adapters and determine host IPs automatically, but may require elevated priviliges.

    .PARAMETER DelayMS
    Optional. Specifies the interpacket delay, default is 2ms. Can be increased if scanning unreliable or high latency networks. 

    .PARAMETER ClearARPCache
    Optional. Clears the ARP cache before starting a scan. This is recommended, but may require elevated priviliges. 

    .EXAMPLE
    Find-LANHosts

    .EXAMPLE
    $IPs = 1..254 | % {"10.250.1.$_"}
    Find-LANHosts -IP $IPs

    .EXAMPLE
    Find-LANHosts -ClearARPCache -DelayMS 5

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
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 1)]
        [string[]]$IP,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateRange(0, 15000)]
        [int]$DelayMS = 2,
        
        [switch]$ClearARPCache
    )

    Begin {

        # Determine local network if none specified
        if ($IP.Count -lt 1) {
            $AssignedIPs = Get-NetAdapter -Physical | ? {$_.Status -eq "up"} | Get-NetIPAddress -AddressFamily IPv4 | Select IPAddress, PrefixLength

            $IP = $AssignedIPs | % {
                $AllIPs = [System.Collections.ArrayList]@()

                [IPAddress]$SubnetMask = ([Math]::Pow(2, $_.PrefixLength) - 1) * [Math]::Pow(2, (32 - $_.PrefixLength))
                $FullMask = [UInt32]'0xffffffff'
                $NetworkId = [IPAddress](([IPAddress]$_.IPAddress).Address -band $SubnetMask.Address)
                $Broadcast = [IPAddress](($FullMask - $NetworkId.Address) -bxor $SubnetMask.Address)

                # Used for determining first usable IP Address
                $FirstIPByteArray = $NetworkId.GetAddressBytes()
                [Array]::Reverse($FirstIPByteArray)

                # Used for determining last usable IP Address
                $LastIPByteArray = $Broadcast.GetAddressBytes()
                [Array]::Reverse($LastIPByteArray)

                # Handler for /31, /30 CIDR prefix values, and default for all others.  
                switch ($PrefixLength) {
                    31 {
                        $FirstIPInt = ([IPAddress]$FirstIPByteArray).Address
                        $LastIPInt = ([IPAddress]$LastIPByteArray).Address
                        break;
                    }

                    32 {
                        $FirstIPInt = ([IPAddress]$FirstIPByteArray).Address
                        $LastIPInt = ([IPAddress]$LastIPByteArray).Address
                        break;
                    }

                    default {

                        # First usable IP
                        $FirstIPInt = ([IPAddress]$FirstIPByteArray).Address + 1
                        $LastIPInt = ([IPAddress]$LastIPByteArray).Address - 1
                    }
                }

                $CurrentIPInt = $FirstIPInt

                Do {
                    $CurrIP = [IPAddress]$CurrentIPInt
                    $CurrIP = ($CurrIP).GetAddressBytes()
                    [Array]::Reverse($CurrIP)
                    $CurrIP = ([IPAddress]$CurrIP).IPAddressToString
                    [void]$AllIPs.Add($CurrIP)
        
                    $CurrentIPInt++
        
                } While ($CurrentIPInt -le $LastIPInt)
                Write-Output $AllIPs
            }
        }

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

        $Hosts = $Hosts | Where-Object { $_ -match "dynamic" } | % { ($_.trim() -replace " {1,}", ",") | ConvertFrom-Csv -Header "IP", "MACAddress" }
        $Hosts = $Hosts | Where-Object { $_.IP -in $IPList }

        Write-Output $Hosts
    }
}