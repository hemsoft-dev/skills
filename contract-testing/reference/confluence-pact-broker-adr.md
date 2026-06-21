# Confluence Reference: Pact Broker Deployment for Target

**Source**: [Contract Testing - Pact Broker Deployment for Target](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/4328882228/Contract+Testing+-+Pact+Broker+Deployment+for+Target)
**Space**: Relias Platform Modernization
**Last Updated**: 2024-10-31
**Status**: Proposed (ADR)

---

## Architecture Decision Record (ADR)

### Context

To prevent integration issues from incompatible service interactions across environments, implementing contract testing with Pact. Deploying a Pact Broker server configured for each environment (Dev1, Dev2, Staging, Production - US, CA, DE, UK) to centralize contract management. Using PactNet libraries within .NET services to define and verify consumer/provider expectations.

**Goal**: Detect and address contract breaches early in the development cycle.

**Reference**: <https://docs.pactflow.io/docs/user-interface/settings/environments>

### Key Terms

| Term | Definition |
|------|-----------|
| **Pact Broker** | Centralized repository that stores, shares, and manages versioned contracts |
| **Pact CLI** | CLI tool for publishing contracts, triggering verification, retrieving contracts |
| **PactNet** | .NET library for creating and verifying contracts within .NET services |

### Key Drivers

1. **Enable Independent Service Evolution**: Teams deploy independently without fear of breaking downstream dependencies
2. **Shift-Left Testing for Faster Feedback**: Identify contract inconsistencies early, prevent costly integration issues
3. **Foster Cross-Team Collaboration**: Shared understanding between consumer and provider teams

### Decision

Adopt Contract Testing with Pact as core strategy for API compatibility between services.

### Compelling Reasons

- **Empower Consumer-Driven Development**: Focus on consumer expectations safeguards against disruptive provider changes
- **Accelerate Development with Early Feedback**: Pact tests run early and often
- **Unlock Independent Deployments**: Verify contract adherence before deploying

### Anticipated Outcomes

1. **Enhanced Test Coverage**: Contract testing strengthens strategy by targeting service interactions, complementing unit and integration tests
2. **Continuous Contract Validation**: Integrating Pact into CI/CD ensures compatibility is verified with each build
3. **Centralized Contract Management**: Pact Broker per environment provides transparency and collaboration

### Environment Deployment Plan

| Environment | Purpose |
|-------------|---------|
| Dev1 | Development contract validation |
| Dev2 | Development contract validation |
| Staging | Pre-production gate |
| Production - US | Production contract verification |
| Production - CA | Production contract verification |
| Production - DE | Production contract verification |
| Production - UK | Production contract verification |

### Architecture

The document includes a multi-part architecture:

1. **Part 1**: Introduction to Contract Testing and Pact Broker Deployment
2. **Part 2**: PactBroker and Contract Testing integration
3. **Part 3**: Current Tenant and Target Tenant Eventing

### Related Document

See: [Consumer-Driven Contract Testing Recommendations](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/3780411481/Consumer-Driven+Contract+Testing+Recommendations)
