# =============================================================================
# NovaPay Homelab — Security Baseline GPO (registry-based hardening)
# Script:  08-Create-SecurityBaseline-GPO.ps1
# Purpose: Create and link a domain-wide hardening GPO covering logon banner,
#          screen lock, legacy-protocol disablement, anonymous restrictions,
#          UAC, host firewall, event-log sizing, and removable-media control.
# Run on:  NOVAPAY-DC01 (elevated PowerShell)
#
# Why registry-based + Set-GPRegistryValue: these are all "Administrative
# Template"/policy-registry settings, which Set-GPRegistryValue applies reliably
# and which auto-register the correct client-side extension on the GPO.
#
# Compliance mapping (summary — see Compliance-GPO-Matrix.md for full detail):
#   PCI-DSS v4.0  Req 2.2  — secure configuration standards
#   PCI-DSS v4.0  Req 8.2.8 — session lock after 15 min idle
#   PCI-DSS v4.0  Req 1.4  — host-based firewall
#   ISO 27001:2022 A.8.9 / A.8.20 / A.8.7 — config, network, malware/media
#   SOC 2          CC6.1 / CC6.6 / CC6.8
# =============================================================================

Import-Module GroupPolicy
Import-Module ActiveDirectory

$GpoName    = "NovaPay - Security Baseline"
$DomainDN   = (Get-ADDomain).DistinguishedName
$DomainDNS  = (Get-ADDomain).DNSRoot

# -- Create (or reuse) the GPO --
$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment "Domain endpoint hardening baseline — created by 08-Create-SecurityBaseline-GPO.ps1"
    Write-Host "Created GPO: $GpoName" -ForegroundColor Green
} else {
    Write-Host "Reusing existing GPO: $GpoName" -ForegroundColor DarkYellow
}

# Convenience wrapper
function Set-Reg {
    param($Key, $Name, $Type, $Value)
    Set-GPRegistryValue -Name $GpoName -Key $Key -ValueName $Name -Type $Type -Value $Value | Out-Null
    Write-Host "  $Name = $Value" -ForegroundColor Gray
}

$SystemPolicy = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$Lsa          = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"

# --- 1. Interactive logon legal notice (GDPR/ISO monitoring + access warning) ---
Write-Host "`n[1] Logon banner (ISO A.5.4 / GDPR transparency)" -ForegroundColor Cyan
Set-Reg $SystemPolicy "legalnoticecaption" String "NovaPay Financial Services - Authorised Use Only"
Set-Reg $SystemPolicy "legalnoticetext"    String "This system is the property of NovaPay Financial Services. Access is restricted to authorised users for business purposes only. All activity is logged and monitored in line with company policy and applicable law. Unauthorised access is prohibited and may be prosecuted."

# --- 2. Machine inactivity / screen lock — 900s = 15 min (PCI 8.2.8) ---
Write-Host "[2] Screen lock at 15 min idle (PCI 8.2.8)" -ForegroundColor Cyan
Set-Reg $SystemPolicy "InactivityTimeoutSecs" DWord 900

# --- 3. Disable SMBv1 server (PCI 2.2 / ISO A.8.9 — remove insecure services) ---
Write-Host "[3] Disable SMBv1 server" -ForegroundColor Cyan
Set-Reg "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SMB1" DWord 0

# --- 4. NTLMv2 only + no LM hash + anonymous restrictions ---
Write-Host "[4] NTLMv2-only, no LM hash, restrict anonymous" -ForegroundColor Cyan
Set-Reg $Lsa "LmCompatibilityLevel"      DWord 5   # send NTLMv2 only, refuse LM/NTLM
Set-Reg $Lsa "NoLMHash"                  DWord 1
Set-Reg $Lsa "RestrictAnonymous"         DWord 1
Set-Reg $Lsa "RestrictAnonymousSAM"      DWord 1
Set-Reg $Lsa "EveryoneIncludesAnonymous" DWord 0

# --- 5. User Account Control hardening ---
Write-Host "[5] UAC hardening" -ForegroundColor Cyan
Set-Reg $SystemPolicy "EnableLUA"                  DWord 1
Set-Reg $SystemPolicy "ConsentPromptBehaviorAdmin" DWord 2   # prompt for consent on secure desktop
Set-Reg $SystemPolicy "PromptOnSecureDesktop"      DWord 1

# --- 6. Audit prerequisites: force subcategory policy + log command lines ---
Write-Host "[6] Advanced-audit prerequisites" -ForegroundColor Cyan
Set-Reg $Lsa "SCENoApplyLegacyAuditPolicy" DWord 1   # let 09-script's subcategory policy win
Set-Reg "$SystemPolicy\Audit" "ProcessCreationIncludeCmdLine_Enabled" DWord 1

# --- 7. Limit cached domain credentials (reduce offline cred theft) ---
Write-Host "[7] Cached logon count = 4" -ForegroundColor Cyan
Set-Reg "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "CachedLogonsCount" String "4"

# --- 8. Host firewall ON for all profiles (PCI 1.4) ---
Write-Host "[8] Windows Firewall enabled (all profiles)" -ForegroundColor Cyan
foreach ($profile in @("DomainProfile","StandardProfile","PublicProfile")) {
    Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\$profile" "EnableFirewall" DWord 1
}

# --- 9. Event log sizing & retention (supports PCI 10 / ISO A.8.15) ---
Write-Host "[9] Event log sizes" -ForegroundColor Cyan
Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security"    "MaxSize" DWord 196608  # ~192 MB
Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application" "MaxSize" DWord 65536
Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\System"      "MaxSize" DWord 65536

# --- 10. Block removable storage (PCI 9 / ISO A.8.7 — data exfiltration) ---
Write-Host "[10] Deny all removable storage" -ForegroundColor Cyan
Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices" "Deny_All" DWord 1

# -- Link at domain root so DC01 + FS01 (and future hosts) inherit it --
Write-Host "`nLinking GPO to domain root..." -ForegroundColor Cyan
$existingLink = (Get-GPInheritance -Target $DomainDN).GpoLinks |
                Where-Object { $_.DisplayName -eq $GpoName }
if (-not $existingLink) {
    New-GPLink -Name $GpoName -Target $DomainDN -LinkEnabled Yes | Out-Null
    Write-Host "  Linked to $DomainDN" -ForegroundColor Green
} else {
    Write-Host "  Already linked." -ForegroundColor DarkYellow
}

Write-Host "`n=== Done. Run 'gpupdate /force' on DC01 and FS01 to apply. ===" -ForegroundColor Cyan
Write-Host "Verify with: gpresult /h C:\baseline-rsop.html  (then open the report)" -ForegroundColor Cyan
