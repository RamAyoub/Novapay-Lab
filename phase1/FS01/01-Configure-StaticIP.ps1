# =============================================================================
# NovaPay Homelab — FS01 Static IP Configuration
# Script:  01-Configure-StaticIP.ps1
# Purpose: Set static IP on NOVAPAY-FS01 and point DNS at DC01
# Run on:  NOVAPAY-FS01 (before domain join)
# =============================================================================

$AdapterName  = "Ethernet"
$IPAddress    = "192.168.10.11"
$PrefixLength = 24
$Gateway      = "192.168.10.1"
$DNSPrimary   = "192.168.10.10"   # DC01
$DNSSecondary = "8.8.8.8"        # Fallback

# -- Remove existing config --
$adapter = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute     -InterfaceIndex $adapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue

# -- Set static IP --
New-NetIPAddress `
    -InterfaceAlias $AdapterName `
    -IPAddress      $IPAddress `
    -PrefixLength   $PrefixLength `
    -DefaultGateway $Gateway

# -- Set DNS pointing at DC01 --
Set-DnsClientServerAddress `
    -InterfaceAlias $AdapterName `
    -ServerAddresses $DNSPrimary, $DNSSecondary

# -- Disable IPv6 --
Disable-NetAdapterBinding -Name $AdapterName -ComponentID ms_tcpip6

# -- Enable ICMP ping (disabled by default on Windows Server) --
Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" `
    -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName "*Echo Request*" | Enable-NetFirewallRule

# -- Verify DC01 is reachable before domain join --
Write-Host "`n=== Connectivity Check ===" -ForegroundColor Cyan
$ping = Test-Connection -ComputerName 192.168.10.10 -Count 1 -Quiet
$dns  = Resolve-DnsName novapay.local -ErrorAction SilentlyContinue

Write-Host "Ping to DC01 (192.168.10.10): $(if($ping){'OK'}else{'FAILED'})" -ForegroundColor $(if($ping){'Green'}else{'Red'})
Write-Host "DNS resolve novapay.local:    $(if($dns){'OK — ' + $dns.IPAddress}else{'FAILED'})" -ForegroundColor $(if($dns){'Green'}else{'Red'})

if ($ping -and $dns) {
    Write-Host "`nReady for domain join. Run 02-Join-Domain.ps1 next." -ForegroundColor Yellow
}
