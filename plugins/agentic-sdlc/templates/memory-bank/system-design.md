<!--
How to use: Copy to your repo's ./memory/ directory.
The scaffold-memory skill auto-creates this; use this template if scaffolding manually.
Updated by session-wrap-up after stories that change system architecture.
Note: this is the PERSISTENT high-level view. The per-story ./context/architecture.md
is the detailed ephemeral design artifact that feeds into this file.
-->

# System Design

Cumulative architecture knowledge. Updated when design-impacting stories complete.

## Components

{{ASCII_OR_MERMAID_COMPONENT_DIAGRAM}}

## Data Flow

1. {{FLOW_1_DESCRIPTION}}
2. {{FLOW_2_DESCRIPTION}}

## Integration Points

| Boundary | Protocol | Auth | Notes |
|----------|----------|------|-------|
| {{BOUNDARY_1}} | {{PROTOCOL_1}} | {{AUTH_1}} | {{NOTES_1}} |

## Security Boundaries

- **Public zone**: {{PUBLIC_ENDPOINTS}}
- **Authenticated zone**: {{AUTHED_ENDPOINTS}}
- **Secrets**: {{HOW_SECRETS_ARE_MANAGED}}
