---
description: |
  Upgrades Angular applications in the repository from any detected (or specified) version
  to a designated target version. Reads the appropriate migration guides for each version hop,
  updates dependencies and code, verifies compilation and tests, then creates a pull request
  with all changes.

  CRITICAL CONSTRAINT: ALL dependency version changes in package.json MUST be made via bash
  commands (ng update, npm install). NEVER directly edit package.json to change version numbers
  using file-editing tools. Previous runs failed with ERESOLVE because package.json was edited
  directly instead of using ng update. The ng update command resolves peer dependencies and runs
  migration schematics automatically — manual edits bypass both.

on:
  workflow_dispatch:
    inputs:
      target-version:
        description: Target Angular major version (e.g. 17, 18, 19, 20, 21)
        required: false
        default: "20"
      current-version:
        description: Current Angular major version (leave empty to auto-detect from package.json)
        required: false
        default: ""
      node-version:
        description: Node.js version for the target Angular (auto-selected if empty)
        required: false
        default: ""
      agent-pool:
        description: Agent pool (non-prod or prod)
        required: true
        type: choice
        options:
          - "GM-IT-DEV-Ubuntu-Latest-64"
          - "GM-IT-PROD-Ubuntu-Latest-64"
        default: "GM-IT-DEV-Ubuntu-Latest-64"

runs-on: ${{ inputs.agent-pool }}

permissions:
  contents: read
  pull-requests: read
  issues: read
  actions: read
  id-token: write

env:
  ARTIFACTORY_URL: 'https://artifactory-ci.gm.com'
  JFROG_CLI_PROJECT: ${{ vars.JFROG_CLI_PROJECT }}

network:
  allowed:
    - defaults
    - github
    - python
    - "angular.dev"
    - "update.angular.dev"
    - "api.github.com"
    - "artifactory-ci.gm.com"
    - "registry.npmjs.org"
    - "v2.angular.dev"
    - "blog.angular.dev"

engine: copilot

sandbox:
  type: default
  agent: false
strict: false

safe-outputs:
  threat-detection: false
  create-pull-request:
    draft: true
    labels: [automation, angular-upgrade]
    github-token: ${{ secrets.GITHUB_TOKEN }}
    base-branch: ${{ github.ref_name || github.event.repository.default_branch }}
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
  glob: true
  web-fetch: {}

mcp-servers:
  jfrog:
    container: "node:lts"
    entrypointArgs:
      - npx
      - -y
      - github:jfrog/mcp-jfrog
    env:
      JFROG_URL: ${{ env.ARTIFACTORY_URL }}
      JFROG_ACCESS_TOKEN: ${{ secrets.ARTIFACTORY_ACCESS_TOKEN }}
    allowed:
      - jfrog_get_package_info
      - jfrog_get_package_versions
      - jfrog_execute_aql_query
      - jfrog_list_repositories

timeout-minutes: 180

steps:
  - name: Checkout repository
    uses: actions/checkout@v4
    with:
      token: ${{ secrets.GITHUB_TOKEN }}
      persist-credentials: false

  - name: Set up Node.js
    uses: actions/setup-node@v4
    with:
      node-version: ${{ inputs.node-version || (inputs.target-version >= '20' && '22') || (inputs.target-version == '19' && '20') || (inputs.target-version == '18' && '20') || (inputs.target-version == '17' && '18') || (inputs.target-version == '16' && '18') || (inputs.target-version == '15' && '18') || '20' }}
      registry-url: 'https://artifactory-ci.gm.com/artifactory/api/npm/npm-local/'

  - name: Configure npm registry
    run: |
      npm config set registry https://artifactory-ci.gm.com/artifactory/api/npm/npm-local/
      echo "Node version: $(node --version)"
      echo "npm version: $(npm --version)"

  - name: Cache node_modules
    uses: actions/cache@v4
    with:
      path: node_modules
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: ${{ runner.os }}-node

  - name: Protect package.json from direct editing
    run: |
      chmod 444 package.json
      echo "package.json is now read-only (chmod 444)."
      echo "Only ng update and npm install (run via bash) can modify it."
      echo "File-editing tools will get 'Permission denied' if they try to edit package.json."

---

# Angular Version Upgrade

Upgrade Angular applications in `${{ github.repository }}` to Angular `${{ inputs.target-version }}`.

- **Target version**: `${{ inputs.target-version }}`
- **Current version override**: `${{ inputs.current-version }}` (blank = auto-detect)
- **Node.js version override**: `${{ inputs.node-version }}` (blank = auto-select based on target)

---

## ⛔ MANDATORY CONSTRAINTS — READ BEFORE ANY ACTION

These constraints are **absolute and non-negotiable**. Violating any of them will cause the workflow to fail with ERESOLVE errors.

### FORBIDDEN ACTIONS (never do these):

1. **NEVER open `package.json` in an editor and change version numbers.** This includes using `replace_string_in_file`, `create_file`, `edit_file`, `sed`, or any file-editing tool to modify dependency versions in `package.json`. The ONLY tools allowed to modify `package.json` dependency versions are `ng update` and `npm install [package]@[version]` commands run in bash.

2. **NEVER assume a third-party package version exists.** For example, do NOT assume `@ngxs/store@20` exists just because Angular 20 exists. NGXS, ngx-translate, ag-grid, ng2-charts, and all non-`@angular/*` packages use their OWN independent version schemes. You MUST run `npm view [package]@latest version` in bash to verify before updating.

3. **NEVER use `npm install --force`.** It masks real incompatibilities and creates broken `node_modules`.

### REQUIRED ACTIONS (always do these):

1. **ALL Angular package updates MUST use `ng update` commands in bash.** Example: `npx @angular/cli@20 update @angular/core@20 --allow-dirty`. This resolves peer deps, runs migration schematics, and updates `package.json` atomically.

2. **ALL third-party package updates MUST use `npm install [pkg]@[version]` in bash** after verifying the version exists with `npm view`.

3. **After every `ng update` or `npm install` that modifies packages, run this verification:**
   ```bash
   cat package.json | grep -E '"@angular/core"|"@angular/cli"|"typescript"'
   ```
   This confirms the versions were set correctly by the tool, not by manual editing.

4. **Before any `npm install`, always clean first:**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

