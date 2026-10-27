<#
.SYNOPSIS
Creates Entra ID users from a CSV (FirstName, LastName, Department, JobTitle)
using the Microsoft Graph REST API. Skips users that already exist and writes
temporary passwords to a local CSV that is not committed to Git.
.EXAMPLE
./New-EntraUsersFromCsv.ps1 -CsvPath ./data/users.csv -Domain contoso.onmicrosoft.com -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$CsvPath,
    [Parameter(Mandatory)][string]$Domain,
    [string]$OutputPath = './reports'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }

$token = az account get-access-token --resource-type ms-graph --query accessToken -o tsv
if (-not $token) { throw 'Could not get a Graph token. Run az login first.' }
$headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
$base = 'https://graph.microsoft.com/v1.0/users'

function New-TempPassword {
    $chars = [char[]]'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    (-join (1..16 | ForEach-Object { $chars | Get-Random })) + 'Aa1!'
}

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

$results = foreach ($u in (Import-Csv $CsvPath)) {
    $first = $u.FirstName.Trim()
    $last  = $u.LastName.Trim()
    $nick  = ("$first.$last").ToLower()
    $upn   = "$nick@$Domain"
    $pw    = ''

    try {
        $filter = [uri]::EscapeDataString("userPrincipalName eq '$upn'")
        $existing = Invoke-RestMethod -Method Get -Uri "$base`?`$filter=$filter" -Headers $headers

        if ($existing.value.Count -gt 0) {
            $outcome = 'Already exists'
        }
        elseif ($PSCmdlet.ShouldProcess($upn, 'Create Entra user')) {
            $pw = New-TempPassword
            $body = @{
                accountEnabled    = $true
                displayName       = "$first $last"
                givenName         = $first
                surname           = $last
                userPrincipalName = $upn
                mailNickname      = $nick
                department        = $u.Department
                jobTitle          = $u.JobTitle
                passwordProfile   = @{ forceChangePasswordNextSignIn = $true; password = $pw }
            } | ConvertTo-Json -Depth 5
            Invoke-RestMethod -Method Post -Uri $base -Headers $headers -Body $body | Out-Null
            $outcome = 'Created'
        }
        else {
            $outcome = 'Skipped (WhatIf)'
        }
    }
    catch {
        $outcome = "Failed: $($_.Exception.Message)"
    }

    [pscustomobject]@{ UPN = $upn; Department = $u.Department; Result = $outcome; TempPassword = $pw }
}

$results | Select-Object UPN, Department, Result | Format-Table -AutoSize

if ($results | Where-Object TempPassword) {
    $file = "$OutputPath/new-users-$stamp.csv"
    $results | Where-Object TempPassword | Export-Csv $file -NoTypeInformation
    Write-Warning "Temporary passwords saved locally to $file (not committed to Git). Users must change them at first sign-in."
}
