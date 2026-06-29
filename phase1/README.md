# Phase 1 — On-Premises Identity Foundation

## Overview
In this phase we establishe the on-premises Active Directory aspects/foundation for NovaPay 
Financial Services. All cloud phases (Entra ID, Sentinel, Defender) build on top 
of what is set up here.

## What Was Built

| Component | Hostname | IP | Role |
|---|---|---|---|
| Domain Controller | NOVAPAY-DC01 | 192.168.10.10 | This machine is our domain controller, where our AD DS is run.
| File Server | NOVAPAY-FS01 | 192.168.10.11 | This machine acts as server used for SMB file share.

- **Domain:** novapay.local
- **Hypervisor:** VirtualBox with NAT Network (NovaPay-Lab: 192.168.10.0/24)
- **OS:** Windows Server 2022 Standard Evaluation (Desktop Experience)

Our domain controller -accurately named- controls our domain and hosts it. Where we can install services, manage group policies and define Users/groups/computers.
And I also hosted another Win server to act as a file server to test File shares.


## OU Structure
```
DC=novapay,DC=local
└── OU=NovaPay
    ├── OU=Users
    │   ├── OU=Finance
    │   ├── OU=Engineering
    │   ├── OU=Compliance
    │   ├── OU=HR
    │   ├── OU=IT
    │   └── OU=Executive
    ├── OU=Computers
    ├── OU=Servers
    ├── OU=ServiceAccounts
    ├── OU=Groups
    └── OU=Privileged
```

## Users Created
| Name | Username | Department | Title |
|---|---|---|---|
| Alice Chen | a.chen | Finance | CFO |
| Bob Kumar | b.kumar | Engineering | Lead Developer |
| Ram Ayoub | r.ayoub | Compliance | GRC Manager |
| Emma Jones | e.jones | HR | HR Director |
| Frank Moore | f.moore | Executive | CEO |
| Grace Lee | g.lee | Finance | Financial Analyst |

## Security Groups
| Group | Members | Purpose |
|---|---|---|
| GRP-IT-Admins | | Elevated IT access 
| GRP-GRC-Team | r.ayoub | Compliance documents 
| GRP-Finance-Users | a.chen, g.lee | Finance shares 
| GRP-Developers | b.kumar | Engineering shares 
| GRP-Executives | f.moore, a.chen, e.jones | Executive shares 
| GRP-HR-Staff | e.jones | HR shares |
| GRP-All-Staff | All users | General access 

## File Shares
| Share | Path | Access Group | Visible |
|---|---|---|---|
| Finance$ | C:\NovaPay-Shares\Finance | GRP-Finance-Users | Hidden |
| Engineering$ | C:\NovaPay-Shares\Engineering | GRP-Developers | Hidden |
| Compliance$ | C:\NovaPay-Shares\Compliance | GRP-GRC-Team | Hidden |
| HR$ | C:\NovaPay-Shares\HR | GRP-HR-Staff | Hidden |
| IT$ | C:\NovaPay-Shares\IT | GRP-IT-Admins | Hidden |
| Executive$ | C:\NovaPay-Shares\Executive | GRP-Executives | Hidden |
| CompanyWide | C:\NovaPay-Shares\CompanyWide | GRP-All-Staff | Visible |

## Group Policy (Compliance Hardening)
Enforced domain-wide. Full control-to-framework mapping in
[Compliance-GPO-Matrix.md](Compliance-GPO-Matrix.md).

| GPO / Policy | Enforces | Linked to |
|---|---|---|
| Default Domain (password policy) | 14-char passwords, complexity, history 24, lockout @ 5 | Domain |
| NovaPay - Security Baseline | Logon banner, 15-min lock, SMBv1 off, NTLMv2-only, no LM hash, restrict anonymous, UAC, host firewall, log sizing, USB block | Domain root |
| NovaPay - Advanced Audit Policy | Logon, account mgmt, object access, privilege use, policy change, DS access auditing | Domain root |
| File share audit SACLs (FS01) | Event 4663 on Finance/Compliance/HR/Executive shares | FS01 |


**Apply order:** 

We need to remember to force refresh/update after any GPO changes using command`gpupdate /force`.
To verify the GPOs configuration use: `gpresult /h`
To verify the audit configuration use: `auditpol /get /category:*`

## Compliance Controls Implemented

I wanted to apply some controls well-established security controls following the different compliance standards

| Control | Framework | Reference |
|---|---|---|
| Centralised identity management | ISO 27001 | A.5.15 |
| User account provisioning | SOC 2 | CC6.2 |
| Role-based access via security groups | PCI-DSS | Req 7.1 |
| Least-privilege NTFS permissions | ISO 27001 | A.8.3 |
| Hidden shares for sensitive data | ISO 27001 | A.8.3 |
| Separate OU per department | ISO 27001 | A.5.15 |
| Compliant password & lockout policy | PCI-DSS | Req 8.3 |
| Endpoint security hardening baseline | PCI-DSS | Req 2.2 |
| Logon monitoring banner | ISO 27001 | A.5.4 |
| Advanced audit logging | PCI-DSS | Req 10.2 |
| File access auditing (SACL) | PCI-DSS | Req 10.2.1 |

## Known Issues & Decisions
| Decision | Reason |
|---|---|
| Faced an issue during partition selection while installing windows server on VirtualBox. Solution was to delete the partition entirely and reassign it. | Not sure exactly |
| Renamed FS01 to NOVAPAY-FS01 (not FILESERV01) | Windows 15-char NetBIOS limit |
| IPv6 disabled on both VMs | VirtualBox NAT Network IPv6 unreliable |

## Scripts

I ran all the scripts through an LLM for clarity and documentation purposes.
```
scripts/
├── DC01/
│   ├── 01-Configure-StaticIP.ps1       — Static IP before domain promotion
│   ├── 02-Install-ADDS.ps1             — Install AD DS role
│   ├── 03-Promote-DomainController.ps1 — Create novapay.local forest
│   ├── 04-Create-OUStructure.ps1       — Build OU hierarchy
│   ├── 05-Create-Users.ps1             — Provision employee accounts
│   ├── 06-Create-SecurityGroups.ps1    — Create groups and assign members
│   ├── 07-Set-PasswordPolicy.ps1       — Domain password & lockout policy
│   ├── 08-Create-SecurityBaseline-GPO.ps1 — Endpoint hardening GPO
│   └── 09-Configure-AuditPolicy-GPO.ps1   — Advanced audit policy GPO
└── FS01/
    ├── 01-Configure-StaticIP.ps1       — Static IP, DNS pointing at DC01
    ├── 02-Join-Domain.ps1              — Join novapay.local domain
    ├── 03-Install-FileServerRole.ps1   — Install FS role and firewall rules
    ├── 04-Configure-Shares.ps1         — Department shares with NTFS permissions
    └── 05-Set-FileShare-SACL.ps1       — Audit SACLs on sensitive shares
```