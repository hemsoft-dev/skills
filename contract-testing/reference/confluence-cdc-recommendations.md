# Confluence Reference: Consumer-Driven Contract Testing Recommendations

**Source**: [Consumer-Driven Contract Testing Recommendations](https://relias.atlassian.net/wiki/spaces/RLMSM/pages/3780411481/Consumer-Driven+Contract+Testing+Recommendations)
**Space**: Relias Platform Modernization
**Last Updated**: 2024-02-21

---

## 1. Introduction to Contract Testing

Contract testing ensures independently deployable services interact correctly. It validates that APIs meet the agreed-upon "contract": expected behavior including request formats, response formats, and error handling.

### Benefits

- **Prevents Breaking Changes**: Changes in one service don't unexpectedly break others
- **Enables Independent Deployment**: Services deploy independently without fear of breaking integrations
- **Facilitates Faster Development**: Teams develop against mock services adhering to the contract
- **Improves Communication**: Contract acts as a shared understanding between teams
- **Reduces Need for E2E Testing**: Validates interactions at contract level, reducing comprehensive E2E tests

### Contract Example

A contract between a consumer (Angular frontend) and provider (User API):

- **Request**: GET `/api/v1/Users?city=Raleigh`
- **Response**: JSON with `Id`, `firstName`, `lastName`, `migrationId`
- Contracts act as documentation of API interactions

## 2. Recommendations

### Recommendation 1: Consumer-Driven (not Bi-Directional)

Consumer-driven testing aligns with the primary objective: design APIs that directly meet consumer expectations. Bi-directional testing introduces complexity by requiring negotiations over provider constraints without significant additional value.

### Recommendation 2: PactNet for Pact File Generation and Verification

PactNet chosen for:

- Robust .NET support aligned with current tech stack
- Comprehensive consumer-driven contract testing
- .NET implementation of the Pact framework
- Consumer and provider support
- Open source, available on NuGet
- GitHub: <https://github.com/pact-foundation/pact-net>

**Learning resources referenced:**

- <https://www.c-sharpcorner.com/article/consumer-driven-contract-testing-using-pactnet/>
- <https://github.com/DiUS/pact-workshop-dotnet-core-v3/>
- <https://github.com/pact-foundation/pact-workshop-dotnet-core-v1/blob/master/readme.md#step-41---creating-a-provider-state-http-server>

### Recommendation 3: Dockerized Pact Broker

Pact Broker serves as centralized hub for managing contracts:

- Version control and tagging
- Repository for publishing and retrieving pacts
- CI/CD integration with webhooks and "Can I Deploy?" query
- Visualization tools for service dependency mapping
- Publishing verification results

GitHub: <https://github.com/pact-foundation/pact-broker-docker/tree/master>

### Recommendation 4: Pact CLI

The Pact CLI automates:

- Publishing pact files to Broker
- Retrieving contracts for verification
- "Can I Deploy?" deployment readiness checks
- Webhook management
- Version tagging of pacticipants

Docs: <https://docs.pact.io/implementation_guides/cli>
Docker: <https://hub.docker.com/r/pactfoundation/pact-cli>

**Security approval**: REA-54

## 3. Implementation Guidelines

### Writing Contract Tests with PactNet

1. **Define the Contract**: Write Pact test in consumer project with expected interactions
2. **Run Consumer Tests**: Generate Pact file (the contract)
3. **Share the Contract**: Share Pact file with the producer
4. **Producer Test**: Producer validates its service meets the contract
5. **Continuous Validation**: Automated as part of CI/CD pipelines

### POC Repositories

- **Self-contained POC**: <https://bitbucket.org/relias/relias-best-practices/pull-requests/39>
- **RLMS Website JS POC**: <https://bitbucket.org/relias/rlms-website/branch/rthomas/develop/RLPD-49997_pact_proof-of_concept_tests>
- **Assessment Service Consumer POC**: <https://bitbucket.org/relias/assessmentservice/branch/rthomas/develop/RLPD-49996_pact_api_to_api_consumer_example_test>

## 4. Appendix

### Pact Broker vs PactFlow

**Pact Broker** (recommended — self-hosted):

- Stores and manages consumer contracts
- Verifies contracts against provider APIs
- Tracks contract versions
- Integrates with CI/CD pipelines
- Open source, self-hosted

**PactFlow** (commercial alternative):

- Extends Broker with bi-directional testing
- Visualization tools, advanced CI/CD integrations
- User management, secrets management
- Managed service (no self-hosting)
- Cons: paid subscription, potential overkill for simple needs

### PactNet Without a Broker

Even without a Pact Broker, PactNet can:

- Write consumer contracts
- Test providers against contracts
- Run contract tests in isolation
- Integrate with CI/CD pipelines
- Document service interactions

### Asynchronous Contract Tests

PactNet supports async/message-based interactions for systems using message queues. Can write and run async contract tests without a Broker.

### Alternative Tools Considered

| Tool | Notes |
|------|-------|
| Spring Cloud Contract | For Spring-based apps only |
| Postman | API testing with contract support |
| Swagger/OpenAPI/Prism/Dredd | API spec validation |
| Schemathesis | Property-based spec testing |
