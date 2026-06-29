# =============================================================================
# NovaPay Homelab — Create Security Groups and Assign Members
# Script:  06-Create-SecurityGroups.ps1
# Purpose: Create role-based security groups and assign user members
# Run on:  NOVAPAY-DC01
# Compliance: ISO 27001 A.5.15 — Identity Management
#             PCI-DSS Req 7.2 — Access control system
# =============================================================================

$DomainBase = "DC=novapay,DC=local"
$GroupsOU   = "OU=Groups,OU=NovaPay,$DomainBase"

# -- Group definitions --
$Groups = @(
    @{ Name="GRP-IT-Admins";       Desc="IT administrators — elevated access"      },
    @{ Name="GRP-GRC-Team";        Desc="Compliance and GRC personnel"             },
    @{ Name="GRP-Finance-Users";   Desc="Finance department users"                 },
    @{ Name="GRP-Developers";      Desc="Engineering and development team"         },
    @{ Name="GRP-Executives";      Desc="Executive leadership"                     },
    @{ Name="GRP-HR-Staff";        Desc="Human Resources team"                     },
    @{ Name="GRP-All-Staff";       Desc="All NovaPay employees — general access"   }
)

Write-Host "Creating security groups..." -ForegroundColor Cyan

foreach ($G in $Groups) {
    if (Get-ADGroup -Filter { Name -eq $G.Name } -ErrorAction SilentlyContinue) {
        Write-Host "  SKIPPED (exists): $($G.Name)" -ForegroundColor DarkYellow
        continue
    }
    New-ADGroup `
        -Name          $G.Name `
        -GroupScope    Global `
        -GroupCategory Security `
        -Description   $G.Desc `
        -Path          $GroupsOU
    Write-Host "  Created: $($G.Name)" -ForegroundColor Green
}

# -- Group memberships --
Write-Host "`nAssigning group members..." -ForegroundColor Cyan

$Memberships = @{
    "GRP-GRC-Team"       = @("r.ayoub")
    "GRP-Finance-Users"  = @("a.chen", "g.lee")
    "GRP-Developers"     = @("b.kumar")
    "GRP-Executives"     = @("f.moore", "a.chen", "e.jones")
    "GRP-HR-Staff"       = @("e.jones")
    "GRP-All-Staff"      = @("a.chen","b.kumar","r.ayoub","e.jones","f.moore","g.lee")
}

foreach ($Group in $Memberships.Keys) {
    Add-ADGroupMember -Identity $Group -Members $Memberships[$Group] -ErrorAction SilentlyContinue
    Write-Host "  $Group → $($Memberships[$Group] -join ', ')" -ForegroundColor Green
}

# -- Summary --
Write-Host "`n=== Group Membership Summary ===" -ForegroundColor Cyan
foreach ($Group in $Memberships.Keys) {
    $Members = Get-ADGroupMember -Identity $Group | Select-Object -ExpandProperty SamAccountName
    Write-Host "  $Group : $($Members -join ', ')" -ForegroundColor White
}
