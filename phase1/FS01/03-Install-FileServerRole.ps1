# =============================================================================
# NovaPay Homelab — Install File Server Role
# Script:  03-Install-FileServerRole.ps1
# Purpose: Install File Server and File Server Resource Manager roles
# Run on:  NOVAPAY-FS01 (after domain join)
# =============================================================================

Write-Host "Installing File Server roles..." -ForegroundColor Cyan

Install-WindowsFeature `
    -Name FS-FileServer, FS-Resource-Manager, RSAT-FSRM-Mgmt `
    -IncludeManagementTools `
    -Verbose

# -- Enable File and Printer Sharing firewall rules --
Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" | Enable-NetFirewallRule
Write-Host "Firewall rules enabled for File and Printer Sharing." -ForegroundColor Green

# -- Verify --
Write-Host "`n=== Role Installation Status ===" -ForegroundColor Cyan
Get-WindowsFeature FS-FileServer, FS-Resource-Manager |
    Select-Object Name, InstallState |
    Format-Table -AutoSize
