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
- What does **not** transfer: label confirmations, model version history, and the folder **deployment**. The `uipath-ixp` skill documents `uip ixp deployments create`/`list` as a CLI path for this — verified against installed CLI v1.200.0, neither exists yet (`error: unknown command`; only `deployments get-taxonomy` is implemented). Re-check after a CLI update before assuming this is still manual. Until then, deploy in-product (verified click-path):
  1. Nine-block app menu → **IXP** → open the project
  2. **Deploy** tab → click **Deploy** on the version you want live
  3. Choose **To folder**, set **Deployment name** (`IXP_Invoices`) and **Location** (the workshop folder), click **Deploy**
  4. Confirm it shows up under **Orchestrator → IXP Models** in that folder
  5. In Studio Web, rebind the flow's `documentExtraction1` node to the new deployment
- To refresh `taxonomy.json` from a source tenant: `uip ixp projects get-taxonomy <project-name-slug> --output json`, then save the inner `Data.dataset` object (not the whole response envelope).
