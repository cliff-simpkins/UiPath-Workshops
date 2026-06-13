# Orchestrator Assets

Files in this directory must be uploaded to UiPath Orchestrator before running the workshop. Each subfolder maps directly to a named artifact in the platform.

## Sample_PDFs → Storage Bucket

Upload all files to a Storage Bucket named **`Sample_PDFs`** in the shared workshop folder.

| File | Scenario | Used in |
| --- | --- | --- |
| case-4-perfect-match-invoice.pdf | Everything matches | Segment 3 first run; eval baseline |
| case-3-freight-discrepancy-invoice.pdf | Freight charge not on PO | Segment 5 breaking scenario |
| case-5-partial-shipment-invoice.pdf | Partial quantity shipped | Segment 8 buffer; attendee eval case |
| case-1-alphabet-google-invoice.pdf | Vendor name mismatch (subsidiary) | Segment 3 breaking scenario 1 |
| case-2-apex-fraud-invoice.pdf | Fraudulent invoice | Attendee eval case |

## Vendor_Contracts → Context Grounding Index

Upload all PDF contracts to a Context Grounding index named **`Vendor_Contracts`** in the shared workspace. This index is attached to the Discrepancy Investigator Agent as a RAG resource.

## purchase_orders → Data Fabric Entity

Import records into a Data Fabric entity named **`purchase_orders`**. Each record corresponds to one of the five sample invoices and is matched by PO number at flow runtime.
