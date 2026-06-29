# =============================================================================
# NovaPay Homelab — Create Department Shares and NTFS Permissions
# Script:  04-Configure-Shares.ps1
# Purpose: Create NovaPay department shared folders with least-privilege access
# Run on:  NOVAPAY-FS01 (after File Server role is installed)
# Compliance: PCI-DSS Req 7 — Restrict access to cardholder data
#             ISO 27001 A.8.3 — Information access restriction
# =============================================================================

$RootPath = "C:\NovaPay-Shares"

# -- Department shares with their AD group mappings --
$Shares = @(
    @{ Name="Finance$";     Path="Finance";     Group="GRP-Finance-Users";  Rights="Modify";         Hidden=$true  },
    @{ Name="Engineering$"; Path="Engineering"; Group="GRP-Developers";     Rights="Modify";         Hidden=$true  },
    @{ Name="Compliance$";  Path="Compliance";  Group="GRP-GRC-Team";       Rights="Modify";         Hidden=$true  },
    @{ Name="HR$";          Path="HR";          Group="GRP-HR-Staff";       Rights="Modify";         Hidden=$true  },
    @{ Name="IT$";          Path="IT";          Group="GRP-IT-Admins";      Rights="Modify";         Hidden=$true  },
    @{ Name="Executive$";   Path="Executive";   Group="GRP-Executives";     Rights="ReadAndExecute"; Hidden=$true  },
    @{ Name="CompanyWide";  Path="CompanyWide"; Group="GRP-All-Staff";      Rights="Modify";         Hidden=$false }
)

# -- Create folder structure --
Write-Host "Creating folder structure..." -ForegroundColor Cyan
foreach ($S in $Shares) {
    $FullPath = "$RootPath\$($S.Path)"
    New-Item -Path $FullPath -ItemType Directory -Force | Out-Null
    Write-Host "  Created: $FullPath" -ForegroundColor Green
}

# -- Apply NTFS permissions (least privilege) --
Write-Host "`nApplying NTFS permissions..." -ForegroundColor Cyan

function Set-LeastPrivilegeACL {
    param($Path, $ADGroup, $Rights)

    $ACL = Get-Acl $Path
    $ACL.SetAccessRuleProtection($true, $false)     # Disable inheritance
    $ACL.Access | ForEach-Object { $ACL.RemoveAccessRule($_) }   # Clear all rules

    # SYSTEM — full control (always required)
    $ACL.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))

    # Domain Admins — full control
    $ACL.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        "NOVAPAY\Domain Admins", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))

    # Department group — least privilege access
    $ACL.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        "NOVAPAY\$ADGroup", $Rights, "ContainerInherit,ObjectInherit", "None", "Allow")))

    Set-Acl -Path $Path -AclObject $ACL
    Write-Host "  $Path → $ADGroup ($Rights)" -ForegroundColor Green
}

foreach ($S in $Shares) {
    Set-LeastPrivilegeACL -Path "$RootPath\$($S.Path)" -ADGroup $S.Group -Rights $S.Rights
}

# -- Create SMB shares --
Write-Host "`nCreating SMB shares..." -ForegroundColor Cyan
foreach ($S in $Shares) {
    $FullPath = "$RootPath\$($S.Path)"

    if (Get-SmbShare -Name $S.Name -ErrorAction SilentlyContinue) {
        Remove-SmbShare -Name $S.Name -Force
    }

    New-SmbShare `
        -Name                  $S.Name `
        -Path                  $FullPath `
        -FullAccess            "NOVAPAY\Domain Admins" `
        -ChangeAccess          "Everyone" `
        -FolderEnumerationMode AccessBased   # Users only see shares they can access

    $visibility = if ($S.Hidden) { "Hidden ($($S.Name) ends in `$)" } else { "Visible" }
    Write-Host "  \\NOVAPAY-FS01\$($S.Name) — $visibility" -ForegroundColor Green
}

# -- Verify --
Write-Host "`n=== SMB Shares Created ===" -ForegroundColor Cyan
Get-SmbShare |
    Where-Object { $_.Name -notmatch "^(ADMIN|C|IPC|print)" } |
    Select-Object Name, Path, Description |
    Format-Table -AutoSize
