---
name: how-to-write-tests
description: V1.1 - Expert guidance for writing perfect unit tests with Vitest and Testing Library, covering patterns, mocking, coverage, and common pitfalls.
---

# How to Write Perfect Unit Tests

## ALWAYS: Log This Interaction

After completing the request, append to `History/{YYYY-MM-DD}.md`:

```
## {HH:MM} - {Action}

{One-line summary of request and outcome}
```

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Isolation** | Each test runs independently; no shared state between tests |
| **Deterministic** | Same input → same output, every time |
| **Fast** | Unit tests should execute in milliseconds |
| **Readable** | Tests document behavior; anyone can understand intent |
| **Focused** | One logical assertion per test |

## Test Structure (AAA Pattern)

```typescript
it("describes expected behavior", () => {
  // Arrange - Set up test data and conditions
  const input = { name: "test" };
  
  // Act - Execute the code under test
  const result = processInput(input);
  
  // Assert - Verify the outcome
  expect(result).toBe("expected");
});
```

## Vitest Essentials

### Basic Test Anatomy

```typescript
import { beforeEach, describe, expect, it, vi } from "vitest";

describe("ComponentName", () => {
  beforeEach(() => {
    vi.clearAllMocks(); // Always clear mocks between tests
  });

  it("does something specific", () => {
    expect(true).toBe(true);
  });
});
```

### Mocking Functions

```typescript
// Simple mock function
const mockFn = vi.fn();
const mockWithReturn = vi.fn().mockReturnValue("value");
const mockAsync = vi.fn().mockResolvedValue({ data: [] });

// Spy on object method
const spy = vi.spyOn(object, "method").mockImplementation(() => "mocked");

// Restore after test
spy.mockRestore();
```

### Mocking Modules

```typescript
// Must be hoisted - place at top of file
vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(() => Promise.resolve({
    from: vi.fn(() => ({
      select: vi.fn().mockReturnThis(),
      insert: vi.fn().mockResolvedValue({ error: null }),
    })),
  })),
}));
```

### Mocking Next.js

```typescript
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() }),
  usePathname: vi.fn().mockReturnValue("/"),
}));

vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
}));
```

## Testing Library Best Practices

### Query Priority (Use in This Order)

| Priority | Query | When to Use |
|----------|-------|-------------|
| 1 | `getByRole` | Most cases - reflects accessibility |
| 2 | `getByLabelText` | Form fields |
| 3 | `getByPlaceholderText` | When no label exists |
| 4 | `getByText` | Non-interactive elements |
| 5 | `getByTestId` | Last resort only |

### Query Types

| Type | No Match | 1 Match | >1 Match | Async |
|------|----------|---------|----------|-------|
| `getBy` | throw | return | throw | No |
| `queryBy` | null | return | throw | No |
| `findBy` | throw | return | throw | Yes |

### Async Testing

```typescript
// Wait for element to appear
await waitFor(() => {
  expect(screen.getByText("Loaded")).toBeDefined();
});

// Or use findBy (combines getBy + waitFor)
const element = await screen.findByText("Loaded");
```

### User Events

```typescript
import { fireEvent, render, screen } from "@testing-library/react";

// Click
fireEvent.click(screen.getByRole("button"));

// Type
fireEvent.change(screen.getByRole("textbox"), { target: { value: "text" } });

// For dropdowns with Radix/shadcn
fireEvent.pointerDown(trigger, { pointerId: 1, buttons: 1 });
fireEvent.pointerUp(trigger, { pointerId: 1, buttons: 1 });
```

## React Component Testing

### Basic Component Test

```typescript
import { render, screen } from "@testing-library/react";

it("renders correctly", () => {
  render(<Component prop="value" />);
  expect(screen.getByText("Expected Text")).toBeDefined();
});
```

### Testing Hooks

```typescript
import { act, renderHook } from "@testing-library/react";

it("updates state correctly", () => {
  const { result } = renderHook(() => useCustomHook());
  
  act(() => {
    result.current.setValue("new");
  });
  
  expect(result.current.value).toBe("new");
});
```

### Testing Async Server Components

```typescript
it("renders async component", async () => {
  const Component = await AsyncServerComponent({ props });
  render(Component);
  expect(screen.getByTestId("content")).toBeDefined();
});
```

## Coverage Configuration

```typescript
// vitest.config.ts
coverage: {
  provider: "v8",
  reporter: ["text", "json", "html"],
  include: ["src/**/*.{ts,tsx}"],
  exclude: ["src/**/*.test.{ts,tsx}", "src/test/setup.ts"],
  thresholds: {
    lines: 100,
    functions: 100,
    branches: 100,
    statements: 100,
  },
}
```

## Common Patterns

### Testing Error States

```typescript
it("logs error on failure", async () => {
  const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
  mockFn.mockRejectedValue(new Error("Failed"));
  
  await functionUnderTest();
  
  expect(consoleSpy).toHaveBeenCalledWith("Error:", expect.any(Error));
  consoleSpy.mockRestore();
});
```

### Testing localStorage

```typescript
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
};

beforeEach(() => {
  Object.defineProperty(window, "localStorage", {
    value: localStorageMock,
    writable: true,
  });
});
```

### Testing matchMedia

```typescript
Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: query === "(prefers-color-scheme: dark)",
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })),
});
```

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Testing implementation details | Brittle tests | Test behavior, not internals |
| Snapshot overuse | Hard to review changes | Use targeted assertions |
| `getByTestId` everywhere | Ignores accessibility | Use semantic queries |
| Not clearing mocks | Test pollution | `vi.clearAllMocks()` in `beforeEach` |
| Huge test files | Hard to maintain | Split by feature/behavior |
| Copy-paste tests | Maintenance burden | Extract test utilities |
| Testing third-party code | Wasted effort | Trust libraries, mock boundaries |
| No assertion | False positive | Every test needs `expect()` |

## Test Naming Convention

```typescript
// Pattern: "it [action] when [condition]"
it("displays error message when form is invalid", () => {});
it("redirects to home when user is authenticated", () => {});
it("calls API with correct params when submitted", () => {});
```

## Setup File Template

```typescript
// src/test/setup.ts
import "@testing-library/jest-dom";
import { vi } from "vitest";

// Global mocks that apply to all tests
vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(() => Promise.resolve({
    auth: { getUser: vi.fn().mockResolvedValue({ data: { user: null } }) },
  })),
}));
```

## Checklist Before Committing

- [ ] All tests pass: `bun test`
- [ ] Coverage meets threshold: `bun test:coverage`
- [ ] No skipped tests (`.skip`)
- [ ] No focused tests (`.only`)
- [ ] Mocks are cleared/restored
- [ ] Tests are deterministic (run multiple times)
- [ ] Test names describe behavior clearly
