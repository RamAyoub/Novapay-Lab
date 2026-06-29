# =============================================================================
# NovaPay Homelab — DC01 Static IP Configuration
# Sets a static IP address on NOVAPAY-DC01 before AD DS promotion
# =============================================================================

$AdapterName   = "Ethernet"
$IPAddress     = "192.168.10.10"
$PrefixLength  = 24
$Gateway       = "192.168.10.1"
$DNSPrimary    = "127.0.0.1"   # the Domain controller should point to itself after promotion
$DNSSecondary  = "8.8.8.8"    # Temporary fallback for Windows Update

# -- just to remove existing IP config on the adapter
$adapter = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $adapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue

# -- Set static IP --
New-NetIPAddress `
    -InterfaceAlias $AdapterName `
    -IPAddress $IPAddress `
    -PrefixLength $PrefixLength `
    -DefaultGateway $Gateway

# -- Set DNS --
Set-DnsClientServerAddress `
    -InterfaceAlias $AdapterName `
    -ServerAddresses $DNSPrimary, $DNSSecondary

# -- Verify --
Write-Host "`n=== IP Configuration Applied ===" -ForegroundColor Cyan
Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 |
    Select InterfaceAlias, IPAddress, PrefixLength
Write-Host "DNS Servers: $((Get-DnsClientServerAddress -InterfaceAlias $AdapterName).ServerAddresses)"
