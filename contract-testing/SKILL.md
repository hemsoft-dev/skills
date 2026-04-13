---
name: contract-testing
description: "V1.0 - Expert in contract testing for .NET/C# microservices using PactNet (consumer-driven) and Specmatic (spec-driven). Covers Pact Broker deployment, CI/CD gating, async messaging contracts, and OpenAPI-based approaches. Use when implementing, reviewing, or discussing contract testing strategy."
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
            firstName = "Franz",
            lastName = "Rufino"
        });

    await _pact.VerifyAsync(async ctx =>
    {
        var client = new UserApiClient(ctx.MockServerUri);
        var user = await client.GetUserAsync(1);
        Assert.Equal("Franz", user.FirstName);
    });
}
```

### Step 2: Publish Pact File to Broker

```bash
# Via Pact CLI (typically in CI pipeline)
pact-broker publish ./pacts \
    --consumer-app-version=$(git rev-parse --short HEAD) \
    --branch=$(git branch --show-current) \
    --broker-base-url=https://pact-broker.example.com
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
        .WithPactBrokerSource(new Uri("https://pact-broker.example.com"), options =>
        {
            options.ConsumerVersionSelectors(
                new ConsumerVersionSelector { MainBranch = true }
            );
            options.PublishResults(gitCommitSha);
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
| Not publishing verification results back to broker | `can-i-deploy` can't work without verification results | Add `options.PublishResults(gitSha)` in provider verification |
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
            ["user 1 exists"] = () => SeedUser(1, "Franz", "Rufino"),
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
| Can-i-deploy says "no results" | Verification results not published to broker | Add `options.PublishResults()` with git SHA |
| Pact verification fails on fields consumer doesn't use | Provider response has extra fields | This is OK — Pact uses "Postel's law" (be liberal in what you accept). Check if you're using strict matching by accident |
| Port conflict in CI | Hardcoded port already in use | Use `UseUrls("http://localhost:0")` for random port |
| Flaky provider tests | Test data not isolated or provider state leaks between tests | Ensure each provider state handler resets to a clean state |

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

- [Consumer-Driven Contract Testing Recommendations](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/3780411481/Consumer-Driven+Contract+Testing+Recommendations) — Architecture team's full recommendation (PactNet, Pact Broker, Pact CLI)
- [Pact Broker Deployment for Target](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/4328882228/Contract+Testing+-+Pact+Broker+Deployment+for+Target) — ADR for Pact Broker deployment per environment (Dev1, Dev2, Staging, Prod)
- [Best Practices Repo - PactNet POC](https://bitbucket.org/relias/relias-best-practices/pull-requests/39) — Self-contained PactNet consumer/provider POC
- [RLMS Website JavaScript POC](https://bitbucket.org/relias/rlms-website/branch/rthomas/develop/RLPD-49997_pact_proof-of_concept_tests) — Frontend consumer POC
- [Assessment Service Consumer POC](https://bitbucket.org/relias/assessmentservice/branch/rthomas/develop/RLPD-49996_pact_api_to_api_consumer_example_test) — API-to-API consumer example

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

## Pact Broker Deployment (Relias ADR)

The architecture team's ADR specifies deploying Pact Broker per environment:

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

## NuGet Packages

```xml
<!-- Consumer and Provider tests -->
<PackageReference Include="PactNet" Version="5.*" />

<!-- For service virtualization (optional) -->
<PackageReference Include="WireMock.Net" Version="1.*" />
```

## ALWAYS: Log This Interaction

After any meaningful interaction, append to `contract-testing/History/{YYYY-MM-DD}.md`:

```markdown
## HH:MM - {Action Taken}
{One-line summary}
```

Get the timestamp with `Get-Date -Format "HH:mm"` — never guess.
