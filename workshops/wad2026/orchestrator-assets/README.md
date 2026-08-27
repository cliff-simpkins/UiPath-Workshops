# Orchestrator Assets

Pre-requisites that must be created in UiPath before running the workshop. Create all assets in the workshop Orchestrator folder (not a personal workspace). Follow the numbered steps in order — step 3 depends on step 1 being complete first.

**Setting this up in your own tenant?** Run `orchestrator-assets/setup-tenant.sh --folder-path "<your-folder>"` after `uip login` — it automates steps 1–5 below (buckets, Data Fabric, context grounding, IXP taxonomy, solution upload) against your own tenant and prints the manual-steps checklist at the end. No access to the original workshop tenant required; everything it needs is already in this repo.

---

## Step 1 — Storage Buckets (`01_storage_bucket/`)

### Sample_PDFs

Create a Storage Bucket named **`Sample_PDFs`** and upload all five files.

| File | Scenario | Used in |
| --- | --- | --- |
| case-4-perfect-match-invoice.pdf | Everything matches — auto-approved | Segment 3 first run; eval baseline |
| case-3-freight-discrepancy-invoice.pdf | Freight charge not in contract — HITL | Segment 5 breaking scenario |
| case-5-partial-shipment-invoice.pdf | Partial quantity shipped | Segment 8 buffer; attendee eval case |
| case-1-alphabet-google-invoice.pdf | Vendor name mismatch (subsidiary) — VRA + HITL | Segment 3 breaking scenario 1 |
| case-2-apex-fraud-invoice.pdf | Fraudulent invoice — reject | Attendee eval case |

### Vendor_Contracts

Create a Storage Bucket named **`Vendor_Contracts`** and upload all five PDF contracts. This bucket backs the context grounding index in step 3 — populate it before creating the index.

| File | Vendor |
| --- | --- |
| 01-google-cloud-services-agreement.pdf | Google LLC |
| 02-apex-manufacturing-supply-agreement.pdf | Apex Manufacturing |
| 03-stratton-office-supply-reseller-agreement.pdf | Stratton Office Supply Co. |
| 04-helix-marketing-services-agreement.pdf | Helix Marketing |
| 05-northwind-industrial-supply-agreement.pdf | Northwind Industrial Supply |

---

## Step 2 — Data Fabric Entities (`02_data_fabric/`)

### Purchase_Orders

Create a Data Fabric entity named **`Purchase_Orders`** and import records from `02_data_fabric/purchase_orders/records.json`. Use `schema.json` in the same folder as a reference for field names and types.

The entity is queried at runtime by PO number to retrieve line items and totals for comparison against the incoming invoice.

### Vendor_Alias

Create a Data Fabric entity named **`Vendor_Alias`** and import records from `02_data_fabric/vendor_alias/records.json`. Used by the Vendor Research Agent to resolve subsidiary and trade names back to their canonical vendor name (e.g. "Alphabet" → "Google LLC"). Required for the vendor name mismatch scenario.

> **Note on system fields:** `records.json` files include instance-specific system fields (`Id`, `CreatedBy`, `RecordOwner`, etc.) from the source environment. These are stripped automatically by the import script — do not remove them manually.
>
> **Permissions:** After creating each entity, open it → **Manage Access** and assign the tenant's participant and facilitator groups (e.g. `<tenant-name>-Participants`) the **Data Reader** role. Without this, lab accounts get a 403 when the flow runs the `Query Entity Records` node — the connection authenticates but the entity rejects the query. Apply to both `Purchase_Orders` and `Vendor_Alias`. See **Manual Steps** below.

---

## Step 3 — Context Grounding Index (`03_context_grounding_index/`)

No files to import. The index is built from the `Vendor_Contracts` bucket populated in step 1 — populate the bucket first. Scriptable via CLI (verified 2026-07-08):

```powershell
uip context-grounding create --index-name "Vendor_Contracts" --bucket-source "Vendor_Contracts" --folder-path "Shared" --description "Vendor contracts for WAD2026 workshop" --output json
uip context-grounding ingest --index-name "Vendor_Contracts" --folder-path "Shared" --output json
# Poll until last_ingestion_status is "Successful"
uip context-grounding retrieve --index-name "Vendor_Contracts" --folder-path "Shared" --output json
```

See `03_context_grounding_index/README.md` for the in-product alternative.

---

## Step 4 — Integration Service Connections (`04_integration_service/`)

