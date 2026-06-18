# Integration Service Connections

Connections are account-bound and cannot be imported. Create each one manually in Integration Service before deploying the solution. The solution's bindings reference these connections by connector key — they must exist in the tenant before deployment.

## Required Connections

| Connector | Name in Solution | Purpose |
| --- | --- | --- |
| UiPath Microsoft Outlook 365 | `UiPathlabsdemo@uipath.com` (or your trigger account) | Email trigger — receives invoices, sends recommendation emails |
| UiPath GenAI Activities | `UiPath_GenAI_Activities` | AI model calls in agents and the flow |
| UiPath Data Service | (tenant default) | Data Fabric queries — Purchase_Orders and Vendor_Alias entities |

## Notes

- The Outlook 365 connection must use the email account configured as the flow trigger inbox.
- After creating connections, verify they appear in Integration Service > My Connections before deploying the solution.
