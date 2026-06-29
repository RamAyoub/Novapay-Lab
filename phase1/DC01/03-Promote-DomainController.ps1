# =============================================================================
# NovaPay Homelab — Promote DC01 to Domain Controller
# Script:  03-Promote-DomainController.ps1
# Creates the novapay.local AD forest and promote DC01

# =============================================================================

# -- IMPORTANT: Save this DSRM password somewhere safe --
# DSRM (Directory Services Restore Mode) is your emergency recovery password
$DSRMPassword = ConvertTo-SecureString "P@ssw0rd!Lab2026" -AsPlainText -Force

Write-Host "Promoting NOVAPAY-DC01 to Domain Controller..." -ForegroundColor Cyan
Write-Host "Domain: novapay.local" -ForegroundColor Yellow

Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName              "novapay.local" `
    -DomainNetBiosName       "NOVAPAY" `
    -DomainMode              "WinThreshold" `
    -ForestMode              "WinThreshold" `
    -InstallDns:             $true `
    -CreateDnsDelegation:    $false `
    -DatabasePath            "C:\Windows\NTDS" `
    -LogPath                 "C:\Windows\NTDS" `
    -SysvolPath              "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $DSRMPassword `
    -Force:                  $true

# After the installation, usually you're prompted to restart the machine. It's necessary
