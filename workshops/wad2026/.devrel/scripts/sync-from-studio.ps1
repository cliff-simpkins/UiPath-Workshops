# Sync solutions/ with current Studio Web state, then commit and push.
# Run from any directory — uses paths relative to this script's location.
#
# Downloads two solutions:
#   wad2026-workshop      → WAD2026 Workshop (baa720e6-c392-44f3-2551-08decd1474e1)
#   wad2026-workshop-hitl → WAD2026 Workshop - with HITL (17acfb56-034c-4561-bd44-905ae9c437fd)
#
# Usage:
#   .devrel\scripts\sync-from-studio.ps1
#   .devrel\scripts\sync-from-studio.ps1 -CommitMessage "custom message"
#   .devrel\scripts\sync-from-studio.ps1 -SkipGit   # download only, no commit/push

param(
    [string]$CommitMessage = "Sync solutions/ with Studio Web state via uip solution download",
    [switch]$SkipGit
)

$Solutions = @(
    @{ Id = "baa720e6-c392-44f3-2551-08decd1474e1"; Dir = "wad2026-workshop" },
    @{ Id = "17acfb56-034c-4561-bd44-905ae9c437fd"; Dir = "wad2026-workshop-hitl" }
)

$Temp        = "$env:TEMP\wad2026-sync"
$SolutionsDir = Join-Path $PSScriptRoot "..\..\solutions"
$RepoRoot    = Join-Path $PSScriptRoot "..\..\"

foreach ($s in $Solutions) {
    $SolutionId  = $s.Id
    $TargetDir   = Join-Path $SolutionsDir $s.Dir
    $TempSub     = Join-Path $Temp $SolutionId

    Write-Host "`nDownloading $($s.Dir) ($SolutionId)..."
    uip solution download $SolutionId -d $Temp --extract --output json
    if ($LASTEXITCODE -ne 0) { Write-Error "Download failed for $SolutionId"; exit 1 }

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Force $TargetDir | Out-Null
    }

    Write-Host "Wiping $TargetDir (preserving .gitignore)..."
    Get-ChildItem -Path $TargetDir | Where-Object { $_.Name -ne ".gitignore" } | Remove-Item -Recurse -Force -Confirm:$false

    Write-Host "Copying fresh download to $TargetDir..."
    Copy-Item -Path "$TempSub\*" -Destination $TargetDir -Recurse -Force
}

Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue

if ($SkipGit) {
    Write-Host "`nDone (git skipped)."
    exit 0
}

Write-Host "`nCommitting and pushing..."
git -C $RepoRoot add "workshops/wad2026/solutions/"
git -C $RepoRoot commit -m "$CommitMessage`n`nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git -C $RepoRoot push
Write-Host "Done."
