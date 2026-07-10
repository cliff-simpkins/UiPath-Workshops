# migrate-import.ps1
# Run against the TARGET tenant -- imports a storage bucket and a Data Fabric
# entity from the migrate-export/ directory. Run TWICE for a full deploy:
#
#   .devrel\scripts\migrate-import.ps1 -FolderPath "Shared"                                            # Sample_PDFs + Purchase_Orders
#   .devrel\scripts\migrate-import.ps1 -FolderPath "Shared" -BucketName "Vendor_Contracts" -EntityName "Vendor_Alias"
#
# Switch your uip tenant to the target BEFORE running:
#   uip login tenant set <target-tenant-name>
#
# Prerequisites:
#   - Run migrate-export.ps1 against the SOURCE tenant first
#   - migrate-export\ directory must exist at workshops\wad2026\migrate-export\
#
# After both runs complete (full playbook verified 2026-07-08 -- see
# orchestrator-assets\README.md steps 3-5 for the exact commands):
#   1. Create + ingest the Vendor_Contracts context grounding index via
#      `uip context-grounding create / ingest / retrieve` (CLI, no Studio Web needed)
#   2. Recreate the IXP_Invoices model from orchestrator-assets\05_ixp_model\
#      (taxonomy import via CLI; folder deployment stays in-product)
#   3. Deploy the solution with `uip solution upload <.uis>` from a FRESH
#      `uip solution download` of the source tenant -- do NOT use pack/publish
#      (EscalationApp fails the local workflow compiler) and do NOT trust the
#      repo solutions\ copy without re-syncing first (sync-from-studio.ps1)
#   4. Note the new solution ID from step 3's output, then update:
#      - .devrel\scripts\sync-from-studio.ps1  ($Solutions)
#      - .devrel\workshop-design.md            (CLI eval commands)
#   5. In-product: IS connections, DF entity Manage Access (participants group
#      -> Data Reader), IXP deployment + flow rebinds

param(
    [Parameter(Mandatory)]
    [string]$FolderPath,                   # Orchestrator folder to create the bucket in (e.g. "Shared")
    [string]$BucketName  = "Sample_PDFs",   # name in the export (used to find the index file)
    [string]$ImportAs    = "",              # rename on import; defaults to $BucketName if not set
    [string]$BucketKey   = "",              # skip bucket creation and use this key directly
    [switch]$SkipBucket,                    # skip bucket creation and file upload entirely
    [string]$EntityName  = "Purchase_Orders",
    [string]$ExportDir   = (Join-Path $PSScriptRoot "..\..\migrate-export")
)

$ErrorActionPreference = "Stop"

# System-managed fields - never included in entity create or record insert
$SystemFields = @("Id", "CreatedBy", "CreateTime", "UpdatedBy", "UpdateTime", "RecordOwner")

# --- Preflight ---
Write-Host "Checking login..."
$loginRaw = & uip login status --output json
$login    = $loginRaw | ConvertFrom-Json
if ($login.Data.Status -ne "Logged in") { Write-Error "Not logged in. Run: uip login"; exit 1 }
$tenantName = $login.Data.Tenant
Write-Host "Logged in - tenant: $tenantName"
if (-not $ImportAs) { $ImportAs = $BucketName }

if (-not (Test-Path $ExportDir)) {
    Write-Error "Export directory not found: $ExportDir`nRun migrate-export.ps1 first."
    exit 1
}

$bucketIndexPath = Join-Path $ExportDir "bucket-$BucketName-index.json"
$schemaPath      = Join-Path $ExportDir "df\$EntityName-schema.json"
$recordsPath     = Join-Path $ExportDir "df\$EntityName-records.json"
$checkPaths = @()
if (-not $SkipBucket) { $checkPaths += $bucketIndexPath }
if ($EntityName)      { $checkPaths += @($schemaPath, $recordsPath) }
foreach ($p in $checkPaths) {
    if (-not (Test-Path $p)) { Write-Error "Missing export file: $p"; exit 1 }
}
Write-Host ""

