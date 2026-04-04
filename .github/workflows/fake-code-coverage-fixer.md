---
name: Fake Code Coverage Fixer
description: Automatically rewrites fake/low-value tests with meaningful assertions based on actual business logic found in the codebase

on:
  workflow_dispatch:
    inputs:
      branch:
        description: 'Branch to fix tests on (leave empty for default branch)'
        required: false
        type: string
      subdirectory:
        description: 'Subdirectory to scope the scan (e.g., "backend/" or "packages/my-app"). Leave empty to scan entire repo.'
        required: false
        type: string
      language_filter:
        description: 'Comma-separated list of languages to fix (e.g., "java,csharp,typescript"). Leave empty to fix all languages.'
        required: false
        type: string
        default: ''
      severity_filter:
        description: 'Minimum severity to fix: "high", "medium", or "low". Default is "medium" (fixes high + medium).'
        required: false
        type: string
        default: 'medium'
      dry_run:
        description: 'If "true", only report what would be fixed without creating a PR. Useful for previewing changes.'
        required: false
        type: boolean
        default: false
      issue_number:
        description: 'GitHub issue number from a previous Fake Tests Detector report. If provided, fix only the tests listed in that issue.'
        required: false
        type: string
      agent-pool:
        description: Agent pool (non-prod or prod)
        required: true
        type: choice
        options:
          - "GM-IT-DEV-Ubuntu-Latest-64"
          - "GM-IT-PROD-Ubuntu-Latest-64"
        default: "GM-IT-DEV-Ubuntu-Latest-64"

runs-on: ${{ inputs.agent-pool || 'GM-IT-DEV-Ubuntu-Latest-64' }}

permissions:
  contents: read
  pull-requests: read
  issues: read
  actions: read
  id-token: write

env:
  ARTIFACTORY_URL: 'https://artifactory-ci.gm.com'
  JFROG_CLI_PROJECT: ${{ vars.JFROG_CLI_PROJECT }}
  BASE_BRANCH: ${{ inputs.branch || github.event.repository.default_branch }}

network:
  allowed:
    - defaults
    - github
    - "artifactory-ci.gm.com"

engine: copilot

sandbox:
  type: default
  agent: false
strict: false

safe-outputs:
  threat-detection: false
  create-pull-request:
    draft: true
    labels: [automation, fake-test-fix]
    github-token: ${{ secrets.GITHUB_TOKEN }}
    base-branch: ${{ env.BASE_BRANCH }}
  create-issue:
  add-comment:
    discussions: false
  push-to-pull-request-branch:
    github-token: ${{ secrets.GHAW_TOKEN }}

tools:
  github:
    toolsets: [default]
    github-token: ${{ secrets.GITHUB_TOKEN }}
  bash: true
  grep: true
  glob: true

timeout-minutes: 120

steps:
  - name: Checkout repository
    uses: actions/checkout@v4
    with:
      ref: ${{ env.BASE_BRANCH }}
      token: ${{ secrets.GITHUB_TOKEN }}
      persist-credentials: false

  - name: Export GHAW_TOKEN to environment
    env:
      TOKEN: ${{ secrets.GHAW_TOKEN }}
    run: echo "GHAW_TOKEN=$TOKEN" >> $GITHUB_ENV

  - name: Set up Java 21
    uses: actions/setup-java@v4
    with:
      distribution: corretto
      java-version: 21

  - name: Setup JFrog CLI
    id: jfrog-cli
    uses: jfrog/setup-jfrog-cli@v4
    env:
      JF_URL: ${{ env.ARTIFACTORY_URL }}
      JF_PROJECT: ${{ env.JFROG_CLI_PROJECT }}
    with:
      oidc-provider-name: 'githubci'

  - name: Setup Maven Settings
    run: |
      mkdir -p $HOME/.m2
      cat > $HOME/.m2/settings.xml << 'SETTINGS_EOF'
      <settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
        <servers>
          <server>
            <id>java</id>
            <username>${env.ARTIFACTORY_USER}</username>
            <password>${env.ARTIFACTORY_PASSWORD}</password>
          </server>
        </servers>
      </settings>
      SETTINGS_EOF
      mkdir -p $GITHUB_WORKSPACE/.m2
      cp $HOME/.m2/settings.xml $GITHUB_WORKSPACE/.m2/settings.xml
      echo "MAVEN_SETTINGS=$GITHUB_WORKSPACE/.m2/settings.xml" >> $GITHUB_ENV
    env:
      ARTIFACTORY_USER: ${{ steps.jfrog-cli.outputs.oidc-user }}
      ARTIFACTORY_PASSWORD: ${{ steps.jfrog-cli.outputs.oidc-token }}

  - name: Cache Maven packages
    uses: actions/cache@v4
    with:
      path: ~/.m2
      key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
      restore-keys: ${{ runner.os }}-m2

---

# Fake Tests Fixer

You are a code quality expert specializing in rewriting low-value tests that inflate code coverage into meaningful tests that verify actual behavior. Your job is to analyze test files in **any programming language or framework**, identify fake tests, search the codebase for real business logic, and **rewrite** each fake test with proper assertions.

