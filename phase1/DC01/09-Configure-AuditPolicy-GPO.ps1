# =============================================================================
# NovaPay Homelab — Advanced Audit Policy GPO
# Script:  09-Configure-AuditPolicy-GPO.ps1
# Purpose: Deploy a domain-wide Advanced Audit Policy via GPO so that the
#          security events your SOC (Phase 5 / Microsoft Sentinel) depends on
#          are generated consistently on every host.
# Run on:  NOVAPAY-DC01 (elevated PowerShell)
#
# HOW THIS WORKS:
#   Advanced Audit Policy is stored inside a GPO as a CSV file in SYSVOL
#   (Machine\Microsoft\Windows NT\Audit\audit.csv) and is applied by the
#   Audit Policy client-side extension (CSE). This script writes that CSV and
#   registers the CSE on the GPO. The companion script 08 already sets
#   SCENoApplyLegacyAuditPolicy=1 so these subcategory settings take effect.
#
#   >>> VERIFY AFTER RUNNING (important):
#       On DC01 and FS01:  gpupdate /force
#       Then:              auditpol /get /category:*
#       You should see Success/Failure on the subcategories below. If a host
#       shows "No Auditing", re-run gpupdate, reboot once, and re-check.
#
# Compliance mapping:
#   PCI-DSS v4.0  Req 10.2  — log all access, admin actions, auth events,
#                             changes to accounts/privileges, audit-log changes
#   ISO 27001:2022 A.8.15   — Logging
#   SOC 2          CC7.2     — Detection of security events
# =============================================================================

Import-Module GroupPolicy
Import-Module ActiveDirectory

$GpoName   = "NovaPay - Advanced Audit Policy"
$DomainDN  = (Get-ADDomain).DistinguishedName
$DomainDNS = (Get-ADDomain).DNSRoot

# -- Create (or reuse) the GPO --
$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment "Advanced audit policy for SIEM/Sentinel — created by 09-Configure-AuditPolicy-GPO.ps1"
    Write-Host "Created GPO: $GpoName" -ForegroundColor Green
} else {
    Write-Host "Reusing existing GPO: $GpoName" -ForegroundColor DarkYellow
}
$gpoId = "{$($gpo.Id)}"

# -- Audit subcategories. Value: 0=None 1=Success 2=Failure 3=Success+Failure --
# GUIDs are fixed, Microsoft-documented subcategory identifiers.
$AuditSettings = @(
    # Account Logon
    @{ Sub="Credential Validation";              GUID="{0CCE923F-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Kerberos Authentication Service";    GUID="{0CCE9242-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Kerberos Service Ticket Operations"; GUID="{0CCE9240-69AE-11D9-BED3-505054503030}"; Val=3 }
    # Account Management
    @{ Sub="User Account Management";            GUID="{0CCE9235-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Security Group Management";          GUID="{0CCE9237-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Computer Account Management";        GUID="{0CCE9236-69AE-11D9-BED3-505054503030}"; Val=3 }
    # Logon/Logoff
    @{ Sub="Logon";                              GUID="{0CCE9215-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Logoff";                             GUID="{0CCE9216-69AE-11D9-BED3-505054503030}"; Val=1 }
    @{ Sub="Account Lockout";                    GUID="{0CCE9217-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Special Logon";                      GUID="{0CCE921B-69AE-11D9-BED3-505054503030}"; Val=3 }
    # Object Access (file shares = cardholder/PII data)
    @{ Sub="File System";                        GUID="{0CCE921D-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Removable Storage";                  GUID="{0CCE9245-69AE-11D9-BED3-505054503030}"; Val=3 }
    # Privilege Use
    @{ Sub="Sensitive Privilege Use";            GUID="{0CCE9228-69AE-11D9-BED3-505054503030}"; Val=3 }
    # Policy Change
    @{ Sub="Audit Policy Change";                GUID="{0CCE922F-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Authentication Policy Change";       GUID="{0CCE9230-69AE-11D9-BED3-505054503030}"; Val=3 }
    # DS Access (changes to AD objects)
    @{ Sub="Directory Service Access";           GUID="{0CCE923B-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="Directory Service Changes";          GUID="{0CCE923C-69AE-11D9-BED3-505054503030}"; Val=3 }
    # Detailed Tracking
    @{ Sub="Process Creation";                   GUID="{0CCE922B-69AE-11D9-BED3-505054503030}"; Val=1 }
    # System
    @{ Sub="Security State Change";              GUID="{0CCE9210-69AE-11D9-BED3-505054503030}"; Val=3 }
    @{ Sub="System Integrity";                   GUID="{0CCE9212-69AE-11D9-BED3-505054503030}"; Val=3 }
)

$ValMap = @{ 0="No Auditing"; 1="Success"; 2="Failure"; 3="Success and Failure" }

# -- Build the audit.csv content --
$header = "Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value"
$lines  = foreach ($a in $AuditSettings) {
    ",System,$($a.Sub),$($a.GUID),$($ValMap[$a.Val]),,$($a.Val)"
}
$csv = ($header, $lines) -join "`r`n"

# -- Write the CSV into the GPO's SYSVOL Audit folder --
$auditDir = "\\$DomainDNS\SYSVOL\$DomainDNS\Policies\$gpoId\Machine\Microsoft\Windows NT\Audit"
New-Item -Path $auditDir -ItemType Directory -Force | Out-Null
$csv | Out-File -FilePath (Join-Path $auditDir "audit.csv") -Encoding ASCII -Force
Write-Host "Wrote audit.csv ($($AuditSettings.Count) subcategories) to SYSVOL." -ForegroundColor Green

# -- Register the Audit Policy CSE on the GPO's gPCMachineExtensionNames --
# CSE GUID {F3CCC681-...} = Audit Policy ; tool GUID {0F3F3735-...} = GPMC.
$gpoADPath = "CN=$gpoId,CN=Policies,CN=System,$DomainDN"
$cse       = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}][{F3CCC681-B74C-4060-9F26-CD84525DCA2A}{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}]"
Set-ADObject -Identity $gpoADPath -Replace @{ gPCMachineExtensionNames = $cse }
Write-Host "Registered Audit Policy client-side extension on GPO." -ForegroundColor Green

# -- Bump the GPO version so clients re-process it --
$current = (Get-ADObject -Identity $gpoADPath -Properties versionNumber).versionNumber
Set-ADObject -Identity $gpoADPath -Replace @{ versionNumber = ($current + 2) }

# -- Link at domain root --
$existingLink = (Get-GPInheritance -Target $DomainDN).GpoLinks |
                Where-Object { $_.DisplayName -eq $GpoName }
if (-not $existingLink) {
    New-GPLink -Name $GpoName -Target $DomainDN -LinkEnabled Yes | Out-Null
    Write-Host "Linked GPO to $DomainDN" -ForegroundColor Green
} else {
    Write-Host "GPO already linked." -ForegroundColor DarkYellow
}

Write-Host "`n=== Next steps ===" -ForegroundColor Cyan
Write-Host "1. On DC01 and FS01:  gpupdate /force" -ForegroundColor White
Write-Host "2. Verify:            auditpol /get /category:*" -ForegroundColor White
Write-Host "3. For File System auditing to log access, you must also set a SACL" -ForegroundColor White
Write-Host "   on the share folders (see 10-Set-FileShare-SACL.ps1 on FS01)." -ForegroundColor White
