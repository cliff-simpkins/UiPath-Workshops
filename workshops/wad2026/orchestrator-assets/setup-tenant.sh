#!/usr/bin/env bash
# setup-tenant.sh
# Self-serve tenant setup for the WAD2026 workshop ("Trust, but Verify").
# Provisions every scriptable prerequisite in this directory against YOUR OWN
# UiPath tenant, then prints the remaining in-product steps.
#
# Works on macOS, Linux, and Windows (via Git Bash). This does NOT need
# access to the original workshop tenant. Everything it imports is already
# checked into this repo, right here and in ../solutions/invoice-processing-flow/.
#
# Prerequisites: uip CLI (npm install -g @uipath/cli), jq (brew install jq /
# apt install jq / https://jqlang.github.io/jq/download/), uip login already run.
#
# Usage (run from anywhere - paths below are relative to this script):
#   uip login                                          # log into YOUR tenant first
#   bash orchestrator-assets/setup-tenant.sh --folder-path "Shared"
#
# Resume a partial run (skip steps already completed):
#   bash orchestrator-assets/setup-tenant.sh --folder-path "Shared" --skip-buckets --skip-data-fabric
#
# What this script does (steps 1-5 of README.md in this directory):
#   1. Storage buckets   - Sample_PDFs, Vendor_Contracts (+ upload PDFs)
#   2. Data Fabric        - Purchase_Orders, Vendor_Alias entities (+ records)
#   3. Context Grounding  - Vendor_Contracts index (create, ingest, poll)
#   4. IXP model           - IXP_Invoices project (taxonomy import, publish)
#   5. Solution upload     - imports the Flow + agents into Studio Web
#
# What it does NOT do (in-product, account-bound - see printed checklist):
#   - Integration Service connections (Outlook 365, GenAI Activities, Data Service)
#   - Data Fabric "Manage Access" grants
#   - IXP folder deployment + documentExtraction1 rebind (uip ixp deployments
#     create/list are documented by the uipath-ixp skill but not implemented
#     on the installed CLI - verified against v1.200.0, "unknown command")
#   - First-deploy connection linking, solution rename, CG index rebind
#
# Reusing this for a different workshop/demo:
#   Copy this whole file into the new workshop's orchestrator-assets/, then:
#   1. Edit the "Asset configuration" block below to match the new asset names.
#   2. Match the directory contract it reads from (relative to this script):
#        01_storage_bucket/<BUCKET_NAMES entry>/*        - files to upload
#        02_data_fabric/<ENTITY_DIRS entry>/schema.json  - uip df entities get shape
#        02_data_fabric/<ENTITY_DIRS entry>/records.json - uip df records list shape
#        <IXP_TAXONOMY_REL_PATH>                         - inner Data.dataset from get-taxonomy
#        ../solutions/<VALID_SOLUTIONS entry>/            - uip solution download --extract output
#   3. Re-run the smoke test end-to-end against a throwaway tenant before trusting it -
#      this exact process surfaced multiple real jq/CLI bugs that only showed up live.
#   This is a copy-and-customize script, not a shared tool read from external config -
#   a bug fix made here (e.g. the uip_json noise-stripping helper) does not propagate
#   to any other workshop's copy; re-apply it by hand if one exists.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Asset configuration ---
# The one place to look/edit to retarget this script at a different set of
# workshop assets. Everything below the "Preflight" section reads from these
# instead of hardcoding names inline.
WORKSHOP_LABEL="Invoice Processing Flow"

BUCKET_NAMES=("Sample_PDFs" "Vendor_Contracts")

# Data Fabric assets to deploy
ENTITY_NAMES=("Purchase_Orders" "Vendor_Alias")
ENTITY_DIRS=("purchase_orders" "vendor_alias")     # parallel to ENTITY_NAMES - schema/records live under 02_data_fabric/<dir>/

# Context Grounding assets to deploy
CG_INDEX_NAME="Vendor_Contracts"
CG_BUCKET_SOURCE="Vendor_Contracts"                # must be one of BUCKET_NAMES

# IXP project to deploy
IXP_PROJECT_TITLE="IXP_Invoices"
IXP_SAMPLE_BUCKET_NAME="Sample_PDFs"               # must be one of BUCKET_NAMES - local PDFs used to seed the project
IXP_TAXONOMY_REL_PATH="05_ixp_model/taxonomy.json"
IXP_MODEL="gemini_2_5_flash"
IXP_PREPROCESSING="none"

