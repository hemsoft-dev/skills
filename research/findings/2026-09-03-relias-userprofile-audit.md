# Relias User Profile audit

**Date:** 2026-09-03  
**Repositories:** [`relias-engineering/userprofile-service`](https://github.com/relias-engineering/userprofile-service), [`relias-engineering/userprofile-gitops`](https://github.com/relias-engineering/userprofile-gitops)  
**Source snapshots:** service `f0970f091c705ff3ac7d43d4f92955f78c4b03c0` (`develop`); GitOps `889b9843f0b15679c6b19033c5a5acd82e71097a` (`main`)  
**Method:** Repository history, committed pipeline and IaC configuration, GitHub APIs, organization code search, live DNS resolution, and live health checks. Inferences are labelled.

## Executive summary

**There is no repository named `relias-engineering/userprofile`.** `GET /repos/relias-engineering/userprofile` returns 404. The audit target resolves to two repositories that together constitute the system: `userprofile-service` (the .NET 8 API) and `userprofile-gitops` (the Kubernetes manifests Flux reconciles).

User Profile is an ASP.NET Core 8 REST API that fronts a legacy User Management API (UMAPI) through an Anti-Corruption Layer (ACL). It owns no data. It runs as a container on shared Azure Kubernetes Service clusters in seven environments across four Azure regions and three public domains.

**Nothing here is deployed by GitHub Actions.** Both repositories report zero workflows, zero runs, zero deployments, zero environments, and zero releases. Delivery is an Azure DevOps multi-stage pipeline that writes an image tag into the GitOps repository, followed by a Flux reconcile.

The service is live and healthy in all seven environments, and it is frozen. The newest application commit is 2025-02-26. Every environment runs image tag `44932`, whose in-image assembly timestamp is 2025-03-20 09:41:00 EDT. Production last received that tag on 2025-04-02.

Highest-priority findings:

1. **Flux still syncs from Bitbucket, not GitHub.** Changes merged to the GitHub GitOps repository reach no cluster.
2. **The PodDisruptionBudget matches zero pods**, so it protects nothing during node drains.
3. **No production application caller was found in indexed organization code.** Every confirmed caller is a test harness or edge/routing configuration.
4. **Four open Dependabot alerts**, two of them high severity.
5. **A client-secret literal is committed** in a consuming repository's "prod" E2E config.
6. The anonymous health endpoint discloses pod name, environment, and build timestamp.

## 1. Repository identity and lifecycle

| Item | `userprofile-service` | `userprofile-gitops` |
|---|---|---|
| Visibility | Internal (private org-visible) | Internal |
| Primary language | C# | none detected |
| Default branch | `develop` | `main` |
| GitHub `created_at` | 2026-09-01 01:26 EDT | 2026-09-02 01:26 EDT |
| GitHub `pushed_at` | 2026-09-03 01:06 EDT | 2026-09-03 01:04 EDT |
| Newest commit inside repo | `f0970f09`, **2025-02-26 12:06 EST** | `889b9843`, **2025-06-11 14:23 EDT** |
| First commit | `f2004058`, 2022-08-16, Franz Hemmer, "Initial commit" | `7182a5fe`, 2022-11-16, Drazen Jovanovic |
| Commits | 700 | 951 |
| Releases / tags | none | none |
| Archived | no | no |

### The GitHub copies are a migration artifact

`created_at` is September 2026 but the newest commit in either repository is June 2025. Commit subjects use Bitbucket's `Merged in <branch> (pull request #N)` format. The pipeline declares its sibling repositories as `type: bitbucket` against the `Relias-Bitbucket` service connection ([`userprofile-api-build.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/userprofile-api-build.yml)). And the Flux source is still a Bitbucket SSH URL (section 8).

**The `pushed_at` timestamps reflect a Bitbucket-to-GitHub import, not development or deployment activity.** Anyone judging freshness from the GitHub UI is misled by roughly 15 months.

Commit volume by author year shows the decline: 105 (2022), 513 (2023), 69 (2024), 13 (2025).

The service's `main` branch is stale and abandoned at `7fcfba3cdfefbb925f2a442c54267adaf94ee3c2`, 2022-08-17, "Merged in feature/RLPD-47920 (pull request #1)". Active work happened on `develop`.

## 2. Purpose and architecture

The README states the intent plainly:

> User Profile API is meant to be used internally for the Integrations, and potentially externally by some of our clients. The end goal is to build a modern microservice that will be deployed to a Kubernetes cluster in Azure. That goal should be achieved in phases, and the initial one is where we are utilizing Anti-Corruption Layer (ACL) API in order to communicate with a legacy User Management API (UMAPI) service to get or update the User Profile data. Eventually, we will be moving toward its own data storage where request will be completed without any dependency on other services (ACL).

Source: [`README.md`](https://github.com/relias-engineering/userprofile-service/blob/develop/README.md). Team contact listed there is `OpenSourcerers@relias.com`.

This is a strangler-pattern facade that never reached phase two.

Four-project Clean Architecture / CQRS layout:

| Project | Role |
|---|---|
| `Relias.UserProfile.Api` | ASP.NET Core host, controllers, auth, Swagger, Serilog, App Insights |
| `Relias.UserProfile.App` | MediatR commands/queries, FluentValidation, AutoMapper, ACL and Identity HTTP clients |
| `Relias.UserProfile.Common` | Caching, paging, exceptions, `ServiceResult`, API versioning |
| `Relias.UserProfile.Infra` | Cosmos DB repository, present but unreachable (section 5) |

MediatR pipeline behaviors supply logging, validation, and unhandled-exception handling ([`ConfigureServices.cs:31-41`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/ConfigureServices.cs#L31-L41)).

Verified request path:

```text
Client
  -> Akamai edge (US/CA) or Cloudflare (DE)
  -> Azure Traffic Manager  <env>-userprofile-tm-001.trafficmanager.net
  -> AKS Application Gateway ingress  userprofile-api-ingress
  -> Service userprofile-api-service :53002
  -> Pod relias-userprofile-api
  -> ACL API -> legacy UMAPI
```

## 3. Languages, frameworks, dependencies

All four projects target `net8.0`. The README requires the .NET 8.0 SDK. Container images are `mcr.microsoft.com/dotnet/aspnet:8.0` (runtime) and `mcr.microsoft.com/dotnet/sdk:8.0` (build), final stage running `USER app` ([`Dockerfile`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Dockerfile)).

API host packages ([`Relias.UserProfile.Api.csproj:15-27`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Relias.UserProfile.Api.csproj#L15-L27)): `Azure.Identity` 1.10.4, `FluentValidation.AspNetCore` 11.2.2, `Microsoft.ApplicationInsights.AspNetCore` 2.21.0, `Microsoft.ApplicationInsights.Kubernetes` 3.1.0, `Microsoft.Azure.AppConfiguration.AspNetCore` 5.1.0, `Microsoft.FeatureManagement.AspNetCore` 2.5.1, `Microsoft.Identity.Web` 1.25.5, `Serilog.AspNetCore` 6.0.1, `Swashbuckle.AspNetCore` 6.4.0.

App layer ([`Relias.UserProfile.App.csproj:10-19`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Relias.UserProfile.App.csproj#L10-L19)): `AutoMapper` 12.0.1, `IdentityModel` 6.0.0, `MediatR.Extensions.Microsoft.DependencyInjection` 10.0.1, `Microsoft.AspNetCore.JsonPatch` 8.0.0, `Microsoft.AspNetCore.Mvc.NewtonsoftJson` 6.0.25, `Microsoft.Identity.Client` 4.46.1, `Polly` 7.2.3.

Common ([`Relias.UserProfile.Common.csproj:16-29`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Common/Relias.UserProfile.Common.csproj#L16-L29)): `Microsoft.Extensions.*` pinned at 6.0.x including `Caching.StackExchangeRedis` 6.0.9 and `Caching.Memory` 6.0.1, plus `Microsoft.AspNetCore.Mvc.Versioning.ApiExplorer` 5.0.0, `Serilog` 2.12.0.

Infra ([`Relias.UserProfile.Infra.csproj:9-10`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Infra/Relias.UserProfile.Infra.csproj#L9-L10)): `IEvangelist.Azure.CosmosRepository` 3.6.0, `Polly` 7.2.3.

Several `Microsoft.Extensions.*` packages sit at 6.0.x while the runtime targets net8.0. That lag causes two of the four open Dependabot alerts in section 6.

## 4. API routes, contracts, authentication

### Routes

Business controllers are versioned under `api/v{version:apiVersion}`, default version 1.0, `AssumeDefaultVersionWhenUnspecified = true` ([`Program.cs:196-204`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L196-L204)).

| Method | Route | Source line |
|---|---|---|
| `GET` | `/api/v1/user-profiles/{userId:int}` | [`UserProfileController.cs:36`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/UserProfileController.cs#L36) |
| `GET` | `/api/v1/user-profiles/search` | [`:88`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/UserProfileController.cs#L88) |
| `GET` | `/api/v1/user-profiles/searchusers` | [`:146`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/UserProfileController.cs#L146) |
| `POST` | `/api/v1/user-profiles` | [`:184`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/UserProfileController.cs#L184) |
| `PUT` | `/api/v1/user-profiles/{userId:int}` | [`:228`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/UserProfileController.cs#L228) |
| `PATCH` | `/api/v1/user-profiles/{userId:int}` | [`:259`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/UserProfileController.cs#L259) |
| `GET/POST/PUT` | `/api/v1/organizations/categories[/{categoryId:int}]` | [`CategoryController.cs:16,33,57,86`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/CategoryController.cs#L16-L86) |
| `GET/POST/PUT` | `/api/v1/organizations/custom-fields[/{customFieldId:int}]` | [`CustomFieldController.cs:16,33,57,86`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/CustomFieldController.cs#L16-L86) |
| `GET/POST/PUT` | `/api/v1/organizations/departments[/{departmentId:int}]` | [`DepartmentController.cs:17,34,58,88`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/DepartmentController.cs#L17-L88) |
| `GET/POST/PUT` | `/api/v1/organizations/employment-types[/{employmentTypeId:int}]` | [`EmploymentTypeController.cs:16,33,57,86`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/EmploymentTypeController.cs#L16-L86) |
| `GET/POST/PUT` | `/api/v1/organizations/jobtitles[/{jobTitleId:int}]` | [`JobTitleController.cs:19,36,60,90`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/JobTitleController.cs#L19-L90) |
| `GET/POST/PUT` | `/api/v1/organizations/locations[/{locationId:int}]` | [`LocationController.cs:16,33,57,87`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/LocationController.cs#L16-L87) |
| `GET` | `/api/v1/organizations/{orgId}/user-profile-customization-fields` | [`UserProfileCustomizationController.cs:15,32`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/V1/Organization/UserProfileCustomizationController.cs#L15-L32) |
| `GET` | `/api/healthcheck?meonly={0\|1}` | [`HealthCheckController.cs:10,34-35`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Controllers/HealthCheckController.cs#L10-L35) |

Note the organization routes are flat (`/api/v1/organizations/categories`), not nested under `{orgId}`. Organization scoping travels in the payload or query string.

### Authentication

API resource name is `userprofile-service-api` ([`Program.cs:69`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L69)).

The service runs two bearer schemes concurrently so it can straddle the identity migration. A policy scheme reads the inbound `Authorization` header, parses the JWT, and forwards to `IdentityServer4` when the issuer equals the configured IDP4 base URL, otherwise to `AzureB2C` ([`ConfigureServices.cs:54-70`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/ConfigureServices.cs#L54-L70), wired at [`Program.cs:104-116`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L104-L116)).

B2C activates only when `UserProfileApiAuth:ClientId` is non-empty ([`Program.cs:95`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L95)); otherwise all traffic forwards to IDP4.

Startup logs `Fatal` (without aborting) when any of `UserProfileClientAuthIDP4` `BaseUrl`, `ClientId`, `ClientSecret`, or `Scopes` is missing ([`Program.cs:71-93`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L71-L93)). Misconfiguration produces a running but non-authenticating service rather than a crash.

Every business controller carries `[Authorize]`. `HealthCheckController` does not, and is hidden from Swagger with `[ApiExplorerSettings(IgnoreApi = true)]`. Anonymous access is required by the Kubernetes probes and the Traffic Manager monitor.

Swagger UI is served only when the environment is not `Production` ([`Program.cs:216-231`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L216-L231)). Production overlays set `ASPNETCORE_ENVIRONMENT=prd`, so `IsProduction()` returns false. The Swagger documents returned HTTP 200 in US, Germany, and Canada during this audit.

## 5. Data stores and external dependencies

### The service owns no database

`Relias.UserProfile.Infra` contains a Cosmos-backed repository ([`UserProfileRepository.cs:12-58`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Infra/Repository/UserProfileRepository.cs#L12-L58)) with a dedicated `CosmosDbRetryPolicy`.

**It is never registered in dependency injection.** Searching `src/**/*.cs` for `AddCosmosRepository`, `AddRepository`, or any registration of `IUserProfileRepository` returns only the interface and class declarations. `AddApplicationServices` registers MediatR, cache, `IDualHttpClientAclService`, `ICacheService`, `IAclService`, `IHealthCheckService`, `IPolicyHolder`, `IIdentityService`, and AutoMapper. It registers nothing from `Infra` ([`ConfigureServices.cs:29-50`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/ConfigureServices.cs#L29-L50)). No Cosmos account appears in `.iac/infra.bicep`.

The Cosmos layer is unreachable code representing the unfinished phase two.

### Redis

Redis is the only stateful store in use, as a token and lookup cache. Provisioned at [`infra.bicep:200-216`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/infra.bicep#L200-L216), defaults `Standard` / family `C` / capacity `1` ([`infra.bicep:61-67`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/infra.bicep#L61-L67)), selected by `"Cache": { "CacheType": "Redis" }` in [`appsettings.prd.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/appsettings.prd.json).

The paired-region Redis is commented out with an inline note that it "isn't being utilized in the AppSettings or Key Vault" ([`infra.bicep:218-235`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/infra.bicep#L218-L235)). There is no cache failover.

### External dependencies

| Dependency | Purpose | Evidence |
|---|---|---|
| ACL API → legacy UMAPI | All profile and organization reads/writes | [`AclService.cs:165,211,257,400,427,528,588`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/AclService.cs#L165-L588) |
| Identity API | Creates Azure AD B2C users via `POST v1/user/` | [`IdentityService.cs:31`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/IdentityService.cs#L31) |
| IdentityServer4 | Client-credentials tokens for outbound ACL calls | [`Program.cs:143-149`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L143-L149), `BearerTokenHandlerIdp4.cs` |
| Azure App Configuration | Runtime config via `ManagedIdentityCredential`, null label then environment label | [`Program.cs:27-42`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L27-L42) |
| Azure Key Vault | Secret backing for App Config references, private endpoint | [`infra.bicep:237-258`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/infra.bicep#L237-L258) |
| Application Insights | Telemetry with Kubernetes enricher | [`Program.cs:174-176`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L174-L176) |

The ACL routes mirror its public routes almost one for one, including `api/v1/user-profiles?userId={userId}` and `api/v1/organizations/{orgId}/user-profile-customization-fields`. This confirms that User Profile is a pass-through service.

Readiness is coupled to ACL: the default health check calls `api/ACLHealthCheck?status=true` ([`AclService.cs:549`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/AclService.cs#L549)). Probes use `meonly=1` to avoid that coupling.

Resilience is Polly-based, configured from `"Policy": { "RetryCount": "3", "SleepDurationInSeconds": "5" }` in [`appsettings.prd.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/appsettings.prd.json).

## 6. Operational and security-relevant configuration

### Kubernetes runtime

From [`base/userprofile-api/deployment.yaml`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/deployment.yaml):

- Namespace `userprofile-ns`, 2 replicas, container port 53002, plain HTTP inside the cluster.
- Azure Workload Identity enabled, service account `userprofile-aksworkload-mi-001-sa`.
- Hardened security context: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `privileged: false`, all capabilities dropped except `NET_BIND_SERVICE`, `runAsUser: 100001`, `runAsGroup: 100002`, `/tmp` as `emptyDir`.
- `COMPlus_EnableDiagnostics: "0"` disables the .NET diagnostics IPC socket.
- Probes: liveness 15s delay / 30s period, readiness 5s / 10s, both on `/api/healthcheck?meonly=1`.
- Requests `20m` CPU / `200M` memory; limits `80m` CPU / `300M` memory.

HPA v2: 2 to 5 replicas, 70% CPU and 80% memory targets, scale-up stabilization 120s, scale-down 300s ([`hpa.yaml`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/hpa.yaml)).

Ingress: `azure/application-gateway` class, cert-manager `letsencrypt-prod`, 720h renewal lead, forced SSL redirect ([`ingress.yaml`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/ingress.yaml)).

### Finding: the PodDisruptionBudget protects zero pods

[`pdb.yaml`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/pdb.yaml) selects on two labels:

```yaml
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: userprofile
      tier: backend
```

The pod template labels are `app: userprofile`, `service: userprofile-api-service`, `azure.workload.identity/use: "true"` ([`deployment.yaml:16-19`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/deployment.yaml#L16-L19)). `tier: backend` appears only on the **Deployment object's own** `metadata.labels` at line 8, never on the pods.

A PDB selector matches pods, not Deployments. In the audited manifest, this selector matches nothing and provides no protection during node drains, cluster upgrades, or evictions. Both replicas can be evicted simultaneously. Add `tier: backend` to the pod template labels.

### Repository governance

Classic branch protection is absent. `GET /repos/{repo}/branches/{default}/protection` returns `404 Branch not protected` for both. **Organization rulesets enforce governance instead**, confirmed through `GET /repos/{repo}/rules/branches/{default}`:

| Rule | `userprofile-service` (`develop`) | `userprofile-gitops` (`main`) | Ruleset |
|---|---|---|---|
| `required_signatures` | yes | yes | 17413445 |
| `pull_request` (merge/squash/rebase allowed, no code-owner review required) | yes | yes | 3530280 |
| `copilot_code_review` (drafts + on push) | yes | no | 8902691 |
| `required_status_checks`, `SonarCloud Code Analysis` | yes | no | 10935292 |
| `code_quality` (severity `errors`) | yes | no | 10935292 |

The GitOps repository, which is what actually changes production, has the weaker rule set: no status checks and no automated review.

### Security posture

1. **Secret scanning, push protection, and Dependabot security updates are all `disabled`** on both repositories (`GET /repos/{repo}` → `security_and_analysis`). Dependabot *alerting* is nonetheless active, which is how the alerts below exist.
2. **Four open Dependabot alerts** on `userprofile-service` (zero on `userprofile-gitops`), retrieved from `GET /repos/relias-engineering/userprofile-service/dependabot/alerts?state=open`:

| Severity | Package | Vulnerable range | Advisory |
|---|---|---|---|
| High | `Microsoft.Extensions.Caching.Memory` | `>= 6.0.0-preview.1.21102.12, <= 6.0.1` | [CVE-2024-43483](https://github.com/advisories/GHSA-qj66-hp5r-2xgm), .NET denial of service |
| High | `AutoMapper` | `< 15.1.1` | [CVE-2026-32933](https://github.com/advisories), DoS via uncontrolled recursion |
| Medium | `Azure.Identity` | `< 1.11.4` | [CVE-2024-35255](https://github.com/advisories/GHSA-m5vv-6r4h-3vj9), elevation of privilege |
| Medium | `Azure.Identity` | `< 1.11.0` | [CVE-2024-29992](https://github.com/advisories), information disclosure |

Both `Azure.Identity` alerts are relevant here because the service authenticates to App Configuration and Key Vault with `ManagedIdentityCredential` from that exact library.

3. **A client-secret literal is committed** at [`rlms-website:apps/user-profile-e2e/environments/cypress.prod-us.config.ts:19-20`](https://github.com/relias-engineering/rlms-website/blob/main/apps/user-profile-e2e/environments/cypress.prod-us.config.ts#L19-L20), alongside `CLIENT_ID: '4370c58f-0dc4-4ec8-bfa9-1093cde6422f'` and the comment `// fill this with client secret before running automation`. The value is redacted here. The comment reads like a placeholder, and the client ID matches the **stg-us** `userProfileClientId` in [`infra-stg-us.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/parameters/infra-stg-us.json), not a production ID, despite the file name. The value was not tested. Someone with tenant access should check it and rotate it if live.
4. **The anonymous health endpoint leaks environment detail.** The response includes the pod hostname, environment name, and build timestamp. Section 10 has the live results. `Deployed on` is computed as `File.GetLastWriteTimeUtc(Assembly.GetEntryAssembly()!.Location)` ([`HealthCheckService.cs:38-40`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/HealthCheckService.cs#L38-L40)), so it is an image build timestamp, not a rollout time.
5. **Verbose production logging.** [`appsettings.prd.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/appsettings.prd.json) sets `Relias.UserProfile` to `Verbose`, and the log output template includes `{Username}`. `AclService` error paths log usernames and organization IDs. This is a PII-in-telemetry exposure worth review.
6. **Identifier disclosure in IaC.** The `.iac/parameters/*.json` files publish Azure tenant IDs, subscription IDs, and app-registration client IDs in plaintext. These are identifiers rather than secrets, but they form a useful reconnaissance set (enumerated in section 7).
7. `appsettings.json` carries a dev1 tenant/client pair and documents that real secrets come from user secrets or Key Vault ([`appsettings.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/appsettings.json)).

### Quality gates in the pipeline

SonarCloud project key `relias_userprofile-service` is wired into the build stage. The Docker build template runs Lacework image scanning. Three unit-test projects run per build: `Relias.UserProfile.Api.UnitTests`, `Relias.UserProfile.App.UnitTests`, and `Relias.UserProfile.Common.UnitTests`.

A local Release test run completed successfully during this audit: **332 passed, 0 failed, 0 skipped**.

## 7. Where it is deployed

Runtime platform is shared Azure Kubernetes Service, namespace `userprofile-ns`. Seven environments have full overlays. `sbox` and `pground` also have Flux contexts.

| Env | Subscription ID | Region (paired) | ACR | Hostname | App Config | Resource group |
|---|---|---|---|---|---|---|
| dev1 | `3741355f-a2fe-4aa7-b024-1cecffdca327` | `eastus2` (`centralus`) | `deveus2lmscr001.azurecr.io` | `dev1-userprofile.reliaslearning.com` | `dev1-eus2-userprofile-appconfig-001.azconfig.io` | `dev1-userprofile-rg` |
| dev2 | `3741355f-a2fe-4aa7-b024-1cecffdca327` | `eastus2` (`centralus`) | `deveus2lmscr001.azurecr.io` | `dev2-userprofile.reliaslearning.com` | `dev2-eus2-userprofile-appconfig-001.azconfig.io` | `dev2-userprofile-rg` |
| stg-us | `bda20fca-5f2e-4080-baf8-3154a48b2fee` | `northcentralus` (`southcentralus`) | `prdscuslmscr001.azurecr.io` | `suserprofile.reliaslearning.com` | `stg-ncus-userprofile-appconfig-001.azconfig.io` | `stg-us-userprofile-rg` |
| stg-de | `e6036236-a7f0-41c5-850a-54de53a62b15` | `germanywestcentral` (`germanynorth`) | `prddewclmscr001.azurecr.io` | `suserprofile.reliaslearning.de` | `stg-dewc-userprofile-appconfig-001.azconfig.io` | `stg-de-userprofile-rg` |
| prd-us | `48d98a9a-2f7b-46ac-9a18-3aabd9fbd39a` | `northcentralus` (`southcentralus`) | `prdscuslmscr001.azurecr.io` | `userprofile.reliaslearning.com` | `prd-ncus-userprofile-appconfig-001.azconfig.io` | `prd-us-userprofile-rg` |
| prd-de | `6674136c-603f-4418-8397-06ece80c7273` | `germanywestcentral` (`germanynorth`) | `prddewclmscr001.azurecr.io` | `userprofile.relias.de` | `prd-dewc-userprofile-appconfig-001.azconfig.io` | `prd-de-userprofile-rg` |
| prd-ca | `760cd487-2f3b-42d2-82ea-124cb83096f4` | `canadacentral` (`canadaeast`) | `prdcaclmscr001.azurecr.io` | `userprofile.relias.ca` | `prd-cac-userprofile-appconfig-001.azconfig.io` | `prd-ca-userprofile-rg` |

Sources: [`.azuredevops/pipelines/variables/*.yml`](https://github.com/relias-engineering/userprofile-service/tree/develop/.azuredevops/pipelines/variables), [`.iac/parameters/*.json`](https://github.com/relias-engineering/userprofile-service/tree/develop/.iac/parameters), and [`userprofile-gitops/overlays/*/userprofile-api-values.yaml`](https://github.com/relias-engineering/userprofile-gitops/tree/main/overlays).

An eighth parameter file, [`infra-sbox-us.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/parameters/infra-sbox-us.json), targets `sbox-us-userprofile-rg` / `sbox-userprofile.reliaslearning.com` but still contains `<placeholder>` values for auth scopes and tenant, and has no pipeline stage or GitOps overlay. It is unfinished configuration.

The same parameter files reference management subscriptions `148f5a47-b62d-43e6-a5e7-34cd39df4c5f` (US/sbox), `ef305fde-0c06-4a71-8d00-239a290bd615` (DE), `4f20d1e5-7e76-44e1-8303-94fabcedc798` (CA), and `5d8f65cc-1c9a-4fac-a100-f56c5e8a0070` (dev). Connectivity subscriptions are `462f3475-7dac-4ae8-bf9d-e0d165cfbef5` (US), `20696ebd-7685-4c92-924c-4369b8543e22` (DE), `0fa713d4-8de8-4982-99fb-e05d84f5e6b1` (CA), and `7fae9531-527e-40f9-b7b6-61929e161a69` (dev).

APIM fronts the service at path `user-profile` on `dev1-eus2-rlms-apim-001`, `dev2-eus2-rlms-apim-001`, `stg-ncus-rlms-apim-001`, `stg-dewc-rlms-apim-001`, `prd-ncus-rlms-apim-001`, `prd-dewc-rlms-apim-001`, `prd-cac-rlms-apim-001`, in resource groups `<env>-<region>-apim-rg`, via ARM service connections named `shared-<geo>-platforms-workloads-<prod|nonprod>`.

Per-environment Azure resources from [`.iac/infra.bicep`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/infra.bicep) (`targetScope = 'subscription'`, 14 modules): resource group, Application Insights, Redis, Key Vault with private endpoint and private DNS zone group, App Configuration with paired-region replica, Traffic Manager, Action Group, K8s pod monitor, health-check web test, metric alert, scheduled query rule. AKS itself is shared platform infrastructure provisioned elsewhere.

Traffic Manager probes `/api/healthcheck?meonly=1` and sets a custom host header per environment.

### Live corroboration (DNS, 2026-09-03)

- `userprofile.reliaslearning.com` → CNAME `wildcard.reliaslearning.com.edgekey.net` → `e341045.dsca.akamaiedge.net` → `23.48.203.147`, `23.48.203.140`
- `suserprofile.reliaslearning.com`, `dev1-userprofile.reliaslearning.com` → same Akamai chain
- `userprofile.relias.ca` → `wildcard.relias.ca.edgekey.net` → `e220270.dsca.akamaiedge.net` → `23.53.11.179`, `23.53.11.168`
- `prd-us-userprofile-tm-001.trafficmanager.net` → CNAME `prd-ncus-lms.northcentralus.cloudapp.azure.com` → `23.100.77.60`, independently confirming the North Central US AKS ingress
- `userprofile.relias.de` → `104.18.43.108`, `172.64.144.148`, `2a06:98c1:...`. This is **Cloudflare**, not Akamai.

The German production edge diverges from both its siblings and from the repository's own Akamai configuration ([`relias-akamai-terraform:properties/relias.de/property-snippets/Origins.json:2009-2024`](https://github.com/relias-engineering/relias-akamai-terraform/blob/main/properties/relias.de/property-snippets/Origins.json#L2009-L2024) declares origin `prd-de-userprofile-tm-001.trafficmanager.net` behind Akamai). The live `server: cloudflare` header confirms it (section 10). Committed edge config and live edge are out of sync for Germany.

## 8. What deploys it

Two hops: Azure DevOps builds and writes a tag; Flux applies it.

### Hop 1: Azure DevOps

The build pipeline is [`.azuredevops/pipelines/userprofile-api-build.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/userprofile-api-build.yml). Its build name is `$(SourceBranch)_$(Date:yyyyMMdd)$(Rev:.r)`. Changes to `develop` and `main` trigger it for `src/*`, `tests/*`, `.azuredevops/*`, and `.iac/*`. A separate [`userprofile-api-pr.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/userprofile-api-pr.yml) handles pull-request validation.

Stages in order:

1. `BuildAndUnitTest`. Uses .NET 8, runs three test projects, and builds with SonarCloud analysis.
2. `BuildAndAttachDockerImages`. Builds `relias-userprofile-api:$(Build.BuildId)` and runs the Lacework scan.
3. `PushDockerImagesToACR_Dev` → `DeployInfra_Dev1` (Bicep) → `UpdateFlux_Dev1` → APIM import → Cypress.
4. Dev2 equivalent.
5. `StagingApprovalGate`. Manual approval through environment `opensourcerers-stg`.
6. Stg De and Stg Us: push → infra → flux → APIM → Cypress.
7. `ProductionApprovalGate`. Manual approval through environment `opensourcerers-prd`.
8. Prd Us, Prd De, Prd Ca: push → infra → flux → APIM → Cypress.

Regional agent pools: `dev-eus2-agent-pool`, `prd-scus-agent-pool`, `prd-dewc-agent-pool`, `prd-cac-agent-pool`. ARM service connection `ReliasAzureCloud_WorkloadContributor`. ACR service connections `acr-<registry>-PlatformDevelopment`.

**IaC is Bicep**, not Terraform or ARM templates, applied by [`templates/infra-deploy.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/templates/infra-deploy.yml). Terraform exists for this service's DNS and WAF, but in `relias-akamai-terraform`, not here.

### Hop 2: Flux GitOps

[`templates/flux-update.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/templates/flux-update.yml) checks out the GitOps repo, sets git identity to `azuredevops-cicd <azure@reliaslearning.com>`, then per overlay runs:

```powershell
yq eval '.spec.template.spec.containers[0].image |= sub(":.*"; ":$(Build.BuildId)")' $overlayFilePath -i
```

commits `"Updated userprofile-api-values.yaml image to version $(Build.BuildId) - $(targetEnv)"`, and pushes with a five-attempt randomized 10-30s backoff loop to survive concurrent regional stages.

Flux reconciles from [`flux-platform-infrastructure:contexts/base/userprofile/sync.yaml`](https://github.com/relias-engineering/flux-platform-infrastructure/blob/main/contexts/base/userprofile/sync.yaml): a `GitRepository` on a 1m interval and a `Kustomization` bound per environment, for example `path: ./overlays/prd-us`, `prune: true`, `interval: 5m0s` ([`contexts/prd-us/userprofile-patch.yaml:7-9`](https://github.com/relias-engineering/flux-platform-infrastructure/blob/main/contexts/prd-us/userprofile-patch.yaml#L7-L9)).

### Finding: Flux still points at Bitbucket

[`sync.yaml:13`](https://github.com/relias-engineering/flux-platform-infrastructure/blob/main/contexts/base/userprofile/sync.yaml#L13):

```yaml
url: ssh://bitbucket.org/relias/userprofile-gitops.git
```

The cluster's source of truth is the Bitbucket repository, not `relias-engineering/userprofile-gitops` on GitHub. **Any change merged to the GitHub GitOps repository will not reach any cluster.** The pipeline's `resources.repositories` block likewise declares `userprofile-gitops`, `relias-api-management`, and `relias-cypress` as `type: bitbucket`. The migration moved the code but not the delivery path.

### No GitHub-native deployment of any kind

`GET /repos/{repo}/actions/workflows`, `/actions/runs`, `/deployments`, `/environments`, and `/releases` all return zero for both repositories, and neither tree contains a `.github/` directory. There is no App Service, no deployment center, no ARM template deployment, and no GitHub Actions involvement.

## 9. Latest code commit vs latest deployment

These are different dates, and the gap is the headline operational fact.

| Signal | Value |
|---|---|
| Latest **code** commit (`develop`) | `f0970f091c705ff3ac7d43d4f92955f78c4b03c0`, **2025-02-26 12:06 EST**, Shraddha Bedekar, "Merged in bug/RPLAT-1208-PipelineCodeChange-Fix2 (pull request #150)" |
| Latest commit on service `main` | `7fcfba3cdfefbb925f2a442c54267adaf94ee3c2`, 2022-08-17 10:58 EDT (abandoned branch) |
| Latest **GitOps** commit | `889b9843f0b15679c6b19033c5a5acd82e71097a`, **2025-06-11 14:23 EDT**, John Martin, "Merged in jm/resourceTuning (pull request #20)" |
| Deployed version, all 7 environments | image tag **`44932`** |
| In-image build timestamp (live probe) | **2025-03-20 09:41 EDT** |
| Deploying identity | `azuredevops-cicd <azure@reliaslearning.com>` |

### Image 44932 promotion timeline

Times are EDT.

| Environment | Commit time | Commit |
|---|---|---|
| dev2 | 2025-03-20 09:44:06 | [`61ad191`](https://github.com/relias-engineering/userprofile-gitops/commit/61ad19195b8c652e84229893bd9deb76fc353b89) |
| dev1 | 2025-03-20 09:44:12 | [`f610859`](https://github.com/relias-engineering/userprofile-gitops/commit/f610859fb17e45b0867928357b051e72b3c6e27e) |
| stg-us | 2025-03-20 15:21:51 | [`f9590ad`](https://github.com/relias-engineering/userprofile-gitops/commit/f9590adc3275cc7af4be693c0049b8baf4401eba) |
| stg-de | 2025-03-20 16:05:31 | [`67607e3`](https://github.com/relias-engineering/userprofile-gitops/commit/67607e3478e22b77c51bdd51280acd059434e086) |
| prd-ca | 2025-04-02 12:08:45 | [`60c0aef`](https://github.com/relias-engineering/userprofile-gitops/commit/60c0aeffcaeee6c21e04e9b10363a3ffd304442d) |
| prd-us | 2025-04-02 12:11:29 | [`006837c`](https://github.com/relias-engineering/userprofile-gitops/commit/006837cd4142edecc874f559443b2d74ec459627) |
| **prd-de** | **2025-04-02 13:09:19** | [`c0287c5`](https://github.com/relias-engineering/userprofile-gitops/commit/c0287c5e459f94cc92c222770097b7c5e91e8c08) |

**Last recorded production image deployment: prd-de, 2025-04-02 13:09:19 EDT.**

**Last deployment-affecting change: 2025-06-11 14:23:04 EDT.** Commit `889b9843` altered CPU/memory requests and limits and added HPA behavior. Because resource settings live in the pod template, a successful Flux reconcile would have rolled the Deployment without changing the image tag. The actual reconcile time is not verifiable from here.

### Interpretation

- The image was built after the final code commit. The Azure DevOps run is unavailable, so the exact source SHA for build `44932` remains unverified.
- Production lagged staging by 13 days, consistent with the manual `ProductionApprovalGate`.
- Production has not received a new image in roughly 17 months.
- The base manifest still hard-codes a stale dev image `deveus2lmscr001.azurecr.io/relias-userprofile-api:4596` ([`deployment.yaml`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/deployment.yaml)), but every overlay patches it, so this is cosmetic.

## 10. Live runtime verification (2026-09-03)

Direct `GET /api/healthcheck` probes returned HTTP 200 in all seven environments.

| Environment | URL | Sample latency | `Environment` | `Deployed on` (EDT) | ACL |
|---|---|---:|---|---|---|
| dev1 | `dev1-userprofile.reliaslearning.com` | 540 ms | `dev1` | 2025-03-20 09:41:00 | OK |
| dev2 | `dev2-userprofile.reliaslearning.com` | 3,996 ms | `dev2` | 2025-03-20 09:41:00 | OK |
| stg-us | `suserprofile.reliaslearning.com` | 4,884 ms | `stg` | 2025-03-20 09:41:00 | OK |
| stg-de | `suserprofile.reliaslearning.de` | 4,726 ms | `stg` | 2025-03-20 09:41:00 | OK |
| prd-us | `userprofile.reliaslearning.com` | 4,445 ms | `prd` | 2025-03-20 09:41:00 | OK |
| prd-de | `userprofile.relias.de` | 709 ms | `prd` | 2025-03-20 09:41:00 | OK |
| prd-ca | `userprofile.relias.ca` | 4,758 ms | `prd` | 2025-03-20 09:41:00 | OK |

Three things this proves that static analysis could not:

1. The service is running in every environment, and the identical `Deployed on` value confirms that each uses the same image build.
2. `ASPNETCORE_ENVIRONMENT` is `prd`, not `Production`, in production. The Swagger gate in section 4 therefore does not behave as its name suggests.
3. `userprofile.relias.de` returned `server: cloudflare`; the others returned no `Server` header, consistent with Akamai.

Several ACL checks took roughly four to five seconds. That deserves a telemetry review even though the checks completed within the liveness period.

## 11. Who calls this API

Nine GitHub org code searches across `relias-engineering`, then direct file fetches to confirm each hit.

### Confirmed callers

| Repository | File and line | Nature | Confidence |
|---|---|---|---|
| `rlms-website` | [`apps/user-profile-e2e/environments/cypress.prod-us.config.ts:23,32`](https://github.com/relias-engineering/rlms-website/blob/main/apps/user-profile-e2e/environments/cypress.prod-us.config.ts#L23-L32) | `userProfileUrl: 'https://userprofile.reliaslearning.com'`; sibling configs for dev1, stg-us, stg-de | **Confirmed** |
| `rlms-website` | [`apps/user-profile-e2e/src/support/auth.ts:41-50`](https://github.com/relias-engineering/rlms-website/blob/main/apps/user-profile-e2e/src/support/auth.ts#L41-L50) | `getUserProfileToken` with `client_id: 'integration-app'` and `scope: 'userprofile-service-api'`, matching `apiName` at `Program.cs:69` | **Confirmed** |
| `rlms-website` | `apps/user-profile-e2e/src/e2e/*.spec.ts`: `Bulk-Get-Users`, `Create-User-Profile`, `Get-User-Profile-By-Org`, `Category`, `Locations`, `Job-Titles`, `Departments`, `Custom-Field`, `Employment-Type`, plus `src/support/utility.ts` | Cypress specs exercising the `api/v1` routes | **Confirmed** |
| `rlms-website` | [`libs/shared-e2e-cypress/src/lib/utils/authentication/auth.ts`](https://github.com/relias-engineering/rlms-website/blob/main/libs/shared-e2e-cypress/src/lib/utils/authentication/auth.ts) | Shared helper listing the scope | **Confirmed** |

**All confirmed callers are automated tests.**

### Scope grants without a located call site

| Repository | File and line | Nature | Confidence |
|---|---|---|---|
| `k6-performance-tests` | [`projects/shared/auth.js:24`](https://github.com/relias-engineering/k6-performance-tests/blob/main/projects/shared/auth.js#L24) | `userprofile-service-api` inside a shared space-delimited scope string | **Medium.** No dedicated UserProfile k6 project exists; only `projects/Identity/...` and shared files matched. |
| `learner-app` | [`appium/src/utils/auth.ts:39`](https://github.com/relias-engineering/learner-app/blob/main/appium/src/utils/auth.ts#L39) | Requests the scope in its Appium auth helper | **Medium.** A token is minted for this audience, but no HTTP call to a UserProfile host was found. |

### Deployment and edge infrastructure (references, not callers)

| Repository | File and line | Nature | Confidence |
|---|---|---|---|
| `flux-platform-infrastructure` | [`contexts/base/userprofile/sync.yaml:13`](https://github.com/relias-engineering/flux-platform-infrastructure/blob/main/contexts/base/userprofile/sync.yaml#L13) | Flux `GitRepository` → Bitbucket, branch `main`, 1m interval | **Confirmed.** This is the deployment control plane. |
| `flux-platform-infrastructure` | [`contexts/prd-us/userprofile-patch.yaml:7,17`](https://github.com/relias-engineering/flux-platform-infrastructure/blob/main/contexts/prd-us/userprofile-patch.yaml#L7-L17) | Binds `./overlays/prd-us`, `prune: true`; workload-identity client ID `b17a001e-cbfe-44f0-812f-9f7dfc0fb96a`. Equivalents for dev1, dev2, sbox, pground, stg-us, stg-de, prd-de, prd-ca | **Confirmed** |
| `akamai-relias-edgeworkers` | [`edgeworkers/reliaslearning/data/origins.js:146,229,421,483`](https://github.com/relias-engineering/akamai-relias-edgeworkers/blob/main/edgeworkers/reliaslearning/data/origins.js#L146-L483) | Maps four `.com` hostnames to `*-userprofile-tm-001.trafficmanager.net` | **Confirmed** |
| `akamai-relias-edgeworkers` | [`edgeworkers/reliaslearning-de/data/origins.js:100`](https://github.com/relias-engineering/akamai-relias-edgeworkers/blob/main/edgeworkers/reliaslearning-de/data/origins.js#L100) | `suserprofile.reliaslearning.de` → `stg-de-userprofile-tm-001` | **Confirmed** |
| `relias-akamai-terraform` | [`dns/reliaslearning.com/reliaslearning_com.tf:1456,2336,4472,4968,5336`](https://github.com/relias-engineering/relias-akamai-terraform/blob/main/dns/reliaslearning.com/reliaslearning_com.tf#L4968) | CNAMEs for all four `.com` hostnames plus `_acme-challenge` TXT for dev1 | **Confirmed** |
| `relias-akamai-terraform` | [`dns/relias.ca/relias_ca.tf`](https://github.com/relias-engineering/relias-akamai-terraform/blob/main/dns/relias.ca/relias_ca.tf), [`properties/relias.ca/property-snippets/main.json`](https://github.com/relias-engineering/relias-akamai-terraform/blob/main/properties/relias.ca/property-snippets/main.json) | Canada DNS and property config | **Confirmed** |
| `relias-akamai-terraform` | [`properties/relias.de/property-snippets/Origins.json:2009-2024`](https://github.com/relias-engineering/relias-akamai-terraform/blob/main/properties/relias.de/property-snippets/Origins.json#L2009-L2024) | German origin configuration, contradicted by live Cloudflare resolution | **Confirmed and stale** |
| `relias-akamai-terraform` | `appsec/first-security-configuration/modules/security/custom-rules.tf` (21 hits), `response-actions.tf` | WAF rules and response actions scoped to every userprofile hostname | **Confirmed** |

### Downstream provider, not a caller

`Relias.ACL` implements [`src/Relias.Acl.Api/Controllers/UserProfile/V1/UserProfileController.cs`](https://github.com/relias-engineering/Relias.ACL/blob/develop/src/Relias.Acl.Api/Controllers/UserProfile/V1/UserProfileController.cs), the `api/v1/user-profiles` routes that `AclService` consumes. The dependency runs the other way.

### Ruled out on evidence

**`notifications-api` is not a caller.** Its test harness sets `"ConfigurationOptions:UserProfileApi"` at [`TestWebApplicationFactory.cs:72`](https://github.com/relias-engineering/notifications-api/blob/main/tests/Relias.CM.Notifications.Integration.Reqnroll.Tests/Support/TestWebApplicationFactory.cs#L72), but the `ConfigurationOptions` class exposes only `UserGroupsApi` and `AclApi` ([`ConfigurationOptions.cs:11-12`](https://github.com/relias-engineering/notifications-api/blob/main/src/Relias.CM.Notifications.Common/Configuration/ConfigurationOptions.cs#L11-L12)). Its similarly named `UserProfileService` builds `{AclApi}/users/search` and posts via the `AclAuthorization` client ([`UserProfileService.cs:41-49`](https://github.com/relias-engineering/notifications-api/blob/main/src/Relias.CM.Notifications.Business/Services/UserProfileService.cs#L41-L49)). It talks to ACL directly and bypasses this service. The test config key is vestigial.

Low-signal name matches only, no API interaction: `cortex-gitops` (`README.md`, `.github/agents/this.cortex-assistant.agent.md`) and `org-metrics` (`data/merged-pr-audit-*.json`).

### Conclusion

**No production application caller was found in indexed `relias-engineering` code.** Every confirmed caller is a test harness. The other matches are routing, DNS, WAF, or GitOps configuration.

The README states the service exists for integrations and potentially external clients, so real callers may be HRIS/integration pipelines configured through APIM and App Configuration rather than source, or may live outside this GitHub organization, or may never have materialised. **Application Insights request telemetry is the only way to settle this.** Useful dimensions: request count by operation, authenticated client ID, caller IP, environment, and last successful request per caller.

## 12. Gaps and uncertainties

1. **Azure DevOps is not reachable from this session.** The audit could not confirm which pipeline run produced build `44932`, its completion time, the source commit, its result, or who approved the gates. GitOps commit times show when the pipeline wrote the tag, not when Flux finished applying it.
2. **Azure Resource Manager access is unavailable.** Subscription IDs, resource groups, and App Config endpoints come from committed IaC parameters. Those files prove intent, not current Azure state.
3. **Cluster access is unavailable.** Pod image digests, replica counts, and Flux reconcile status remain unverified. The health endpoints corroborate the shared build timestamp, but they do not expose the image digest or rollout time.
4. **`relias-api-management` and `relias-cypress` are not on GitHub.** Both return 404 under `relias-engineering`, and the pipeline declares them as Bitbucket repositories. The APIM import template and policies could not be audited.
5. **The German Cloudflare edge is unexplained.** It contradicts the sibling hostnames and committed Akamai configuration. Akamai or Cloudflare access is needed to identify the authoritative setup.
6. **GitHub code search has indexing limits.** It skips some large files and does not cover every branch. The caller list is a strong lower bound, not proof of completeness. Follow-up searches should cover Bitbucket and APIM-relative paths such as `/user-profile/api/v1`.
7. **The committed `CLIENT_SECRET` was not tested.** Its validity and expiry require tenant access.
8. **Dependabot alerts show vulnerable package ranges, not proven exploitability.** The four advisories in section 6 come from GitHub's Dependabot API.

## Evidence table

| # | Claim | Source | Type |
|---|---|---|---|
| 1 | `relias-engineering/userprofile` does not exist | `GET /repos/relias-engineering/userprofile` → 404 | GitHub REST API |
| 2 | Service repo C#, internal, default `develop`, created 2026-09-01 | `GET /repos/relias-engineering/userprofile-service` | GitHub REST API |
| 3 | GitOps repo syncs K8s manifests to Platform AKS | repo `description` | GitHub REST API |
| 4 | ACL facade over legacy UMAPI, phase two never delivered | [`README.md`](https://github.com/relias-engineering/userprofile-service/blob/develop/README.md) | Repo source |
| 5 | net8.0 across four projects; aspnet:8.0 / sdk:8.0 images | four `*.csproj`, [`Dockerfile`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Dockerfile) | Repo source |
| 6 | 13 route groups under `api/v1`; all `[Authorize]` except healthcheck | attribute extraction across `src/.../Controllers/**` | Repo source |
| 7 | API resource name `userprofile-service-api` | [`Program.cs:69`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/Program.cs#L69) | Repo source |
| 8 | Dual IDP4 + Azure B2C scheme chosen by token issuer | [`ConfigureServices.cs:54-70`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/ConfigureServices.cs#L54-L70) | Repo source |
| 9 | Cosmos repository exists but is never DI-registered | grep for `AddCosmosRepository`/`IUserProfileRepository`; [`ConfigureServices.cs:29-50`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/ConfigureServices.cs#L29-L50) | Repo source |
| 10 | Redis only live store; paired-region cache commented out | [`infra.bicep:200-235`](https://github.com/relias-engineering/userprofile-service/blob/develop/.iac/infra.bicep#L200-L235), [`appsettings.prd.json`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.Api/appsettings.prd.json) | Repo source |
| 11 | Outbound ACL `api/v1/...`, Identity `v1/user/`, ACL healthcheck | [`AclService.cs`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/AclService.cs), [`IdentityService.cs:31`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/IdentityService.cs#L31) | Repo source |
| 12 | Hardened pod security context, workload identity, port 53002 | [`deployment.yaml`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/deployment.yaml) | Repo source |
| 13 | **PDB selector matches zero pods** | [`pdb.yaml:7-10`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/pdb.yaml#L7-L10) vs [`deployment.yaml:16-19`](https://github.com/relias-engineering/userprofile-gitops/blob/main/base/userprofile-api/deployment.yaml#L16-L19) | Repo source |
| 14 | Secret scanning, push protection, Dependabot updates disabled | `GET /repos/{r}` → `security_and_analysis` | GitHub REST API |
| 15 | No classic branch protection; org rulesets enforce signatures, PR review, SonarCloud, Copilot review | `GET /repos/{r}/branches/{b}/protection` → 404; `GET /repos/{r}/rules/branches/{b}` | GitHub REST API |
| 16 | Four open Dependabot alerts, two high | `GET /repos/.../dependabot/alerts?state=open` | GitHub REST API |
| 17 | Zero Actions workflows, runs, deployments, environments, releases | `GET /repos/{r}/actions/workflows`, `/actions/runs`, `/deployments`, `/environments`, `/releases` | GitHub REST API |
| 18 | 7 environments with subscriptions, regions, ACRs, hostnames, APIM | [`variables/*.yml`](https://github.com/relias-engineering/userprofile-service/tree/develop/.azuredevops/pipelines/variables), [`parameters/*.json`](https://github.com/relias-engineering/userprofile-service/tree/develop/.iac/parameters) | Repo source |
| 19 | Azure DevOps multi-stage pipeline, two manual gates, Bitbucket resources | [`userprofile-api-build.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/userprofile-api-build.yml) | Repo source |
| 20 | Flux image bump via `yq` + retry push as `azuredevops-cicd` | [`flux-update.yml`](https://github.com/relias-engineering/userprofile-service/blob/develop/.azuredevops/pipelines/templates/flux-update.yml) | Repo source |
| 21 | **Flux `GitRepository` points at Bitbucket, not GitHub** | [`sync.yaml:13`](https://github.com/relias-engineering/flux-platform-infrastructure/blob/main/contexts/base/userprofile/sync.yaml#L13) | Org code search + file fetch |
| 22 | Latest code commit `f0970f09`, 2025-02-26 | `GET /repos/.../commits?per_page=1`; `git log` | GitHub REST API + git |
| 23 | Latest prod deploy 2025-04-02, image 44932 | `git log` in `userprofile-gitops`; `overlays/prd-*/userprofile-api-values.yaml` | Git history |
| 24 | All 7 overlays pinned to tag 44932 | all `overlays/*/userprofile-api-values.yaml` | Repo source |
| 25 | All 7 environments healthy; build stamp 2025-03-20 09:41 EDT; `prd` env name; DE on Cloudflare | live `GET /api/healthcheck` | Live first-party API |
| 26 | `Deployed on` is an assembly file timestamp | [`HealthCheckService.cs:38-40`](https://github.com/relias-engineering/userprofile-service/blob/develop/src/Relias.UserProfile.App/Services/HealthCheckService.cs#L38-L40) | Repo source |
| 27 | `notifications-api` calls ACL, not this service | [`UserProfileService.cs:41-49`](https://github.com/relias-engineering/notifications-api/blob/main/src/Relias.CM.Notifications.Business/Services/UserProfileService.cs#L41-L49), [`ConfigurationOptions.cs:11-12`](https://github.com/relias-engineering/notifications-api/blob/main/src/Relias.CM.Notifications.Common/Configuration/ConfigurationOptions.cs#L11-L12) | Org code search + file fetch |
| 28 | Committed Akamai edge, DNS, and WAF configuration references the UserProfile hostnames | `akamai-relias-edgeworkers`, `relias-akamai-terraform` (lines in section 11) | Org code search + file fetch |
| 29 | Live DNS: Akamai → Traffic Manager → NCUS AKS; DE on Cloudflare | `Resolve-DnsName` on 6 hostnames | Live DNS |
| 30 | `relias-api-management`, `relias-cypress` absent from GitHub org | `GET /repos/relias-engineering/{name}` → 404 | GitHub REST API |
| 31 | Commit volume 105/513/69/13 by year 2022-2025; 700 commits total | `git log --date=format:%Y` grouping; `git rev-list --count` | Git history |
| 32 | 332 tests passed; 0 failed; 0 skipped | `dotnet test UserProfileService.sln --configuration Release` | Local test run |

## Recommended follow-ups

Ordered by risk.

1. **Repoint the Flux `GitRepository` to GitHub, or label the GitHub GitOps repo read-only.** Today the two disagree silently and the cluster follows Bitbucket. A change merged on GitHub in good faith would appear deployed and would not be.
2. **Fix the PodDisruptionBudget.** Add `tier: backend` to the pod template labels in `base/userprofile-api/deployment.yaml`. One line, removes a real availability risk during node drains.
3. **Pull Application Insights request telemetry before any other decision about this service.** Section 11 shows no production caller in source. Confirm whether real traffic exists, and from whom, before modernizing or retiring.
4. **Have someone with tenant access review the `rlms-website` Cypress client secret and rotate if live.**
5. **Patch the four Dependabot alerts**, starting with `Azure.Identity` (used for the managed-identity path to Key Vault and App Configuration) and `Microsoft.Extensions.Caching.Memory`.
6. **Enable secret scanning and push protection** on both repositories. Add deployment-specific status checks, automated review, and ownership rules to the GitOps repository.
7. **Resolve the German edge discrepancy** between committed Akamai config and live Cloudflare serving.
8. **Decide whether production Swagger should be public.** It currently returns HTTP 200 in all three production regions. If that is unintended, align the environment name with `IsProduction()` and change the APIM import flow so it does not depend on a public production document.
9. **Reduce production log verbosity** from `Verbose` and stop emitting usernames in the Serilog output template.
10. **Delete `Relias.UserProfile.Infra`** if phase two is dead. Unreachable Cosmos code implies a datastore that does not exist and misleads every future reader.
11. **Remove or complete `infra-sbox-us.json`**, which still carries `<placeholder>` auth values and has no pipeline stage.
