# Context: Dotnet

## When to use
- `project.language == Dotnet`

## How to apply
- Follow the repo's existing .NET project layout and build system (`*.csproj`, solution files, CI scripts); do not guess.
- Prefer the repo's current unit test framework (commonly xUnit/NUnit/MSTest) and mocking library (commonly Moq).
- Keep tests deterministic (avoid real network/clock dependencies; use fakes/mocks).
- Place business logic in service layers; keep API/controller layers minimal.
- Apply the repo's existing error handling conventions so API responses are consistent.

## What not to do
- Do not add new production dependencies without explicit approval.
- Do not modify production code unless the task explicitly requires it.
- Do not create tests that assert internal state transitions that are not part of the public contract.

