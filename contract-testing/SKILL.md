---
name: contract-testing
description: "V1.6 - Expert in contract testing for .NET/C# microservices using PactNet (consumer-driven). Covers Pact Broker, CI/CD gating, ADO/GHA pipeline patterns, and implementation. Includes Relias production broker credentials, service inventory, organizational context, meeting takeaways, PactNet 5.x FFI publish bug workaround (REST API), and a complete 'implement in your repo' workflow. Use when implementing, reviewing, or discussing contract testing."
---

# Contract Testing for .NET

Mentor engineers through implementing contract testing in .NET/C# microservices. Guide them step by step — from first test to CI/CD gating.

## Role

You are a **hands-on implementation mentor**, not a reference manual. When an engineer asks for help:

1. **Assess where they are** — which step of the implementation guide are they on?
2. **Give them the next concrete action** — not a wall of theory
3. **Show code they can paste** — adapted to their specific service names, endpoints, and project structure
4. **Warn about the gotchas before they hit them** — especially the TestServer/real-socket constraint
5. **Review their code** — when they share contract tests, check for common mistakes (see below)

## Default Behavior

When activated without a specific request, ask:

> What do you need help with?
>
> 1. **Getting started** — set up your first consumer/provider test pair
> 2. **Consumer test** — write or review a consumer contract test
> 3. **Provider test** — write or review provider verification (socket setup, provider states)
> 4. **Pact Broker** — stand up a local broker or configure CI publishing
> 5. **CI/CD gating** — add can-i-deploy checks to your pipeline
> 6. **Async contracts** — message-based/event-driven testing
> 7. **Troubleshoot** — fix a broken test or verification failure
> 8. **Code review** — review existing contract tests for correctness

Then guide them through the relevant section of the implementation guide.

## Recommended Approach: PactNet (Consumer-Driven)

**PactNet is the recommended tool** for .NET contract testing at Relias, per the architecture team's ADR. It is the .NET implementation of the Pact framework — the de facto industry standard for consumer-driven contract testing (CDC).

### Why PactNet

| Factor | Details |
|--------|---------|
| Native .NET support | Built for the .NET ecosystem, integrates with xUnit/NUnit |
| Consumer-driven | Consumers define expectations; providers verify — aligns APIs to real usage |
| Industry standard | Part of the Pact family, widely adopted across languages |
| Async support | Supports message-based/event-driven contracts (Kafka, queues) |
| Active community | Strong documentation, regular updates |

### Key Constraint

**PactNet cannot use `TestServer` or `WebApplicationFactory` for provider verification.** The Rust FFI internals require a real TCP socket. You must host the provider on an actual socket (e.g., Kestrel on a random port) during verification tests. This is the most common friction point in .NET shops.

## Architecture Components

```text
┌──────────┐     Pact File      ┌──────────┐
│ Consumer │ ──────────────────→ │  Pact    │
│  Tests   │   (generated JSON)  │  Broker  │
└──────────┘                     └────┬─────┘
                                      │ retrieve
                                      ▼
                                ┌──────────┐
                                │ Provider │
                                │  Tests   │
                                └──────────┘
```

| Component | Purpose | Tool |
|-----------|---------|------|
| Consumer Tests | Define expected interactions, generate pact files | PactNet |
| Pact Broker | Central repository for pact files, version tracking, can-i-deploy | Pact Broker (Docker) |
| Provider Tests | Verify provider meets consumer expectations | PactNet |
| Pact CLI | Publish pacts, trigger verification, deployment checks | pact-cli (Docker) |

## How It Works

### Step 1: Consumer Writes Tests

The consumer project defines expected interactions using PactNet's DSL:

```csharp
// Consumer test generates a pact file (JSON contract)
[Fact]
public async Task GetUser_ReturnsExpectedUser()
{
    // Arrange — define the expected interaction
    _pact
        .UponReceiving("a request for user by id")
        .Given("user 1 exists")
        .WithRequest(HttpMethod.Get, "/api/users/1")
        .WillRespond()
        .WithStatus(HttpStatusCode.OK)
        .WithJsonBody(new
        {
            id = 1,
            firstName = "Jane",
            lastName = "Doe"
        });

    await _pact.VerifyAsync(async ctx =>
    {
        var client = new UserApiClient(ctx.MockServerUri);
        var user = await client.GetUserAsync(1);
        Assert.Equal("Jane", user.FirstName);
    });
}
```

### Step 2: Publish Pact File to Broker

```bash
# Via Pact CLI (typically in CI pipeline)
pact-broker publish ./pacts \
    --consumer-app-version=$(git rev-parse --short HEAD) \
    --branch=$(git branch --show-current) \
    --broker-base-url=https://relias-pactbroker.reliaslearning.com
```

### Step 3: Provider Verifies Contract

```csharp
// Provider test — must use real TCP socket, not TestServer
[Fact]
public void VerifyPacts()
{
    var config = new PactVerifierConfig();
    using var provider = new PactVerifier("UserApi", config);

    provider
        .WithHttpEndpoint(new Uri("http://localhost:5000"))
        .WithPactBrokerSource(new Uri("https://relias-pactbroker.reliaslearning.com"), options =>
        {
            options.ConsumerVersionSelectors(
                new ConsumerVersionSelector { MainBranch = true }
            );
            options.EnablePending();
            // ⚠️ Do NOT use options.PublishResults() — PactNet 5.x FFI silently
            // fails to publish (pact-net#486). Publish via broker REST API instead.
            // See "PactNet 5.x FFI Publish Bug" section below.
        })
        .WithProviderStateUrl(new Uri("http://localhost:5000/provider-states"))
        .Verify();
}
```

### Step 4: Can I Deploy?

```bash
# CI gate — blocks deployment if contracts aren't verified
pact-broker can-i-deploy \
    --pacticipant=UserApi \
    --version=$(git rev-parse --short HEAD) \
    --to-environment=staging
```

## Implementation Guide

Walk engineers through these steps in order. **Do not skip ahead** — each step builds on the previous one. When mentoring, identify which step the engineer is on and guide them through it.

### Phase 1: First Contract (1 service pair)

| Step | What | Time Est. |
|------|------|-----------|
| 1.1 | Pick a consumer + provider pair with a simple REST interaction | 15 min |
| 1.2 | Add PactNet NuGet package to consumer test project | 5 min |
| 1.3 | Write first consumer test (1 endpoint, happy path) | 30 min |
| 1.4 | Run test, inspect generated pact JSON file | 10 min |
| 1.5 | Add PactNet to provider test project | 5 min |
| 1.6 | Write provider verification with real socket hosting | 45 min |
| 1.7 | Implement provider state handler | 30 min |
| 1.8 | Run provider verification against local pact file | 15 min |

