# Orchestrator Assets

Files in this directory must be set up in UiPath before running the workshop. Each subfolder maps directly to a named artifact in the platform. Set them up in order: Data Fabric entities first, then storage buckets, then the context grounding index.

## Sample_PDFs → Storage Bucket

Create a Storage Bucket named **`Sample_PDFs`** in the shared workshop folder and upload all five files.

| File | Scenario | Used in |
| --- | --- | --- |
| case-4-perfect-match-invoice.pdf | Everything matches — auto-approved | Segment 3 first run; eval baseline |
| case-3-freight-discrepancy-invoice.pdf | Freight charge not in contract — HITL | Segment 5 breaking scenario |
| case-5-partial-shipment-invoice.pdf | Partial quantity shipped | Segment 8 buffer; attendee eval case |
| case-1-alphabet-google-invoice.pdf | Vendor name mismatch (subsidiary) — VRA HITL | Segment 3 breaking scenario 1 |
| case-2-apex-fraud-invoice.pdf | Fraudulent invoice — reject | Attendee eval case |

## Vendor_Contracts → Context Grounding Index

Create a Context Grounding index named **`Vendor_Contracts`** backed by a Storage Bucket of the same name. Upload all five PDF contracts to the bucket, then trigger a re-index. The index is attached to the Discrepancy Investigator Agent as a RAG resource.

| File | Vendor |
| --- | --- |
| 01-google-cloud-services-agreement.pdf | Google LLC |
| 02-apex-manufacturing-supply-agreement.pdf | Apex Manufacturing |
| 03-stratton-office-supply-reseller-agreement.pdf | Stratton Office Supply Co. |
| 04-helix-marketing-services-agreement.pdf | Helix Marketing |
| 05-northwind-industrial-supply-agreement.pdf | Northwind Industrial Supply |

## purchase_orders → Data Fabric Entity

Create a Data Fabric entity named **`Purchase_Orders`** and import records from `records.json`. Use `schema.json` as a reference for field types. The `records.json` file includes system fields (Id, CreatedBy, etc.) that the import script strips automatically — do not remove them manually.

The entity is queried at runtime by PO number to retrieve line items and totals for comparison against the incoming invoice.

## vendor_alias → Data Fabric Entity

Create a Data Fabric entity named **`Vendor_Alias`** and import records from `records.json`. This entity is used by the Vendor Research Agent to resolve subsidiary or trade names back to their canonical vendor name (e.g. "Alphabet" → "Google LLC"). Required for the vendor name mismatch scenario to work correctly.
