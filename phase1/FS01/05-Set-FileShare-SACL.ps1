# =============================================================================
# NovaPay Homelab — File Share Audit SACLs
# Script:  05-Set-FileShare-SACL.ps1
# Purpose: Apply audit SACLs to sensitive share folders so that access to
#          cardholder/PII data generates Security Event 4663 / 4660. The
#          Advanced Audit Policy "File System" subcategory (set by GPO 09)
#          only logs folders that carry a SACL — this script provides it.
# Run on:  NOVAPAY-FS01 (elevated PowerShell), after GPO 09 is applied.
#
# Compliance mapping:
#   PCI-DSS v4.0  Req 10.2.1 — log all individual access to cardholder data
#   ISO 27001:2022 A.8.15    — Logging
#   SOC 2          CC7.2      — Detection of security events
# =============================================================================

$RootPath = "C:\NovaPay-Shares"

# Folders holding regulated/sensitive data — audit success & failure here.
$AuditTargets = @("Finance", "Compliance", "HR", "Executive")

# We audit Everyone for the access types that matter for an audit trail.
$AuditRights = [System.Security.AccessControl.FileSystemRights]"Modify, Delete, ChangePermissions, TakeOwnership, ReadData"
$Inherit     = "ContainerInherit,ObjectInherit"
$Prop        = "None"
$AuditFlags  = "Success,Failure"

foreach ($Target in $AuditTargets) {
    $Path = Join-Path $RootPath $Target
    if (-not (Test-Path $Path)) {
        Write-Host "  SKIPPED (missing): $Path" -ForegroundColor DarkYellow
        continue
    }

    $ACL  = Get-Acl -Path $Path -Audit
    $Rule = New-Object System.Security.AccessControl.FileSystemAuditRule(
        "Everyone", $AuditRights, $Inherit, $Prop, $AuditFlags)
    $ACL.AddAuditRule($Rule)
    Set-Acl -Path $Path -AclObject $ACL

    Write-Host "  SACL applied: $Path (Everyone / $AuditFlags)" -ForegroundColor Green
}

# -- Verify --
Write-Host "`n=== Audit SACLs ===" -ForegroundColor Cyan
foreach ($Target in $AuditTargets) {
    $Path = Join-Path $RootPath $Target
    if (Test-Path $Path) {
        Write-Host "`n$Path" -ForegroundColor White
        (Get-Acl -Path $Path -Audit).Audit |
            Select-Object IdentityReference, FileSystemRights, AuditFlags |
            Format-Table -AutoSize
    }
}

Write-Host "Tip: trigger a test event by opening/deleting a file in a share," -ForegroundColor Cyan
Write-Host "     then check Security log for Event ID 4663." -ForegroundColor Cyan
