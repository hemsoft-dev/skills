# Azure Account Tracking

**Last Updated**: 2026-01-09  
**User**: <fhemmer@relias.com>  
**Default Subscription**: S00-DEVOPS-SERVICES

---

## Tenants Overview

| Tenant | Tenant ID | Domain | Subscription Count |
|--------|-----------|--------|-------------------|
| Relias Azure Cloud | 29f26ee9-781d-469c-8da7-78951300cbb4 | ReliasAzureCloud.onmicrosoft.com | 22 |
| Relias Playground | 7417dbf1-36fb-43fd-8a13-a38385d9bd22 | ReliasPlaygroundoutlook.onmicrosoft.com | 1 |
| Relias Dev/Test | f2e1c93b-a3b8-46ff-8490-923eaffd24a5 | reliasazuretestreliaslearni.onmicrosoft.com | 3 |

---

## Subscriptions by Tenant

### Relias Azure Cloud (Primary Production Tenant)

#### S00 - Connectivity Subscriptions

| Name | ID | Environment | Status | Workload |
|------|----|----|--------|---------|
| S00-DEVOPS-SERVICES | e4ab9a4c-5333-4e52-a0e3-fd16c0c8e2f5 | Production | 🟢 **DEFAULT** | Relias Assistant |
| S00-DEV-CONN-NONPROD | 7fae9531-527e-40f9-b7b6-61929e161a69 | Non-Production | 🟢 Enabled |
| S00-DE-CONN-PROD | 20696ebd-7685-4c92-924c-4369b8543e22 | Production | 🟢 Enabled |
| S00-US-CONN-PROD | 462f3475-7dac-4ae8-bf9d-e0d165cfbef5 | Production | 🟢 Enabled |
| S00-CA-CONN-PROD | 0fa713d4-8de8-4982-99fb-e05d84f5e6b1 | Production | 🟢 Enabled |
| S00-PLAYGROUND-NONPROD | 45bd3c2e-3e13-4195-a597-c0e403d27dc3 | Non-Production | 🟢 Enabled |

#### S01 - Management Subscriptions

| Name | ID | Environment | Status |
|------|----|----|--------|
| S01-DEV-MGMT-NONPROD | 5d8f65cc-1c9a-4fac-a100-f56c5e8a0070 | Non-Production | 🟢 Enabled |
| S01-DE-MGMT-PROD | ef305fde-0c06-4a71-8d00-239a290bd615 | Production | 🟢 Enabled |
| S01-US-MGMT-PROD | 148f5a47-b62d-43e6-a5e7-34cd39df4c5f | Production | 🟢 Enabled |
| S01-CA-MGMT-PROD | 4f20d1e5-7e76-44e1-8303-94fabcedc798 | Production | 🟢 Enabled |

#### S02 - Identity Subscriptions

| Name | ID | Environment | Status |
|------|----|----|--------|
| S02-DEV-IDENTITY-NONPROD | 9404d162-9023-4d1f-b400-5f06c2c85e44 | Non-Production | 🟢 Enabled |
| S02-DE-IDENTITY-PROD | 0f6d09ae-47a3-4d52-9955-3e2a724e8b04 | Production | 🟢 Enabled |
| S02-US-IDENTITY-PROD | cbfa1789-275e-4361-a320-5eddaa3cc414 | Production | 🟢 Enabled |

#### S03 - Workload Subscriptions

| Name | ID | Environment | Status |
|------|----|----|--------|
| S03-DEV-WORKLOAD-NONPROD | 3741355f-a2fe-4aa7-b024-1cecffdca327 | Non-Production | 🟢 Enabled |
| S03-DE-WORKLOAD-PROD | 6674136c-603f-4418-8397-06ece80c7273 | Production | 🟢 Enabled |
| S03-CA-WORKLOAD-PROD | 760cd487-2f3b-42d2-82ea-124cb83096f4 | Production | 🟢 Enabled |
| S03-US-WORKLOAD-PROD | 48d98a9a-2f7b-46ac-9a18-3aabd9fbd39a | Production | 🟢 Enabled |

#### S04 - Workload Subscriptions

| Name | ID | Environment | Status |
|------|----|----|--------|
| S04-DE-WORKLOAD-NONPROD | e6036236-a7f0-41c5-850a-54de53a62b15 | Non-Production | 🟢 Enabled |
| S04-CA-WORKLOAD-NONPROD | 83551bd7-8457-42bc-ab34-6cbc45155fb2 | Non-Production | 🟢 Enabled |
| S04-US-WORKLOAD-NONPROD | bda20fca-5f2e-4080-baf8-3154a48b2fee | Non-Production | 🟢 Enabled |

---

### Relias Playground (Secondary Tenant)

| Name | ID | Environment | Status |
|------|----|----|--------|
| Enterprise Dev/Test | 3d8d1710-94a4-4d4a-bafd-52b96d553e05 | Non-Production | 🟢 Enabled |

---

### Relias Dev/Test (Development Tenant)

| Name | ID | Environment | Status |
|------|----|----|--------|
| Relias DEVELOPMENT | 27f2f628-d36b-48b0-8095-1830d68d96bb | Development | 🟢 Enabled |
| Relias DevOps Services | 66e2400e-340f-4dab-8f02-8174cdb0193b | Development | 🟢 Enabled |
| Relias INTEGRATION | 846d929e-cbe7-43cb-8e2f-90301a53bed4 | Integration | 🟢 Enabled |

---

## Subscription Organization Patterns

### Naming Convention

**Format**: `S{N}-{REGION}-{WORKLOAD}-{ENVIRONMENT}`

- **S#** (00-04): Subscription tier (Connectivity, Management, Identity, Workload-1, Workload-2)
- **REGION**: US, DE (Germany), CA (Canada), DEV
- **WORKLOAD**: CONN, MGMT, IDENTITY, WORKLOAD
- **ENVIRONMENT**: PROD, NONPROD, DEV, INT

### Environment Distribution

**Production** (14 subscriptions):

- All S01-S04 with PROD suffix
- Multi-region: US, DE, CA
- Default: S00-DEVOPS-SERVICES

**Non-Production** (10 subscriptions):

- NONPROD environments for testing & staging
- DEV environments for development
- Playground for experimentation

---

## Quick Reference

### Set Active Subscription

```powershell
# Default (DevOps Services)
az account set --subscription e4ab9a4c-5333-4e52-a0e3-fd16c0c8e2f5

# Connectivity - DE Production
az account set --subscription 20696ebd-7685-4c92-924c-4369b8543e22

# Management - US Production
az account set --subscription 148f5a47-b62d-43e6-a5e7-34cd39df4c5f

# Identity - US Production
az account set --subscription cbfa1789-275e-4361-a320-5eddaa3cc414
```

### List All in Current Tenant

```bash
az account list --query "[].{Name:name, ID:id, Tenant:tenantDisplayName, Env:state}" --output table
```

---

## Notes

- All subscriptions are currently **Enabled** and accessible
- Single user: **<fhemmer@relias.com>**
- Total: **26 subscriptions** across 3 tenants
- Primary workload tenant: **Relias Azure Cloud**
- Multi-region deployment strategy: US, DE, CA regions