### WHY: Previous runs failed because `package.json` was manually edited with versions like `@angular-devkit/build-angular@"20.3.22"` alongside `typescript@"~5.7.3"`, causing ERESOLVE conflicts. The `ng update` command would have bumped TypeScript automatically.

### PROTECTION: `package.json` is set to read-only (`chmod 444`) after checkout. If you try to edit it with file-editing tools, you will get "Permission denied". The bash scripts in Steps 4 and 5 temporarily unlock it (`chmod 644`) before running `ng update` / `npm install`, then re-lock it. This is intentional — it prevents the exact failure mode that broke every previous run.

---

## Version reference table

| Angular | Min Node.js | TypeScript | Notes |
|---------|-------------|------------|-------|
| 14      | 14.15       | 4.6–4.8   | Legacy; standalone components preview |
| 15      | 14.20       | 4.8–4.9   | Standalone APIs stable; directive composition API |
| 16      | 16.14       | 4.9–5.1   | Signals preview; required inputs; esbuild builder preview |
| 17      | 18.13       | 5.2–5.2   | New control flow (@if/@for/@switch); deferrable views; esbuild default |
| 18      | 18.19       | 5.4–5.5   | Zoneless preview; material 3 default; @angular/build stable |
| 19      | 18.19       | 5.5–5.7   | Standalone defaults; linkedSignal; resource API preview; incremental hydration |
| 20      | 20.x        | 5.8+       | Zoneless stable; signals stabilized; authoring format (.angular) preview |
| 21      | 22.x        | 5.9+       | Next generation (check official docs for requirements) |

## Operator notes (npm and network)

- **Artifactory npm registry**: `ARTIFACTORY_ACCESS_TOKEN` must authenticate npm registry access for package installs. If `npm install` fails with authentication errors, ensure the token has read access for the npm repositories.
- **Network**: The workflow needs access to `angular.dev` and `update.angular.dev` for official migration guides, `artifactory-ci.gm.com` for npm packages, and `registry.npmjs.org` for npm metadata.

## Critical rules

> **NEVER manually edit version numbers in `package.json`** for Angular packages (`@angular/*`, `@angular-devkit/*`) or their peer dependencies (`typescript`, `zone.js`, `rxjs`). Always use `ng update` which:
> 1. Resolves peer dependencies correctly
> 2. Runs migration schematics that update code automatically
> 3. Updates `package.json` and `package-lock.json` atomically
>
> **Third-party packages do NOT follow Angular's version scheme.** Do NOT assume that `@ngxs/store@20` exists because Angular 20 exists. Always verify with `npm view [package]@latest` before updating.
>
> **ERESOLVE errors** mean npm cannot resolve compatible versions. The fix is almost always: `rm -rf node_modules package-lock.json && npm install`. Never use `--force` on `npm install` — it masks real incompatibilities.
>
> **Transitive peer dependency conflicts** (where a sub-dependency of a third-party package requires an older version of a shared package like `eslint` or `@typescript-eslint/utils`) should be resolved using npm `overrides` in `package.json`. This forces the conflicting transitive dependency to a compatible version without `--force` or `--legacy-peer-deps`. Example:
> ```json
> "overrides": {
>   "@typescript-eslint/utils": "^8.0.0"
> }
> ```
> Only use `overrides` when the newer version is already proven compatible (i.e., every other consumer in the dependency tree already uses it). After adding overrides, always clean install: `rm -rf node_modules package-lock.json && npm install`.

## Steps

### 1. Detect Current Version

Examine `package.json` to identify the current Angular version.

1. **Read the root `package.json`** and look for:
   - `@angular/core` version in `dependencies`.
   - `@angular/cli` version in `devDependencies`.
   - `@angular-devkit/build-angular` or `@angular/build` version in `devDependencies`.
2. **Extract the version**: Parse the Angular version from the `@angular/core` dependency. The version format may include range specifiers (`^`, `~`, `>=`). Strip the range specifier and extract the major version (e.g. `^19.1.6` → major `19`).
3. **Cross-validate**: Confirm that `@angular/cli`, `@angular/compiler-cli`, and other `@angular/*` packages are on the same major version. If there is a mismatch, warn and use the `@angular/core` version as the source of truth.
4. **Validate against input**: If `${{ inputs.current-version }}` is provided, confirm it matches the detected major version. If there is a mismatch, warn and use the `package.json`-detected version as the source of truth.
5. **Detect additional ecosystem details**:
   - **Package manager**: Check for `package-lock.json` (npm), `yarn.lock` (Yarn), or `pnpm-lock.yaml` (pnpm).
   - **Build system**: Check `angular.json` for `builder` — `@angular-devkit/build-angular:application` (esbuild), `@angular-devkit/build-angular:browser` (webpack legacy), or `@angular/build:application`.
   - **Test runner**: Check for `jest.config.js`/`jest.config.ts` (Jest) or `karma.conf.js` (Karma).
   - **State management**: Check for `@ngxs/store`, `@ngrx/store`, or similar.
   - **UI library**: Check for `@angular/material`, `@angular/cdk`, `ag-grid-angular`, or similar.
6. **Record the detected current version and ecosystem details** for use in all subsequent steps.

### 2. Determine Upgrade Path

Based on the detected current version and `${{ inputs.target-version }}`, determine the upgrade path.

**Angular's recommended approach is to upgrade one major version at a time.** The Angular CLI `ng update` command is designed for single-version hops. Multi-version jumps are supported by chaining sequential updates.

| From | To | Upgrade path |
|------|----|-------------|
| Any  | Current+1 | Direct: single `ng update` hop |
| Any  | Current+2 | Two hops: e.g. 17 → 18 → 19 |
| Any  | Current+3 | Three hops: e.g. 16 → 17 → 18 → 19 |
| Any  | Current+N | N hops: upgrade one major version at a time |
| 14   | 17  | Three hops: 14 → 15 → 16 → 17 |
| 15   | 18  | Three hops: 15 → 16 → 17 → 18 |
| 16   | 19  | Three hops: 16 → 17 → 18 → 19 |
| 17   | 20  | Three hops: 17 → 18 → 19 → 20 |
| 18   | 20  | Two hops: 18 → 19 → 20 |
| 19   | 20  | Direct: 19 → 20 |
| 19   | 21  | Two hops: 19 → 20 → 21 |

**Important**: Always use the Angular Update Guide at https://update.angular.dev/ to confirm the recommended upgrade path between any two versions. The guide provides version-specific instructions and automated migration schematics.

