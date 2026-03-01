---
name: red-green-tdd
description: V1.0 - Expert in Red/Green Test-Driven Development for AI-assisted coding. Enforces the test-first, fail-first, then implement cycle to produce verified, regression-proof code. Use when building features, fixing bugs, or refactoring with any tech stack.
---

# Red/Green TDD

When the user activates this skill without specifying an action, apply the Red/Green TDD workflow to whatever coding task is in progress.

## What Is Red/Green TDD?

Red/Green TDD is a disciplined software development cycle where:

1. **RED** — Write a failing test that defines the desired behavior
2. **GREEN** — Write the minimum implementation to make the test pass
3. **REFACTOR** — Clean up while keeping tests green

The "Red/Green" name comes from test runner output colors: red for failure, green for passing.

## Why It Matters for AI-Assisted Development

Coding agents risk producing code that:

- Doesn't actually work (never executed)
- Is unnecessary (solves problems that don't exist)
- Silently breaks existing features

Red/Green TDD eliminates all three risks:

| Risk | How Red/Green TDD Prevents It |
|---|---|
| Code doesn't work | GREEN phase proves it works by running tests |
| Unnecessary code | RED phase defines exact requirements before writing any implementation |
| Regression | Accumulated test suite catches future breakage |
| False confidence | RED phase confirms test actually exercises new code (not a tautology) |

## The Workflow

### Phase 1: RED (Write Failing Tests)

1. Understand the requirement or bug
2. Write one or more tests that express the expected behavior
3. **Run the tests — they MUST fail**
4. If they pass, the test is wrong (it doesn't exercise new behavior)

### Phase 2: GREEN (Make Tests Pass)

1. Write the minimum implementation to pass the failing tests
2. **Run the tests — they MUST pass**
3. Do not add behavior beyond what the tests require
4. Do not optimize or refactor yet

### Phase 3: REFACTOR (Clean Up)

1. Improve code structure, naming, duplication
2. **Run the tests after every change — they MUST stay green**
3. No new behavior in this phase

### Repeat

Return to Phase 1 for the next slice of behavior.

## Critical Rules

### Never Skip the RED Phase

If a test passes before implementation, one of these is true:

- The feature already exists (no work needed)
- The test doesn't actually test what you think it does
- The test is trivially correct (tautological)

Always verify failure first. A test that never fails proves nothing.

### One Behavior Per Cycle

Each Red/Green cycle should cover one discrete behavior. Don't write 20 tests then implement everything at once. Small cycles keep feedback tight and errors traceable.

### Run Tests Constantly

- After writing tests (must see RED)
- After writing implementation (must see GREEN)
- After every refactor step (must stay GREEN)
- Before committing (must be GREEN)

### Minimum Implementation

In the GREEN phase, write only enough code to pass the tests. Resist the urge to "also handle" edge cases not yet covered by tests. Those edge cases get their own RED/GREEN cycle.

## Prompting for Red/Green TDD

These short prompts activate the full discipline across any LLM coding agent:

| Prompt | When to Use |
|---|---|
| `Use red/green TDD` | New feature or function |
| `Fix this bug using red/green TDD` | Bug fix — write a test that reproduces the bug first |
| `Refactor using red/green TDD` | Restructure code — write characterization tests first |
| `First run the tests` | Starting a session on an existing project with tests |
| `Add tests for {feature}, confirm they fail, then implement` | Explicit step-by-step variant |

## Applying Red/Green TDD to Common Tasks

### New Feature

```text
1. RED:   Write tests for the new feature's expected behavior
2. RUN:   Confirm tests fail (feature doesn't exist yet)
3. GREEN: Implement the feature
4. RUN:   Confirm tests pass
5. REFACTOR: Clean up implementation
6. RUN:   Confirm tests still pass
```

### Bug Fix

```text
1. RED:   Write a test that reproduces the bug (test should FAIL on current code)
2. RUN:   Confirm the test fails (proves the bug exists)
3. GREEN: Fix the bug
4. RUN:   Confirm the test passes (proves the fix works)
5. RUN:   Confirm all other tests still pass (no regression)
```

### Refactoring

```text
1. VERIFY: Run existing tests — they MUST pass (establish baseline)
2. ADD:    Write characterization tests for any untested behavior you'll touch
3. RUN:    Confirm new tests pass on current code
4. REFACTOR: Make structural changes
5. RUN:    Confirm ALL tests still pass after each change
```

### Legacy Code (No Tests)

```text
1. CHARACTERIZE: Write tests that describe current behavior (pass against existing code)
2. RUN:          Confirm characterization tests pass
3. RED:          Write tests for desired new behavior (these fail)
4. GREEN:        Implement changes
5. RUN:          Confirm new tests pass AND characterization tests still pass
```

## Language & Framework Examples

These are illustrative examples — the process is identical regardless of stack.

### Python (pytest)

```python
# RED: test_calculator.py
def test_add_positive_numbers():
    assert add(2, 3) == 5

def test_add_negative_numbers():
    assert add(-1, -1) == -2

def test_add_zero():
    assert add(0, 5) == 5
```

```bash
# RUN: Confirm RED
pytest test_calculator.py  # FAILS — add() doesn't exist yet
```

```python
# GREEN: calculator.py
def add(a, b):
    return a + b
```

```bash
# RUN: Confirm GREEN
pytest test_calculator.py  # PASSES
```

### JavaScript/TypeScript (Vitest)

```typescript
// RED: math.test.ts
import { describe, it, expect } from 'vitest';
import { multiply } from './math';

describe('multiply', () => {
  it('multiplies two positive numbers', () => {
    expect(multiply(3, 4)).toBe(12);
  });

  it('returns zero when multiplied by zero', () => {
    expect(multiply(5, 0)).toBe(0);
  });
});
```

```bash
# RUN: Confirm RED
npx vitest run math.test.ts  # FAILS — multiply() doesn't exist
```

```typescript
// GREEN: math.ts
export function multiply(a: number, b: number): number {
  return a * b;
}
```

```bash
# RUN: Confirm GREEN
npx vitest run math.test.ts  # PASSES
```

### C# (xUnit)

```csharp
// RED: ConverterTests.cs
public class ConverterTests
{
    [Fact]
    public void CelsiusToFahrenheit_FreezingPoint()
    {
        Assert.Equal(32.0, Converter.CelsiusToFahrenheit(0));
    }

    [Fact]
    public void CelsiusToFahrenheit_BoilingPoint()
    {
        Assert.Equal(212.0, Converter.CelsiusToFahrenheit(100));
    }
}
```

```bash
# RUN: Confirm RED
dotnet test  # FAILS — Converter class doesn't exist
```

```csharp
// GREEN: Converter.cs
public static class Converter
{
    public static double CelsiusToFahrenheit(double celsius)
    {
        return celsius * 9.0 / 5.0 + 32;
    }
}
```

```bash
# RUN: Confirm GREEN
dotnet test  # PASSES
```

### Go (testing)

```go
// RED: calc_test.go
func TestDivide(t *testing.T) {
    result, err := Divide(10, 2)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if result != 5.0 {
        t.Errorf("expected 5.0, got %f", result)
    }
}

func TestDivideByZero(t *testing.T) {
    _, err := Divide(10, 0)
    if err == nil {
        t.Fatal("expected error for division by zero")
    }
}
```

```bash
# RUN: Confirm RED
go test ./...  # FAILS — Divide() doesn't exist
```

```go
// GREEN: calc.go
func Divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, fmt.Errorf("division by zero")
    }
    return a / b, nil
}
```

```bash
# RUN: Confirm GREEN
go test ./...  # PASSES
```

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Write implementation first, tests after | Tests become rubber-stamps that pass by definition | Write tests first, see RED, then implement |
| Write tests that always pass | No proof the test exercises real behavior | Confirm RED before writing implementation |
| Write all tests at once, then all code | Lose the tight feedback loop; hard to isolate failures | One behavior per RED/GREEN cycle |
| Skip REFACTOR phase | Accumulates tech debt; code rots | Always refactor while GREEN after each cycle |
| Refactor during GREEN | Confuses "make it work" with "make it right" | Separate concerns — GREEN is only about passing |
| Over-implement in GREEN | Adds untested behavior that may mask bugs | Minimum code to pass — additional behavior gets its own RED cycle |
| Test implementation details | Tests break on refactor even though behavior is unchanged | Test behavior and public API, not internal structure |

## When NOT to Use Red/Green TDD

- **Exploratory prototyping** — When you're discovering what to build, not building it. Throw away the prototype, then TDD the real thing.
- **Configuration files** — YAML, JSON, TOML changes don't benefit from unit tests. Use integration or smoke tests instead.
- **One-off scripts** — Disposable automation that runs once. But if it becomes reusable, add tests.
- **Pure UI layout** — Visual layout (CSS, positioning) is better verified by visual inspection or screenshot tests, not unit tests.

## Integration with Agentic Workflows

Red/Green TDD pairs naturally with coding agents because:

1. **"Use red/green TDD"** — A 4-word prompt that activates the full discipline. Every good model understands this shorthand.
2. **"First run the tests"** — Start any session by running the existing test suite. This teaches the agent the project's testing patterns and scope.
3. **Tests as specification** — Tests serve as unambiguous, executable specs that tell the agent exactly what to build.
4. **Tests as guardrails** — The agent can freely iterate on implementation knowing tests will catch mistakes.
5. **Tests as onboarding** — When an agent reads existing tests, it learns the codebase's conventions, edge cases, and expected behaviors.

## Quick Reference

```text
┌─────────────────────────────────────────┐
│           RED/GREEN/REFACTOR            │
├─────────────────────────────────────────┤
│                                         │
│  1. RED     → Write test → Run → FAIL  │
│  2. GREEN   → Implement  → Run → PASS  │
│  3. REFACTOR → Clean up  → Run → PASS  │
│  4. REPEAT                              │
│                                         │
│  Rules:                                 │
│  • Never skip RED (verify failure)      │
│  • One behavior per cycle               │
│  • Minimum code in GREEN                │
│  • Tests green after every refactor     │
│                                         │
└─────────────────────────────────────────┘
```
