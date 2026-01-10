---
name: azure
description: V1.0 - Expert in Azure account management, subscription structure, resource groups, service principals, and Azure CLI operations for personal and enterprise (Relias) environments.
---

# Azure

Expert assistant for Azure cloud operations, account management, and CLI-based resource provisioning. Specializes in subscription and resource group management, service principal creation, and authentication workflows.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Core Competencies

### Account & Subscription Management

- **`az account list`** - List all subscriptions for logged-in account
- **`az account set --subscription {ID}`** - Switch active subscription
- **`az account show`** - Display current subscription details
- **`az account get-access-token`** - Get authentication token for API access
- **`az account list-locations`** - List available regions for current subscription
- **`az account clear`** - Clear subscription cache

### Resource Groups

- **`az group create --name {RG_NAME} --location {REGION}`** - Create resource group
- **`az group list`** - List all resource groups
- **`az group show --name {RG_NAME}`** - Display resource group details
- **`az group delete --name {RG_NAME}`** - Remove resource group
- **`az group export --name {RG_NAME}`** - Export resource group as template (ARM/Bicep/JSON)
- **`az group update --name {RG_NAME} --tags {KEY=VALUE}`** - Add/update tags

### Management Groups & Organizational Structure

- **`az account management-group list`** - List management groups (for enterprise hierarchies)
- **`az account management-group create --name {MG_NAME}`** - Create management group
- **`az account management-group subscription add`** - Add subscription to management group
- **`az account management-group entities list`** - View all management entities (organizations)

### Service Principals & Authentication

- **`az ad sp create-for-rbac --name {APP_NAME}`** - Create app + service principal with RBAC
  - Optional: `--role {ROLE}` and `--scopes {SCOPE}` to assign permissions
  - Optional: `--create-cert` for certificate-based authentication
  - Optional: `--keyvault {VAULT}` to store cert in Key Vault
- **`az ad sp list --show-mine`** - List service principals owned by current user
- **`az ad sp show --id {SP_ID}`** - Get service principal details
- **`az ad sp credential list --id {SP_ID}`** - List SP credentials (metadata only, not content)
- **`az ad sp credential reset --id {SP_ID}`** - Reset/rotate SP credentials
- **`az ad sp delete --id {SP_ID}`** - Remove service principal

### Locks & Governance

- **`az account lock create`** - Create subscription-level locks
- **`az group lock create --name {LOCK} --resource-group {RG}`** - Lock resource group

## Relias-Specific Patterns

When working with Relias Azure infrastructure:

1. **Subscription Organization**: Relias typically uses multiple subscriptions per environment (Dev, Test, Prod)
2. **Resource Groups**: Structure follows `relias-{environment}-{workload}` naming convention
3. **Service Principals**: Used for CI/CD pipelines, automation, and application authentication
4. **RBAC Scoping**: Assign roles at subscription or resource group level based on team access needs
5. **Tags**: Apply mandatory tags: `Environment`, `CostCenter`, `Owner`, `Project`

## PowerShell Integration

When scripting Azure operations in PowerShell, leverage Azure CLI with JSON output:

```powershell
# Get subscriptions as objects
$subs = az account list | ConvertFrom-Json
$subs | Where-Object { $_.name -like "*Relias*" }

# Query with JMESPath
az resource list --query "[?tags.Environment=='prod']" --output json

# Iterate and process
az account list --query '[].id' -o tsv | ForEach-Object {
    az account set --subscription $_
    # ... perform operations in each subscription
}
```

## Output Formats

- **Default JSON** - Use `--output json` for programmatic parsing
- **Table Format** - Use `--output table` for CLI readability
- **TSV** - Use `--output tsv` for scripting and piping
- **JMESPath Filtering** - Use `--query` to extract specific fields

## Common Workflows

### List All Resources Across Subscriptions
```bash
for sub in $(az account list --query '[].id' -o tsv); do
  az account set -s $sub
  az resource list --query "[].{Name:name, Type:type, RG:resourceGroup}"
done
```

### Find Resources by Tag
```bash
az resource list --query "[?tags.Environment=='prod']" --output table
```

### Export Resource Group Template
```bash
az group export --name my-rg --resource-ids "*" --export-format bicep > template.bicep
```

### Create Service Principal with Certificate
```bash
az ad sp create-for-rbac \
  --name "relias-automation" \
  --role Contributor \
  --scopes /subscriptions/{SUB_ID}/resourceGroups/{RG_NAME} \
  --create-cert \
  --years 2
```

## Best Practices

- **Always use `--subscription`** flag to avoid accidental changes in wrong subscription
- **Enable locks** on production resource groups to prevent accidental deletion
- **Use tags** for cost tracking and compliance
- **Rotate credentials** regularly, especially for service principals
- **Use managed identities** when possible instead of service principals with secrets
- **Filter by query** to avoid human error with wildcards in deletion commands
- **Test in non-prod** before executing automation scripts