For each hop in the path, record the intermediate target version. Each hop will go through steps 3–6 sequentially before proceeding to the next hop.

### 3. Read Migration Guides

For each hop in the upgrade path, read the relevant migration resources:

1. **Angular Update Guide**: Fetch https://update.angular.dev/ — select the "from" and "to" versions for the current hop. This provides the canonical list of breaking changes, deprecations, and required migration steps.
2. **Angular Blog**: Read the release announcement for each target version at https://blog.angular.dev/ for context on new features and breaking changes.
3. **Official documentation**: Read https://angular.dev/reference/migrations for available automatic migration schematics.
4. **Angular Material**: If the project uses `@angular/material`, read the Angular Material changelog for the corresponding version at https://github.com/angular/components/blob/main/CHANGELOG.md.
5. **Third-party library guides**: For major dependencies like `@ngxs/store`, `ag-grid-angular`, `angular-oauth2-oidc`, check their changelogs/migration guides for the target Angular version compatibility.

Record all breaking changes, deprecation warnings, and required migration steps for each hop.

### 4. Update Angular Core Packages

For each hop in the upgrade path, update all Angular core packages by running the following **single bash script**. Replace `TARGET_MAJOR` with the target major version for the current hop (e.g. `20`).

**You MUST run this as a bash script. Do NOT manually edit `package.json` — the `ng update` commands inside this script will update `package.json` automatically and also run migration schematics that update source code.**

Copy this entire script into a single bash execution block and run it:

```bash
#!/bin/bash
set -euo pipefail

# ==============================================================
# Angular Core Upgrade Script
# Set TARGET_MAJOR to the version you are upgrading TO for this hop
# ==============================================================
TARGET_MAJOR=20

echo "========================================="
echo "UPGRADING ANGULAR CORE TO VERSION ${TARGET_MAJOR}"
echo "========================================="

# 4a. Unlock package.json and clean state
echo ">>> Step 4a: Unlocking package.json and cleaning node_modules..."
chmod 644 package.json
rm -rf node_modules package-lock.json
npm install
echo ">>> Current versions before upgrade:"
cat package.json | grep -E '"@angular/core"|"@angular/cli"|"@angular-devkit/build-angular"|"typescript"'

# 4b. Update Angular CLI
echo ""
echo ">>> Step 4b: Updating @angular/cli..."
npx @angular/cli@${TARGET_MAJOR} update @angular/cli@${TARGET_MAJOR} --allow-dirty || {
  echo ">>> CLI update failed, retrying with --force..."
  rm -rf node_modules package-lock.json
  npm install
  npx @angular/cli@${TARGET_MAJOR} update @angular/cli@${TARGET_MAJOR} --allow-dirty --force
}

# 4c. Update Angular Core
echo ""
echo ">>> Step 4c: Updating @angular/core..."
npx @angular/cli@${TARGET_MAJOR} update @angular/core@${TARGET_MAJOR} --allow-dirty || {
  echo ">>> Core update failed, retrying with --force..."
  rm -rf node_modules package-lock.json
  npm install
  npx @angular/cli@${TARGET_MAJOR} update @angular/core@${TARGET_MAJOR} --allow-dirty --force
}

# 4d. Update Angular Material/CDK if present
if grep -q '"@angular/material"' package.json; then
  echo ""
  echo ">>> Step 4d: Updating @angular/material and @angular/cdk..."
  npx @angular/cli@${TARGET_MAJOR} update @angular/cdk@${TARGET_MAJOR} @angular/material@${TARGET_MAJOR} --allow-dirty || {
    echo ">>> Material update failed, retrying with --force..."
    npx @angular/cli@${TARGET_MAJOR} update @angular/cdk@${TARGET_MAJOR} @angular/material@${TARGET_MAJOR} --allow-dirty --force
  }
fi

# 4e. Update build packages
if grep -q '"@angular-devkit/build-angular"' package.json; then
  echo ""
  echo ">>> Step 4e: Updating @angular-devkit/build-angular..."
  npx @angular/cli@${TARGET_MAJOR} update @angular-devkit/build-angular@${TARGET_MAJOR} --allow-dirty || true
fi
if grep -q '"@angular/build"' package.json; then
  echo ""
  echo ">>> Step 4e: Updating @angular/build..."
  npx @angular/cli@${TARGET_MAJOR} update @angular/build@${TARGET_MAJOR} --allow-dirty || true
fi

# 4f. Update Angular ESLint if present
if grep -q '"@angular-eslint"' package.json; then
  echo ""
  echo ">>> Step 4f: Updating @angular-eslint..."
  npx @angular/cli@${TARGET_MAJOR} update @angular-eslint/schematics@${TARGET_MAJOR} --allow-dirty || true
fi

# 4g. Clean install and verify
echo ""
echo ">>> Step 4g: Clean install after core updates..."
rm -rf node_modules package-lock.json
npm install

# 4g-post. Lock package.json again to prevent direct editing
echo ""
echo ">>> Locking package.json (chmod 444)..."
chmod 444 package.json

echo ""
echo "========================================="
echo "VERIFICATION: package.json versions after core upgrade"
echo "========================================="
cat package.json | grep -E '"@angular|"typescript"|"zone.js"|"rxjs"' | head -25
echo "========================================="
echo "CORE UPGRADE COMPLETE"
echo "========================================="
```

**After running the script**: Read the VERIFICATION output at the bottom. Confirm that:
- `@angular/core` is on version `${TARGET_MAJOR}.x.x`
- `@angular/cli` is on version `${TARGET_MAJOR}.x.x`
- `typescript` was bumped to the appropriate version (see version reference table)
- `npm install` completed without ERESOLVE errors

If `npm install` at step 4g fails with ERESOLVE, the conflicting package needs updating in Step 5. Temporarily use `npm install --legacy-peer-deps` and proceed to Step 5.

#### 4g. Clean install and verify after core update

After all `ng update` commands complete for this hop, run **in bash**:

```bash
# Step 4g: Clean install
rm -rf node_modules package-lock.json
npm install

# Verify: show what ng update changed in package.json
echo "=== VERIFICATION: Current package.json versions ==="
cat package.json | grep -E '"@angular|"typescript"|"zone.js"|"rxjs"' | head -20
echo "=== END VERIFICATION ==="
```