Connections are account-bound and cannot be imported. See `04_integration_service/README.md` for the required connections and setup notes.

---

## Step 5 — IXP Model (`05_ixp_model/`)

IXP models cannot be exported across tenants, but the taxonomy can. `05_ixp_model/taxonomy.json` recreates the **`IXP_Invoices`** project via CLI (create → import-taxonomy → configure-model → publish); the folder deployment and flow rebind remain in-product steps. See `05_ixp_model/README.md`. Depends on step 1's sample PDFs being available locally.

---

## MANUAL STEPS

Everything below is in-product and account- or tenant-bound — none of it can be scripted or imported. Do these after steps 1–5 above.

### Data Fabric access

Within Data Fabric, for each of `Purchase_Orders` and `Vendor_Alias`:

1. Open the entity → **Manage Access**
2. Add your participant and facilitator groups, and give them the `Data Reader` role

### Integration Service connections

Create the three connections listed in `04_integration_service/README.md` (Outlook 365 trigger inbox, UiPath GenAI Activities, Data Service). Verify they appear under **Integration Service > My Connections** before touching the solution.

### IXP deployment

The CLI recreation in step 5 publishes the model but cannot deploy it to a folder — `uip ixp deployments create`/`list` are documented by the `uipath-ixp` skill but not implemented on the installed CLI (verified against v1.200.0: `error: unknown command`; only `deployments get-taxonomy` exists). Until that ships for real:

1. Open the nine-block app menu → **IXP** → open the **`IXP_Invoices`** project
2. Select the **Deploy** tab
3. On the version card you want live (the latest one the script published), click **Deploy**
4. In the dialog, choose **To folder** (not "To project"), set **Deployment name** to `IXP_Invoices` and **Location** to the workshop Orchestrator folder (e.g. `Shared`), then click **Deploy**
5. Verify it now appears under **Orchestrator → IXP Models** in that folder
6. In Studio Web, open each flow's `documentExtraction1` node and rebind it to the new deployment (the imported binding still points at the source tenant's folder GUID)

### First deploy — link resources to the new tenant (verified 2026-07-09)

The uploaded solution's resource declarations still reference the **source tenant's** connection IDs and folder GUIDs. Debug runs work anyway (node-level resolution picks up the tenant's default connections), but **Publish → Deploy** resolves the solution-level declarations — unresolved connections get provisioned into the deploy target (an attendee's personal workspace) instead of using the shared ones. Fix it once, owner-side, on the first deploy:

1. **Publish** the solution, then **Deploy** — the wizard pauses at the **Configure** step with validation issues
2. For each connection resource (Data Fabric, O365, GenAI Activities): select it → click **Link to existing** (upper right) → pick the shared connection (e.g. `Data Fabric - WAD2026 (Shared)`). A linked resource is not created at deployment; execution uses it directly. Each shows a `Linked` badge when done.
3. The `Vendor_Contracts` index resolves differently — its name matches, so it shows a conflict banner: "This resource already exists … in destination tenant" → click **Use existing**
4. **Validate**, then **Continue** through Deploy and Activate

> **Reduce this friction next time:** create the tenant's connections with the **exact names the solution's resources use** (`Data Fabric`, `O365 - UiPathlabsdemo@uipath.com`, `UiPath GenAI Activities`) — name-matched resources offer one-click "Use existing" instead of manual linking. The linking dialog warns that linking under a different name "may lead to runtime errors"; the flow bindings reference connections by ID, so linking works, but same-name is safer.

### Studio Web solution checks

After `uip solution upload`:

1. Rename the solution if needed — it lands with whatever name the source tenant last used (e.g. "WAD2026 Workshop")
2. Rebind the flows' `Indexes/Vendor_Contracts` reference to the new tenant's index (also an attendee step in the guide — verify it works on the Complete flow first)
3. Reconnect the **Email Received** trigger to the new tenant's Outlook connection, and review the trigger filter — it carries a hardcoded subject filter (`WAD-yourname`) and mailbox folder ID from the source setup
4. Share the solution/projects with the participant group per the attendee-provisioning approach for the event

### Pre-event environment checks

1. Confirm the models the workshop uses are available in the tenant — GPT-5.4 (calibrated baseline) and Claude Sonnet (the model-sensitivity aside in the guide's Facilitator Notes)
2. Update `.devrel/scripts/sync-from-studio.ps1` and the eval commands in `.devrel/workshop-design.md` with the new tenant's solution ID (printed by `uip solution upload`)