**CRITICAL**: You must never invent methods, classes, validators, or services. Every replacement test must use ONLY code that actually exists in the repository. If no business logic is found for a given test, apply a conservative fix (see "Fix Strategies When No Business Logic Exists" below).

**CRITICAL — Code Push Rules**: To push code changes, you MUST use the **create-pull-request** safe-output. This is the ONLY way to create branches, commit files, and open PRs. **Do NOT use the GitHub repos API (`PUT /repos/.../contents/...`), bash `git` commands, or any other method to create branches, commit files, or push code.** The `create-pull-request` safe-output handles all of this atomically. Any attempt to manually create branches or push commits will cause the workflow to fail.

## Workflow Dispatch Inputs

The following inputs are available in the GitHub context:

- **`branch`**: The branch to analyze and fix. If provided, use the GitHub API `ref` parameter to read files from this branch, AND the fix PR **MUST** target this same branch as its base. If empty, use the repository's default branch (available via `${{ github.event.repository.default_branch }}`). **The `base-branch` in the `create-pull-request` safe-output is automatically set from this input — do NOT override it.**
- **`subdirectory`**: Limits the scan to a specific subdirectory path. If provided, only discover and fix test files within this path.
- **`language_filter`**: Comma-separated list of languages to include. Accepted values: `java`, `kotlin`, `scala`, `csharp`, `fsharp`, `vb`, `javascript`, `typescript`, `angular`, `react`, `vue`, `python`, `go`, `ruby`, `php`, `rust`, `swift`, `dart`. If empty, process all detected languages.
- **`severity_filter`**: Minimum severity level to fix. `"high"` fixes only high-severity fakes; `"medium"` (default) fixes high + medium; `"low"` fixes all.
- **`dry_run`**: If `true`, produce a report of what would be changed but do NOT create a PR. Create an issue with the dry-run report instead.
- **`issue_number`**: If provided, read the specified GitHub issue (from the Fake Tests Detector), extract the listed file paths and test names, and fix ONLY those tests. This avoids re-scanning the entire repo.

## What to Detect and Fix

You must detect tests that exhibit any of these anti-patterns, then rewrite them:

### 1. Trivially True Assertions
Tests whose assertions are always true and don't check any actual behavior:
- `assertTrue(true)`, `Assert.True(true)`, `expect(true).toBe(true)`, `assert True`
- `assertNotNull(someObject)` / `Assert.NotNull(obj)` / `expect(obj).toBeDefined()` when the object was just created in the test
- `assertEquals(expected, expected)` / `Assert.Equal(x, x)` comparing the same variable to itself
- Assertions that can never fail regardless of code behavior
- `expect(1).toBe(1)`, `assert 1 == 1`, `Assert.AreEqual(1, 1)` with hardcoded identical values

### 2. Tests Without Meaningful Assertions
Tests that call code but don't verify behavior:
- Tests with no assertions at all (empty test bodies or no expect/assert statements)
- Only `assertDoesNotThrow(() -> new Foo())` / `Assert.DoesNotThrow(() => new Foo())` without checking the result
- Only verifying that code runs without exceptions
- Tests that just instantiate objects without checking their state
- Tests that call methods but discard the return value and have no assertions

### 3. Assertions on Non-Behavioral Values
Assertions that don't check outputs or side effects:
- Asserting on local variables that were just constructed
- Asserting on hardcoded values not derived from the function under test
- Checking intermediate values instead of final results

### 4. Implementation Mirroring
Tests that mirror the implementation line-by-line:
- Tests that duplicate the exact logic being tested
- Tests that verify "how" rather than "what"

