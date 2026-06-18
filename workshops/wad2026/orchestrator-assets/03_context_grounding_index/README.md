# Context Grounding Index

No files to import. The index is built from the `Vendor_Contracts` storage bucket (step 1).

## Setup

1. In Orchestrator, navigate to **AI Features > Context Grounding**.
2. Create a new index named **`Vendor_Contracts`**.
3. Set the data source to the **`Vendor_Contracts`** storage bucket created in step 1.
4. Trigger an index build and wait for it to complete before running the workshop.

The index is attached to the Discrepancy Investigator Agent as a RAG resource.