# Studio solutions to deploy
VALID_SOLUTIONS=("invoice-processing-flow" "wad2026-workshop-hitl")
DEFAULT_SOLUTION="invoice-processing-flow"

# --- Defaults ---
FOLDER_PATH=""
SOLUTION="$DEFAULT_SOLUTION"
SKIP_BUCKETS=0
SKIP_DATA_FABRIC=0
SKIP_CONTEXT_GROUNDING=0
SKIP_IXP=0
SKIP_SOLUTION_UPLOAD=0
FORCE_SOLUTION_UPLOAD=0
ASSETS_DIR="$SCRIPT_DIR"
SOLUTIONS_DIR="$SCRIPT_DIR/../solutions"
SUMMARY_OUT="$SCRIPT_DIR/setup-tenant-summary.json"

usage() {
    grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --folder-path) FOLDER_PATH="$2"; shift 2 ;;
        --solution) SOLUTION="$2"; shift 2 ;;
        --skip-buckets) SKIP_BUCKETS=1; shift ;;
        --skip-data-fabric) SKIP_DATA_FABRIC=1; shift ;;
        --skip-context-grounding) SKIP_CONTEXT_GROUNDING=1; shift ;;
        --skip-ixp) SKIP_IXP=1; shift ;;
        --skip-solution-upload) SKIP_SOLUTION_UPLOAD=1; shift ;;
        --force-solution-upload) FORCE_SOLUTION_UPLOAD=1; shift ;;
        --assets-dir) ASSETS_DIR="$2"; shift 2 ;;
        --solutions-dir) SOLUTIONS_DIR="$2"; shift 2 ;;
        --summary-out) SUMMARY_OUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown argument: $1" >&2; usage ;;
    esac
done

if [[ -z "$FOLDER_PATH" ]]; then
    echo "ERROR: --folder-path is required (the Orchestrator folder to provision into, e.g. \"Shared\")" >&2
    exit 1
fi
solution_valid=0
for s in "${VALID_SOLUTIONS[@]}"; do
    [[ "$SOLUTION" == "$s" ]] && solution_valid=1 && break
done
if [[ "$solution_valid" -eq 0 ]]; then
    echo "ERROR: --solution must be one of: ${VALID_SOLUTIONS[*]}" >&2
    exit 1
fi

section() { echo ""; echo "=== $1 ==="; }

# System-managed fields - never included in entity create or record insert
SYSTEM_FIELDS_JQ='["Id","CreatedBy","CreateTime","UpdatedBy","UpdateTime","RecordOwner"]'

# --- Preflight ---
section "Preflight"

if ! command -v uip >/dev/null 2>&1; then
    echo "ERROR: uip CLI not found on PATH. Install it first: npm install -g @uipath/cli" >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not found on PATH. Install it: brew install jq (Mac) / apt install jq (Linux) / see https://jqlang.github.io/jq/download/ (Windows)" >&2
    exit 1
fi

# The uip CLI's own background update-check intermittently prints non-JSON
# noise ("Checking for updates...", "Update failed: ...", "Re-running the
# requested command...") ahead of the actual --output json payload (a known
# npm-registry/SSH bug, not fixable from here). Every call whose output gets
# parsed goes through this so a stray noise line can't break jq. Take the
# LAST top-level '{'-opening line onward (tac/sed/tac) rather than the first,
# since the real payload always prints last and noise can appear in more than
# one chunk - taking the first '{' can still capture a corrupted mix.
uip_json() {
    uip "$@" 2>&1 | tac | sed -n '0,/^[{[]$/p' | tac
}

login_raw="$(uip_json login status --output json)"
login_status="$(echo "$login_raw" | jq -r '.Data.Status')"
if [[ "$login_status" != "Logged in" ]]; then
    echo "ERROR: Not logged in. Run 'uip login' against YOUR OWN tenant first, then re-run this script." >&2
    exit 1
fi
tenant="$(echo "$login_raw" | jq -r '.Data.Tenant')"
tenant_id="$(echo "$login_raw" | jq -r '.Data.TenantId')"
echo "Logged in - tenant: $tenant"
echo "Target Orchestrator folder: $FOLDER_PATH"

if [[ ! -d "$ASSETS_DIR" ]]; then
    echo "ERROR: orchestrator-assets not found at: $ASSETS_DIR" >&2
    exit 1
