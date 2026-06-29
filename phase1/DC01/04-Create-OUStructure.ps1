# =============================================================================
# NovaPay Homelab — Create Organisational Unit Structure
# Script:  04-Create-OUStructure.ps1
# Used to quickly build the OU hierarchy that mirrors NovaPay's company structure
# =============================================================================

$DomainBase = "DC=novapay,DC=local"

# -- Root OU --
New-ADOrganizationalUnit -Name "NovaPay" `
    -Path $DomainBase `
    -ProtectedFromAccidentalDeletion $true

$RootOU = "OU=NovaPay,$DomainBase"

# -- Second-level OUs --
$TopLevelOUs = @("Users", "Computers", "Servers", "ServiceAccounts", "Groups", "Privileged")
foreach ($OU in $TopLevelOUs) {
    New-ADOrganizationalUnit -Name $OU `
        -Path $RootOU `
        -ProtectedFromAccidentalDeletion $true
    Write-Host "  Created: OU=$OU" -ForegroundColor Green
}

# -- Department OUs under Users --
$UsersOU = "OU=Users,$RootOU"
$Departments = @("Finance", "Engineering", "Compliance", "HR", "IT", "Executive")
foreach ($Dept in $Departments) {
    New-ADOrganizationalUnit -Name $Dept `
        -Path $UsersOU `
        -ProtectedFromAccidentalDeletion $true
    Write-Host "  Created: OU=$Dept (under Users)" -ForegroundColor Green
}

# -- Verify --
Write-Host "`n=== OU Structure Created ===" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * |
    Sort-Object DistinguishedName |
    Select-Object DistinguishedName
