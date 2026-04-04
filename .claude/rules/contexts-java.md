---
paths:
  - "pom.xml"
  - "build.gradle"
  - "build.gradle.kts"
  - "**/*.java"
---

# Context: Java

## When to use
- `project.language == Java`

## How to apply
- Follow the repo's existing build tool configuration (Maven or Gradle); do not guess.
- Prefer JUnit 5 for unit/integration tests and Mockito for mocking.
- Keep tests deterministic (no wall-clock dependent assertions; use fixed clocks/mocks when needed).
- Place business logic in service/application layers; keep controllers thin.
- Follow existing exception-to-error mapping patterns so API errors remain consistent.

## What not to do
- Do not add new production dependencies without explicit approval.
- Do not modify production code unless the task requires it.
- Do not create tests that assert internal implementation details; assert externally observable behavior.