fi
SOLUTION_PATH="$SOLUTIONS_DIR/$SOLUTION"
if [[ "$SKIP_SOLUTION_UPLOAD" -eq 0 && ! -d "$SOLUTION_PATH" ]]; then
    echo "ERROR: Solution folder not found at: $SOLUTION_PATH" >&2
    exit 1
fi

# IXP (the `uip ixp` surface, backed by the "reinfer" tenant service) requires
# its own licensing entitlement, separate from classic Document Understanding.
# A tenant can have "du" enabled and still 404 on `uip ixp projects create`
# with ServiceNotInstalledError - and `uip ixp projects list` alone does NOT
# reveal this (list succeeds even when create can't; the license gate is
# enforced on the write path). Check the real tenant-service state instead of
# probing the IXP surface itself, so this triggers before Step 1, not Step 4.
if [[ "$SKIP_IXP" -eq 0 ]]; then
    # `uip admin tenants services list` does NOT return a Status field per its
    # actual (current) output, despite what its own docs say - use `tenants
    # get`'s TenantServiceInstances[] instead, which does carry Status and was
    # verified directly against a live tenant.
    services_raw="$(uip_json admin tenants get "$tenant_id" --output json)"
    services_result="$(echo "$services_raw" | jq -r '.Result // empty' 2>/dev/null)"
    if [[ "$services_result" != "Success" ]]; then
        echo "NOTE: could not verify IXP licensing (uip admin tenants get failed) - continuing; Step 4 may still fail." >&2
    else
        reinfer_status="$(echo "$services_raw" | jq -r '[.Data.TenantServiceInstances[]? | select(.ServiceType == "reinfer")] | .[0].Status // "NotProvisioned"' 2>/dev/null)"
        if [[ "$reinfer_status" != "Enabled" ]]; then
            echo "WARNING: IXP is not licensed on tenant '$tenant' (reinfer service: $reinfer_status)." >&2
            echo "  This is a licensing entitlement gap, not something this script can route around." >&2
            echo "  Provision: uip admin tenants services add --tenant-id $tenant_id --service reinfer --output json" >&2
            echo "  If that returns 'Insufficient License', this tenant's plan needs the entitlement upgraded first." >&2
            echo "  Skipping Step 4 (IXP model) for this run." >&2
            SKIP_IXP=1
        fi
    fi
fi

# Tenant-level licensing (above) is necessary but not sufficient: IXP also
# gates access per-USER, separate from the tenant service. A tenant can have
# "reinfer" fully licensed and a specific user still gets a 401
# authentication_required / [IxpUpstreamError] on every `uip ixp` call until
# an admin grants them access on the IXP product page's "Assign Users"
# screen (in-product only - no CLI/admin-service equivalent found). This is
# NOT the same failure as the tenant-service check above and that check
# cannot see it, so probe the actual surface too.
if [[ "$SKIP_IXP" -eq 0 ]]; then
    ixp_probe_raw="$(uip_json ixp projects list --output json)"
    ixp_probe_result="$(echo "$ixp_probe_raw" | jq -r '.Result // empty' 2>/dev/null)"
    if [[ "$ixp_probe_result" != "Success" ]]; then
        echo "WARNING: IXP rejected the current user on tenant '$tenant' (uip ixp projects list: $ixp_probe_result)." >&2
        echo "  This is usually a per-user permission gap, not a tenant licensing issue -" >&2
        echo "  in the product UI: IXP -> Assign Users -> grant this user access, then re-run." >&2
        echo "  Skipping Step 4 (IXP model) for this run." >&2
        SKIP_IXP=1
    fi
fi

