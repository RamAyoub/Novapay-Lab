# =============================================================================
# NovaPay Homelab — Create Domain User Accounts
# Script:  05-Create-Users.ps1
# quickly provision the employee accounts in the correct department OUs

# =============================================================================

$DefaultPassword = ConvertTo-SecureString "Welcome123!Change" -AsPlainText -Force
$DomainBase      = "DC=novapay,DC=local"
$UsersBase       = "OU=Users,OU=NovaPay,$DomainBase"

# -- NovaPay employee roster --
$Users = @(
    @{ Name="Alice Chen";   SAM="a.chen";   Dept="Finance";     Title="CFO";                  OU="Finance"     },
    @{ Name="Bob Kumar";    SAM="b.kumar";  Dept="Engineering"; Title="Lead Developer";        OU="Engineering" },
    @{ Name="Ram Ayoub";  SAM="r.ayoub";  Dept="Compliance";  Title="GRC Manager";           OU="Compliance"  },
    @{ Name="Emma Jones";   SAM="e.jones";  Dept="HR";          Title="HR Director";           OU="HR"          },
    @{ Name="Frank Moore";  SAM="f.moore";  Dept="Executive";   Title="CEO";                   OU="Executive"   },
    @{ Name="Grace Lee";    SAM="g.lee";    Dept="Finance";     Title="Financial Analyst";     OU="Finance"     }
)

Write-Host "Creating NovaPay user accounts..." -ForegroundColor Cyan

foreach ($U in $Users) {
    $UPN     = "$($U.SAM)@novapay.local"
    $OUPath  = "OU=$($U.OU),$UsersBase"

    # Skip if user already exists
    if (Get-ADUser -Filter { SamAccountName -eq $U.SAM } -ErrorAction SilentlyContinue) {
        Write-Host "  SKIPPED (exists): $($U.Name)" -ForegroundColor DarkYellow
        continue
    }

    New-ADUser `
        -Name                  $U.Name `
        -SamAccountName        $U.SAM `
        -UserPrincipalName     $UPN `
        -Department            $U.Dept `
        -Title                 $U.Title `
        -Path                  $OUPath `
        -AccountPassword       $DefaultPassword `
        -Enabled               $true `
        -ChangePasswordAtLogon $true `
        -PasswordNeverExpires  $false

    Write-Host "  Created: $($U.Name) [$UPN]" -ForegroundColor Green
}