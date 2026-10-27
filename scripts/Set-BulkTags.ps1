<#
.SYNOPSIS
Merges tags onto every resource in a resource group.
.EXAMPLE
./Set-BulkTags.ps1 -ResourceGroupName rg-pslab -Tags @{Environment='Dev'; Owner='Ravi'} -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][hashtable]$Tags
)

$ErrorActionPreference = 'Stop'

if (-not (Get-AzContext)) { throw 'Not logged in. Run Connect-AzAccount first.' }

try { $null = Get-AzResourceGroup -Name $ResourceGroupName }
catch { throw "Resource group '$ResourceGroupName' not found." }

$resources = Get-AzResource -ResourceGroupName $ResourceGroupName
Write-Host "Found $($resources.Count) resources in $ResourceGroupName"

foreach ($r in $resources) {
    if ($PSCmdlet.ShouldProcess($r.Name, "Merge tags: $($Tags.Keys -join ', ')")) {
        try {
            Update-AzTag -ResourceId $r.ResourceId -Tag $Tags -Operation Merge | Out-Null
            Write-Host "Tagged $($r.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed on $($r.Name): $($_.Exception.Message)"
        }
    }
}