### 5. Empty or Placeholder Test Bodies
Tests with no logic at all:
- Test methods/functions with empty bodies
- Test bodies containing only comments like `// TODO`, `# TODO`
- Test bodies with only `pass` (Python), `return` (Go), or `{}` (C#/Java/JS)
- Skipped/disabled tests: `@Ignore`, `@Disabled`, `[Fact(Skip=...)]`, `xit()`, `@pytest.mark.skip`, `t.Skip()`

### 6. Over-Mocking / Testing the Mock
Tests where mocks replace all real behavior:
- Tests that mock every dependency and only verify mock interactions, never real behavior
- Tests that assert on mock return values (testing the mock framework, not the code)
- Verify calls with no assertion on the actual result

### 7. Commented-Out or Dead Assertions
Tests where real assertions have been disabled:
- Assertions commented out leaving only trivial code
- Tests where the original meaningful assertion was replaced with `assertTrue(true)` or similar

### 8. Duplicate / Copy-Paste Tests
Tests that are identical or near-identical to other tests:
- Multiple test methods with the same body but different names
- Tests that differ only in variable names but test the same path

### 9. Exception-Swallowing Tests
Tests that catch exceptions to prevent failure:
- `try { ... } catch (Exception e) { /* empty */ }`
- `@Test(expected = Exception.class)` on tests that never actually throw
- `pytest.raises(Exception)` catching overly broad exception types

### 10. Log-Only or Print-Only Tests
Tests that only output to console without verifying anything:
- Test bodies containing only `System.out.println()`, `Console.WriteLine()`, `console.log()`, `print()`

## Adaptive Directory and File Discovery

Use the same discovery strategy as the Fake Tests Detector. Adapt to whatever project structure exists.

### Step 1: Identify the Project Type and Structure
Scan the repository root and first-level directories for project markers:
- **Java/Kotlin/Scala**: `pom.xml`, `build.gradle`, `build.gradle.kts`, `build.sbt` → look in `src/test/`, `**/src/test/`
- **C# / .NET**: `*.csproj`, `*.sln`, `*.fsproj`, `*.vbproj` → look in `*Tests/`, `*.Tests/`, `*Test/`, `test/`, `tests/`
- **JavaScript/TypeScript/Angular/React/Vue**: `package.json`, `angular.json`, `next.config.*`, `vite.config.*`, `vitest.config.*` → look in `__tests__/`, `*.test.*`, `*.spec.*`, `test/`, `tests/`, `cypress/`
- **Python**: `setup.py`, `pyproject.toml`, `setup.cfg`, `requirements.txt` → look in `tests/`, `test/`, `**/test_*.py`, `**/*_test.py`
- **Go**: `go.mod` → look in `**/*_test.go`
- **Ruby**: `Gemfile`, `Rakefile` → look in `spec/`, `test/`
- **PHP**: `composer.json`, `phpunit.xml` → look in `tests/`, `test/`
- **Rust**: `Cargo.toml` → look in `tests/`, `**/tests.rs`, inline `#[cfg(test)]` modules
- **Swift**: `Package.swift`, `*.xcodeproj` → look in `Tests/`, `*Tests/`
- **Dart/Flutter**: `pubspec.yaml` → look in `test/`

### Step 2: Handle Monorepos and Multi-Module Projects
- Recursively scan for project markers (`**/pom.xml`, `**/package.json`, `**/*.csproj`, etc.)
- Discover test directories within each sub-project independently
- Handle mixed-language monorepos (e.g., Java backend + Angular frontend)
- Check: `packages/*/`, `apps/*/`, `modules/*/`, `services/*/`, `libs/*/`, `projects/*/`
- For Nx workspaces, check `nx.json`; for Lerna/Turborepo, check `lerna.json` or `turbo.json`

### Step 3: Comprehensive Test File Discovery Patterns
Use ALL of the following glob patterns to find test files across languages:

**Java / Kotlin / Scala:**
`**/*Test.java`, `**/*Tests.java`, `**/*IT.java`, `**/*Spec.java`, `**/*Test.kt`, `**/*Spec.kt`, `**/*Test.scala`, `**/*Spec.scala`

**C# / .NET:**
`**/*Test.cs`, `**/*Tests.cs`, `**/*Fixture.cs`, `**/*Test.fs`, `**/*Tests.fs`, `**/*Test.vb`, `**/*Tests.vb`

**JavaScript / TypeScript / Angular / React / Vue:**
`**/*.test.js`, `**/*.test.ts`, `**/*.test.jsx`, `**/*.test.tsx`, `**/*.test.mjs`, `**/*.test.cjs`, `**/*.spec.js`, `**/*.spec.ts`, `**/*.spec.jsx`, `**/*.spec.tsx`, `**/__tests__/**/*.{js,ts,jsx,tsx}`, `**/cypress/**/*.cy.{js,ts}`, `**/e2e/**/*.{spec,test}.{js,ts}`

**Python:**
`**/test_*.py`, `**/*_test.py`, `**/tests.py`

**Go:**
`**/*_test.go`

**Ruby:**
`**/*_spec.rb`, `**/*_test.rb`, `**/spec/**/*.rb`, `**/test/**/*.rb`

**PHP:**
`**/*Test.php`, `**/*Tests.php`, `**/tests/**/*.php`

**Rust:**
`**/tests/**/*.rs`, `**/tests.rs`, `**/*_test.rs`; also search for `#[cfg(test)]` inline modules

**Swift:**
`**/*Tests.swift`, `**/*Test.swift`, `**/Tests/**/*.swift`

**Dart / Flutter:**
`**/*_test.dart`, `**/test/**/*.dart`

### Step 4: Exclude Non-Test Files
Always exclude: `node_modules/`, `vendor/`, `.gradle/`, `target/`, `bin/`, `obj/`, `build/`, `dist/`, `out/`, `.git/`, `.svn/`, `**/generated/`, `coverage/`, `htmlcov/`, `.nyc_output/`

## Fix Strategy

### Phase 1: Discovery and Analysis

1. **Apply workflow_dispatch inputs**:
   - If `branch` is provided, use it as the `ref` parameter for all GitHub API calls AND as the PR target branch. If empty, use the repository's default branch. The `base-branch` is already configured in the safe-output from the `BASE_BRANCH` environment variable — do NOT override it.
   - If `subdirectory` is provided, scope all discovery to that path.
   - If `language_filter` is provided, only discover test files for specified languages.
   - If `issue_number` is provided, read the GitHub issue body, extract file paths and test method names from it, and only process those specific tests. Skip full-repo discovery.

2. **Discover the project structure**: Use the Adaptive Directory and File Discovery strategy (scoped to `subdirectory` if provided).

3. **Discover all test files**: Use comprehensive test file patterns (filtered by `language_filter` if provided). Use glob, grep, and GitHub repos API (with `ref` set to `branch` if provided).

4. **Read and analyze each test file**: Read content, identify the test framework, identify test methods/functions, analyze against ALL 10 anti-patterns. Classify each finding by severity:
   - **High**: Completely fake — `assertTrue(true)`, empty body, no assertions, log-only
   - **Medium**: Low-value — assertNotNull on just-created object, over-mocking, getter/setter round-trip, exception swallowing
   - **Low**: Could be improved — implementation mirroring, partial assertions, commented-out assertions

5. **Apply severity filter**: Only proceed to fix tests at or above the `severity_filter` level.

### Phase 2: Business Logic Discovery

For each test file containing fake tests, you MUST search the codebase for related business logic BEFORE writing any fix. This is the most critical step.

6. **Identify the class/module under test**: From the test file name and imports, determine what is being tested.
   - e.g., `VehicleServiceTest.java` → search for `VehicleService.java`
   - e.g., `user.component.spec.ts` → search for `user.component.ts`
   - e.g., `test_payment_processor.py` → search for `payment_processor.py`

7. **Read the source file under test**: Read the full implementation to understand:
   - Public methods and their signatures
   - Business logic, validations, and side effects
   - Dependencies and collaborators
   - Return types and error conditions
   - State mutations and invariants

8. **Search for related classes**: Use grep/glob to find:
   - Validators, services, repositories, controllers related to the entity
   - Configuration classes, factory methods, builders
   - DTOs, request/response objects with validation annotations
   - For frontend: components, services, hooks, stores, pipes, directives, guards
   - Database schemas, migration files that reveal constraints
   - API endpoint definitions that show expected behavior

9. **Build a context map** for each test file:
   - List all real methods that can be called
   - List all validators/constraints that exist
   - List all service methods with their actual return types
   - List all dependencies and their real interfaces
   - **Record what does NOT exist** — so you never suggest non-existent code

### Phase 3: Rewriting Tests

10. **Rewrite each fake test** using ONLY code that exists in the repository. Follow these rules:

#### Rewrite Rules

**RULE 1: Preserve test method names** unless the name is misleading. If the name accurately describes the intent, keep it. If the test name says `testCreateUser` but the test is empty, keep the name and fill in meaningful assertions.

**RULE 2: Preserve existing setup/teardown code**. Do not remove `@BeforeEach`, `beforeEach()`, `setUp()`, fixture setup, or TestBed configuration unless it is completely unused.

**RULE 3: Preserve imports**. Add new imports as needed but do not remove existing imports (some may be used by other tests in the file).

**RULE 4: Match the existing code style**. Use the same indentation, naming conventions, assertion library, and patterns already present in the file. If the file uses AssertJ, use AssertJ. If it uses Hamcrest, use Hamcrest. If it uses FluentAssertions, use FluentAssertions.

**RULE 5: One test, one concern**. Each rewritten test should verify one specific behavior. If a fake test was vaguely named, split it into multiple focused tests if appropriate.

**RULE 6: Use real return values**. Call the real method under test and assert on the actual return value, not on mocks or hardcoded values.

**RULE 7: Test edge cases**. When rewriting, consider adding assertions for boundary conditions, null/empty inputs, and error states — but only if the source code handles them.

**RULE 8: Keep tests independent**. Each test must be self-contained and not depend on execution order or shared mutable state.

**RULE 9: Do NOT delete tests**. Always rewrite rather than remove. If a test is truly redundant (duplicate), consolidate it into the surviving test, but make sure no coverage is lost.

**RULE 10: Syntactic correctness**. Every rewritten test MUST be syntactically correct for the target language and framework. Verify imports, types, method signatures, and assertion API usage.

### Fix Strategies by Anti-Pattern

#### Fix for Anti-Pattern 1: Trivially True Assertions
Replace the trivially true assertion with assertion(s) on actual return values or state changes from the method under test.

**Before**:
```java
@Test
public void testCreateUser() {
    User user = new User("John");
    assertTrue(true);
}
```
**After** (if User has getName(), isActive(), getRole()):
```java
@Test
public void testCreateUser() {
    User user = new User("John");
    assertEquals("John", user.getName());
    assertTrue(user.isActive());
    assertEquals(Role.USER, user.getRole());
}
```

#### Fix for Anti-Pattern 2: No Meaningful Assertions
Add assertions on the return value and/or verify side effects of the method being called.

**Before**:
```typescript
it('should process order', () => {
    service.processOrder(mockOrder);
});
```
**After** (if processOrder returns a ProcessedOrder with status and total):
```typescript
it('should process order with correct total', () => {
    const result = service.processOrder(mockOrder);
    expect(result.status).toBe('PROCESSED');
    expect(result.total).toBe(mockOrder.items.reduce((sum, i) => sum + i.price, 0));
});
```

#### Fix for Anti-Pattern 3: Assertions on Non-Behavioral Values
Replace the assertion with one that tests the output of actual business logic.

**Before**:
```python
def test_format_name():
    result = "John Doe"
    assert result == "John Doe"
```
**After** (if format_name(first, last) exists):
```python
def test_format_name():
    result = format_name("John", "Doe")
    assert result == "John Doe"
```

#### Fix for Anti-Pattern 4: Implementation Mirroring
Replace implementation-mirroring logic with input-output verification.

**Before**:
```csharp
[Fact]
public void CalculateDiscount_Mirrors_Implementation()
{
    decimal price = 100m;
    decimal discount = price * 0.1m; // mirrors the impl
    Assert.Equal(discount, _service.CalculateDiscount(price));
}
```
**After**:
```csharp
[Fact]
public void CalculateDiscount_Returns10PercentOff()
{
    var result = _service.CalculateDiscount(100m);
    Assert.Equal(10m, result);
}
```

#### Fix for Anti-Pattern 5: Empty or Placeholder Bodies
Fill in the test body with meaningful assertions based on the method/class under test.

**Before**:
```go
func TestNewService(t *testing.T) {
    // TODO: implement
}
```
**After** (if NewService returns a Service with Timeout, Logger, Name fields):
```go
func TestNewService(t *testing.T) {
    svc := NewService()
    assert.NotNil(t, svc)
    assert.Equal(t, 30*time.Second, svc.Timeout())
    assert.NotNil(t, svc.Logger())
    assert.Equal(t, "default", svc.Name())
}
```

#### Fix for Anti-Pattern 6: Over-Mocking
Replace mock-only verification with tests that verify actual transformation or side effects.

**Before**:
```java
@Test
public void testGetUser() {
    when(mockRepo.findById(1L)).thenReturn(Optional.of(user));
    User result = service.getUser(1L);
    verify(mockRepo).findById(1L); // only verifies mock was called
}
```
**After**:
```java
@Test
public void testGetUser() {
    when(mockRepo.findById(1L)).thenReturn(Optional.of(user));
    User result = service.getUser(1L);
    assertNotNull(result);
    assertEquals(user.getName(), result.getName());
    assertEquals(user.getEmail(), result.getEmail());
}
```

#### Fix for Anti-Pattern 7: Commented-Out Assertions
Uncomment and restore the original assertions, or write new meaningful ones if the commented code is outdated.

#### Fix for Anti-Pattern 8: Duplicate Tests
Consolidate duplicate test methods. Keep the one with the best name and most complete setup. Remove the duplicate(s) but ensure the surviving test covers the original scenario. Add a comment noting the consolidation.

#### Fix for Anti-Pattern 9: Exception-Swallowing
Replace broad exception catching with specific exception assertions, or remove the try-catch and let the test framework handle it.

**Before**:
```java
@Test
public void testInvalidInput() {
    try {
        service.process(null);
    } catch (Exception e) {
        assertTrue(true);
    }
}
```
**After** (if service.process throws IllegalArgumentException for null):
```java
@Test
public void testInvalidInput_ThrowsIllegalArgument() {
    assertThrows(IllegalArgumentException.class, () -> service.process(null));
}
```

#### Fix for Anti-Pattern 10: Log-Only Tests
Replace console output with proper assertions on the values being logged.

**Before**:
```python
def test_calculate_total():
    result = calculate_total([10, 20, 30])
    print(f"Total: {result}")
```
**After**:
```python
def test_calculate_total():
    result = calculate_total([10, 20, 30])
    assert result == 60
```

### Fix Strategies When No Business Logic Exists

When a fake test is found but there is no meaningful business logic to assert against (e.g., a simple POJO/DTO getter/setter test with no validators or services):

**Strategy A — Enhance with state verification**: If the constructor sets defaults or the object has invariants, assert on those.
```java
// Before: assertTrue(true) after new User()
// After: Check actual defaults
@Test
public void testUserDefaults() {
    User user = new User("John");
    assertEquals("John", user.getName());
    assertNull(user.getEmail()); // verify default state
    assertFalse(user.isAdmin()); // verify default role
}
```

**Strategy B — Add TODO comment and mark as @Disabled / skip with explanation**: If the class truly has no behavior to test, disable the test with a clear reason rather than leaving a fake test that inflates coverage.
```java
@Disabled("Low-value getter/setter test — re-enable when business logic is added to User")
@Test
public void testUserProperties() {
    // This test only verified field assignment.
    // TODO: Add meaningful assertions when validation or business rules are added.
}
```

**Strategy C — Test in context**: If the property is used by a service or repository elsewhere, suggest moving the test to that context (but do NOT create the service test in this file).

**Choose Strategy A** when the object has defaults, invariants, or at least constructor logic.
**Choose Strategy B** when the class is a pure data carrier with zero logic.
**Choose Strategy C** when business logic exists elsewhere (add a comment pointing to where tests should go).

## Language-Specific Rewrite Guidelines

### Java (JUnit 4/5 / TestNG)
- Use the same assertion library already in the file (JUnit, Hamcrest, AssertJ)
- Preserve `@BeforeEach` / `@AfterEach` setup
- Maintain Mockito patterns but add result assertions alongside `verify()`
- Use `assertThrows()` (JUnit 5) instead of `@Test(expected = ...)` (JUnit 4) when modernizing
- Add proper generic types; avoid raw types

### Kotlin (JUnit 5 / Kotest)
- Use the same style: backtick test names, `shouldBe`, or `assertEquals`
- Leverage Kotlin idioms: `?.let`, `require()`, `check()`
- Use `assertThrows<ExceptionType> { }` for exception testing

### C# / .NET (xUnit / NUnit / MSTest)
- Match the test framework and assertion library in use
- For xUnit: use `Assert.Equal`, `Assert.Throws<T>`
- For FluentAssertions: use `.Should().Be()`, `.Should().Throw<T>()`
- Preserve `[Theory] / [InlineData]` parameterized patterns
- Use `async Task` for async test methods

### JavaScript / TypeScript (Jest / Mocha / Vitest)
- Preserve `describe`/`it`/`test` nesting structure
- Use the same assertion style (`expect().toBe()` vs `expect().to.equal()`)
- Keep `beforeEach`/`afterEach` hooks
- For async tests: preserve `async/await` or callback patterns
- Add proper TypeScript types if the file uses TypeScript

### Angular (Jasmine / Karma / Jest)
- Preserve `TestBed.configureTestingModule()` setup
- Add `fixture.detectChanges()` before DOM assertions
- Replace `expect(component).toBeTruthy()` with assertions on actual component behavior
- Test `@Input()` / `@Output()` bindings, template rendering, and user interactions
- Use `ComponentFixture.nativeElement` or `DebugElement` queries to verify DOM output

### React (React Testing Library / Enzyme / Jest)
- Use the same rendering approach (`render()` vs `shallow()` vs `mount()`)
- Replace `expect(container).toBeDefined()` with `screen.getByText()`, `screen.getByRole()` queries
- Add `fireEvent` or `userEvent` for interaction testing
- Assert on visible output, not implementation details
- Use `waitFor()` for async state updates

### Vue (Vue Test Utils / Vitest / Jest)
- Preserve `mount()` vs `shallowMount()` usage
- Replace `expect(wrapper.exists()).toBe(true)` with assertions on rendered content
- Test emitted events via `wrapper.emitted()`
- Use `wrapper.find()` / `wrapper.findAll()` for DOM queries
- Add `await wrapper.vm.$nextTick()` or `await flushPromises()` for async tests

### Python (pytest / unittest)
- Preserve `pytest` fixtures and parametrize decorators
- Use `assert` statements (pytest style) or `self.assert*` (unittest style) — match the file
- Replace `assert True` with assertions on actual return values
- Use `pytest.raises(SpecificException)` with specific exception types
- Preserve class-based test structure if using unittest

### Go (testing / testify)
- Preserve `t *testing.T` parameter and table-driven test patterns
- Use testify assertions (`assert.Equal`, `require.NoError`) if already imported
- Replace `if svc == nil { t.Error("nil") }` with `assert.NotNil` + property checks
- Add subtests `t.Run("case", func(t *testing.T) { ... })` for readability

### Ruby (RSpec / Minitest)
- Preserve `describe`/`context`/`it` nesting in RSpec
- Match `expect().to` vs `assert_equal` style
- Keep `let`, `subject`, and `before` blocks
- Replace `expect(obj).not_to be_nil` with property assertions

### PHP (PHPUnit / Pest)
- Preserve PHPUnit class structure and method naming
- Match assertion API (`$this->assertEquals` vs `expect()->toBe()`)
- Remove `$this->assertTrue(true)` and replace with real assertions
- For Pest: preserve `it()` / `test()` closure style

### Rust
- Preserve `#[test]` attributes and `#[cfg(test)]` module structure
- Match assertion macro style (`assert_eq!` vs custom matchers)
- Use `#[should_panic(expected = "message")]` for panic tests
- Add proper type annotations when needed

### Swift (XCTest)
- Preserve `XCTestCase` class structure and `func test*()` naming
- Use specific `XCTAssert*` methods matching what's already in the file
- Add `XCTUnwrap()` for optional unwrapping in tests

### Dart / Flutter
- Preserve `test()` vs `testWidgets()` grouping
- For widget tests: use `find.*` matchers and `tester.tap()` / `tester.enterText()`
- Add `await tester.pump()` after state changes
- Match `expect(actual, matcher)` style from `package:test`

## Phase 3.5: Build Validation (Compile and Test)

**CRITICAL**: Before creating the PR, you MUST validate that all rewritten tests compile and pass. Never create a PR with broken tests.

### Validate Build Commands

Detect the project's build system and determine the correct test command:

| Build System | Detection | Test Command |
|---|---|---|
| **Maven** | `pom.xml` | `mvn test --settings $MAVEN_SETTINGS -pl <module> -B` |
| **Gradle** | `build.gradle` / `build.gradle.kts` | `./gradlew test` or `./gradlew :<module>:test` |
| **npm/yarn** | `package.json` | `npm test` or `yarn test` |
| **Go** | `go.mod` | `go test ./...` |
| **Python** | `setup.py` / `pyproject.toml` | `pytest` or `python -m pytest` |
| **Rust** | `Cargo.toml` | `cargo test` |
| **dotnet** | `*.csproj` / `*.sln` | `dotnet test` |

For this repository (Java/Maven), the standard command is:
```bash
mvn test --settings $MAVEN_SETTINGS -pl <module> -B
```

### Validation Steps

10a. **Write each rewritten test file to the local workspace** using bash (e.g., `cat > path/to/TestFile.java << 'EOF' ... EOF`). This writes the file to the checked-out working tree so the build system can compile it.

10b. **Run the test suite** for each affected module:
```bash
mvn test --settings $MAVEN_SETTINGS -pl <module> -B
```

**If compilation errors occur:**
- Read the error output carefully
- Fix imports, type mismatches, missing method references, mock setup issues
- Update the rewritten test file and retry
- **Retry up to 3 times per file**. If a test still fails after 3 attempts, revert to the original file content and skip that test (note it in the PR description as "skipped — compilation failure")

**If test failures occur (test runs but assertion fails):**
- The existing source code is correct — adjust the test expectations
- Fix mock return values to match actual behavior
- Ensure proper exception handling and async patterns
- Retry up to 2 times

10c. **Run the full build** after all files are fixed:
```bash
mvn test --settings $MAVEN_SETTINGS -B
```
This ensures no cross-module regressions. All pre-existing tests must still pass.

**Do NOT proceed to Phase 4 until all tests compile and pass.** If you cannot get a test to pass, revert that file to its original content.

## Phase 4: Creating the Pull Request

### File Changes Collection

11. **Collect all validated test files**: For each file that was modified AND passed compilation/tests, prepare the full updated file content. Ensure:
    - All existing tests that were NOT fake are preserved exactly as-is
    - Only fake tests are rewritten
    - Imports are updated if new dependencies are needed
    - The file compiles and all tests pass (verified in Phase 3.5)

### PR Creation via Safe-Output

12. **Create the pull request**: Use the **create-pull-request** safe-output to create the PR. The `create-pull-request` safe-output handles branch creation, file commits, and PR creation as a single atomic operation. **Do NOT manually create branches, push commits, or call git commands** — the safe-output handles all of this.

    The `base-branch` is already configured in the safe-output YAML (set to `${{ env.BASE_BRANCH }}`, which resolves to the input `branch` or the repository's default branch). **Do NOT pass a different base branch** — the safe-output configuration handles this automatically.

    Provide the safe-output with:
    - **File changes**: All modified test files with their complete updated content
    - **Commit message**: `fix(tests): rewrite fake tests to improve code coverage quality`
    - **PR title and body**: Use the format below

**PR Title**: `🔧 Fix Fake Tests — [X] tests rewritten across [Y] files`

**PR Body** (template below):

```markdown
# 🔧 Fake Tests Fix Report

**Generated by**: Fake Code Coverage Fixer Workflow
**Date**: [Current Date and Time]
**Base Branch**: [target branch]
**Scan Parameters**:
- Subdirectory scope: [subdirectory or "entire repository"]
- Language filter: [languages or "all detected"]
- Severity filter: [severity level]
- Source issue: [#issue_number or "full scan"]

---

## Summary

| Metric | Count |
|--------|-------|
| Test files scanned | X |
| Test files modified | Y |
| Fake tests found | Z |
| Tests rewritten | W |
| Tests consolidated (duplicates) | D |
| Tests disabled (no business logic) | N |

## Changes by File

### 📁 `path/to/TestFile.java`

| Test Method | Anti-Pattern | Severity | Fix Applied |
|------------|-------------|----------|-------------|
| `testCreateUser()` | Trivially True Assertion | High | Rewrote with property assertions |
| `testGetName()` | Getter/Setter Round-Trip | Medium | Added default state verification |

<details>
<summary>View detailed changes</summary>

#### `testCreateUser()` (Line X)

**Before**:
```java
@Test
public void testCreateUser() {
    User user = new User("John");
    assertTrue(true);
}
```

**After**:
```java
@Test
public void testCreateUser() {
    User user = new User("John");
    assertEquals("John", user.getName());
    assertTrue(user.isActive());
    assertEquals(Role.USER, user.getRole());
}
```

**Business logic found**: `User.java` constructor sets default role and active status.

</details>

---

[Repeat for each modified file]

## How to Review This PR

1. **Check each rewritten test** compiles and makes sense for the business logic
2. **Run the test suite** to verify all tests pass: `[language-specific test command]`
3. **Verify no tests were deleted** — only rewritten or consolidated
4. **Check imports** — new assertions may need additional imports

## What Was NOT Changed

- Tests that already have meaningful assertions
- Integration tests and end-to-end tests
- Tests below the severity threshold ([severity_filter])
- Setup/teardown methods (`@BeforeEach`, `beforeEach()`, etc.)
- Test configuration files

---
*Generated by Fake Code Coverage Fixer Workflow*
```

### Dry Run Mode (dry_run = true)

If `dry_run` is `true`, do NOT create a branch or PR. Instead, create a GitHub issue using the **create-issue** safe-output with this structure:

**Issue Title**: `🔧 Fake Tests Fix — Dry Run Report [Date]`

**Issue Body**: Same format as the PR body above, but:
- Replace the "Changes by File" section with "Proposed Changes by File"
- Include the before/after code for each test
- Add a note: "This is a dry run. No code changes were made. Run the workflow again with `dry_run: false` to create a PR with these fixes."

## Important Guidelines

### Safety

- **NEVER delete a test file**. Only modify individual test methods within files.
- **NEVER delete a test method** unless it is an exact duplicate of another test (Anti-Pattern 8). For duplicates, keep the better-named test and add a comment.
- **NEVER modify production/source code**. Only touch test files.
- **NEVER introduce new dependencies**. Only use assertion libraries and test frameworks already present in the project.
- **NEVER change test infrastructure** (`conftest.py`, `jest.config.*`, `karma.conf.*`, `pom.xml` dependencies, etc.).

### Quality

- **ONLY use existing code in replacements**. Before writing any assertion, verify the method/class exists with grep/glob.
- **Match the coding style** of the existing file: indentation, naming, assertion library, patterns.
- **Ensure syntactic correctness**. Every rewritten test must be valid for the target language.
- **Preserve test intent**. If a test is named `testVinValidation`, the rewritten test should still test VIN validation.
- **Add comments** explaining why a test was rewritten, e.g., `// Rewritten: was trivially true assertion, now tests actual defaults`

### Context Awareness

- Prioritize high-severity fixes first.
- If a test file has 20+ fake tests, fix the worst ones and note the remainder in the PR description.
- For monorepos, group changes by module in the PR description.
- If the project uses a custom test utility class, use it in rewrites.
- Respect existing mocking patterns (Mockito, Moq, Jest mocks, unittest.mock, etc.).

### Error Handling

- If unable to determine the class under test, skip the test and note it in the unfixed section of the report.
- If the source file for the class under test cannot be found, apply Strategy A or B from "Fix Strategies When No Business Logic Exists".
- If `issue_number` is invalid or the issue body cannot be parsed, fall back to full-repository scanning.
- Never fail the workflow — always produce a report even if no fixes could be applied.

## Workflow Steps

1. **Apply inputs**: Read `branch`, `subdirectory`, `language_filter`, `severity_filter`, `dry_run`, and `issue_number` from the GitHub context.

2. **Determine scope**:
   - If `issue_number` is provided: read the issue, extract file paths and test names, scope fixes to those.
   - Otherwise: run full discovery using Adaptive Directory and File Discovery (scoped to `subdirectory` if provided, filtered by `language_filter` if provided).

3. **Discover and analyze test files**: Find all test files, read each, identify fake tests against ALL 10 anti-patterns, classify severity.

4. **Filter by severity**: Keep only tests at or above the `severity_filter` level.

5. **For each fake test — search for business logic**:
   - Identify the class/module under test.
   - Read the source implementation.
   - Search for related validators, services, repositories, controllers.
   - Build a context map of what exists.

6. **Rewrite each fake test**:
   - Apply the appropriate fix strategy based on the anti-pattern.
   - Use ONLY methods and classes that exist in the codebase.
   - Follow all Rewrite Rules (1–10).
   - Follow language-specific guidelines.
   - Write each rewritten test file to the local workspace using bash.

7. **Compile and validate all changes** (Phase 3.5):
   - For each affected module, run the test suite: `mvn test --settings $MAVEN_SETTINGS -pl <module> -B`
   - If compilation errors: fix the rewritten test, retry up to 3 times. If still failing, revert that file.
   - If test assertion failures: adjust test expectations and retry up to 2 times.
   - Run the full build: `mvn test --settings $MAVEN_SETTINGS -B` to ensure no cross-module regressions.
   - **Do NOT proceed until all tests compile and pass.**

8. **Check dry_run**:
   - If `dry_run` is `true`: Create an issue with the dry-run report (proposed changes without creating a PR). **Stop here.**
   - If `dry_run` is `false`: Continue to step 9.

9. **Create pull request with validated changes**: Use **create-pull-request** safe-output to create the PR. This safe-output handles branch creation, file commits, and PR creation as a single atomic operation — **do NOT manually create branches, push commits, or call git commands**. Provide all modified test files that passed compilation/tests with their full updated content, the base branch, a commit message, and the PR title/body following the template in Phase 4.

10. **Post summary comment**: If `issue_number` was provided, use **add-comment** safe-output to comment on the source issue linking to the newly created PR.

Start fixing now!

Thanks
Raj