**Check the verification output**: Confirm that `@angular/core`, `@angular/cli`, `@angular-devkit/build-angular`, and `typescript` are all on the target major version. If they are not, one of the `ng update` commands in steps 4b–4f did not run correctly — re-run it.

If `npm install` fails with ERESOLVE errors at this point:
1. Read the error to identify which package has a conflicting peer dependency.
2. That package likely needs updating in step 5 (third-party dependencies).
3. Temporarily run `npm install --legacy-peer-deps` to proceed, then fix the conflicting package in step 5.
4. After fixing, do a final clean `rm -rf node_modules package-lock.json && npm install` (without `--legacy-peer-deps`) to verify resolution is clean.

### 5. Update Third-Party Dependencies (BASH ONLY)

After the core Angular upgrade in Step 4, update third-party dependencies for compatibility.

**You MUST use bash `npm install` commands to update dependencies. Do NOT manually edit `package.json`.**

Run the following bash script to discover compatible versions and update each third-party dependency:

```bash
#!/bin/bash
set -uo pipefail

TARGET_MAJOR=20

echo "========================================="
echo "UPDATING THIRD-PARTY DEPENDENCIES"
echo "========================================="

# Unlock package.json for npm install commands
echo ">>> Unlocking package.json for third-party updates..."
chmod 644 package.json

# Helper function: safely update a dependency
safe_update() {
  local PKG=$1
  local SAVE_FLAG=${2:---save}  # --save or --save-dev
  local LATEST_VER

  echo ""
  echo ">>> Checking ${PKG}..."
  LATEST_VER=$(npm view "${PKG}@latest" version 2>/dev/null || echo "NOT_FOUND")

  if [ "$LATEST_VER" = "NOT_FOUND" ]; then
    echo "    SKIPPED: ${PKG}@latest not found on registry"
    return 1
  fi

  echo "    Latest version: ${LATEST_VER}"
  echo "    Peer dependencies:"
  npm view "${PKG}@${LATEST_VER}" peerDependencies 2>/dev/null || echo "    (none)"

  echo "    Installing ${PKG}@${LATEST_VER}..."
  npm install "${PKG}@${LATEST_VER}" ${SAVE_FLAG} 2>&1 || {
    echo "    WARNING: npm install failed for ${PKG}@${LATEST_VER}, trying --legacy-peer-deps..."
    npm install "${PKG}@${LATEST_VER}" ${SAVE_FLAG} --legacy-peer-deps 2>&1 || {
      echo "    ERROR: Could not install ${PKG}@${LATEST_VER}"
      return 1
    }
  }
  echo "    SUCCESS: ${PKG}@${LATEST_VER} installed"
}

# 5a. NGXS packages (if present)
if grep -q '"@ngxs/store"' package.json; then
  echo ""
  echo "--- NGXS Packages ---"
  # NGXS has its own versioning - check what's available for this Angular
  echo "Available @ngxs/store versions:"
  npm view @ngxs/store versions --json 2>/dev/null | tail -5
  safe_update "@ngxs/store" "--save"
  safe_update "@ngxs/storage-plugin" "--save"
  safe_update "@ngxs/devtools-plugin" "--save-dev"
fi

# 5b. Translation packages
if grep -q '"@ngx-translate/core"' package.json; then
  echo ""
  echo "--- ngx-translate ---"
  safe_update "@ngx-translate/core" "--save"
  safe_update "@ngx-translate/http-loader" "--save"
fi

# 5c. OAuth
if grep -q '"angular-oauth2-oidc"' package.json; then
  echo ""
  echo "--- angular-oauth2-oidc ---"
  safe_update "angular-oauth2-oidc" "--save"
fi

# 5d. AG Grid
if grep -q '"ag-grid-angular"' package.json; then
  echo ""
  echo "--- AG Grid ---"
  safe_update "ag-grid-angular" "--save"
  safe_update "ag-grid-community" "--save"
fi

# 5e. Charts
if grep -q '"@swimlane/ngx-charts"' package.json; then
  echo ""
  echo "--- ngx-charts ---"
  safe_update "@swimlane/ngx-charts" "--save"
fi
if grep -q '"ng2-charts"' package.json; then
  echo ""
  echo "--- ng2-charts ---"
  safe_update "ng2-charts" "--save"
fi

# 5f. Jest (devDependency)
if grep -q '"jest-preset-angular"' package.json; then
  echo ""
  echo "--- jest-preset-angular ---"
  safe_update "jest-preset-angular" "--save-dev"

  # jest-preset-angular 16+ requires Jest 30. Check if bump is needed:
  JPA_VER=$(npm view jest-preset-angular version 2>/dev/null || echo "")
  JPA_MAJOR=$(echo "$JPA_VER" | cut -d. -f1)
  if [ "$JPA_MAJOR" -ge 16 ] 2>/dev/null; then
    echo "jest-preset-angular >= 16 requires jest ^30.0.0"
    safe_update "jest" "--save-dev"
    safe_update "jest-environment-jsdom" "--save-dev"
  fi
fi

# 5g. RxJS and zone.js - check Angular's peer dependency requirements
echo ""
echo "--- RxJS and zone.js ---"
echo "Angular ${TARGET_MAJOR} peer dependency requirements:"
npm view "@angular/core@${TARGET_MAJOR}" peerDependencies 2>/dev/null || echo "(could not fetch)"

REQUIRED_RXJS=$(npm view "@angular/core@${TARGET_MAJOR}" peerDependencies.rxjs 2>/dev/null || echo "")
REQUIRED_ZONEJS=$(npm view "@angular/core@${TARGET_MAJOR}" peerDependencies.zone.js 2>/dev/null || echo "")

if [ -n "$REQUIRED_RXJS" ]; then
  echo "Required rxjs: ${REQUIRED_RXJS}"
  RXJS_LATEST=$(npm view "rxjs@${REQUIRED_RXJS}" version 2>/dev/null | tail -1 || echo "")
  if [ -n "$RXJS_LATEST" ]; then
    echo "Installing rxjs@${RXJS_LATEST}..."
    npm install "rxjs@${RXJS_LATEST}" --save 2>&1 || echo "WARNING: rxjs install failed"
  fi
fi

if [ -n "$REQUIRED_ZONEJS" ]; then
  echo "Required zone.js: ${REQUIRED_ZONEJS}"
  ZONEJS_LATEST=$(npm view "zone.js@${REQUIRED_ZONEJS}" version 2>/dev/null | tail -1 || echo "")
  if [ -n "$ZONEJS_LATEST" ]; then
    echo "Installing zone.js@${ZONEJS_LATEST}..."
    npm install "zone.js@${ZONEJS_LATEST}" --save 2>&1 || echo "WARNING: zone.js install failed"
  fi
fi

# 5h. Internal packages - check with npm view (or use JFrog MCP for Artifactory)
echo ""
echo "--- Internal packages ---"
if grep -q '"@fabric/components"' package.json; then
  echo "Checking @fabric/components..."
  npm view @fabric/components@latest version 2>/dev/null || echo "@fabric/components: not found on public registry (check Artifactory)"
fi
if grep -q '"@ux-foundry/eslint-config-angular"' package.json; then
  echo "Checking @ux-foundry/eslint-config-angular..."
  npm view @ux-foundry/eslint-config-angular@latest version 2>/dev/null || echo "@ux-foundry/eslint-config-angular: not found on public registry (check Artifactory)"
fi

# 5i. Final clean install
echo ""
echo ">>> Final clean install..."

# 5i-pre. Add overrides for known transitive peer dependency conflicts
# eslint-plugin-vitest@0.3.x depends on @typescript-eslint/utils@^7.x which requires ESLint 8,
# but the project uses ESLint 9. Force all @typescript-eslint/utils to v8+ via overrides.
if grep -q '"eslint-plugin-vitest"' package.json && ! grep -q '"overrides"' package.json; then
  echo ">>> Adding npm overrides for @typescript-eslint/utils peer dep conflict..."
  # Insert overrides before the closing brace of package.json
  node -e "
    const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
    if (!pkg.overrides) pkg.overrides = {};
    pkg.overrides['@typescript-eslint/utils'] = '^8.0.0';
    require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\\n');
    console.log('Added overrides to package.json');
  "
fi

rm -rf node_modules package-lock.json
npm install 2>&1

# Lock package.json again after all updates
echo ">>> Locking package.json (chmod 444)..."
chmod 444 package.json

echo ""
echo "========================================="
echo "VERIFICATION: Final dependency versions"
echo "========================================="
cat package.json | grep -E '"@angular|"typescript"|"@ngxs|"rxjs"|"zone.js"|"ag-grid|"jest-preset-angular"|"@ngx-translate"' | head -30
echo ""
echo "========================================="
echo "THIRD-PARTY UPDATE COMPLETE"
echo "========================================="
```

