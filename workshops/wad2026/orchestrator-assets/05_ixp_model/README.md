# IXP Model — IXP_Invoices

The flow's `documentExtraction1` node binds to an IXP deployment named **`IXP_Invoices`**. IXP models cannot be exported or imported across tenants, but the taxonomy (field definitions and prompt instructions — the substance of the generative model) can. `taxonomy.json` in this folder is the exported `dataset` object from the source project.

## Recreate in a new tenant (CLI)

Run from this directory, logged into the target tenant:

```powershell
# 1. Create the project with the five sample invoices (taxonomy comes next)
uip ixp projects create "IXP_Invoices" "..\01_storage_bucket\Sample_PDFs" --skip-taxonomy --output json

# 2. Import the taxonomy (note the ProjectName slug from step 1's output)
uip ixp projects import-taxonomy <project-name-slug> taxonomy.json --output json

# 3. Match the source model configuration
uip ixp projects configure-model <project-name-slug> --model gemini_2_5_flash --preprocessing none --output json

# 4. Publish
uip ixp projects publish <project-name-slug> --description "Invoice IXP model - for WAD2026 workshop" --output json
```

Notes:

- `projects create` can race its own document uploads — if a file fails with `404 [ProjectNotFoundError]`, re-upload it: `uip ixp documents upload <project-name-slug> <file> --output json`.
- What does **not** transfer: label confirmations, model version history, and the folder **deployment**. After publishing, deploy the model to the workshop folder in-product (Studio Web / IXP UI) so the flow's `documentExtraction1` node can be rebound to it.
- To refresh `taxonomy.json` from a source tenant: `uip ixp projects get-taxonomy <project-name-slug> --output json`, then save the inner `Data.dataset` object (not the whole response envelope).
