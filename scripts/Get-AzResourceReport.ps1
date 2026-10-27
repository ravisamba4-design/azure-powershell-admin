<#
.SYNOPSIS
Reports resources missing required tags, plus unused resources
(unattached disks, unassociated public IPs, orphaned NICs).
.EXAMPLE
./Get-AzResourceReport.ps1 -RequiredTags Environment,Owner -OutputPath ./reports
#>
[CmdletBinding()]
param(
    [string[]]$RequiredTags = @('Environment', 'Owner'),
    [string]$OutputPath = './reports'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-AzContext)) { throw 'Not logged in. Run Connect-AzAccount first.' }

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

# 1. Resources missing required tags
Write-Host 'Checking tags...'
$untagged = foreach ($r in Get-AzResource) {
    $missing = @($RequiredTags | Where-Object { -not ($r.Tags -and $r.Tags.ContainsKey($_)) })
    if ($missing.Count -gt 0) {
        [pscustomobject]@{
            Name          = $r.Name
            Type          = $r.ResourceType
            ResourceGroup = $r.ResourceGroupName
            MissingTags   = $missing -join ', '
        }
    }
}

# 2. Unused resources
Write-Host 'Checking for unused resources...'
$unused = @()

$unused += Get-AzDisk | Where-Object { -not $_.ManagedBy -and $_.DiskState -eq 'Unattached' } |
    ForEach-Object {
        [pscustomobject]@{ Type = 'Disk'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName; Detail = "$($_.DiskSizeGB) GB, $($_.Sku.Name)" }
    }

$unused += Get-AzPublicIpAddress | Where-Object { -not $_.IpConfiguration } |
    ForEach-Object {
        [pscustomobject]@{ Type = 'PublicIP'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName; Detail = $_.PublicIpAllocationMethod }
    }

$unused += Get-AzNetworkInterface | Where-Object { -not $_.VirtualMachine -and -not $_.PrivateEndpoint } |
    ForEach-Object {
        [pscustomobject]@{ Type = 'NIC'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName; Detail = 'Not attached to a VM' }
    }

# 3. Output
if ($untagged) {
    $untagged | Export-Csv "$OutputPath/untagged-$stamp.csv" -NoTypeInformation
    Write-Host "`nResources missing tags: $(@($untagged).Count)" -ForegroundColor Yellow
    $untagged | Format-Table -AutoSize
} else {
    Write-Host 'All resources have the required tags.' -ForegroundColor Green
}

if ($unused) {
    $unused | Export-Csv "$OutputPath/unused-$stamp.csv" -NoTypeInformation
    Write-Host "`nUnused resources: $(@($unused).Count)" -ForegroundColor Yellow
    $unused | Format-Table -AutoSize
} else {
    Write-Host 'No unused resources found.' -ForegroundColor Green
}

Write-Host "`nCSV reports saved to $OutputPath"