**After running the script**: Review the output carefully:
- Check which packages were successfully updated and which failed
- If `npm install` fails at the end with ERESOLVE, identify the conflicting package from the error
- For internal packages not found in the public registry, use the JFrog MCP tool `jfrog_get_package_versions` to find available versions, then run: `npm install @package/name@version --save`
- If needed, temporarily use `npm install --legacy-peer-deps` and document this in the PR

### 6. Apply Version-Specific Changes

Apply changes based on the version boundary being crossed. **Only apply sections that are relevant to the detected upgrade path.** If a section does not apply to this transition, skip it.

#### 6a. Changes for crossing 14 → 15 boundary

- **Standalone components**: `@Component({ standalone: true })` is now stable. No forced migration, but begin planning transition from NgModules.
- **Directive composition API**: `hostDirectives` property available on `@Component` and `@Directive`.
- **Image directive**: `NgOptimizedImage` is stable. Consider migrating `<img>` tags to use it.
- **Router**: `RouterModule.forRoot()` guards and resolvers now support functional patterns. Migrate class-based guards to functional guards.
- **MDC-based Material components**: Angular Material completes migration to MDC (Material Design Components). Custom CSS overrides targeting old class names (e.g. `mat-form-field`) may need updating to new MDC class names.

#### 6b. Changes for crossing 15 → 16 boundary

- **Required inputs**: Components can now mark inputs as `required`. No breaking change, but schematics may update code.
- **Signals (preview)**: Signals API introduced as developer preview. No migration required.
- **Router**: `withComponentInputBinding()` enables route params as component inputs. Consider adopting.
- **DestroyRef**: `DestroyRef` is available as an alternative to `takeUntilDestroyed`. Consider migrating.
- **esbuild builder (preview)**: `@angular-devkit/build-angular:browser-esbuild` available as opt-in alternative to webpack.
- **TypeScript 5.0+**: Required. Update `tsconfig.json` if needed.
- **Node.js 16+**: Required minimum.

#### 6c. Changes for crossing 16 → 17 boundary

- **New control flow syntax**: Angular 17 introduces `@if`, `@for`, `@switch`, `@defer` as built-in template syntax replacing `*ngIf`, `*ngFor`, `*ngSwitch`. Run the automatic migration schematic:
  ```bash
  ng generate @angular/core:control-flow
  ```
  This migrates all templates from structural directives to the new control flow syntax. If the automatic migration does not cover all cases, manually update remaining templates.
- **Deferrable views**: `@defer` blocks enable lazy-loading of component subtrees. No forced migration but available for optimization.
- **esbuild as default**: New projects use esbuild by default. Existing projects should migrate from `@angular-devkit/build-angular:browser` to `@angular-devkit/build-angular:application`:
  - In `angular.json`, change `builder` from `@angular-devkit/build-angular:browser` to `@angular-devkit/build-angular:application`.
  - Replace `"main"` with `"browser"` in the build options.
  - Remove webpack-specific options that are not supported by the application builder.
- **View Transitions**: `withViewTransitions()` available for router. Optional adoption.
- **Standalone APIs are emphasized**: While NgModules still work, the ecosystem is shifting to standalone. Non-breaking but consider migration.
- **Node.js 18.13+**: Required minimum.
- **TypeScript 5.2+**: Required.

#### 6d. Changes for crossing 17 → 18 boundary

- **Material 3 as default**: `@angular/material` defaults to Material 3 design. If the project uses Material 2 theming:
  - Custom themes need migration. Run the Material 3 migration schematic if available.
  - CSS custom properties change. Review all component-specific style overrides.
  - If not ready for M3, the M2 theme can be temporarily restored using `@angular/material/theming` backward-compat mixins.
