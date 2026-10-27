<#
.SYNOPSIS
Starts or stops (deallocates) VMs that carry a given tag.
.EXAMPLE
./Set-VmPowerState.ps1 -Action Stop -ResourceGroupName rg-pslab -WhatIf
./Set-VmPowerState.ps1 -Action Start -TagName AutoShutdown -TagValue true
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Start', 'Stop')][string]$Action,
    [string]$ResourceGroupName,
    [string]$TagName = 'AutoShutdown',
    [string]$TagValue = 'true'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-AzContext)) { throw 'Not logged in. Run Connect-AzAccount first.' }

$scope = @{}
if ($ResourceGroupName) { $scope.ResourceGroupName = $ResourceGroupName }

$vms = Get-AzVM @scope | Where-Object { $_.Tags -and $_.Tags[$TagName] -eq $TagValue }
Write-Host "Found $(@($vms).Count) VM(s) tagged $TagName=$TagValue"

$results = foreach ($vm in $vms) {
    $state = (Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status).Statuses |
        Where-Object Code -like 'PowerState/*' | Select-Object -ExpandProperty DisplayStatus

    $outcome = 'Skipped'
    if ($Action -eq 'Stop' -and $state -eq 'VM deallocated') { $outcome = 'Already stopped' }
    elseif ($Action -eq 'Start' -and $state -eq 'VM running') { $outcome = 'Already running' }
    elseif ($PSCmdlet.ShouldProcess($vm.Name, "$Action VM")) {
        try {
            if ($Action -eq 'Stop') { Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force | Out-Null }
            else { Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name | Out-Null }
            $outcome = "$Action succeeded"
        }
        catch { $outcome = "Failed: $($_.Exception.Message)" }
    }

    [pscustomobject]@{ VM = $vm.Name; ResourceGroup = $vm.ResourceGroupName; Before = $state; Result = $outcome }
}

$results | Format-Table -AutoSize
