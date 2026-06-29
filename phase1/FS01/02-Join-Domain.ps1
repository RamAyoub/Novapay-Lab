# =============================================================================
# NovaPay Homelab — Join FS01 to the NovaPay Domain
# Script:  02-Join-Domain.ps1
# Purpose: Join NOVAPAY-FS01 to novapay.local and place in Servers OU
# Run on:  NOVAPAY-FS01
# NOTE:    You will be prompted for domain credentials
#          Username: NOVAPAY\Administrator
#          Password: P@ssw0rd!Lab2026
# =============================================================================

$DomainName = "novapay.local"
$OUPath     = "OU=Servers,OU=NovaPay,DC=novapay,DC=local"

Write-Host "Joining $env:COMPUTERNAME to $DomainName..." -ForegroundColor Cyan
Write-Host "Enter credentials: NOVAPAY\Administrator`n" -ForegroundColor Yellow

Add-Computer `
    -DomainName $DomainName `
    -Credential (Get-Credential) `
    -OUPath     $OUPath `
    -Restart

# Server restarts automatically
# After reboot: log in as NOVAPAY\Administrator to confirm domain membership