- **Zoneless change detection (preview)**: `provideExperimentalZonelessChangeDetection()` available. No forced migration.
- **`@angular/build` stable**: The new `@angular/build` package is the recommended builder. Consider migrating from `@angular-devkit/build-angular`.
- **Signal inputs stable**: `input()`, `input.required()` function-based inputs are stable. Consider migrating `@Input()` decorators.
- **Signal queries stable**: `viewChild()`, `viewChildren()`, `contentChild()`, `contentChildren()` are stable.
- **Route redirects with functions**: `redirectTo` can now be a function. Useful for dynamic redirects.
- **Fallback content for ng-content**: `<ng-content>` supports default/fallback content.
- **TypeScript 5.4+**: Required.
- **Node.js 18.19+**: Required minimum.

#### 6e. Changes for crossing 18 → 19 boundary

- **Standalone defaults**: New components are standalone by default. `standalone: true` is the default and can be omitted. `standalone: false` must be explicitly set for NgModule-declared components.
- **Strict standalone enforcement**: If the project still has NgModule-based components, they must explicitly declare `standalone: false`.
- **`linkedSignal`**: New reactive primitive for derived state with writability. Available for adoption.
- **`resource` API (preview)**: Async data loading reactive primitive. Optional adoption.
- **Incremental hydration**: For SSR applications, `@defer` blocks can hydrate incrementally.
- **`effect()` no longer requires `allowSignalWrites`**: The restriction on writing signals inside effects has been removed.
- **TypeScript 5.5+**: Required.
- **`@angular/material` 19**: Renaming of Material component prefixes and API refinements. Review for any custom selectors or class references.
- **Karma deprecation**: Karma is officially deprecated. Migrate to Jest, Web Test Runner, or another test framework if still on Karma.

#### 6f. Changes for crossing 19 → 20 boundary

- **Zoneless change detection stable**: `provideZonelessChangeDetection()` is stable (no longer experimental). Consider migrating from zone.js:
  - Replace `provideExperimentalZonelessChangeDetection()` with `provideZonelessChangeDetection()`.
  - Remove `zone.js` from `polyfills` in `angular.json` if adopting zoneless.
  - Remove `zone.js` from `package.json` dependencies if fully zoneless.
  - Audit all components for proper change detection — ensure all state changes go through signals or explicitly call `ChangeDetectorRef.markForCheck()`.
- **Signal-based forms (if introduced)**: Check official docs for reactive forms signal integration.
- **Auth and HTTP changes**: Review `HttpClient` interceptor API for any updates.
- **`@angular/build` as primary**: `@angular-devkit/build-angular` may be fully deprecated. Migrate to `@angular/build`.
- **TypeScript 5.8+**: Required.
- **Node.js 20+**: Required minimum.
- **RxJS compatibility**: Verify RxJS version compatibility.
- **ng2-charts v9 breaking change**: `NgChartsModule` has been **removed** in `ng2-charts` v9+. Replace all imports of `NgChartsModule` with `BaseChartDirective` (a standalone directive). This affects:
  - Component TypeScript files: change `import { BaseChartDirective, NgChartsModule } from 'ng2-charts'` → `import { BaseChartDirective } from 'ng2-charts'`
  - Component `imports` arrays: replace `NgChartsModule` with `BaseChartDirective`
  - Test spec files: same import change in `TestBed.configureTestingModule({ imports: [...] })`
  Search the codebase with: `grep -rn 'NgChartsModule' src/` and fix every occurrence.
- **`eslint-plugin-vitest` peer dependency conflict**: `@ux-foundry/eslint-config-angular` (v7.x) pulls in `eslint-plugin-vitest@0.3.26`, which depends on `@typescript-eslint/utils@^7.x`. That v7 utils package has a peer dependency on ESLint 8, conflicting with ESLint 9 used in Angular 20 projects. Every other package in the tree already uses `@typescript-eslint/utils@8.x`. Fix by adding an npm `overrides` section to `package.json`:
  ```json
  "overrides": {
    "@typescript-eslint/utils": "^8.0.0"
  }
  ```
  Then clean install: `rm -rf node_modules package-lock.json && npm install`. Verify with `npm ls @typescript-eslint/utils` — all instances should resolve to v8.x with no v7.x remnants.
- **AG Grid 35 + jsdom `CSS.escape()` issue**: AG Grid 35.x calls `CSS.escape()` during initialization. jsdom does not implement `CSS.escape()`. If the project mocks `window.CSS` as `null` in the Jest setup file (common pattern), tests will crash with `TypeError: Cannot read properties of null (reading 'escape')`. Fix by replacing the mock:
  ```typescript
  // BEFORE (breaks AG Grid 35):
  Object.defineProperty(window, 'CSS', { value: null });
  // AFTER (works with AG Grid 35):
  Object.defineProperty(window, 'CSS', {
    value: { supports: () => false, escape: (s: string) => s },
  });
  ```
- **AG Grid in Jest transform patterns**: AG Grid 35 ships ESM. Add `ag-grid-community` and `ag-grid-angular` to `transformIgnorePatterns` in `jest.config.js`:
  ```javascript
  transformIgnorePatterns: [
    '/node_modules/(?!ng2-charts|chart.js|lodash-es|@angular|ag-grid-community|ag-grid-angular).+\\.js$'
  ]
  ```
- **@swimlane/ngx-charts 23**: Version 22.x only supports Angular <=19. Upgrade to `@swimlane/ngx-charts@^23.0.0` for Angular 20 peer dependency support.

#### 6g. Changes for crossing 20 → 21 boundary

- **Check official Angular 21 release notes** at https://blog.angular.dev/ and https://angular.dev/ for breaking changes.
- **TypeScript 5.9+**: Likely required.
- **Node.js 22+**: Likely required minimum.
- **Review all deprecated API removals**: APIs deprecated in Angular 18/19/20 may be removed in 21. Search the codebase for deprecation warnings and replace with recommended alternatives.
- Consult the Angular Update Guide at https://update.angular.dev/ for the complete migration checklist.

### 6.5. Update CI, Docker, and Documentation Files

After applying all version-specific code and dependency changes, scan the repository for non-`package.json` files that reference the Node.js version or contain version-sensitive configuration. Update them to match the target.

#### A. GitHub Actions workflow files (`.github/workflows/*.yml`)

