function Get-LANIPs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 1)]
        [CimInstance[]]$NetAdapter=$null
    )
    
    if ($null -eq $NetAdapter) {
        Write-Verbose "IP or NetAdapter Parameters not provided, determining local networks"
        $AssignedIPs = Get-NetAdapter | ? { $_.Status -eq "up" } | Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select IPAddress, PrefixLength
    } else {
        Write-Verbose "Determining networks on specified adapters"
        $AssignedIPs = $NetAdapter | Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select IPAddress, PrefixLength
    }

    # Permit only valid LAN ranges. Avoids scanning 169.x, etc
    $AssignedIPs = $AssignedIPs | ? { $_.IPAddress -match "(^10\.)|(^172\.(1[6-9]\.|2[0-9]\.|3[0-1]\.)|(^192\.168\.))" }
    
    Write-Verbose "Found the following valid range(s)"
    $AssignedIPs | % { Write-Verbose "$($_.IPAddress.ToString())/$($_.PrefixLength.ToString())" }
    
    Write-Verbose "Enumerating possible host IPs"
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
    Write-Output $IP
}