# Context Grounding's AdvancedIngestion draws from the org's AI Units (AIU)
# pool. There's no clean per-operation preflight for this, but a quick balance
# check surfaces an obviously-exhausted account before Step 3 wastes 5 minutes
# polling an ingestion that already failed on licensing.
if [[ "$SKIP_CONTEXT_GROUNDING" -eq 0 ]]; then
    aiu_raw="$(uip_json platform licenses consumables get --tenant "$tenant" --output json)"
    aiu_line="$(echo "$aiu_raw" | jq -r '.Data[]? | select(.code == "AIU") | "AI Units - total: \(.totalUnitsInAccount // "?"), consumed (tenant pool): \(.consumedFromTenantPool // "?"), consumed (org pool): \(.consumedFromOrgPool // "?")"' 2>/dev/null)"
    if [[ -n "$aiu_line" ]]; then
        echo "$aiu_line"
    else
        echo "NOTE: could not read AI Units balance (uip platform licenses consumables get) - continuing anyway." >&2
    fi
fi

# Running summary, built up as jq filter args so we never hand-craft JSON strings
summary_bucket_args=()
summary_df_args=()
summary_cg_status="not run"
summary_ixp_slug=""
summary_solution_id=""

# --- Step 1: Storage Buckets ---
if [[ "$SKIP_BUCKETS" -eq 1 ]]; then
    section "Step 1: Storage Buckets (skipped)"
else
    section "Step 1: Storage Buckets"

    for bucket_name in "${BUCKET_NAMES[@]}"; do
        source_dir="$ASSETS_DIR/01_storage_bucket/$bucket_name"
        if [[ ! -d "$source_dir" ]]; then
            echo "WARNING: no source folder for bucket '$bucket_name' at $source_dir - skipping." >&2
            continue
        fi

        echo ""
        echo "-- Bucket: $bucket_name --"
        # --name is a "contains" filter (not exact), and there's no documented
        # default page size for --limit - pass both the name filter (keeps the
        # result set small) and a generous explicit --limit (belt-and-suspenders
        # against an unstated default truncating results on a busy tenant).
        existing_raw="$(uip_json or buckets list --folder-path "$FOLDER_PATH" --name "$bucket_name" --limit 1000 --output json)"
        bucket_key="$(echo "$existing_raw" | jq -r --arg n "$bucket_name" '(.Data // [])[] | select(.Name == $n) | (.Key // .key // empty)' 2>/dev/null | head -n1)"
        if [[ -n "$bucket_key" ]]; then
            echo "Bucket already exists - key: $bucket_key (skipping create)"
        else
            create_raw="$(uip_json or buckets create "$bucket_name" \
                --folder-path "$FOLDER_PATH" \
                --description "$WORKSHOP_LABEL asset - $bucket_name" \
                --output json)"
            bucket_key="$(echo "$create_raw" | jq -r '.Data.Identifier // .Data.Key // .Data.key // empty')"
            if [[ -z "$bucket_key" ]]; then
                echo "ERROR: bucket created but could not read key from response:" >&2
                echo "$create_raw" >&2
                exit 1
            fi
            echo "Created bucket - key: $bucket_key"
        fi

        # Uploads are safe to repeat - a re-upload to the same remote path
        # overwrites rather than duplicates.

        file_count=0
        for f in "$source_dir"/*; do
            [[ -f "$f" ]] || continue
            file_count=$((file_count + 1))
        done
        echo "Uploading $file_count file(s)..."
        for f in "$source_dir"/*; do
            [[ -f "$f" ]] || continue
            echo "  $(basename "$f")"
            uip or bucket-files upload "$bucket_key" "$(basename "$f")" \
                --folder-path "$FOLDER_PATH" --file "$f" --output json >/dev/null
        done
        summary_bucket_args+=(--arg "$bucket_name" "$bucket_key")
    done
    echo ""
    echo "Storage buckets complete."
fi

# --- Step 2: Data Fabric ---
if [[ "$SKIP_DATA_FABRIC" -eq 1 ]]; then
    section "Step 2: Data Fabric (skipped)"
else
    section "Step 2: Data Fabric"

    for i in "${!ENTITY_NAMES[@]}"; do
        entity_name="${ENTITY_NAMES[$i]}"
        entity_dir="${ENTITY_DIRS[$i]}"
        schema_path="$ASSETS_DIR/02_data_fabric/$entity_dir/schema.json"
        records_path="$ASSETS_DIR/02_data_fabric/$entity_dir/records.json"
        if [[ ! -f "$schema_path" || ! -f "$records_path" ]]; then
            echo "WARNING: missing schema/records for entity '$entity_name' under $entity_dir - skipping." >&2
            continue
        fi

        echo ""
        echo "-- Entity: $entity_name --"

        existing_raw="$(uip_json df entities list --native-only --output json)"
        entity_id="$(echo "$existing_raw" | jq -r --arg n "$entity_name" '(.Data // [])[] | select(.Name == $n) | (.Id // .id // empty)' 2>/dev/null | head -n1)"
        if [[ -n "$entity_id" ]]; then
            echo "Entity already exists - id: $entity_id (skipping create + record seed - records insert has no dedup, so re-seeding an existing entity would double up rows)"
            summary_df_args+=(--arg "$entity_name" "$entity_id")
            continue
        fi

        skipped_complex="$(jq -r --argjson sys "$SYSTEM_FIELDS_JQ" '
            .Data.Fields[]
            | (.FieldName // .fieldName // .Name) as $n
            | select(($sys | index($n)) == null)
            | (.FieldDataType.Name // .FieldDataType // .fieldDataType.name) as $t
            | select($t != null and ($t | test("^(CHOICE_SET|RELATIONSHIP|FILE|AUTO_NUMBER)")))
            | "\($n) (\($t))"
        ' "$schema_path")"
        if [[ -n "$skipped_complex" ]]; then
            echo "WARNING: skipped complex field(s) on '$entity_name' - recreate manually in Studio Web if needed:" >&2
            echo "$skipped_complex" | sed 's/^/  /' >&2
        fi

        # Field key: docs (uipath-platform skill, entity-schema.md) say "name";
        # the live CLI (confirmed against v1.199.0) rejects that and requires
        # "fieldName" ({"Message":"Each field must include a 'fieldName' string"}).
        # Send both so this works regardless of which generation of the API a
        # given MVP's installed CLI actually talks to.
        create_body="$(jq --argjson sys "$SYSTEM_FIELDS_JQ" '{
            displayName: (.Data.DisplayName // .Data.Name),
            description: (.Data.Description // null),
            fields: [
                .Data.Fields[]
                | (.FieldName // .fieldName // .Name) as $n
                | select(($sys | index($n)) == null)
                | . as $f
                | ($f.FieldDataType.Name // $f.FieldDataType // $f.fieldDataType.name) as $t
                | select($t != null and (($t | test("^(CHOICE_SET|RELATIONSHIP|FILE|AUTO_NUMBER)")) | not))
                | { name: $n, fieldName: $n, type: ($t | ascii_upcase) }
                  + (if ($f.DisplayName // $f.displayName) then {displayName: ($f.DisplayName // $f.displayName)} else {} end)
                  + (if ($f.Description // $f.description) then {description: ($f.Description // $f.description)} else {} end)
                  + (if (($f.IsRequired // $f.isRequired) == true) then {isRequired: true} else {} end)
                  + (if (($f.IsUnique // $f.isUnique) == true) then {isUnique: true} else {} end)
            ]
        } | with_entries(select(.value != null))' "$schema_path")"

        echo "Fields to create on '$entity_name':"
        echo "$create_body" | jq -r '.fields[] | "  - \(.name) (\(.type))"'

        temp_body="$(mktemp)"
        echo "$create_body" > "$temp_body"

        entity_raw="$(uip_json df entities create "$entity_name" --file "$temp_body" --output json)"
        rm -f "$temp_body"
        entity_id="$(echo "$entity_raw" | jq -r '.Data.Id // .Data.id // empty')"
        if [[ -z "$entity_id" ]]; then
            echo "ERROR: entity created but could not read Id from response:" >&2
            echo "$entity_raw" >&2
            exit 1
        fi
        echo "Created entity - id: $entity_id"

        insert_body="$(jq --argjson sys "$SYSTEM_FIELDS_JQ" '[.[] | with_entries(select(.key as $k | ($sys | index($k)) == null))]' "$records_path")"
        record_count="$(echo "$insert_body" | jq 'length')"
        temp_insert="$(mktemp)"
        echo "$insert_body" > "$temp_insert"

        echo "Inserting $record_count record(s)..."
        insert_raw="$(uip_json df records insert "$entity_id" --file "$temp_insert" --output json)"
        rm -f "$temp_insert"
        success_count="$(echo "$insert_raw" | jq '.Data.SuccessRecords | length? // 0')"
        fail_count="$(echo "$insert_raw" | jq '.Data.FailureRecords | length? // 0')"
        echo "Inserted: $success_count success, $fail_count failure(s)"
        if [[ "$fail_count" != "0" ]]; then
            echo "WARNING: some records failed:" >&2
            echo "$insert_raw" | jq -c '.Data.FailureRecords[]' | sed 's/^/  /' >&2
        fi

        summary_df_args+=(--arg "$entity_name" "$entity_id")
    done
    echo ""
    echo "Data Fabric complete."
    echo "Reminder: grant your participant/facilitator group 'Data Reader' access on both entities (Manage Access, in-product - see checklist at the end)."
fi

# --- Step 3: Context Grounding Index ---
if [[ "$SKIP_CONTEXT_GROUNDING" -eq 1 ]]; then
    section "Step 3: Context Grounding Index (skipped)"
else
    section "Step 3: Context Grounding Index"

    if [[ "$SKIP_BUCKETS" -eq 1 ]]; then
        echo "WARNING: buckets step was skipped - the index create call may fail if $CG_BUCKET_SOURCE doesn't already exist." >&2
    fi

    existing_raw="$(uip_json context-grounding list --folder-path "$FOLDER_PATH" --output json)"
    cg_exists="$(echo "$existing_raw" | jq -r --arg n "$CG_INDEX_NAME" '(if type == "array" then . else (.Data // []) end)[] | select(.name == $n) | .name' 2>/dev/null | head -n1)"
    if [[ -n "$cg_exists" ]]; then
        echo "Index already exists - skipping create. Re-ingesting to refresh from the bucket..."
    else
        create_raw="$(uip_json context-grounding create --index-name "$CG_INDEX_NAME" --bucket-source "$CG_BUCKET_SOURCE" \
            --folder-path "$FOLDER_PATH" --description "$WORKSHOP_LABEL - $CG_BUCKET_SOURCE" --output json)"
        # This command group (list/retrieve, confirmed live) returns bare
        # objects/arrays, not the usual {Result,Code,Data} envelope - accept
        # either shape as a success signal rather than assuming one.
        create_ok="$(echo "$create_raw" | jq -r --arg n "$CG_INDEX_NAME" '(.Result == "Success") or (.name == $n)' 2>/dev/null)"
        if [[ "$create_ok" != "true" ]]; then
            echo "ERROR: index create failed:" >&2
            echo "$create_raw" >&2
            exit 1
        fi
        echo "Index created. Starting ingestion..."
    fi

    uip context-grounding ingest --index-name "$CG_INDEX_NAME" --folder-path "$FOLDER_PATH" --output json >/dev/null

    max_attempts=20
    delay_seconds=15
    ingested=0
    failed=0
    for ((i = 1; i <= max_attempts; i++)); do
        sleep "$delay_seconds"
        retrieve_raw="$(uip_json context-grounding retrieve --index-name "$CG_INDEX_NAME" --folder-path "$FOLDER_PATH" --output json)"
        ingestion_status="$(echo "$retrieve_raw" | jq -r '.last_ingestion_status // empty' 2>/dev/null)"
        if [[ "$ingestion_status" == "Successful" ]]; then
            echo "Ingestion successful (checked after $((i * delay_seconds))s)."
            ingested=1
            break
        fi
        if [[ "$ingestion_status" == "Failed" ]]; then
            failure_reason="$(echo "$retrieve_raw" | jq -r '.last_ingestion_failure_reason // "no reason given"' 2>/dev/null)"
            echo "ERROR: ingestion failed - $failure_reason" >&2
            failed=1
            break
        fi
        echo "  ...still ingesting (attempt $i/$max_attempts)"
    done
    if [[ "$failed" -eq 1 ]]; then
        summary_cg_status="Failed: $failure_reason"
    elif [[ "$ingested" -eq 0 ]]; then
        echo "WARNING: ingestion did not report 'Successful' within $((max_attempts * delay_seconds))s. Check the index status in Orchestrator before running the workshop." >&2
        summary_cg_status="Unconfirmed - check in Orchestrator"
    else
        summary_cg_status="Successful"
    fi
fi

# --- Step 4: IXP Model ---
if [[ "$SKIP_IXP" -eq 1 ]]; then
    section "Step 4: IXP Model (skipped)"
else
    section "Step 4: IXP Model"

    sample_pdfs_dir="$ASSETS_DIR/01_storage_bucket/$IXP_SAMPLE_BUCKET_NAME"
    taxonomy_path="$ASSETS_DIR/$IXP_TAXONOMY_REL_PATH"
    if [[ ! -d "$sample_pdfs_dir" || ! -f "$taxonomy_path" ]]; then
        echo "WARNING: missing $sample_pdfs_dir or $taxonomy_path - skipping IXP model setup." >&2
    else
        # Documented default limit is 50 (max 10000) - no title filter exists,
        # so pass the max to make sure a project past page 1 isn't missed.
        existing_raw="$(uip_json ixp projects list --limit 10000 --output json)"
        project_slug="$(echo "$existing_raw" | jq -r --arg t "$IXP_PROJECT_TITLE" '(.Data.Projects // [])[] | select(.Title == $t) | .Name' 2>/dev/null | head -n1)"
        project_existed=0
        if [[ -n "$project_slug" ]]; then
            project_existed=1
            echo "IXP project already exists - slug: $project_slug (skipping create)"
        else
            create_raw="$(uip_json ixp projects create "$IXP_PROJECT_TITLE" "$sample_pdfs_dir" --skip-taxonomy --output json)"
            project_slug="$(echo "$create_raw" | jq -r '.Data.ProjectName // .Data.Name // empty')"
            if [[ -z "$project_slug" ]]; then
                echo "ERROR: IXP project created but could not read project name/slug from response:" >&2
                echo "$create_raw" >&2
                exit 1
            fi
            echo "Created IXP project - slug: $project_slug"
        fi

        # Known race: individual document uploads can 404 if they land before the
        # project is fully provisioned. Re-upload anything that isn't present yet.
        docs_raw="$(uip_json ixp documents list "$project_slug" --output json)"
        remote_names="$(echo "$docs_raw" | jq -r '(.Data.Documents // [])[] | (.Filename // .Name // .FileName // empty)')"
        missing_count=0
        for f in "$sample_pdfs_dir"/*; do
            [[ -f "$f" ]] || continue
            base="$(basename "$f")"
            if ! echo "$remote_names" | grep -Fxq "$base"; then
                if [[ "$missing_count" -eq 0 ]]; then
                    echo "WARNING: file(s) missing after create (likely the documented upload race) - retrying:" >&2
                fi
                missing_count=$((missing_count + 1))
                echo "  re-uploading: $base"
                uip ixp documents upload "$project_slug" "$f" --output json >/dev/null
            fi
        done

        if [[ "$project_existed" -eq 1 ]]; then
            echo "Skipping taxonomy import - import-taxonomy merges and never replaces (uipath-ixp skill:"
            echo "re-importing into an existing project silently leaves duplicate fields/groups)."
        else
            uip ixp projects import-taxonomy "$project_slug" "$taxonomy_path" --output json >/dev/null
            echo "Taxonomy imported."
        fi

        uip ixp projects configure-model "$project_slug" --model "$IXP_MODEL" --preprocessing "$IXP_PREPROCESSING" --output json >/dev/null
        echo "Model configured."

        uip ixp projects publish "$project_slug" --description "$WORKSHOP_LABEL - $IXP_PROJECT_TITLE" --output json >/dev/null
        echo "Model published."

        # NOTE: the `uipath-ixp` skill documents `uip ixp deployments create/
        # list` as the way to deploy this to a folder from the CLI. Verified
        # live against CLI v1.200.0: neither command exists ("error: unknown
        # command") - only `deployments get-taxonomy` is implemented. The
        # skill is ahead of what's actually shipped. Folder deployment stays
        # a manual, in-product step until that command ships for real.
        echo "Folder deployment is still an in-product step (uip ixp deployments create/list"
        echo "are documented but not implemented on the installed CLI - verified against v1.200.0)."
        echo "In the IXP app: open '$IXP_PROJECT_TITLE' -> Deploy tab -> Deploy on the version you want"
        echo "live -> 'To folder' -> Deployment name '$IXP_PROJECT_TITLE', Location '$FOLDER_PATH' -> Deploy."

        summary_ixp_slug="$project_slug"
    fi
fi

# --- Step 5: Solution Upload ---
if [[ "$SKIP_SOLUTION_UPLOAD" -eq 1 ]]; then
    section "Step 5: Solution Upload (skipped)"
else
    section "Step 5: Solution Upload ($SOLUTION)"

    upload_args=("$SOLUTION_PATH" --output json)
    if [[ "$FORCE_SOLUTION_UPLOAD" -eq 1 ]]; then
        upload_args+=(--force)
    fi

    set +e
    upload_raw="$(uip_json solution upload "${upload_args[@]}")"
    upload_exit=$?
    set -e 2>/dev/null || true

    if [[ "$upload_exit" -ne 0 ]]; then
        echo "WARNING: upload failed. Raw output:" >&2
        echo "$upload_raw" >&2
        echo "WARNING: if a solution with this SolutionId already exists in this tenant, re-run with --force-solution-upload (this replaces the cloud project and wipes its Studio Web version history)." >&2
    else
        solution_id="$(echo "$upload_raw" | jq -r '.Data.SolutionId // .Data.Id // empty')"
        echo "Solution uploaded - id: $solution_id"
        summary_solution_id="$solution_id"
    fi
fi

# --- Summary ---
bucket_names_json="$(printf '%s\n' "${BUCKET_NAMES[@]}" | jq -R . | jq -s .)"
entity_names_json="$(printf '%s\n' "${ENTITY_NAMES[@]}" | jq -R . | jq -s .)"
jq -n \
    --arg tenant "$tenant" \
    --arg folderPath "$FOLDER_PATH" \
    --arg cgIndexName "$CG_INDEX_NAME" \
    --arg cgStatus "$summary_cg_status" \
    --arg ixpTitle "$IXP_PROJECT_TITLE" \
    --arg ixpSlug "$summary_ixp_slug" \
    --arg solutionId "$summary_solution_id" \
    --arg solutionName "$SOLUTION" \
    --argjson bucketNames "$bucket_names_json" \
    --argjson entityNames "$entity_names_json" \
    "${summary_bucket_args[@]}" \
    "${summary_df_args[@]}" \
    '{
        Tenant: $tenant,
        FolderPath: $folderPath,
        Buckets: $ARGS.named | to_entries | map(select(.key | IN($bucketNames[]))) | from_entries,
        DataFabric: $ARGS.named | to_entries | map(select(.key | IN($entityNames[]))) | from_entries,
        ContextGrounding: { ($cgIndexName): $cgStatus },
        Ixp: { ($ixpTitle): $ixpSlug },
        Solution: { Id: $solutionId, Name: $solutionName }
    }' > "$SUMMARY_OUT" 2>/dev/null || echo "(could not write summary file - continuing)" >&2

echo ""
echo "================================================================"
echo " Scriptable setup complete. Summary written to: $SUMMARY_OUT"
echo "================================================================"
echo ""
echo "MANUAL STEPS - finish these in-product before running the workshop"
echo "(full detail: README.md in this directory, MANUAL STEPS section)"
echo ""
entity_names_display="$(printf ', %s' "${ENTITY_NAMES[@]}")"
entity_names_display="${entity_names_display:2}"
echo "1. Data Fabric access"
echo "   Open each entity ($entity_names_display) -> Manage Access"
echo "   -> grant your user/group the Data Reader role."
echo ""
echo "2. Integration Service connections (Integration Service > My Connections)"
echo "   Create these in the '$FOLDER_PATH' folder, NOT your personal workspace -"
echo "   connections are folder-scoped and won't resolve for the deployed solution otherwise:"
echo "   - UiPath Microsoft Outlook 365   (use YOUR OWN mailbox as the trigger inbox)"
echo "   - UiPath GenAI Activities"
echo "   - UiPath Data Service"
echo ""
echo "3. IXP deployment"
echo "   Nine-block app menu -> IXP -> open '$IXP_PROJECT_TITLE' -> Deploy tab -> Deploy on the"
echo "   version you want live -> 'To folder' -> Deployment name '$IXP_PROJECT_TITLE',"
echo "   Location '$FOLDER_PATH' -> Deploy. Confirm it shows up under Orchestrator > IXP Models"
echo "   in that folder. Then in Studio Web, open the flow's documentExtraction1 node and"
echo "   rebind it to the new deployment."
echo ""
echo "4. First deploy - link resources (Publish -> Deploy -> Configure step)"
echo "   For each connection (Data Fabric, O365, GenAI Activities): 'Link to existing'"
echo "   -> pick your own connection. $CG_INDEX_NAME index: 'Use existing'."
echo ""
echo "5. Studio Web checks"
echo "   - Rename the solution if you want a friendlier name than '$SOLUTION'"
echo "   - Rebind the flows' Indexes/$CG_INDEX_NAME reference to your new index"
echo "   - Reconnect the Email Received trigger to your own Outlook connection,"
echo "     and update the hardcoded subject filter / mailbox folder as needed"
echo ""
echo "Resource IDs from this run are in $SUMMARY_OUT for reference."
