
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
    [Cmdletbinding(DefaultParameterSetName = "IPBlock")]

    Param (
        [Parameter(Mandatory = $false, ValueFromPipeline, ParameterSetName = "IPBlock")]
        [string[]]$IP = $null,

        [Parameter(Mandatory = $false, ValueFromPipeline, ParameterSetName = "Interface")]
        [CimInstance[]]$NetAdapter = $null,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateRange(0, 15000)]
        [int]$DelayMS = 2,
        
        [switch]$ClearARPCache
    )

    Begin {

        $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
        $Bytes = $ASCIIEncoding.GetBytes("!")
        $UDP = New-Object System.Net.Sockets.Udpclient

        if ($ClearARPCache) {
            $ARPClear = arp -d 2>&1
            if (($ARPClear.count -gt 0) -and ($ARPClear[0] -is [System.Management.Automation.ErrorRecord]) -and ($ARPClear[0].Exception -notmatch "The parameter is incorrect")) {
                Throw $ARPClear[0].Exception
            }
        }

        $IPList = [System.Collections.ArrayList]@()
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "Beginning scan"
    }

    Process {

        if (($null -eq $IP) -and ($null -eq $NetAdapter)) {
            if ($VerbosePreference -eq "SilentlyContinue") { $IP = Get-LANIPs }
            else { $IP = Get-LANIPs -Verbose }
        }

        if ($PsCmdlet.ParameterSetName -eq "Interface") {
            if ($VerbosePreference -eq "SilentlyContinue") { $IP = Get-LANIPs -NetAdapter $NetAdapter }
            else { $IP = Get-LANIPs -NetAdapter $NetAdapter -Verbose }
        }
        
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
