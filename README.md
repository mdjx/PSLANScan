# PSLANScan

[![version](https://img.shields.io/badge/version-1.2.0-blue.svg)](https://semver.org)

PSLANScan is a PowerShell module for layer 2 host discovery via ARP. It quickly finds live hosts on your network segment given a list of IP addresses, even if the hosts have ICMP/ping blocked by a firewall. 


## Installation


### Via PowerShell Gallery

`Install-Module -Name PSLANScan -Scope CurrentUser`


### Via Git

Clone the repository and run `.\build.ps1 deploy`.

This will install several modules if you do not already have them, see `build.ps1` for details. These are only required for the build process and are not otherwise used by `PSLANScan`.


### Manually

Copy the files from `src` to `$Home\Documents\WindowsPowerShell\Modules\PSLANScan` for PowerShell 5.1 or `$Home\Documents\PowerShell\Modules\PSLANScan` for PowerShell 7, and rename the `.ps1` file(s) to `.psm1`. 

## Usage

`Find-LANHosts [-IP <String[]>] [-NetAdapter <CimInstance[]>] [-DelayMS <int>] [-ClearARPCache]`

## Examples

```powershell
Find-LANHosts
```

```powershell
Find-LANHosts -ClearARPCache -DelayMS 5
```

```powershell
Get-NetAdapter -Name Ethernet | Find-LANHosts
```

```powershell
Get-NetAdapter | ? {($_ | Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue) -ne $null} | Find-LANHosts
```

```powershell
Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Get-NetAdapter | Find-LANHosts
```

```powershell
$IPs = 1..254 | % {"192.168.0.$_"}
Find-LANHosts $IPs
```

```powershell
1..254 | % {"192.168.1.$_"} | Find-LANHosts -ClearARPCache
```

```powershell
1..254 | % {"10.1.1.$_"} | Find-LANHosts -DelayMS 5
```

## More info

See this [blog post](https://xkln.net/blog/layer-2-host-discovery-with-powershell-in-under-a-second/) for further details. 