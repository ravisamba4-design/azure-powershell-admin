# azure-powershell-admin

PowerShell scripts for everyday Azure administration, built and tested against my own Azure subscription.
Each script supports `-WhatIf`, validates input, handles errors per resource, and is safe to rerun.

## Scripts

| Script | What it does |
|---|---|
| `Set-BulkTags.ps1` | Merges tags onto every resource in a resource group |
| `Get-AzResourceReport.ps1` | Reports resources missing required tags, plus unattached disks, unassociated public IPs and orphaned NICs; exports CSV |
| `Set-VmPowerState.ps1` | Starts or deallocates VMs selected by tag (cost control) |
| `New-EntraUsersFromCsv.ps1` | Creates Entra ID users from a CSV via the Microsoft Graph REST API; skips existing users; writes temporary passwords to a local, git-ignored file |

## Requirements
- PowerShell 7+, Az.Accounts, Az.Resources, Az.Storage, Az.Compute, Az.Network
- Azure CLI (used for sign-in and the Graph token)
- An Azure subscription with permission to manage resources and users

## Usage

    ./scripts/Set-BulkTags.ps1 -ResourceGroupName rg-pslab -Tags @{Environment='Dev'; Owner='Ravi'} -WhatIf
    ./scripts/Get-AzResourceReport.ps1 -RequiredTags Environment,Owner
    ./scripts/Set-VmPowerState.ps1 -Action Stop -ResourceGroupName rg-pslab
    ./scripts/New-EntraUsersFromCsv.ps1 -CsvPath ./data/users.csv -Domain <tenant>.onmicrosoft.com -WhatIf

## Design choices
- `-WhatIf` / `SupportsShouldProcess` on every script that changes anything
- Idempotent: reruns skip things already done (existing users, stopped VMs)
- Per-item `try/catch`, so one failure does not stop the whole run
- No secrets in the repo; generated reports and passwords are git-ignored

## Troubleshooting
Real problems I hit and how I diagnosed them: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
