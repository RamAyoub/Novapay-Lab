# =============================================================================
# NovaPay Homelab — Domain Password & Account Lockout Policy
# Script:  07-Set-PasswordPolicy.ps1
# Purpose: Enforce a compliant domain-wide password and lockout baseline.
# Run on:  NOVAPAY-DC01 (elevated PowerShell)
#
# NOTE: Domain password/lockout settings live in the "Default Domain Policy"
#       security settings, which are NOT registry-based and cannot be set with
#       Set-GPRegistryValue. The supported, reliable method is to set them on
#       the domain object directly via Set-ADDefaultDomainPasswordPolicy — this
#       produces the exact same effective policy the GPO would.
#
# Compliance mapping:
#   PCI-DSS v4.0  Req 8.3.6  — min 12 chars (we use 14), alpha + numeric
#   PCI-DSS v4.0  Req 8.3.4  — lock account after no more than 10 attempts
#   ISO 27001:2022 A.5.17    — Authentication information
#   SOC 2          CC6.1     — Logical access security
# =============================================================================

Import-Module ActiveDirectory

$Domain = (Get-ADDomain).DistinguishedName
Write-Host "Applying password & lockout policy to: $Domain" -ForegroundColor Cyan

# Parameters are passed via a hashtable ("splatting"). This avoids fragile
# line-continuation backticks and lets each setting carry an inline comment.
$PolicyParams = @{
    Identity                  = (Get-ADDomain).DNSRoot
    MinPasswordLength         = 14                        # PCI 8.3.6 (exceeds 12 minimum)
    ComplexityEnabled         = $true                     # 3 of 4 character classes
    PasswordHistoryCount      = 24                        # prevents reuse
    MaxPasswordAge            = (New-TimeSpan -Days 90)
    MinPasswordAge            = (New-TimeSpan -Days 1)
    LockoutThreshold          = 5                         # PCI 8.3.4 (well under 10)
    LockoutDuration           = (New-TimeSpan -Minutes 30)
    LockoutObservationWindow  = (New-TimeSpan -Minutes 30)
    ReversibleEncryptionEnabled = $false
}

Set-ADDefaultDomainPasswordPolicy @PolicyParams

# -- Verify --
Write-Host "`n=== Effective Domain Password Policy ===" -ForegroundColor Cyan
Get-ADDefaultDomainPasswordPolicy |
    Select-Object MinPasswordLength, ComplexityEnabled, PasswordHistoryCount,
                  MaxPasswordAge, MinPasswordAge, LockoutThreshold,
                  LockoutDuration, LockoutObservationWindow |
    Format-List
