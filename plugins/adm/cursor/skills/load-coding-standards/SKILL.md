---
name: load-coding-standards
description: Detects languages and frameworks in the workspace, then fetches appropriate instruction files for coding standards. Use when implementing features, generating tests, or ensuring code follows project standards.
---

# Load Coding Standards Skill

## Purpose

Combines language detection and instruction file retrieval into a single workflow. Analyzes the workspace to identify languages and frameworks, then loads the appropriate coding standards using a local-first strategy with GitHub fallback.

**Use this skill when:**
- Starting development on a new story (to load relevant coding standards)
- Implementing code in a specific language (TypeScript, Java, Python, etc.)
- Generating tests (to load test-specific instructions)
- Need to ensure code follows project standards

## Algorithm

### Step 1: Scan Build Configuration Files

Check for language-specific configuration files in priority order:

**JavaScript/TypeScript:** `package.json`, `tsconfig.json`, `.ts`, `.tsx`, `.js`, `.jsx` files

**Java:** `pom.xml`, `build.gradle`, `build.gradle.kts`, `.java` files, `src/main/java/` directory

**Python:** `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile`, `.py` files

**Go:** `go.mod`, `.go` files

**C#/.NET:** `.csproj`, `.sln`, `.vbproj`, `.cs` files

### Step 2: Analyze Dependencies for Frameworks

For detected languages, scan dependency files for framework indicators:

**JavaScript/TypeScript Frameworks:** React (`react` in package.json), Angular (`@angular/core`), Express (`express`), Next.js (`next`)

**Java Frameworks:** Spring Boot (`spring-boot-starter` in pom.xml), Jakarta (`jakarta.servlet`)

**Python Frameworks:** Django (`django`), Flask (`flask`), FastAPI (`fastapi`)

### Step 3: Map to Instruction Files

Based on detected languages/frameworks, determine which instruction files are needed:

**Always Required:**
- `architecture-coding-standards.instructions.md` - Core principles (Library-First, CLI-First, TDD)

**Language-Specific:**
- TypeScript → `typescript.instructions.md`
- Java → `java.instructions.md`
- Python → `python.instructions.md`
- Go → `go.instructions.md`

**Framework-Specific:**
- Spring Boot → `springboot.instructions.md`
- Angular → `angular.instructions.md`
- React → `reactjs.instructions.md`

**Test-Specific (if requested):**
- TypeScript tests → `typescript-tests.instructions.md`
- Java tests → `java-tests.instructions.md`
- Python tests → `python-tests.instructions.md`
- Integration tests → `integration-tests.instructions.md`
- Functional tests → `functional-tests.instructions.md`

### Step 4: Fetch Instruction Files (Local-First Strategy)

For each required instruction file:

1. **Check if file exists locally**: `.github/instructions/{filename}`
2. **If exists**: Use local file (no action needed)
3. **If missing**: Fetch from remote repository:
   - Repository: `GeneralMotors-IT/GPSCBox_229577_context_engineering`
   - Path: `instructions/{filename}`
   - Use GitHub MCP tool: `get_file_contents`
   - Save locally to: `.github/instructions/{filename}`

### Step 5: Report Back

Tell the agent what happened:
- Languages and frameworks detected
- Which instruction files were already available locally
- Which files were fetched from GitHub
- Any files that failed to fetch (with specific error)
- Confirm all required instruction files are now ready

**Example report:**
```
Detected: TypeScript with React framework

✅ Instruction files ready:
- architecture-coding-standards.instructions.md (local)
- typescript.instructions.md (local)
- reactjs.instructions.md (fetched from GitHub)
```

## When Invoked

Agents call this skill with natural language:

- "Load coding standards for this project"
- "Load coding standards including test instructions"
- "Detect languages and load instruction files"

The skill determines languages automatically and reports back naturally.

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| No languages detected | Empty or non-project directory | Return success with core architecture standards only |
| GitHub Fetch Fails | GitHub MCP unavailable or network issue | Report error with specific file that failed |
| GitHub MCP Not Available | GitHub MCP server not configured | Stop execution, report MCP configuration issue |
| File Write Failure | Permission or disk issue | Report permission error, check directory permissions |
