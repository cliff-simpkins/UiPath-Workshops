# migrate-export.ps1
# Run against staging.uipath.com -- exports Sample_PDFs storage bucket and
# purchase_orders Data Fabric entity to a local migrate-export/ directory.
#
# Switch your uip tenant to staging BEFORE running:
#   uip login tenant set <staging-tenant-name>
#
# Usage:
#   .devrel\scripts\migrate-export.ps1 -FolderPath "Shared"
#
# Output: workshops\wad2026\migrate-export\
#   bucket\           - downloaded PDF files
#   bucket-index.json - maps remote paths to local filenames
#   df\schema.json    - purchase_orders entity schema
#   df\records.json   - all purchase_orders records

param(
    [Parameter(Mandatory)]
    [string]$FolderPath,                   # Orchestrator folder containing the bucket (e.g. "Shared")
    [string]$BucketName  = "Sample_PDFs",
    [string]$BucketKey   = "",                 # optional: skip name lookup and use this key directly
    [string]$EntityName  = "Purchase_Orders",  # pass "" to skip Data Fabric export
    [string]$OutputDir   = (Join-Path $PSScriptRoot "..\..\migrate-export")
)

$ErrorActionPreference = "Stop"

# --- Preflight ---
Write-Host "Checking login..."
$loginRaw = & uip login status --output json
$login    = $loginRaw | ConvertFrom-Json
if ($login.Data.Status -ne "Logged in") { Write-Error "Not logged in. Run: uip login"; exit 1 }
$tenantName = $login.Data.Tenant
Write-Host "Logged in - tenant: $tenantName"
Write-Host ""

New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "bucket\$BucketName") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "df")                 | Out-Null

# --- Storage Bucket ---
Write-Host "=== Storage Bucket: $BucketName ==="

if ($BucketKey) {
    Write-Host "Using provided bucket key: $BucketKey"
} else {
    $bucketsRaw = & uip or buckets list --all-folders --name $BucketName --output json
    $buckets    = $bucketsRaw | ConvertFrom-Json
    $bucket     = $buckets.Data | Where-Object { $_.Name -eq $BucketName } | Select-Object -First 1
    if (-not $bucket) {
        Write-Host "Bucket not found. Raw response:"
        Write-Host ($bucketsRaw | Out-String)
        Write-Error "Bucket '$BucketName' not found. Check the name and that you are on the correct tenant."
        exit 1
    }
    $BucketKey = $bucket.Key
    Write-Host "Found bucket - key: $BucketKey"
}

# List all files with continuation-token pagination
$allFiles  = [System.Collections.Generic.List[object]]::new()
$token     = $null
$pageCount = 0
do {
    $cmdArgs = @("or", "bucket-files", "list", $BucketKey, "--folder-path", $FolderPath, "--output", "json")
    if ($token) { $cmdArgs += @("--continuation-token", $token) }
    $pageRaw = & uip @cmdArgs
    $page    = $pageRaw | ConvertFrom-Json
    # Files are under Data.Items[]
    foreach ($f in $page.Data.Items) { $allFiles.Add($f) }
    $token   = $page.Data.ContinuationToken
    $pageCount++
} while ($token)

Write-Host "Files found: $($allFiles.Count) (across $pageCount page(s))"

$fileIndex = [System.Collections.Generic.List[object]]::new()
foreach ($f in $allFiles) {
    # FullPath is the bucket-relative path (e.g. "case-4-perfect-match-invoice.pdf")
    $remotePath = if ($f.FullPath) { $f.FullPath } else { $f.Path }
    if (-not $remotePath) { Write-Warning "Skipping file with no path: $($f | ConvertTo-Json -Compress)"; continue }

    # Strip leading slash, then flatten any remaining path separators
    $remotePath = $remotePath.TrimStart('/')
    $localName  = $remotePath -replace '/', '_'
    $destPath  = Join-Path $OutputDir "bucket\$BucketName\$localName"
    Write-Host "  Downloading: $remotePath"
    & uip or bucket-files download $BucketKey $remotePath `
        --folder-path $FolderPath --destination $destPath --output json | Out-Null
    $fileIndex.Add([pscustomobject]@{ RemotePath = $remotePath; LocalFile = $localName })
}

$fileIndex | ConvertTo-Json | Set-Content (Join-Path $OutputDir "bucket-$BucketName-index.json") -Encoding utf8
Write-Host "Bucket export complete."
Write-Host ""

# --- Data Fabric ---
if (-not $EntityName) {
    Write-Host "No EntityName specified - skipping Data Fabric export."
    Write-Host ""
    Write-Host "Export complete -> $OutputDir"
    exit 0
}
Write-Host "=== Data Fabric: $EntityName ==="

$entitiesRaw = & uip df entities list --native-only --output json
$entities    = $entitiesRaw | ConvertFrom-Json
$entity      = $entities.Data | Where-Object { $_.Name -eq $EntityName } | Select-Object -First 1
if (-not $entity) {
    Write-Host "Entity not found. Raw response:"
    Write-Host ($entitiesRaw | Out-String)
    Write-Error "Entity '$EntityName' not found. Verify the entity exists in staging."
    exit 1
}
$entityId = $entity.Id
Write-Host "Found entity - id: $entityId"

# Save full schema (used by import script to reconstruct field definitions)
$schemaRaw = & uip df entities get $entityId --output json
$schemaRaw | Set-Content (Join-Path $OutputDir "df\$EntityName-schema.json") -Encoding utf8
Write-Host "Schema saved."

# Export all records with cursor pagination
$allRecords = [System.Collections.Generic.List[object]]::new()
$cursor     = $null
$recPages   = 0
do {
    $cmdArgs = @("df", "records", "list", $entityId, "--limit", "200", "--output", "json")
    if ($cursor) { $cmdArgs += @("--cursor", $cursor) }
    $pageRaw = & uip @cmdArgs
    $page    = $pageRaw | ConvertFrom-Json
    $items   = if ($page.Data.Items) { $page.Data.Items } else { $page.Data }
    foreach ($r in $items) { $allRecords.Add($r) }
    $cursor  = if ($page.Data.HasNextPage) { $page.Data.NextCursor } else { $null }
    $recPages++
} while ($cursor)

Write-Host "Records exported: $($allRecords.Count) (across $recPages page(s))"
$allRecords | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $OutputDir "df\$EntityName-records.json") -Encoding utf8

Write-Host ""
Write-Host "Export complete -> $OutputDir"
Write-Host ""
Write-Host "Next: switch uip to cloud tenant, then run migrate-import.ps1 -FolderPath `"<target-folder>`""
