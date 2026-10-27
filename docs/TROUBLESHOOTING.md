# Troubleshooting log

## 1. Connect-AzAccount fails on macOS
**Symptom:** `Interactive requests with mac broker enabled must be executed on the main thread`, then `SharedTokenCacheCredential authentication failed` on device-code login.
**Diagnosis:** the failure was in Az PowerShell's token handling on macOS, not in the account (the portal and `az login` worked).
**Fix:** signed in with Azure CLI (`az login`) and passed its token to Az with `Connect-AzAccount -AccessToken`.

## 2. Service principal login failed straight after creation
**Symptom:** `Could not find tenant id for provided tenant domain`.
**Diagnosis:** the tenant ID matched `az account show`, so it was a sign-in quirk and not a wrong tenant.
**Fix:** used the token login above to keep moving.

## 3. SkuNotAvailable (capacity restrictions) in uksouth
**Symptom:** VM creation failed for Standard_B1s, B2ats_v2 and B1ls.
**Diagnosis:** the error named the SKU and region, so this was regional capacity and not quota or permissions.
**Fix:** looped over several regions and sizes, deleting leftover NICs and public IPs after each failure. Standard_B2ats_v2 in swedencentral worked.

## 4. Microsoft.Graph.Users module failed to download
**Symptom:** `Package 'Microsoft.Graph.Users' failed to download` from the PowerShell Gallery.
**Fix:** replaced the module with direct Graph REST calls (`Invoke-RestMethod`) using an Azure CLI token. This also removed the one-hour token expiry.

## 5. mkdir with comma-separated paths in PowerShell
**Symptom:** `Could not find a part of the path` when writing a script.
**Fix:** use `New-Item -ItemType Directory -Force -Path a, b, c`; `mkdir -p` with commas does not work in PowerShell.