# --- Storage Bucket ---
if ($SkipBucket) {
    Write-Host "Skipping bucket import (-SkipBucket set)."
    $newBucketKey = "(skipped)"
} else {
Write-Host "=== Storage Bucket: $ImportAs ==="

if ($BucketKey) {
    Write-Host "Using provided bucket key: $BucketKey (skipping create)"
    $newBucketKey = $BucketKey
} else {
    $createRaw = & uip or buckets create $ImportAs `
        --folder-path $FolderPath `
        --description "WAD2026 workshop invoice PDFs" `
        --output json
    $createResult = $createRaw | ConvertFrom-Json
    # create response uses "Identifier"; list response uses "Key"
    $newBucketKey = if ($createResult.Data.Identifier) { $createResult.Data.Identifier } `
                    elseif ($createResult.Data.Key)     { $createResult.Data.Key } `
                    else                                { $createResult.Data.key }
    if (-not $newBucketKey) { Write-Error "Bucket created but could not read Identifier from response:`n$createRaw"; exit 1 }
    Write-Host "Created bucket - key: $newBucketKey"
}

$fileIndex = Get-Content $bucketIndexPath | ConvertFrom-Json
Write-Host "Uploading $($fileIndex.Count) files..."
foreach ($entry in $fileIndex) {
    $localFile = Join-Path $ExportDir "bucket\$BucketName\$($entry.LocalFile)"
    if (-not (Test-Path $localFile)) {
        Write-Warning "Local file missing, skipping: $localFile"
        continue
    }
    Write-Host "  $($entry.RemotePath)"
    & uip or bucket-files upload $newBucketKey $entry.RemotePath `
        --folder-path $FolderPath --file $localFile --output json | Out-Null
}
Write-Host "Bucket import complete."
} # end else (-not SkipBucket)
Write-Host ""

# --- Data Fabric ---
if (-not $EntityName) {
    Write-Host "No EntityName specified - skipping Data Fabric import."
} else {
Write-Host "=== Data Fabric: $EntityName ==="

# Parse exported schema and build create-body fields
$schemaRaw    = Get-Content $schemaPath | ConvertFrom-Json
$schemaFields = $schemaRaw.Data.Fields

$createFields   = [System.Collections.Generic.List[object]]::new()
$skippedComplex = [System.Collections.Generic.List[string]]::new()

foreach ($f in $schemaFields) {
    $name = if ($f.FieldName)     { $f.FieldName }
            elseif ($f.fieldName) { $f.fieldName }
            elseif ($f.Name)      { $f.Name }
            else                  { $null }
    if (-not $name) { Write-Warning "Skipping field with no name"; continue }
    if ($name -in $SystemFields) { continue }

    # FieldDataType may be an object { Name: "STRING", ... } or a plain string
    $typeName = if ($f.FieldDataType -is [string])  { $f.FieldDataType }
                elseif ($f.FieldDataType.Name)       { $f.FieldDataType.Name }
                elseif ($f.fieldDataType.name)        { $f.fieldDataType.name }
                else                                 { $null }

    if (-not $typeName) { Write-Warning "Could not determine type for field '$name' - skipping"; continue }

    # Complex types require additional config that does not transfer automatically
    if ($typeName -match "^CHOICE_SET|^RELATIONSHIP|^FILE|^AUTO_NUMBER") {
        $skippedComplex.Add("$name ($typeName)")
        continue
    }

    $field = [ordered]@{ fieldName = $name; type = $typeName.ToUpper() }
    $displayName = if ($f.DisplayName) { $f.DisplayName } else { $f.displayName }
    $description = if ($f.Description) { $f.Description } else { $f.description }
    $isRequired  = if ($f.PSObject.Properties["IsRequired"])     { $f.IsRequired  } `
                   elseif ($f.PSObject.Properties["isRequired"]) { $f.isRequired  } else { $false }
    $isUnique    = if ($f.PSObject.Properties["IsUnique"])       { $f.IsUnique    } `
                   elseif ($f.PSObject.Properties["isUnique"])   { $f.isUnique    } else { $false }

    if ($displayName) { $field.displayName = $displayName }
    if ($description) { $field.description = $description }
    if ($isRequired)  { $field.isRequired  = $isRequired }
    if ($isUnique)    { $field.isUnique    = $isUnique }

    $createFields.Add($field)
}

if ($skippedComplex.Count -gt 0) {
    Write-Warning "Skipped $($skippedComplex.Count) complex field(s) - recreate manually in Studio Web:"
    $skippedComplex | ForEach-Object { Write-Warning "  $_" }
}

$createBody = (@{ fields = @($createFields) } | ConvertTo-Json -Depth 10 -Compress)
$tempBody   = [System.IO.Path]::GetTempFileName() + ".json"
[System.IO.File]::WriteAllText($tempBody, $createBody)

$entityRaw    = & uip df entities create $EntityName --file $tempBody --output json
$entityResult = $entityRaw | ConvertFrom-Json
$newEntityId  = if ($entityResult.Data.Id) { $entityResult.Data.Id } else { $entityResult.Data.id }
if (-not $newEntityId) { Write-Error "Entity created but could not read Id from response:`n$entityRaw"; exit 1 }
Write-Host "Created entity - id: $newEntityId"
Remove-Item $tempBody -Force

# Strip system fields from records and batch-insert
$rawRecords    = Get-Content $recordsPath | ConvertFrom-Json
$insertRecords = foreach ($r in $rawRecords) {
    $clean = [ordered]@{}
    $r.PSObject.Properties | Where-Object { $_.Name -notin $SystemFields } | ForEach-Object {
        $clean[$_.Name] = $_.Value
    }
    $clean
}

Write-Host "Inserting $($insertRecords.Count) records..."
$insertBody = ($insertRecords | ConvertTo-Json -Depth 10 -Compress)
$tempInsert = [System.IO.Path]::GetTempFileName() + ".json"
[System.IO.File]::WriteAllText($tempInsert, $insertBody)

$insertRaw    = & uip df records insert $newEntityId --file $tempInsert --output json
$insertResult = $insertRaw | ConvertFrom-Json
$successCount = if ($insertResult.Data.SuccessRecords) { @($insertResult.Data.SuccessRecords).Count } else { "?" }
$failCount    = if ($insertResult.Data.FailureRecords) { @($insertResult.Data.FailureRecords).Count } else { 0 }
Write-Host "Inserted: $successCount success, $failCount failures"
if ($failCount -gt 0) {
    Write-Warning "Some records failed. Failure details:"
    $insertResult.Data.FailureRecords | ForEach-Object { Write-Warning "  $($_ | ConvertTo-Json -Compress)" }
}
Remove-Item $tempInsert -Force
} # end else (EntityName)

# --- Summary ---
Write-Host ""
Write-Host "Import complete."
Write-Host ""
Write-Host "Resource IDs for cloud.uipath.com:"
Write-Host "  Storage bucket key : $newBucketKey"
if ($EntityName) { Write-Host "  DF entity ID       : $newEntityId" }
Write-Host ""
Write-Host "Remaining steps (see header comment + orchestrator-assets\README.md steps 3-5):"
Write-Host "  1. Second import run if not done yet: -BucketName Vendor_Contracts -EntityName Vendor_Alias"
Write-Host "  2. CG index: uip context-grounding create/ingest/retrieve (CLI)"
Write-Host "  3. IXP model: recreate from orchestrator-assets\05_ixp_model\"
Write-Host "  4. Solution: uip solution upload <fresh .uis download> (NOT pack/publish)"
Write-Host "  5. Update sync-from-studio.ps1 + workshop-design.md with the new solution ID"
Write-Host "  6. In-product: IS connections, DF entity access, IXP deployment + rebinds"
