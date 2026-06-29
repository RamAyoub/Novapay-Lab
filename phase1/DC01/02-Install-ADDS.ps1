# =============================================================================
# NovaPay Homelab — Install Active Directory Domain Services Role
# Script:  02-Install-ADDS.ps1
# Installs the AD DS Windows feature and management tools
# I myself didn't use this script and opted to use the Graphical Interface since I had the GUI version of Windows Server
# =============================================================================

Install-WindowsFeature `
    -Name AD-Domain-Services `
    -IncludeManagementTools `
    -Verbose

# Verify installation
$feature = Get-WindowsFeature -Name AD-Domain-Services
if ($feature.InstallState -eq "Installed") {
    Write-Host "`nAD DS is installed successfully." -ForegroundColor Green
} else {
    Write-Host "`nInstallation may have failed." -ForegroundColor Red
}