### Phase 2: Pact Broker

| Step | What | Time Est. |
|------|------|-----------|
| 2.1 | Stand up local Pact Broker via Docker Compose | 20 min |
| 2.2 | Publish pact from consumer CI to broker | 15 min |
| 2.3 | Configure provider to verify from broker (not local file) | 15 min |
| 2.4 | Verify can-i-deploy works locally | 10 min |

### Phase 3: CI/CD Integration

| Step | What | Time Est. |
|------|------|-----------|
| 3.1 | Add pact publish step to consumer pipeline | 20 min |
| 3.2 | Add pact verify step to provider pipeline | 20 min |
| 3.3 | Add can-i-deploy gate before deployment | 15 min |
| 3.4 | Configure webhook for provider verification on new pacts | 30 min |

### Phase 4: Scale

| Step | What | Time Est. |
|------|------|-----------|
| 4.1 | Add more interactions to existing contract | Ongoing |
| 4.2 | Add error/edge-case scenarios | Ongoing |
| 4.3 | Roll out to additional service pairs | Per pair |
| 4.4 | Add async/messaging contracts if applicable | 1-2 hours |

## Common Mistakes to Watch For

When reviewing contract tests, check for these — they are the top reasons contract testing fails in .NET:

| Mistake | Why It's Wrong | Fix |
|---------|---------------|-----|
| Using `WebApplicationFactory` for provider verification | PactNet's Rust FFI needs a real TCP socket — tests will hang or fail silently | Host on Kestrel with `UseUrls("http://localhost:0")` for random port |
| Testing implementation details in consumer tests | Contract tests verify the interface, not internals. Don't assert on headers, timing, or internal IDs that consumers don't actually use | Only assert on fields the consumer reads |
| Missing provider states | Consumer test says `Given("user 1 exists")` but provider has no state handler → verification fails | Implement `/provider-states` endpoint that seeds test data |
| Hardcoded URLs/ports in provider verification | Tests break when port is in use | Use random port assignment and pass URI dynamically |
| Not publishing verification results back to broker | `can-i-deploy` can't work without verification results | **Do NOT use `options.PublishResults()`** — PactNet 5.x FFI silently fails (pact-net#486). Use broker REST API in CI instead (see workaround section) |
| Using `options.PublishResults()` in PactNet 5.x | FFI silently fails to POST results to broker — logs "published" but nothing arrives. Tests pass green regardless | Remove `PublishResults()` from PactNet config. Publish via broker REST API `pb:publish-verification-results` HAL link in CI workflow |
| Testing too much in contracts | Contract tests are NOT integration tests — don't test business logic, auth flows, or multi-step workflows | One interaction = one request/response pair. Keep it thin |
| Pact file checked into source control | Pact files are generated artifacts — committing them creates merge conflicts and staleness | Publish to Pact Broker instead, `.gitignore` the pacts directory |

## Provider State Pattern

This is the most commonly misunderstood part. When a consumer test says `.Given("user 1 exists")`, the provider needs a handler:

```csharp
// In provider test project — ProviderStateMiddleware.cs
public class ProviderStateMiddleware
{
    private readonly IDictionary<string, Action> _providerStates;

    public ProviderStateMiddleware(RequestDelegate next)
    {
        _providerStates = new Dictionary<string, Action>
        {
            ["user 1 exists"] = () => SeedUser(1, "Jane", "Doe"),
            ["no users exist"] = () => ClearUsers(),
        };
    }

    private void SeedUser(int id, string first, string last)
    {
        // Insert into in-memory DB or test database
    }

    private void ClearUsers()
    {
        // Clear test data
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path == "/provider-states")
        {
            var body = await new StreamReader(context.Request.Body)
                .ReadToEndAsync();
            var state = JsonSerializer.Deserialize<ProviderState>(body);

            if (_providerStates.TryGetValue(state.State, out var action))
                action();

            context.Response.StatusCode = 200;
            return;
        }

        // Pass through to actual API
        await context.Next(context);
    }
}
```

## Provider Socket Hosting Pattern

The correct way to host the provider for verification:

```csharp
public class ProviderPactFixture : IAsyncLifetime
{
    public Uri ServerUri { get; private set; } = null!;
    private IHost _host = null!;

    public async Task InitializeAsync()
    {
        _host = Host.CreateDefaultBuilder()
            .ConfigureWebHostDefaults(web => web
                .UseStartup<Startup>()
                .ConfigureServices(services =>
                {
                    // Override real DB with in-memory for testing
                    services.AddDbContext<AppDbContext>(o =>
                        o.UseInMemoryDatabase("PactTests"));
                })
                .UseUrls("http://localhost:0"))  // random available port
            .Build();

        await _host.StartAsync();

        // Capture the actual port assigned
        var server = _host.Services.GetRequiredService<IServer>();
        var addresses = server.Features.Get<IServerAddressesFeature>();
        ServerUri = new Uri(addresses!.Addresses.First());
    }

    public async Task DisposeAsync() => await _host.StopAsync();
}
```

## Async/Messaging Contract Pattern

For event-driven services (Kafka, RabbitMQ, Azure Service Bus):

```csharp
// Consumer side — define expected message
[Fact]
public void VerifyUserCreatedEvent()
{
    var pact = Pact.V4("OrderService", "UserService")
        .WithMessageInteractions();

    pact
        .ExpectsToReceive("a user created event")
        .WithJsonContent(new
        {
            eventType = "UserCreated",
            userId = Match.Type(1),
            email = Match.Type("test@example.com")
        })
        .Verify<UserCreatedEvent>(message =>
        {
            Assert.NotNull(message);
            Assert.True(message.UserId > 0);
        });
}
```

