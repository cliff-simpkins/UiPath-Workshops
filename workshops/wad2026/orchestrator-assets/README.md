# Orchestrator Assets

Pre-requisites that must be created in UiPath before running the workshop. Create all assets in the workshop Orchestrator folder (not a personal workspace). Follow the numbered steps in order — step 3 depends on step 1 being complete first.

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
> **Permissions:** After creating each entity, open it → **Manage Access** and assign the **`WeAreDevelopers_2026_20260616-Participants`** group the **Data Reader** role. Without this, lab accounts get a 403 when the flow runs the `Query Entity Records` node — the connection authenticates but the entity rejects the query. Apply to both `Purchase_Orders` and `Vendor_Alias`.

---

## Step 3 — Context Grounding Index (`03_context_grounding_index/`)

No files to import. See `03_context_grounding_index/README.md` for setup instructions. The index is built from the `Vendor_Contracts` bucket populated in step 1.

---

## Step 4 — Integration Service Connections (`04_integration_service/`)

Connections are account-bound and cannot be imported. See `04_integration_service/README.md` for the required connections and setup notes.