- Scan all `.yml` files under `.github/workflows/` for `node-version:` in `actions/setup-node` steps.
- Update the `node-version` value to match the minimum Node.js version for the target Angular (see version reference table).
- If `setup-node` uses an outdated action version (e.g. `@v3`), update to `@v4`.
- **Permissions note**: Pushing changes to `.github/workflows/` files requires the `GHAW_TOKEN` (with `workflows` scope). If the push fails due to insufficient permissions, document the required workflow file changes in the PR description as a manual step for the developer.

#### B. Dockerfiles (`**/Dockerfile`, `**/Dockerfile.*`)

- Scan all Dockerfiles for Node.js base image references matching patterns like `node:18`, `node:20`, `node-lts`.
- Replace the Node.js version portion with the target version if a Node.js build stage exists.
- For nginx-only Dockerfiles (serving pre-built static assets), no Node.js version change is needed — but verify the output path is correct:
  - Angular 17+ with the `application` builder outputs to `dist/[project-name]/browser/` (not `dist/[project-name]/`).
  - If the Dockerfile `COPY` path references the build output, confirm it matches the `outputPath` in `angular.json`.
- If the project uses an Artifactory-hosted base image, use the JFrog MCP `jfrog_execute_aql_query` tool to verify the new image tag exists before updating.

#### C. Azure Pipelines (`azure-pipelines.yml`, `azure-pipeline.yml`)

- Scan for Node.js version selection logic such as `NodeTool@0`, `node-version`, or `NODE_VERSION` variables.
- Update to the minimum Node.js version for the target Angular.
- Scan for `npm install`, `npm ci`, or `npm run build` steps and verify they are compatible with the updated package.json scripts.

#### D. Documentation files (`README.md`, `CONTRIBUTING.md`, docs)

- Scan `README.md`, `CONTRIBUTING.md`, and any files under a `docs/` directory for Node.js / Angular version prerequisites.
- Look for patterns like `Node.js 18`, `Angular 19`, `npm 9`.
- Update all occurrences to reflect the new versions.

#### E. ESLint configuration

- If the project uses `@angular-eslint`, ensure the ESLint config (`eslint.config.mjs`, `.eslintrc.*`) is compatible with the target Angular version.
- Angular 17+ uses the flat ESLint config by default. If upgrading from 16 or earlier, migrate from `.eslintrc.json` to `eslint.config.mjs`.
- Update `@angular-eslint/*` packages to match the target Angular major version.

#### F. TypeScript configuration

- Verify `tsconfig.json` settings are compatible with the target Angular version:
  - `target` and `module` should be `ES2022` or later for Angular 16+.
  - `moduleResolution` — Angular 17+ supports `bundler` resolution. Consider updating from `node` to `bundler` if using the application builder.
  - `useDefineForClassFields` — Angular 17+ may require this to be `true` or removed (check official guidance).
- Remove deprecated compiler options that the new Angular version no longer supports.

#### G. Test configuration

- If migrating from Karma to Jest (Karma deprecated in Angular 19+):
  - Remove `karma.conf.js` and Karma-related dependencies.
  - Ensure `jest.config.js` and `jest-preset-angular` are properly configured.
  - Update test scripts in `package.json`.
- If already using Jest, update `jest-preset-angular` to a version compatible with the target Angular.
  - `jest-preset-angular` 16+ requires `jest@^30.0.0` and `jest-environment-jsdom@^30.0.0`. If upgrading jest-preset-angular to 16+, bump both `jest` and `jest-environment-jsdom` to `^30.0.0` in devDependencies.
- Update test setup files (`jest-setup.ts`, `test-setup.ts`) if migration schematics modified the test bootstrap.
- **AG Grid 35 + jsdom**: If the project uses AG Grid and `jest-environment-jsdom`, ensure the Jest setup file provides a proper `CSS` mock with `escape()` and `supports()` methods (not `null`). AG Grid 35 calls `CSS.escape()` during grid initialization — a `null` mock will cause `TypeError: Cannot read properties of null (reading 'escape')` in every test that renders an AG Grid.
- **AG Grid transform**: Add `ag-grid-community` and `ag-grid-angular` to the `transformIgnorePatterns` allowlist in `jest.config.js` so Jest transforms their ESM code.
- **ng2-charts v9**: Search test files for `NgChartsModule` imports and replace with `BaseChartDirective`. Test suites that import the removed module will fail to compile.

### 7. Verify Compilation (Build)

**Before starting build verification**, unlock `package.json` so build tools can read it, and ensure all ERESOLVE issues are resolved:

```bash
chmod 644 package.json
rm -rf node_modules package-lock.json
npm install
```

If `npm install` fails with ERESOLVE at this point, go back to Step 5 and fix the conflicting dependency before proceeding.

Use a structured **build → diagnose → fix → rebuild** loop. You have a maximum of **5 attempts** to get a clean build.

#### Attempt 1: Initial build

Run:

```bash
npm run build 2>&1 | tee /tmp/build-attempt-1.log
echo "EXIT_CODE=$?"
```

If the build command is different (check `package.json` scripts), use the appropriate command. If the exit code is `0`, build succeeded — skip to step 8.

#### On failure: diagnose → fix → retry (attempts 2–5)

For each failed attempt, follow this cycle before re-running the build:

1. **Capture the full error output.** Read the log to identify every distinct build error (there may be multiple).
2. **Categorize each error** and apply the appropriate fix:
   - **"Module not found" / "Cannot resolve"**: A dependency is missing or its import path changed. Check if the package was renamed, moved to a different entry point, or needs installation. Run `npm install` to ensure all dependencies are installed.
   - **TypeScript compilation errors**:
     - **Type errors**: API signatures may have changed between Angular versions. Update the code to match new type signatures.
     - **Decorator errors**: Angular may have changed decorator requirements (e.g. `standalone` default value). Update component metadata.
     - **Template errors**: Template syntax may have changed (especially control flow in v17+). Fix template syntax.
   - **Angular compiler errors**:
     - **Unknown element/attribute**: A component or directive import is missing. Add the required import to the component's `imports` array (for standalone) or the NgModule's `declarations`/`imports`.
     - **Selector changes**: An Angular Material or CDK component may have changed its selector. Update templates.
   - **Build configuration errors**: `angular.json` may have invalid or deprecated options for the new builder. Remove unsupported options or migrate to updated configuration format.
   - **Sass/SCSS errors**: Angular may have changed the Sass compilation pipeline (e.g. migration from `node-sass` to `sass`, or Sass API changes). Update stylesheets.
   - **Peer dependency warnings/errors (ERESOLVE)**: This means a third-party package has an incompatible peer dependency. Do NOT use `npm install --force`. Instead:
     1. Read the ERESOLVE error to identify which package has the conflict.
     2. Check if a newer version of that package supports the target Angular: `npm view [PACKAGE]@latest peerDependencies`.
     3. Update that specific package to the compatible version.
     4. Run `rm -rf node_modules package-lock.json && npm install` to verify clean resolution.
     5. If no compatible version exists, use `npm install --legacy-peer-deps` temporarily and document it in the PR.