## Troubleshooting Guide

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Provider verification hangs | Using `TestServer` instead of real socket | Switch to Kestrel hosting (see pattern above) |
| "No interactions found" | Consumer test didn't run or pact file not generated | Check consumer test output, look for pact JSON in output directory |
| Provider state not found | State string mismatch between consumer and provider | Compare `.Given()` strings exactly — they're case-sensitive |
| Can-i-deploy says "no results" | Verification results not published to broker | **Do NOT use `PublishResults()`** — it silently fails in PactNet 5.x. Publish via broker REST API in CI (see workaround below) |
| PactNet logs "published" but broker shows no verification | PactNet 5.x FFI publish bug (pact-net#486) | Remove `PublishResults()`, use REST API workaround in CI |
| Broker REST API returns 404 on verification publish | Using wrong URL — `_links.self.href` is the consumer-version URL, not the publish endpoint | Use `_links."pb:publish-verification-results".href` from the HAL response (includes correct pact-version hash + metadata segment) |
| Pact verification fails on fields consumer doesn't use | Provider response has extra fields | This is OK — Pact uses "Postel's law" (be liberal in what you accept). Check if you're using strict matching by accident |
| Port conflict in CI | Hardcoded port already in use | Use `UseUrls("http://localhost:0")` for random port |
| Flaky provider tests | Test data not isolated or provider state leaks between tests | Ensure each provider state handler resets to a clean state |
| `github.sha` doesn't match head commit on PR events | PR events use merge commit SHA, not head SHA | For provider version registration, this is acceptable — push events use the correct SHA. Address if `can-i-deploy` becomes inconsistent |
| `github.ref_name` returns `1/merge` on PR events | PR events use merge ref, not source branch | Use `github.head_ref` for PR events or accept that push events provide the correct branch name |

## PactNet 5.x FFI Publish Bug (CRITICAL)

**Status:** Known bug as of PactNet 5.0.1. Issues: [pact-net#486](https://github.com/pact-foundation/pact-net/issues/486), [pact-net#401](https://github.com/pact-foundation/pact-net/issues/401).

**Symptom:** `options.PublishResults()` tells the Rust FFI to publish verification results. The FFI logs "a successful verification result has been published" — but NO version or verification appears in the Pact Broker. Tests always pass green regardless.

**Root cause:** The FFI's HTTP call to the broker either silently fails or never executes. The log message is misleading — it's emitted by the FFI as part of the verification flow, not as confirmation of actual HTTP success.

**Impact:** Without verification results in the broker, `can-i-deploy` always returns "no results" and the contract matrix stays empty.

### Workaround: Publish via Broker REST API in CI

Remove `PublishResults()` from PactNet config. Instead, add a CI workflow step that:

1. Creates the provider version with branch metadata via `PUT /pacticipants/{name}/versions/{sha}`
2. Fetches the publish URL from the broker's HAL response (`pb:publish-verification-results` link)
3. POSTs the verification result (success/failure) to that URL

**Key detail:** You MUST use the `pb:publish-verification-results` HAL link from the broker's `/latest` pact response. Do NOT construct the URL manually or use `_links.self.href` + `/verification-results` — that points to the consumer-version URL (`/version/{sha}`) which returns 404. The correct HAL link includes the pact-version hash and a metadata segment.

**PactNet config (remove PublishResults):**

```csharp
options.EnablePending();
// ⚠️ PublishResults intentionally omitted — PactNet 5.x FFI silently
// fails to publish (see pact-net#486). The CI workflow publishes
// verification results via the broker REST API instead.
```

**CI workflow step (GitHub Actions example):**

```yaml
- name: Publish verification result to broker
  if: vars.PACTBROKER_URL != ''
  env:
    PACT_BROKER_URL: ${{ vars.PACTBROKER_URL }}
    PACT_BROKER_USERNAME: ${{ vars.PACTBROKER_USERNAME }}
    PACT_BROKER_PASSWORD: ${{ secrets.PACTBROKER_PASSWORD }}
    GIT_SHA: ${{ github.sha }}
    GIT_BRANCH: ${{ github.ref_name }}
    VERIFY_RESULT: ${{ steps.verify.outcome }}
    BUILD_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
  run: |
    # Register the provider version with branch metadata
    curl -s -X PUT \
      -u "${PACT_BROKER_USERNAME}:${PACT_BROKER_PASSWORD}" \
      -H "Content-Type: application/json" \
      -d "{\"branch\":\"${GIT_BRANCH}\",\"buildUrl\":\"${BUILD_URL}\"}" \
      "${PACT_BROKER_URL}/pacticipants/${PROVIDER_NAME}/versions/${GIT_SHA}" \
      -o /dev/null -w "Create version: HTTP %{http_code}\n"

    if [ "$VERIFY_RESULT" = "success" ]; then SUCCESS=true; else SUCCESS=false; fi

    # Get the publish URL from the broker's HAL response
    PACT_RESPONSE=$(curl -s \
      -u "${PACT_BROKER_USERNAME}:${PACT_BROKER_PASSWORD}" \
      -H "Accept: application/hal+json" \
      "${PACT_BROKER_URL}/pacts/provider/${PROVIDER_NAME}/consumer/${CONSUMER_NAME}/latest")

    PUBLISH_URL=$(echo "$PACT_RESPONSE" | jq -r '._links."pb:publish-verification-results".href')

    if [ "$PUBLISH_URL" = "null" ] || [ -z "$PUBLISH_URL" ]; then
      echo "::warning title=Publish Failed::Could not find publish URL from broker"
      exit 0
    fi

    # Publish the verification result
    HTTP_CODE=$(curl -s -X POST \
      -u "${PACT_BROKER_USERNAME}:${PACT_BROKER_PASSWORD}" \
      -H "Content-Type: application/json" \
      -d "{\"success\":${SUCCESS},\"providerApplicationVersion\":\"${GIT_SHA}\",\"buildUrl\":\"${BUILD_URL}\"}" \
      "${PUBLISH_URL}" \
      -o /tmp/publish-response.json -w "%{http_code}")

    echo "Publish verification result: HTTP ${HTTP_CODE} (success=${SUCCESS})"
    if [ "$HTTP_CODE" -ge 400 ]; then
      echo "::warning title=Publish Failed::Broker returned HTTP ${HTTP_CODE}"
      cat /tmp/publish-response.json
    fi
```

**For ADO pipelines**, adapt the same curl calls into a PowerShell or bash script task.

**Verification step must use `continue-on-error: true` and `id: verify`** so the publish step can:

- Always run (even on verification failure)
- Read the outcome via `${{ steps.verify.outcome }}`
- A subsequent "Check verification result" step then fails the job if needed

### Broker REST API Endpoints Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/pacticipants/{name}/versions/{sha}` | PUT | Create/update provider version with branch metadata |
| `/pacts/provider/{P}/consumer/{C}/latest` | GET | Get latest pact (HAL response with `pb:publish-verification-results` link) |
| `{pb:publish-verification-results href}` | POST | Publish verification result (`{"success": bool, "providerApplicationVersion": "sha"}`) |

## Alternative: Specmatic (Spec-Driven)

If the team already maintains OpenAPI specs and wants zero consumer-side test authoring:

| Factor | Details |
|--------|---------|
| Approach | Contract-driven development (CDD) — OpenAPI spec IS the contract |
| No consumer tests | Tests auto-generated from OpenAPI spec |
| No pact files | Spec is the single source of truth |
| Async support | Kafka contract testing supported |
| Trade-off | Less granular consumer expectations; relies on spec completeness |

**When to prefer Specmatic over PactNet:**

- Team already has comprehensive OpenAPI specs
- No appetite for consumer-side test authoring overhead
- Want contract testing with minimal code changes

**When to prefer PactNet:**

- Need precise consumer-driven expectations
- Multiple consumers with different needs from the same provider
- Want CI/CD gating via Pact Broker's `can-i-deploy`
- Team decision/ADR already recommends it

## Other Tools (Supplementary)

| Tool | Role |
|------|------|
| **WireMock.Net** | Service virtualization — stub external APIs during integration tests. Not contract testing itself, but commonly paired with PactNet |
| **Schemathesis** | Property-based testing from OpenAPI/GraphQL specs — auto-generates edge-case requests. Complements structured contract testing |

## Relias Internal References

### Authoritative Sources

- **ADR (Decision Record):** [`08-Pact-Broker.md`](https://github.com/relias-engineering/decision-records-system/blob/main/platform-foundations/backend/08-Pact-Broker.md) — Official architecture decision. Contains broker URL, credentials, deployment strategy.
- **Pact Broker Config Repo:** [`relias-engineering/pact-broker`](https://github.com/relias-engineering/pact-broker) — Docker-compose for local dev, README lists services under contract.
- **Confluence: CDC Recommendations:** [Consumer-Driven Contract Testing Recommendations](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/3780411481/Consumer-Driven+Contract+Testing+Recommendations) — Architecture team's full recommendation (PactNet, Pact Broker, Pact CLI)
- **Confluence: Pact Broker Deployment ADR:** [Contract Testing – Pact Broker Deployment for Target](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/4328882228/Contract+Testing+-+Pact+Broker+Deployment+for+Target) — Per-environment deployment plan

### Active Service Repos with Contract Tests (RPLAT-19223)

- [`relias-engineering/grc-library-service`](https://github.com/relias-engineering/grc-library-service) — Producer + Consumer ([PR #64](https://github.com/relias-engineering/grc-library-service/pull/64))
- [`relias-engineering/policy-manager`](https://github.com/relias-engineering/policy-manager) — Producer ([PR #243](https://github.com/relias-engineering/policy-manager/pull/243))
- [`relias-engineering/content-scheduler`](https://github.com/relias-engineering/content-scheduler) — Consumer ([PR #193](https://github.com/relias-engineering/content-scheduler/pull/193))
- [`relias-engineering/content-library-service`](https://github.com/relias-engineering/content-library-service) — Consumer ([PR #599](https://github.com/relias-engineering/content-library-service/pull/599))
- [`relias-engineering/content-engagement-service`](https://github.com/relias-engineering/content-engagement-service) — Consumer ([PR #338](https://github.com/relias-engineering/content-engagement-service/pull/338))

### POC and Reference Repos

- [`relias-engineering/contract-testing`](https://github.com/relias-engineering/contract-testing) — **Primary POC repo** with working GHA workflows (consumer + provider CI), PactNet 5.x FFI publish bug workaround, kill switch, and break-contract demo scenario. Uses org-level vars/secrets. Created by @fhemmer (2026-05-29).
- [`relias-engineering/best-practices`](https://github.com/relias-engineering/best-practices) — `Contract Testing/` folder with Users.API PactNet consumer/provider example
- [`relias-engineering/slide-decks`](https://github.com/relias-engineering/slide-decks) — [`pact-contract-testing-is-it-worth-it.md`](https://github.com/relias-engineering/slide-decks/blob/main/decks/pact-contract-testing-is-it-worth-it.md) — Marp presentation deck
- [Best Practices Repo - PactNet POC (Bitbucket)](https://bitbucket.org/relias/relias-best-practices/pull-requests/39) — Original self-contained PactNet consumer/provider POC
- [RLMS Website JavaScript POC (Bitbucket)](https://bitbucket.org/relias/rlms-website/branch/rthomas/develop/RLPD-49997_pact_proof-of_concept_tests) — Frontend consumer POC
- [Assessment Service Consumer POC (Bitbucket)](https://bitbucket.org/relias/assessmentservice/branch/rthomas/develop/RLPD-49996_pact_api_to_api_consumer_example_test) — API-to-API consumer example

## External Resources

- [PactNet GitHub](https://github.com/pact-foundation/pact-net) — .NET implementation
- [Pact Broker Docker](https://github.com/pact-foundation/pact-broker-docker/tree/master) — Self-hosted broker
- [Pact CLI Docs](https://docs.pact.io/implementation_guides/cli) — Publishing, verification, can-i-deploy
- [Pact Workshop .NET Core](https://github.com/DiUS/pact-workshop-dotnet-core-v3/) — Step-by-step tutorial
- [Specmatic GitHub](https://github.com/znsio/specmatic) — OpenAPI-based contract testing
- [Specmatic C# Sample](https://github.com/znsio/specmatic-order-bff-csharp) — .NET sample with Docker
- [Microsoft CDC Testing Playbook](https://microsoft.github.io/code-with-engineering-playbook/automated-testing/cdc-testing/) — Microsoft's engineering guidance
- [Pact Docs](https://docs.pact.io/) — Official Pact documentation
- [PactFlow](https://pactflow.io/) — Managed Pact Broker (commercial, bi-directional support)
- [Pact AI Tools](https://docs.pact.io/ai_tools/installation) — Official Pact skills, MCP server, and Kiro agent for AI-assisted contract testing
- [Pact Nirvana Guide](https://docs.pact.io/pact_nirvana) — CI/CD maturity levels (Bronze → Diamond)

## Pact Broker — Production Instance

**URL:** [`https://relias-pactbroker.reliaslearning.com/`](https://relias-pactbroker.reliaslearning.com/)
**ADR:** `relias-engineering/decision-records-system/platform-foundations/backend/08-Pact-Broker.md` (status: accepted)
**Config repo:** `relias-engineering/pact-broker` (docker-compose for local dev, README lists services under contract)

### Credentials

| Access | Username | Password |
|--------|----------|----------|
| Read/Write | `pactbroker` | Stored in Azure Key Vault: [`relias-pactbroker-kv-001`](https://portal.azure.com/#@ReliasAzureCloud.onmicrosoft.com/resource/subscriptions/e4ab9a4c-5333-4e52-a0e3-fd16c0c8e2f5/resourceGroups/relias-pactbroker-rg/providers/Microsoft.KeyVault/vaults/relias-pactbroker-kv-001/overview) (subscription `e4ab9a4c-5333-4e52-a0e3-fd16c0c8e2f5`, RG `relias-pactbroker-rg`) |
| Read-Only | `pactbrokerRO` | `Hg&#ePysE2Hst8` |

### Services Under Contract (RPLAT-19223)

| Service | Role | Repo | PR |
|---------|------|------|----|
| GRC Library Service | Producer + Consumer | `relias-engineering/grc-library-service` | [#64](https://github.com/relias-engineering/grc-library-service/pull/64) |
| Policy Manager | Producer | `relias-engineering/policy-manager` | [#243](https://github.com/relias-engineering/policy-manager/pull/243) |
| Content Scheduler | Consumer | `relias-engineering/content-scheduler` | [#193](https://github.com/relias-engineering/content-scheduler/pull/193) |
| Content Library Service | Consumer | `relias-engineering/content-library-service` | [#599](https://github.com/relias-engineering/content-library-service/pull/599) |
| Content Engagement Service | Consumer | `relias-engineering/content-engagement-service` | [#338](https://github.com/relias-engineering/content-engagement-service/pull/338) |

### Environment Deployment (ADR)

| Environment | Purpose |
|-------------|---------|
| Dev1/Dev2 | Development contract validation |
| Staging | Pre-production gate |
| Production (US, CA, DE, UK) | Production contract verification |

Each broker instance provides:

- Centralized pact file storage and versioning
- `can-i-deploy` CI/CD gate
- Service dependency visualization
- Webhook-triggered provider verification

### ⚠️ Duplicate Repo — To Be Deleted

`relias-engineering/contract-testing-server` is a **duplicate** POC broker deployment (Bicep IaC → Azure Container Apps in `relias-int-svc-rg`). It is NOT the real broker. Needs cleanup: delete the repo AND its Azure resources.

## Organizational Context (from #contract-testing Slack channel)

**Slack channel:** [`#contract-testing`](https://relias-engineering.slack.com/archives/C0ATZFS4SBY) (created 2026-04-20 by @jbuda)

### Key Contacts (by Slack handle)

| Handle | Role in Contract Testing |
|--------|-------------------------|
| @jbuda | Created channel. Built PactNet POC for GRC backend Service Bus messages. Running Diamond-level `can-i-deploy` (with `--dry-run`). Drove RPLAT-19223 PRs across 5 repos. |
| @grufino | Deployed production Pact Broker ~1 year ago. Authored the ADR. Provided Pact AI tools link (skills, MCP server, Kiro agent). Raised onboarding/training concerns. |
| @fhemmer | Created the `contract-testing` POC repo. Pushing for AI skill + reference repo approach. Proposed chapter meeting demos. Reviewed pactbroker version bump PR. |
| @ganthony | Advocated including contract testing in Golden Path template (health/live check contracts). Suggested rollout via SDC, AI, and Quality Chapter meetings. Proposed scorecards for adoption tracking before hard-gating. |
| @bhalterman | Concerned about scaffolding cleanup burden in Golden Path. Suggested giving teams time to reach min threshold before enforcement. |
| @mapaul | Argued Golden Path inclusion forces conscious decision to implement or remove. |
| @cmutaba | New to the channel, expressed enthusiasm. |

### Agreed Strategy (as of 2026-04-29)

1. **Reference repo + AI skill** as the primary onboarding package (@fhemmer's proposal — agreed)
2. **Demo sessions** at chapter meetings: SDC, AI Chapter, Quality Chapter (@ganthony's suggestion — agreed)
3. **Scorecards** for adoption tracking before hard-gating (@ganthony/@bhalterman — agreed)
4. **Golden Path**: Debated. Consensus leaning toward adding `can-i-deploy` CI/CD step (not full test scaffolding) since no dummy contracts to clean up. Template wouldn't add consumer/producer tests — just pipeline wiring.
5. **Pact Nirvana level**: Start at **Gold level** (practical starting point). Diamond's Verifier pipeline has scaling cost concerns (excessive pipeline triggers as services grow). @jbuda's PRs target Diamond with `--dry-run` as aspirational.
6. **Pact Broker version**: Updated to `2.138.0-pactbroker2.119.0` (from `2.107.0.1`) — [Bitbucket PR #9](https://bitbucket.org/relias/pactbroker/pull-requests/9)
7. **Deployment philosophy**: Consumers deploy first; producers deploy only after compatibility verified (reduces data loss/runtime breakage risk)
8. **Contracts are versioned artifacts**: Multiple versions may exist simultaneously (dev, staging, prod, PR) — not a single "current" definition

### Known Concerns (from Slack discussion)

| Concern | Raised By | Status |
|---------|-----------|--------|
| **Cross-repo blast radius** — badly implemented contracts can block deployments across multiple repos | @grufino | Open — needs strong onboarding/training |
| **Knowledge gap** — devs won't know where to look when pipeline fails | @grufino | Open — Pact Broker UI helps but needs training |
| **Organizational buy-in** — ADR says 100% coverage for 2+ years but adoption is near-zero | @ganthony/@jbuda | Open — need enforcement mechanism |
| **Pact Broker is mission-critical** — once wired into CI/CD, broker downtime blocks all deployments org-wide | @jbuda/@fhemmer (Apr 29 meeting) | Open — needs backup/recovery strategy, redundancy planning |
| **Shared NuGet package already provides compile-time safety** — raises ROI questions for runtime contract testing | @jbuda (Apr 29 meeting) | Open — contract testing catches runtime/schema drift that compile-time can't |
| **ADR may be outdated** — existing architecture decision record may be partially incorrect | @jbuda/@fhemmer (Apr 29 meeting) | Open — needs Architecture Review Board revalidation |
| **Golden Path scaffolding cleanup** — adding templates means teams must clean up examples | @bhalterman | Resolved — only add CI/CD wiring, not test scaffolding |
| **Pact Broker version** — old version can't parse v4 pact specs | @jbuda | Resolved — version bump PR submitted |
| **PactNet 5.x FFI silently fails to publish verification results** — `PublishResults()` logs success but HTTP never reaches broker | @fhemmer (May 29 POC) | **Resolved** — workaround: publish via broker REST API in CI workflow. See "PactNet 5.x FFI Publish Bug" section. Issues: pact-net#486, pact-net#401 |
| **Pact Broker deployment** — deployed via ADO pipeline (definition 427) in Bitbucket `relias/pactbroker` | @grufino | Documented |

### Pact AI Tools (mentioned by @grufino)

Pact provides official AI integration: skills, MCP server, and an agent called **Kiro**.
Docs: [https://docs.pact.io/ai_tools/installation](https://docs.pact.io/ai_tools/installation)

### Infrastructure Notes

- **Pact Broker is deployed from Bitbucket** (`relias/pactbroker`), NOT GitHub — uses ADO pipeline [definition 427](https://dev.azure.com/ReliasEngineering/PlatformDevelopment/_build?definitionId=427)
- **Environments seeded in Pact Broker** by @jbuda: matches deployment environments for `can-i-deploy` checks
- **Docker image version**: `pactfoundation/pact-broker:2.138.0-pactbroker2.119.0` (upstream changed tagging convention from simple semver)

### Meeting: Contract Testing Chat (2026-04-29, Franz Hemmer + Jeff Buda)

**Recording:** [Contract Testing Chat-20260429](https://reliaslearning-my.sharepoint.com/personal/fhemmer_relias_com/Documents/Recordings/Contract%20Testing%20Chat-20260429_130340-Meeting%20Recording.mp4?web=1)

**Key technical clarifications:**

- Current contracts cover **Azure Service Bus message payloads** (async), NOT HTTP REST APIs
- Contracts were generated **manually** from latest source code and uploaded to broker — no CI/CD automation yet
- Shared NuGet packages already provide **compile-time safety** — contract testing adds **runtime/schema drift detection** that compile-time cannot catch
- Pact deployment philosophy: **consumers deploy first**, producers only after compatibility verified (reduces data loss risk)

**Strategy decisions:**

- **Gold-level** Pact Nirvana is the practical starting point (Diamond has scaling cost concerns with excessive pipeline triggers)
- Platinum/Diamond introduce a **Verifier pipeline** (auto-validates compatibility across producer/consumer ecosystem) — revisit once adoption matures
- Contracts are **versioned artifacts** (dev, staging, prod, PR branches) — not a single "current" definition
- Existing ADR needs revalidation — may be outdated or partially incorrect

**Infrastructure risk:**

- Pact Broker becomes **mission-critical** once wired into CI/CD — broker downtime = org-wide deployment freeze
- Requires: backup/recovery strategy, ongoing maintenance, potential redundancy planning

**Action items (Franz):**

1. Create Confluence onboarding FAQ for contract testing concepts
2. Engage Architecture Review Board to revalidate org-wide buy-in
3. Consult Clark (legacy deployment manager) for deployment insights
4. Share findings with Malia to determine proceed/validate decision
5. Plan Pact Broker backup & recovery strategy before broader rollout

### Meeting: GRC Pilot Kickoff (2026-05-27)

**Attendees:** Malia Paul (organizer), Jeff Buda, Franz Hemmer, Warren Sutherland (GRC team lead), Nick Peterson, Giovanni Rufino

**Recording:** `Contract Testing - GRC Pilot-20260527` (Teams recording, VTT transcript in skill assets)

**Context:** First working meeting with the GRC team to align on next steps for merging Jeff's existing PRs and getting contract testing live in Policy Manager and GRC Library Service.

**Key decisions:**

- **Start at Gold-level (warm)** — pipeline logs results as **warning only** (yellow ADO icon), does NOT block deployments
- **Policy Manager PR (#243)** is the recommended starting point — low risk, no production code changes, just pipeline wiring + contract test assembly
- **Gradual escalation plan:** warning → monitoring → gating (once team understands failure scenarios)
- **Working session approach** — Franz/Gio/Jeff collaborate together vs. hand-off
- **Org-level "kill switch" variable** proposed to disable contract testing org-wide if broker goes down (prevents SonarCloud-style outage impact)
- **Repo-level variable override** as team-level bypass option (GitHub variable precedence: repo overrides org)
- **Capitalizable work** — Malia confirmed user stories for this can be capitalized

**Warren's approval:**

- On board if basic MVP with logging runs by **end of quarter**
- Capacity caveat: Jeff/Gio can help, but team has competing priorities (Policy Plan cleanup, Magic Strings)
- No additional buy-in needed — Policy Manager and GRC repos are within Warren's area of responsibility

**Gio's critical points:**

- If contract gating is enabled later, teams **must** know how to use Pact (can't opt out of learning)
- Pact Broker shows "broken" if producer deploys before consumer — deployment order matters
- This is fundamentally an **upskilling** challenge, not just a tooling challenge
- "Contract matrix" is built into PactNet for per-environment version tracking

**Nick Peterson:**

- Playing assist role in working group meetings
- Will review PRs (on his to-do list)

**Pipeline risk mitigation details (Jeff):**

- New contract testing stages use `continueOnError: true` — pipeline never blocks on contract failures
- PR pipeline (`policy-manager-pr.yaml`) is completely safe to experiment on — no deployment side effects
- Build pipeline: worst case is a warning icon, never a red/blocked status
- Secrets already set at repo level; org-level move enables cross-repo consistency

**Value positioning (for socializing):**

- Contract testing = **AI guardrail** — enables more AI-generated code with confidence
- Enables more **frequent and confident deployments** (deployment bottleneck reduction)
- Franz: "The more autonomous goals we have, the more guardrails we need"

**Action items:**

1. ✅ Franz: Create org-level variables/secrets + kill switch — **DONE (2026-05-29)**
2. Jeff: Write 2 user stories (Policy Manager + GRC) in Jira
3. Jeff: Refresh memory on PRs, run pipeline on branch to validate
4. Franz: Schedule working sessions for next week with Jeff/Gio
5. Everyone: Review Jeff's PRs async (linked in meeting chat) — don't wait for next meeting
6. Malia: Schedule follow-up meeting in 1-2 weeks
7. Franz + Malia: Brainstorm roadmap items (debugging broken contracts, downstream scenarios)
8. Franz: Build FAQ in contract-testing repo as issues surface

## NuGet Packages

```xml
<!-- Consumer and Provider tests -->
<PackageReference Include="PactNet" Version="5.*" />

<!-- For service virtualization (optional) -->
<PackageReference Include="WireMock.Net" Version="1.*" />
```

## Implement in Your Repo

**This section is the actionable guide for when a developer invokes `/contract-testing implement this in my repo`.** Follow these steps in order. Adapt to the repo's structure, service names, and CI system.

### Step 0: Assess the Repo

Before writing any code, survey the repository:

1. **Find service projects:** `glob **/*.csproj` — identify the main service project(s)
2. **Find existing test projects:** `glob **/Tests/**/*.csproj` or `glob **/*.Tests.csproj`
3. **Identify the service role:**
   - **Consumer** — calls other services via `HttpClient`, `IHttpClientFactory`, or typed clients. Search for: `HttpClient`, `IHttpClientFactory`, `Refit`, `RestSharp`
   - **Provider** — exposes API endpoints consumed by other services. Has `Controller` or `MinimalApi` endpoints
   - **Both** — many services are both consumer AND provider
4. **Find CI pipeline:** Look for `.azuredevops/pipelines/*.yml` (ADO) or `.github/workflows/*.yml` (GHA)
5. **Check for existing PactNet usage:** `grep -r "PactNet" --include="*.csproj"` and `grep -r "PactBrokerConfig" --include="*.cs"`
6. **Identify the service's Pact participant name:** Usually matches the service name as it appears in deployment. Ask the developer if unclear.

**Ask the developer:**

- Which role does this service play? (Consumer / Provider / Both)
- What is the participant name for the Pact Broker? (e.g., "Content Scheduler Messaging")
- Which service(s) does it interact with? (for consumer: which provider? for provider: which consumers?)
- What are the key API endpoints or messages involved?

### Step 1: Create Contract Test Project

Create a dedicated contract test project. Do NOT mix contract tests with unit or integration tests.

```powershell
# From the repo root
dotnet new xunit -n YourService.Contract.Tests -o tests/YourService.Contract.Tests
```

Edit the `.csproj` to add PactNet and reference the service project:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PactNet" Version="5.*" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
    <PackageReference Include="xunit" Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\YourService\YourService.csproj" />
  </ItemGroup>
</Project>
```

**Add the project to the solution:** `dotnet sln add tests/YourService.Contract.Tests`

### Step 2: Create PactBrokerConfig Helper

This is the env-var-driven config helper. Every service uses the same pattern:

```csharp
namespace YourService.Contract.Tests.Helpers;

/// <summary>
/// Centralised Pact Broker configuration. Values are read from environment
/// variables so CI can inject real broker credentials.
/// </summary>
public static class PactBrokerConfig
{
    public static string PactDir =>
        Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory, "..", "..", "..", "pacts"));

    public static string? BrokerUrl =>
        Environment.GetEnvironmentVariable("PACT_BROKER_URL");

    public static string? BrokerUsername =>
        Environment.GetEnvironmentVariable("PACT_BROKER_USERNAME");

    public static string? BrokerPassword =>
        Environment.GetEnvironmentVariable("PACT_BROKER_PASSWORD");

    public static string GitCommitSha =>
        Environment.GetEnvironmentVariable("GIT_COMMIT_SHA") ?? "local";

    public static string GitBranch =>
        Environment.GetEnvironmentVariable("GIT_BRANCH") ?? "local";

    public static bool IsBrokerConfigured =>
        !string.IsNullOrWhiteSpace(BrokerUrl)
        && !string.IsNullOrWhiteSpace(BrokerUsername)
        && !string.IsNullOrWhiteSpace(BrokerPassword);
}
```

### Step 3a: Consumer Test (if this service is a consumer)

The consumer test defines what this service expects from the provider API.

**Key rules:**

- One test class per provider
- One test per interaction (endpoint + scenario)
- Use the consumer's own DTO models, NOT the provider's
- Only assert on fields the consumer actually reads

```csharp
using System.Net;
using PactNet;

namespace YourService.Contract.Tests.Consumer;

public class SomeProviderApiConsumerTests
{
    private readonly IPactBuilderV4 _pactBuilder;

    public SomeProviderApiConsumerTests()
    {
        var pact = Pact.V4(
            "YourService",           // ← Consumer participant name
            "SomeProviderService",   // ← Provider participant name
            new PactConfig { PactDir = PactBrokerConfig.PactDir });
        _pactBuilder = pact.WithHttpInteractions();
    }

    [Fact]
    [Trait("Category", "Contract")]
    public async Task GetResource_WhenExists_ReturnsExpectedShape()
    {
        _pactBuilder
            .UponReceiving("a request to get a resource")
            .Given("resource 1 exists")
            .WithRequest(HttpMethod.Get, "/api/resources/1")
            .WillRespond()
            .WithStatus(HttpStatusCode.OK)
            .WithHeader("Content-Type", "application/json; charset=utf-8")
            .WithJsonBody(new
            {
                id = 1,
                name = "Example"
            });

        await _pactBuilder.VerifyAsync(async ctx =>
        {
            // Use the REAL client class from the consumer project
            var client = new YourApiClient(ctx.MockServerUri);
            var result = await client.GetResourceAsync(1);
            Assert.NotNull(result);
            Assert.Equal("Example", result.Name);
        });
    }
}
```

### Step 3b: Provider Test (if this service is a provider)

The provider test verifies that this service's actual API matches what consumers expect.

**Critical: PactNet CANNOT use `WebApplicationFactory` or `TestServer`.** The Rust FFI internals require a real TCP socket. Use Kestrel hosting.

**Create the fixture:**

```csharp
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;

namespace YourService.Contract.Tests.Provider;

public class YourServiceFixture : IAsyncLifetime
{
    public Uri ServerUri { get; private set; } = null!;
    private IHost _host = null!;

    public async Task InitializeAsync()
    {
        _host = Host.CreateDefaultBuilder()
            .ConfigureWebHostDefaults(web =>
            {
                web.UseUrls("http://127.0.0.1:0"); // Random available port
                web.ConfigureServices(services =>
                {
                    // Register your controllers and DI
                    services.AddControllers()
                        .AddApplicationPart(typeof(YourController).Assembly);
                    // Override real dependencies with test doubles
                    services.AddSingleton<IYourRepository, InMemoryTestRepository>();
                });
                web.Configure(app =>
                {
                    app.UseMiddleware<ProviderStateMiddleware>();
                    app.UseRouting();
                    app.UseEndpoints(endpoints => endpoints.MapControllers());
                });
            })
            .Build();

        await _host.StartAsync();
        var server = _host.Services.GetRequiredService<IServer>();
        var addresses = server.Features.Get<IServerAddressesFeature>();
        ServerUri = new Uri(addresses!.Addresses.First());
    }

    public async Task DisposeAsync()
    {
        await _host.StopAsync();
        _host.Dispose();
    }
}
```

**Create the provider state middleware:**

```csharp
using Microsoft.AspNetCore.Http;
using System.Text.Json;

namespace YourService.Contract.Tests.Provider;

public class ProviderStateMiddleware(RequestDelegate next)
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    // Map provider state strings to data-seeding actions
    private readonly Dictionary<string, Action> _providerStates = new()
    {
        ["resource 1 exists"] = () => { /* seed test data */ },
        ["no resources exist"] = () => { /* clear test data */ },
    };

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path.StartsWithSegments("/provider-states"))
        {
            var body = await new StreamReader(context.Request.Body).ReadToEndAsync();
            var state = JsonSerializer.Deserialize<ProviderStateRequest>(body, JsonOptions);

            if (state?.State is not null && _providerStates.TryGetValue(state.State, out var action))
                action();

            context.Response.StatusCode = 200;
            return;
        }

        await next(context);
    }

    private sealed class ProviderStateRequest
    {
        public string? State { get; set; }
    }
}
```

**Create the verification test:**

```csharp
using PactNet.Verifier;
using Xunit.Abstractions;

namespace YourService.Contract.Tests.Provider;

public class YourServiceProviderTests(YourServiceFixture fixture, ITestOutputHelper output)
    : IClassFixture<YourServiceFixture>
{
    [Fact]
    [Trait("Category", "Contract")]
    public void VerifyPacts()
    {
        var config = new PactVerifierConfig
        {
            Outputters = [new XUnitOutput(output)]
        };

        using var verifier = new PactVerifier("YourProviderService", config);
        verifier.WithHttpEndpoint(fixture.ServerUri);

        IPactVerifierSource source;

        if (PactBrokerConfig.IsBrokerConfigured)
        {
            source = verifier.WithPactBrokerSource(
                new Uri(PactBrokerConfig.BrokerUrl!), options =>
            {
                options.BasicAuthentication(
                    PactBrokerConfig.BrokerUsername!,
                    PactBrokerConfig.BrokerPassword!);
                options.ConsumerVersionSelectors(
                    new ConsumerVersionSelector { MainBranch = true },
                    new ConsumerVersionSelector { MatchingBranch = true },
                    new ConsumerVersionSelector { DeployedOrReleased = true }
                );
                options.EnablePending();
                // ⚠️ PublishResults intentionally omitted — PactNet 5.x FFI silently
                // fails to publish (see pact-net#486). The CI workflow publishes
                // verification results via the broker REST API instead.
                // See "PactNet 5.x FFI Publish Bug" section.
            });
        }
        else
        {
            var pactFile = Path.Combine(PactBrokerConfig.PactDir,
                "ConsumerName-YourProviderService.json");
            source = verifier.WithFileSource(new FileInfo(pactFile));
        }

        source
            .WithProviderStateUrl(new Uri(fixture.ServerUri, "/provider-states"))
            .Verify();
    }
}
```

### Step 4: Wire CI/CD Pipeline

**For GitHub Actions**, the POC repo [`relias-engineering/contract-testing`](https://github.com/relias-engineering/contract-testing) has working reference workflows:

- **Consumer:** `.github/workflows/consumer-ci.yml` — publishes pacts to broker
- **Provider:** `.github/workflows/provider-ci.yml` — verifies pacts, publishes results via REST API workaround, advisory `can-i-deploy`, record-deployment

**Critical:** The provider workflow includes a REST API step to publish verification results because PactNet 5.x `PublishResults()` silently fails. See "PactNet 5.x FFI Publish Bug" section. The verification step must use `continue-on-error: true` and `id: verify` so the publish step can always run and read the outcome.

**For Azure DevOps** (primary at Relias), adapt the same patterns into ADO pipeline stages. Copy from the POC repo's `pipelines/` directory:

- **Consumer:** Use `pipelines/consumer-ci.yml` as reference — add the ContractTests stage
- **Provider:** Use `pipelines/provider-ci.yml` as reference — add the ContractVerification stage
- **Post-deploy:** Use `pipelines/templates/pact-record-deployment.yml` to record deployments

**GitHub org-level variables/secrets** (already configured for `relias-engineering`):

| Variable/Secret | Value | Type |
|-----------------|-------|------|
| `PACTBROKER_URL` | `https://relias-pactbroker.reliaslearning.com/` | Org variable (all repos) |
| `PACTBROKER_USERNAME` | `pactbroker` | Org variable (all repos) |
| `PACTBROKER_USERNAME_R` | `pactbrokerRO` | Org variable (all repos) |
| `PACTBROKER_PASSWORD` | (from Key Vault) | Org secret (all repos) |
| `PACTBROKER_PASSWORD_R` | (read-only password) | Org secret (all repos) |
| `PACTBROKER_ENABLED` | `true` | Org variable — kill switch (set to `false` to disable) |

**ADO pipeline variables** (set via Variable Group or pipeline settings):

| Variable | Value | Secret? |
|----------|-------|---------|
| `PACT_BROKER_URL` | `https://relias-pactbroker.reliaslearning.com` | No |
| `PACT_BROKER_USERNAME` | `pactbroker` | Yes |
| `PACT_BROKER_PASSWORD` | From Key Vault `relias-pactbroker-kv-001` | Yes |

**Key CI/CD patterns:**

- All contract testing steps gracefully skip when credentials aren't configured
- Use `--filter "Category=Contract"` to run only contract tests
- `can-i-deploy` in CI should use `--dry-run` (advisory). The real gate goes in the deploy pipeline
- `record-deployment` runs AFTER successful deployment, not in CI
- Pipeline examples target **Linux hosted agents** (`vmImage: ubuntu-latest`)
- **Kill switch:** Org-level `PACTBROKER_ENABLED` variable. Set to `false` to disable all contract testing org-wide (e.g., if broker goes down). Repos can override with a repo-level variable.

### Step 5: Add .gitignore Entry

Ensure generated pact files are not committed:

```gitignore
# Generated pact contract files
pacts/
```

### Step 6: Multi-Repo Considerations

Most Relias services are in separate repositories. Key differences from the mono-repo POC:

| Concern | Mono-Repo (POC) | Multi-Repo (Production) |
|---------|-----------------|------------------------|
| Pact source for provider | Local file from disk | Pact Broker (via `WithPactBrokerSource`) |
| Pact publishing | Optional (can use file) | Required — consumer CI must publish to broker |
| Provider state coordination | Shared code | State strings documented in contract; teams must coordinate |
| `can-i-deploy` | Against local broker | Against production broker with real environment data |
| Versioning | Git SHA from same repo | Git SHA from each repo independently |

**Consumer repo responsibilities:**

1. Generate pact files via consumer tests
2. Publish pacts to broker with version (git SHA) and branch
3. Run advisory `can-i-deploy` in CI

**Provider repo responsibilities:**

1. Verify pacts from broker (not local files)
2. Publish verification results back to broker
3. Run `can-i-deploy` gate before deployment
4. `record-deployment` after successful deployment

### Implementation Checklist

Before reporting success, verify ALL applicable items:

- [ ] Contract test project created and added to solution
- [ ] `PactBrokerConfig.cs` helper present
- [ ] Tests have `[Trait("Category", "Contract")]` for filtering
- [ ] Consumer tests: one test per interaction, using real client class
- [ ] Provider tests: real TCP socket hosting (NOT `WebApplicationFactory`)
- [ ] Provider tests: `ProviderStateMiddleware` handles all consumer states
- [ ] Provider tests: broker verification publishes results with version + branch
- [ ] `.gitignore` includes `pacts/`
- [ ] CI pipeline stage added with graceful skip when creds missing
- [ ] Build succeeds with zero errors
- [ ] Tests pass locally (in local/file mode)

## ALWAYS: Log This Interaction

After any meaningful interaction, append to `contract-testing/History/{YYYY-MM-DD}.md`:

```markdown
## HH:MM - {Action Taken}
{One-line summary}
```

Get the timestamp with `Get-Date -Format "HH:mm"` — never guess.