3. **Apply all fixes** before the next attempt — do not fix only one error per cycle.
4. **Re-run build**:
   ```bash
   npm run build 2>&1 | tee /tmp/build-attempt-N.log
   echo "EXIT_CODE=$?"
   ```
   (Replace `N` with the current attempt number.)
5. **If the same error recurs** after a fix attempt, try an alternative approach (different package version, different import path, removing the problematic code temporarily).

Repeat until build succeeds or you have exhausted all 5 attempts. **Do not proceed to step 8 until the build succeeds.** If the build still fails after 5 attempts, document all remaining errors in the PR description and create an issue with the full error logs.

### 8. Verify Tests Run and Pass

**Attempt to fix failing tests as much as possible.** Ignoring or disabling tests (e.g. with `xit`, `xdescribe`, or Jest `skip`) is only acceptable as a **last resort** after applying the failure loop below and when a fix is not feasible.

Use a structured **test → diagnose → fix → retest** loop. You have a maximum of **5 attempts** to get all tests passing.

#### Attempt 1: Initial test run

Run tests:

```bash
npm test 2>&1 | tee /tmp/test-attempt-1.log
echo "EXIT_CODE=$?"
```

If the exit code is `0`, all tests passed — skip to step 9.

#### On failure: diagnose → fix → retry (attempts 2–5)

For each failed attempt, follow this cycle:

1. **Capture and parse the failure output.** Identify every distinct failing test and its root cause from the error messages and stack traces. Group failures by root cause — multiple test failures often share the same underlying issue.
2. **Categorize each failure** and apply the appropriate fix:
   - **Import errors in tests**: Tests may import from paths that changed. Update imports.
   - **Dependency injection errors**: Provider configurations may have changed. Update `TestBed` configuration in spec files — especially `imports`, `providers`, and `schemas`.
   - **Template compilation errors in tests**: Tests that compile components may fail due to missing standalone imports or changed template syntax. Update test module configuration.
   - **Material/CDK test harness errors**: Angular Material component harnesses may have changed API. Update test harness usage.
   - **Snapshot failures**: If using Jest snapshots, delete outdated snapshots and regenerate:
     ```bash
     npx jest --updateSnapshot
     ```
   - **Async/timing issues**: Angular version changes may affect change detection timing in tests. Ensure tests properly use `fakeAsync`/`tick`, `waitForAsync`, or `fixture.whenStable()`.
   - **Zone.js related failures**: If migrating to zoneless, tests may need `provideZonelessChangeDetection()` in their `TestBed` configuration.
   - **JSDOM limitations**: If tests fail with DOM API errors in `jest-environment-jsdom`, ensure `jest-preset-angular` is properly configured for the target version.
3. **Apply all fixes** to test files, source files, and configuration files before the next attempt — fix as many distinct failures as possible in each cycle.
4. **Re-run tests**:
   ```bash
   npm test 2>&1 | tee /tmp/test-attempt-N.log
   echo "EXIT_CODE=$?"
   ```
   (Replace `N` with the current attempt number.)
5. **If a test keeps failing** after two fix attempts with different approaches, and no viable fix exists:
   - Add `xit(` or `xdescribe(` with a comment `// TODO: Fix after Angular upgrade — <brief reason>` as a last resort.
   - Record the test name and failure reason for the PR description.
6. **If new build errors appear** after test fixes, go back to the Step 7 fix cycle before re-running tests.

Repeat until all tests pass (or only explicitly skipped tests remain) or you have exhausted all 5 attempts.

#### After the loop

- **Record final test results**: Run `npm test` one final time if any fixes were applied in the last attempt, and capture the summary (total/passed/failed/skipped).
- **Document any remaining failures** in the PR description with the test name, error summary, and reason the fix was not feasible.

### 9. Verify Lint Passes

Run the linter to catch any code style or static analysis issues introduced during the upgrade:

```bash
npm run lint 2>&1 | tee /tmp/lint.log
echo "EXIT_CODE=$?"
```

If lint errors are found:
1. **Auto-fix what's possible**: Run `npm run lint:fix` if available.
2. **Manually fix remaining issues**: Update code to satisfy linting rules.
3. **Update ESLint config if needed**: If linting rules reference Angular APIs that no longer exist, update the ESLint configuration.

Do not disable lint rules to suppress upgrade-related warnings. Fix the underlying issues.

### 10. Create Pull Request

**Never commit `node_modules/` or local environment files.** Ensure `.gitignore` excludes `node_modules/`, `dist/`, and any temporary files.

Once the build succeeds and changes have been made, create a pull request:
- **Base branch**: The PR must target the branch the workflow runs on, or the repository default branch if no branch context is available.
- **Title**: `Upgrade Angular from [detected-current-version] to ${{ inputs.target-version }}`
- **Description**: Include:
  - Upgrade path taken (e.g. 19 → 20, or 17 → 18 → 19 → 20)
  - Changes made at each hop
  - Build status
  - Test results (total/passed/failed/skipped)
  - Lint status
  - Links to migration guides followed
  - Node.js version change (if applicable)
  - TypeScript version change (if applicable)
  - Third-party dependency updates (list packages and version changes)
  - Peripheral files updated (list all CI workflows, Dockerfiles, README, azure-pipelines, ESLint config, and tsconfig that were modified in step 6.5)
  - **Required manual steps** (only if some files could not be updated automatically — e.g. `.github/workflows/` files that failed to push due to missing `workflows` token scope, or Artifactory images that could not be verified)
  - **Breaking changes** that developers should be aware of (new template syntax, standalone defaults, Material 3, etc.)
  - Document any test failures that could not be resolved
  - Any deprecation warnings that should be addressed in follow-up PRs

If blocking issues (e.g., unresolvable build failures) prevent a useful upgrade, create an issue instead with full details.



Thanks
Raj