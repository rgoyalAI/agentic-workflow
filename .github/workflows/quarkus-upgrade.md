---
description: |
  Upgrades Quarkus applications in the repository from any detected (or specified) version
  to a designated target version. Reads the appropriate migration guides for each version hop,
  updates dependencies and code, verifies compilation and tests, then creates a pull request
  with all changes.

on:
  workflow_dispatch:
    inputs:
      target-version:
        description: Target Quarkus version (e.g. 3.8, 3.15, 3.17, 3.21, 3.34)
        required: false
        default: "3.34"
      current-version:
        description: Current Quarkus version (leave empty to auto-detect from POM)
        required: false
        default: ""
      java-version:
        description: Java version for the target Quarkus (11 for 2.x, 17 for 3.0-3.14, 21 for 3.15+/3.34; auto-selected if empty)
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
    - "quarkus.io"
    - "github.com"
    - "api.github.com"
    - "artifactory-ci.gm.com"
    - "repo.maven.apache.org"
    - "central.sonatype.com"
    - "registry.quarkus.io"

engine: copilot

sandbox:
  type: default
  agent: false
strict: false

safe-outputs:
  threat-detection: false
  create-pull-request:
    draft: true
    labels: [automation, quarkus-upgrade]
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

  - name: Set up Java
    uses: actions/setup-java@v4
    with:
      distribution: microsoft
      java-version: ${{ inputs.java-version || (startsWith(inputs.target-version, '3.15') && '21') || (startsWith(inputs.target-version, '3.16') && '21') || (startsWith(inputs.target-version, '3.17') && '21') || (startsWith(inputs.target-version, '3.18') && '21') || (startsWith(inputs.target-version, '3.19') && '21') || (startsWith(inputs.target-version, '3.2') && '21') || (startsWith(inputs.target-version, '3.3') && '21') || (startsWith(inputs.target-version, '3.') && '17') || (startsWith(inputs.target-version, '2.') && '11') || '21' }}

  - name: Setup JFrog CLI
    id: jfrog-cli
    uses: jfrog/setup-jfrog-cli@v4
    env:
      JF_URL: ${{ env.ARTIFACTORY_URL }}
      JF_PROJECT: ${{ vars.JFROG_CLI_PROJECT }}
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

# Quarkus Version Upgrade

Upgrade Quarkus applications in `${{ github.repository }}` to `${{ inputs.target-version }}`.

- **Target version**: `${{ inputs.target-version }}`
- **Current version override**: `${{ inputs.current-version }}` (blank = auto-detect)
- **Java version override**: `${{ inputs.java-version }}` (blank = auto-select based on target)

## Version reference table

| Quarkus   | Min Java | Notes |
|-----------|----------|-------|
| 2.7       | 11       | Last 2.x LTS; javax.* namespace |
| 2.16      | 11       | Final 2.x release; javax.* namespace |
| 3.0       | 11       | Jakarta EE 10 migration (javax → jakarta) |
| 3.2       | 11       | LTS |
| 3.8       | 17       | LTS |
| 3.15      | 17       | LTS |
| 3.17      | 21       | LTS |
| 3.21      | 21       | LTS |
| 3.26      | 21       | LTS |
| 3.34      | 21       | Latest LTS; latest release is 3.34.1 |

## Operator notes (MCP and network)

- **JFrog MCP**: `ARTIFACTORY_ACCESS_TOKEN` must authenticate Artifactory **REST** calls (AQL, repositories, package metadata). If tools register but every call returns authentication errors, ensure the token has read access for the needed repositories.
- **Network**: The workflow needs access to `quarkus.io` for official migration guides and extension registry, `github.com` for Quarkus release notes, `artifactory-ci.gm.com` for Maven dependencies, and `repo.maven.apache.org` / `central.sonatype.com` for Maven Central.

## Steps

### 1. Detect Current Version

Examine `pom.xml` files to identify the current Quarkus version.

1. **Read the root `pom.xml`** and any parent POM references. Look for:
   - `quarkus.platform.version` or `quarkus.version` in `<properties>`.
   - `io.quarkus.platform:quarkus-bom` or `io.quarkus:quarkus-bom` version in `<dependencyManagement>`.
   - `io.quarkus:quarkus-universe-bom` version in `<dependencyManagement>`.
   - `quarkus-maven-plugin` version in `<build><plugins>`.
   - If using the Quarkus parent POM (`io.quarkus:quarkus-build-parent`), extract version from `<parent>`.
2. **Extract the version**: Parse the Quarkus version. The version format is `X.Y.Z.Final` or `X.Y.Z` (e.g. `3.8.6`). Extract the major.minor (e.g. `3.8`).
3. **Validate against input**: If `${{ inputs.current-version }}` is provided, confirm it matches the detected version. If there is a mismatch, warn and use the POM-detected version as the source of truth.
4. **Record the detected current version** for use in all subsequent steps.

### 2. Determine Upgrade Path

Based on the detected current version and `${{ inputs.target-version }}`, determine the upgrade path. Quarkus recommends upgrading through LTS versions when crossing major boundaries.

| From   | To     | Upgrade path |
|--------|--------|-------------|
| 2.x    | 3.0    | Direct: 2.x → 3.0 (Jakarta EE migration) |
| 2.x    | 3.2    | Direct: 2.x → 3.2 (Jakarta migration + LTS target) |
| 2.x    | 3.8+   | Two hops: 2.x → 3.2 → 3.8+ (stabilize on LTS first) |
| 2.x    | 3.15+  | Three hops: 2.x → 3.2 → 3.8 → 3.15+ |
| 2.x    | 3.34   | Five hops: 2.x → 3.2 → 3.8 → 3.15 → 3.21 → 3.26 → 3.34 (via LTS chain) |
| 3.0–3.1 | 3.2   | Direct: 3.x → 3.2 |
| 3.2    | 3.8    | Direct: 3.2 → 3.8 |
| 3.2    | 3.15+  | Two hops: 3.2 → 3.8 → 3.15+ |
| 3.8    | 3.15   | Direct: 3.8 → 3.15 |
| 3.8    | 3.17+  | Two hops: 3.8 → 3.15 → 3.17+ |
| 3.8    | 3.34   | Four hops: 3.8 → 3.15 → 3.21 → 3.26 → 3.34 (via LTS chain) |
| 3.15   | 3.17   | Direct: 3.15 → 3.17 |
| 3.15   | 3.21+  | Two hops: 3.15 → 3.17 → 3.21+ |
| 3.17   | 3.21   | Direct: 3.17 → 3.21 |
| 3.17   | 3.26+  | Two hops: 3.17 → 3.21 → 3.26+ |
| 3.21   | 3.26   | Direct: 3.21 → 3.26 |
| 3.21   | 3.34   | Two hops: 3.21 → 3.26 → 3.34 |
| 3.26   | 3.34   | Direct: 3.26 → 3.34 |
| 3.x    | 3.y (y > x, gap ≤ 2 LTS) | Direct if within one LTS gap; otherwise hop through intermediate LTS versions |

**Important**: Quarkus recommends upgrading through LTS versions for stability. The Quarkus `update` command and OpenRewrite migration recipes are available for each LTS-to-LTS hop. Use them when possible.

For transitions not listed, consult the official Quarkus migration documentation at https://quarkus.io/guides/update-quarkus and https://github.com/quarkusio/quarkus/wiki/Migration-Guides to determine if intermediate hops are required.

### 3. Read Migration Guides

Read all migration guides relevant to the upgrade path determined in step 2.

- **Official guide**: Read https://quarkus.io/guides/update-quarkus — this is the main Quarkus upgrade guide.
- **Migration guides per version**: Read https://github.com/quarkusio/quarkus/wiki/Migration-Guides — find migration guides for each version hop. Key guides:
  - **2.x → 3.0**: https://github.com/quarkusio/quarkus/wiki/Migration-Guide-3.0
  - **3.x → 3.y**: https://github.com/quarkusio/quarkus/wiki/Migration-Guide-3.y (replace `3.y` with each target minor version)
- **Release blog posts**: Check https://quarkus.io/blog/ for release announcements of each target version — they often highlight breaking changes.
- If upgrading across multiple hops (e.g. 2.x → 3.2 → 3.8 → 3.15), read all intermediate guides and combine their requirements.

### 4. Update Quarkus BOM and Plugin Version

Update the Quarkus BOM version and Maven plugin version in all `pom.xml` files.

1. **Find the latest patch release** for the target Quarkus version. Use `web-fetch` to check https://quarkus.io/blog/ or the Quarkus GitHub releases page at https://github.com/quarkusio/quarkus/releases to confirm the latest patch version (e.g. for target `3.17`, the latest might be `3.17.5`).
2. **Update `quarkus.platform.version`** (or `quarkus.version`) property in the root `pom.xml` and any module POMs:
   ```xml
   <properties>
       <quarkus.platform.version>[TARGET_VERSION]</quarkus.platform.version>
   </properties>
   ```
3. **Update `quarkus-bom`** in `<dependencyManagement>`:
   ```xml
   <dependencyManagement>
       <dependencies>
           <dependency>
               <groupId>io.quarkus.platform</groupId>
               <artifactId>quarkus-bom</artifactId>
               <version>${quarkus.platform.version}</version>
               <type>pom</type>
               <scope>import</scope>
           </dependency>
       </dependencies>
   </dependencyManagement>
   ```
   - If the project uses `io.quarkus:quarkus-bom` (non-platform), consider switching to `io.quarkus.platform:quarkus-bom` which includes platform extensions.
   - If the project uses `quarkus-universe-bom`, note it was merged into `quarkus-bom` in Quarkus 3.x. Replace with `io.quarkus.platform:quarkus-bom`.
4. **Update `quarkus-maven-plugin`** version:
   ```xml
   <plugin>
       <groupId>io.quarkus.platform</groupId>
       <artifactId>quarkus-maven-plugin</artifactId>
       <version>${quarkus.platform.version}</version>
   </plugin>
   ```
   - If the group ID is `io.quarkus` instead of `io.quarkus.platform`, update it to `io.quarkus.platform` for Quarkus 3.x+.
5. **Update Quarkus platform BOMs for extensions** if present (e.g. `quarkus-camel-bom`, `quarkus-blaze-persistence-bom`). These must match the Quarkus platform version.

### 5. Update Third-Party Dependencies

Scan all `pom.xml` files for explicitly versioned dependencies and update them for compatibility with the target Quarkus version:

1. **Dependencies managed by Quarkus BOM**: Remove explicit version overrides for dependencies that the Quarkus BOM manages (e.g. RESTEasy, Hibernate ORM, Vert.x, SmallRye, Jackson, etc.). Let the `quarkus-bom` manage them.
2. **Dependencies NOT managed by Quarkus BOM**: For libraries with explicit versions (e.g. Apache POI, commons-collections4, custom libraries), check Maven Central or use the JFrog MCP tools to find the latest compatible version.
3. **Quarkus extension alignment**: Ensure all Quarkus extensions (`quarkus-*`) come from the same platform version. Do not mix extension versions.
4. **Check for deprecated or removed extensions**: Some Quarkus extensions may have been renamed, merged, split, or removed in newer versions. Consult the Quarkus extension registry at https://quarkus.io/extensions/ and replace deprecated extensions with their successors. Common changes:
   - `quarkus-resteasy` → `quarkus-resteasy-reactive` (or `quarkus-rest` in 3.9+)
   - `quarkus-resteasy-jackson` → `quarkus-resteasy-reactive-jackson` (or `quarkus-rest-jackson` in 3.9+)
   - `quarkus-smallrye-reactive-messaging-kafka` → renamed in some versions
   - `quarkus-hibernate-orm-panache` unchanged but check configuration changes
5. **MicroProfile dependency versions**: If the project uses MicroProfile APIs directly, verify the MicroProfile version bundled with the target Quarkus version is compatible.

### 6. Apply Version-Specific Changes

Apply changes based on the version boundary being crossed. **Only apply sections that are relevant to the detected upgrade path.** If a section does not apply to this transition, skip it.

#### 6a. Changes for crossing 2.x → 3.x boundary (applies when upgrading from any 2.x to any 3.x)

These changes apply to **any** upgrade that crosses the Quarkus 2 → 3 major version boundary.

- **Java version**: Set `maven.compiler.source` and `maven.compiler.target` to at least `11` (Quarkus 3.0–3.7) or `17` (Quarkus 3.8+). Update `<java.version>` properties in all `pom.xml` files.
- **Jakarta EE 10 migration**: This is the largest change. Replace all `javax.*` namespace imports with `jakarta.*` equivalents:
  - `javax.persistence.*` → `jakarta.persistence.*`
  - `javax.validation.*` → `jakarta.validation.*`
  - `javax.servlet.*` → `jakarta.servlet.*`
  - `javax.annotation.*` → `jakarta.annotation.*`
  - `javax.inject.*` → `jakarta.inject.*`
  - `javax.enterprise.*` → `jakarta.enterprise.*` (CDI)
  - `javax.ws.rs.*` → `jakarta.ws.rs.*` (JAX-RS)
  - `javax.json.*` → `jakarta.json.*`
  - `javax.websocket.*` → `jakarta.websocket.*`
  - `javax.transaction.*` → `jakarta.transaction.*`
  - Leave `javax.sql.*`, `javax.xml.*`, `javax.crypto.*`, and `javax.security.*` unchanged (these are in the JDK, not Jakarta EE).
- **Maven dependency coordinate changes**: Update dependency group IDs and artifact IDs that changed for Jakarta:
  - `javax.persistence:javax.persistence-api` → `jakarta.persistence:jakarta.persistence-api`
  - `javax.validation:validation-api` → `jakarta.validation:jakarta.validation-api`
  - `javax.inject:javax.inject` → `jakarta.inject:jakarta.inject-api`
  - `javax.enterprise:cdi-api` → `jakarta.enterprise:jakarta.enterprise.cdi-api`
  - `javax.ws.rs:javax.ws.rs-api` → `jakarta.ws.rs:jakarta.ws.rs-api`
  - `javax.annotation:javax.annotation-api` → `jakarta.annotation:jakarta.annotation-api`
  - `javax.mail:mail` or `javax.mail:javax.mail-api` → `jakarta.mail:jakarta.mail-api` + `org.eclipse.angus:angus-mail`
  - `javax.activation:activation` → `jakarta.activation:jakarta.activation-api`
- **`persistence.xml` and `orm.xml`**: Update XML namespace URIs from `http://xmlns.jcp.org/xml/ns/persistence` to `https://jakarta.ee/xml/ns/persistence`. Update schema locations accordingly.
- **`beans.xml`**: Update namespace from `http://xmlns.jcp.org/xml/ns/javaee` to `https://jakarta.ee/xml/ns/jakartaee`.
- **RESTEasy Classic → RESTEasy Reactive**: Quarkus 3.x strongly recommends migrating from RESTEasy Classic to RESTEasy Reactive (renamed to `quarkus-rest` in 3.9+). Key changes:
  - Replace `quarkus-resteasy` with `quarkus-rest` (or `quarkus-resteasy-reactive` for Quarkus < 3.9).
  - Replace `quarkus-resteasy-jackson` with `quarkus-rest-jackson`.
  - Replace `quarkus-resteasy-jsonb` with `quarkus-rest-jsonb`.
  - `@Context` injection for `UriInfo`, `HttpHeaders`, etc. may need adjustments in reactive endpoints.
  - Multipart handling API changes: `org.jboss.resteasy.plugins.providers.multipart.*` → `org.jboss.resteasy.reactive.multipart.*` or Quarkus `@RestForm`.
- **CDI changes**: Quarkus 3.x uses ArC (CDI Lite). Check for:
  - Removed: `@Produces` on fields (use `@Produces` on methods instead).
  - `@Dependent` scope behavior changes for producers.
  - `@Inject` fields must not be `private` in Quarkus (prefer package-private or constructor injection).
- **Configuration property renames**: Several `quarkus.*` properties were renamed. Consult the migration guide. Common renames:
  - `quarkus.http.cors` → `quarkus.http.cors.enabled`
  - `quarkus.smallrye-openapi.path` → `quarkus.swagger-ui.path` (varies by version)
  - Many datasource properties were restructured.
- **`application.properties` / `application.yaml`**: Scan all configuration files for renamed or removed properties. Use the migration guide's property mapping table.
- **Test changes**:
  - `@QuarkusTest` behavior is unchanged but some test utilities moved packages.
  - `quarkus-junit5` is the primary test dependency; ensure it is present.
  - `@QuarkusTestResource` may have annotation changes; check if lifecycle management annotations changed.
  - `@InjectMock` moved from `io.quarkus.test.junit.mockito.InjectMock` to `io.quarkus.test.InjectMock` (Quarkus 3.13+). `@InjectSpy` was similarly relocated. **Always grep all test files** for `io.quarkus.test.junit.mockito` and update to `io.quarkus.test`.

#### 6b. Changes for 3.x → 3.y within the 3.x line

For minor-version upgrades within the Quarkus 3.x line (e.g. 3.2 → 3.8, 3.8 → 3.15):

- **Official release notes**: Read the migration guide for each version hop from https://github.com/quarkusio/quarkus/wiki/Migration-Guides and apply documented breaking changes.
- **Java version**: If the target requires a higher Java version (e.g. 3.8 requires Java 17, 3.17 requires Java 21), update `maven.compiler.source`, `maven.compiler.target`, and `<java.version>` accordingly.
- **Extension renames (3.9+)**: Quarkus 3.9 renamed several core extensions. Update all `pom.xml` dependencies AND any `application.properties` that reference the old names:
  - `quarkus-resteasy-reactive` → `quarkus-rest`
  - `quarkus-resteasy-reactive-jackson` → `quarkus-rest-jackson`
  - `quarkus-resteasy-reactive-jsonb` → `quarkus-rest-jsonb`
  - `quarkus-resteasy-reactive-links` → `quarkus-rest-links`
  - `quarkus-resteasy-reactive-jaxb` → `quarkus-rest-jaxb`
  - `quarkus-resteasy-reactive-kotlin` → `quarkus-rest-kotlin`
  - `quarkus-reactive-routes` → `quarkus-vertx-web` (check migration guide)
  - `quarkus-smallrye-reactive-messaging` submodules may also be renamed.
- **Test annotation relocations (3.13+)**: Several test annotations were relocated in Quarkus 3.13. **Search all test source files** (`src/test/`) and update imports:
  - `io.quarkus.test.junit.mockito.InjectMock` → `io.quarkus.test.InjectMock`
  - `io.quarkus.test.junit.mockito.InjectSpy` → `io.quarkus.test.InjectSpy`
  - The old `io.quarkus.test.junit.mockito` package is removed. Any remaining imports from this package will cause compilation failures.
  - Use `grep -rn "io.quarkus.test.junit.mockito" src/test/` to find all occurrences and replace them.
- **RESTEasy Reactive `FileUpload` interface changes (3.15+)**: The `org.jboss.resteasy.reactive.multipart.FileUpload` interface added a `getHeaders()` method returning `jakarta.ws.rs.core.MultivaluedMap<String, String>`. Any anonymous implementations or custom classes implementing `FileUpload` must add this method:
  ```java
  @Override
  public MultivaluedMap<String, String> getHeaders() {
      return new MultivaluedHashMap<>();
  }
  ```
  - Add imports: `jakarta.ws.rs.core.MultivaluedMap` and `jakarta.ws.rs.core.MultivaluedHashMap`.
  - Search all source and test files: `grep -rn "new FileUpload()" src/` and `grep -rn "implements FileUpload" src/` to find all implementations that need updating.
  - If using Mockito mocks (`Mockito.mock(FileUpload.class)`), no change is needed — Mockito handles new interface methods automatically.
- **Deprecated configuration properties**: Check for renamed/removed `quarkus.*` properties. Each minor release may rename properties — consult the migration guide.
- **Hibernate ORM changes**: Quarkus upgrades Hibernate ORM across minor versions. Check for:
  - Hibernate 5.x → 6.x (happened in Quarkus 3.0): HQL syntax changes, removed legacy annotations.
  - Hibernate 6.x updates: query syntax stricter, implicit joins behavior changes, ID generation strategy changes.
  - **Native query result type changes (Hibernate 6+)**: Native queries (`createNativeQuery`) now return `java.time.LocalDateTime` instead of `java.sql.Timestamp` for datetime/timestamp columns. Any code that casts native query result array elements to `(Timestamp)` will throw `ClassCastException` at runtime. Fix by converting: `Timestamp.valueOf((LocalDateTime) result[index])` instead of `(Timestamp) result[index]`. Search with: `grep -rn "(Timestamp)" src/main/` to find all casts that may need updating. Add `import java.time.LocalDateTime;` where needed.
  - Panache API changes (rare, but method signatures may evolve).
- **SmallRye specification updates**: SmallRye implementations of MicroProfile specs (Health, Metrics, OpenAPI, Fault Tolerance) update across Quarkus versions. Check for:
  - MicroProfile Metrics → Micrometer migration (Quarkus 3.x uses Micrometer by default).
  - SmallRye OpenAPI annotation changes.
  - SmallRye Fault Tolerance API changes.
- **Vert.x version bumps**: Quarkus upgrades Vert.x across minor versions. If the project uses Vert.x APIs directly, check for breaking changes in the Vert.x changelog.
- **Dev Services configuration**: Dev Services property names may change. Verify `quarkus.datasource.devservices.*`, `quarkus.kafka.devservices.*`, etc.
- **Native image**: If using GraalVM native image compilation, verify the minimum GraalVM version required for the target Quarkus version. Update GraalVM tooling accordingly.

#### 6c. Changes for upgrading to Quarkus 3.15+ (applies when target is 3.15 or later)

In addition to the applicable sections above:

- **Java 17 minimum**: Ensure `maven.compiler.source`, `maven.compiler.target`, and `<java.version>` are set to at least `17`.
- **Java 21 for 3.17+**: If target is 3.17 or later, set Java version to `21`.
- **Virtual threads**: Quarkus 3.15+ has production-ready virtual thread support. If migrating to Java 21, consider enabling `@RunOnVirtualThread` annotations where appropriate. Check configuration property `quarkus.virtual-threads.enabled`.
- **Hibernate ORM 6.4+/6.5+ changes**: Later Quarkus 3.x versions ship with newer Hibernate 6.x releases. Check for:
  - Stricter HQL parsing.
  - Changes to `@IdGeneratorType` and sequence generation defaults.
  - `@SoftDelete` and other new annotations.
- **Security changes**: Quarkus security annotations and configuration may have evolved. Check:
  - `@RolesAllowed`, `@Authenticated`, `@PermissionsAllowed` annotation behavior.
  - OIDC configuration property changes (`quarkus.oidc.*`).
  - Security testing utilities (`quarkus-test-security`).
- **Observability**: Quarkus 3.15+ has enhanced observability. Check for:
  - Micrometer integration changes.
  - OpenTelemetry extension updates (`quarkus-opentelemetry`).
  - Health check endpoint changes.

#### 6e. Changes for upgrading to Quarkus 3.20+ (applies when target is 3.20 or later, including 3.34)

In addition to all applicable sections above, the following changes apply when the target version is 3.20 or later (including the latest 3.34.x line):

- **Java 21 (required)**: Ensure `maven.compiler.source`, `maven.compiler.target`, and `<java.version>` are set to `21` in all `pom.xml` files. Quarkus 3.20+ requires Java 21 as the baseline.
- **Hibernate ORM 7.x**: Quarkus 3.20+ ships with Hibernate ORM 7 (previously 6.x). Key breaking changes:
  - **Proxy enforcement**: Hibernate 7 strictly enforces that getter/setter methods on `@Entity` and `@MappedSuperclass` classes must NOT be `final`. Hibernate creates proxy subclasses; `final` on getters/setters breaks lazy loading. Search all entity classes and remove `final` from public getters/setters.
  - **`@Type` / `@TypeDef` removal**: These annotations were deprecated in Hibernate 6 and are fully removed in Hibernate 7. Replace with `@JdbcType`, `@JdbcTypeCode`, `@JavaType`, or `@Convert` (JPA `AttributeConverter`).
  - **ID generation**: `@GeneratedValue(strategy = GenerationType.AUTO)` defaults to `SequenceStyleGenerator` in Hibernate 7. Projects relying on `IDENTITY` must explicitly set `strategy = GenerationType.IDENTITY`.
  - **HQL strict mode**: Hibernate 7's HQL parser is stricter. Common fixes:
    - Implicit property joins no longer allowed; use explicit `JOIN` syntax.
    - `TREAT()` is required for downcasting in polymorphic queries.
    - `SELECT new ClassName(...)` requires the fully qualified class name or a proper `@NamedNativeQuery` result mapping.
  - **`org.hibernate.engine.spi.Mapping` removed**: Any third-party library referencing this class (e.g. `jackson-datatype-hibernate6`) will fail. Replace with `jackson-datatype-hibernate7` or equivalent.
  - **`SessionFactory` / `Session` API changes**: Some deprecated methods in Hibernate 6 are removed. Check for `Session.save()`, `Session.update()`, `Session.delete()` — use `Session.persist()`, `Session.merge()`, `Session.remove()` instead.
  - **Panache**: `PanacheEntity` and `PanacheRepository` are updated for Hibernate 7. Most user code is unaffected, but check for uses of deprecated Panache methods.
  - **Native query result type changes**: Native queries return `java.time.LocalDateTime` instead of `java.sql.Timestamp` for datetime/timestamp columns (carried from Hibernate 6). Any `(Timestamp) result[index]` cast will throw `ClassCastException` at runtime. Replace with `Timestamp.valueOf((LocalDateTime) result[index])` and add `import java.time.LocalDateTime;`.
- **Vert.x 5.x**: Quarkus 3.26+ ships with Vert.x 5 (previously Vert.x 4). If the project uses Vert.x APIs directly:
  - `io.vertx.core.json.JsonObject` and `JsonArray` API is mostly compatible but some deprecated methods removed.
  - `Vertx.vertx()` creation options and `DeploymentOptions` may have changed.
  - `HttpClient` API changes — review if using low-level Vert.x HTTP client.
  - If the project only uses Vert.x through Quarkus extensions (e.g. `quarkus-vertx`, `quarkus-rest`), most changes are handled by Quarkus internally.
- **RESTEasy Reactive → Quarkus REST finalization**: By Quarkus 3.20+, `quarkus-rest` is the standard. Ensure all legacy extension names are updated:
  - `quarkus-resteasy-reactive*` → `quarkus-rest*`
  - `quarkus-resteasy` (classic) is deprecated and may be removed in future versions. Migrate to `quarkus-rest`.
- **SmallRye and MicroProfile updates**:
  - **MicroProfile 7.0**: Quarkus 3.20+ aligns with MicroProfile 7.0. Check for API changes in Fault Tolerance, Health, Metrics (Micrometer), OpenAPI, Config, JWT.
  - **SmallRye Config 3.x**: Configuration source priority and profile handling may have changed. Test configuration-sensitive code.
  - **SmallRye OpenAPI**: Annotation scanning and schema generation behavior may differ. Verify generated OpenAPI specs.
- **Security enhancements**:
  - `@PermissionsAllowed` annotation enhancements — check for new `params` or `inclusive` attributes.
  - OIDC multi-tenancy improvements — verify `quarkus.oidc.tenant-resolver.*` properties.
  - Revised `AuthorizationPolicy` / `HttpSecurityPolicy` interfaces.
- **Observability changes**:
  - **OpenTelemetry**: Quarkus 3.20+ updates OTel SDK. Check `quarkus.otel.*` property names and default behaviors.
  - **Micrometer**: Timer and counter API may have minor changes. Custom `MeterBinder` implementations should be reviewed.
- **Dev Services and Dev UI**:
  - Dev UI v2 is the standard. If the project has custom Dev UI extensions, they may need migration.
  - Dev Services configuration properties may have changed — verify `quarkus.*.devservices.*` settings.
- **Build-time vs runtime configuration enforcement**: Quarkus 3.20+ is stricter about separating build-time and runtime configuration properties. Properties marked as build-time cannot be overridden at runtime. Review `application.properties` for any build-time properties that were previously overridden at runtime.
- **Gradle users**: If the project uses Gradle instead of Maven, ensure the Quarkus Gradle plugin version matches the target Quarkus version. The plugin coordinates are `io.quarkus:gradle-application-plugin`.
- **Native compilation**: GraalVM/Mandrel minimum versions increase with newer Quarkus releases. For Quarkus 3.34, ensure:
  - GraalVM 23.1+ or Mandrel 23.1+ for Java 21.
  - Review `@RegisterForReflection` annotations — some may no longer be needed due to improved automatic registration.
  - `--allow-incomplete-classpath` is no longer a valid GraalVM option in newer versions; remove if present.
- **Jackson updates**: Quarkus 3.20+ may ship with Jackson 2.17+ or Jackson 2.18+. Check for:
  - Stricter null handling defaults.
  - Changed `@JsonProperty` behavior for records.
  - `@JsonCreator` disambiguation changes.
- **Quarkus `update` command**: For LTS-to-LTS hops, consider running `mvn io.quarkus.platform:quarkus-maven-plugin:${TARGET_VERSION}:update` which applies OpenRewrite migration recipes automatically. This can handle many mechanical changes (import renames, property renames, extension renames). Review the changes it produces and apply additional manual fixes as needed.

#### 6d. Quarkus extension-specific migration

Scan the project's dependencies for Quarkus extensions and apply extension-specific migration steps:

- **`quarkus-hibernate-orm` / `quarkus-hibernate-orm-panache`**:
  - Check for deprecated Hibernate annotations (`@Type`, `@TypeDef` — removed in Hibernate 6).
  - `@GeneratedValue(strategy = GenerationType.AUTO)` behavior changed in Hibernate 6 (uses sequence instead of identity). Explicitly set the strategy if needed.
  - `@Column(columnDefinition = ...)` may need review.
  - Panache: Check if `PanacheEntity` or `PanacheRepository` method signatures changed.

- **`quarkus-hibernate-validator`**:
  - Jakarta Validation 3.0: `javax.validation.*` → `jakarta.validation.*`.
  - Check for removed or changed constraint annotations.

- **`quarkus-oidc` / `quarkus-keycloak-authorization`**:
  - OIDC extension configuration properties may be renamed across versions.
  - Token validation behavior changes.
  - Multi-tenancy configuration updates.

- **`quarkus-smallrye-openapi` / `quarkus-swagger-ui`**:
  - OpenAPI annotation package may change.
  - Swagger UI configuration properties may be renamed.

- **`quarkus-mailer`**:
  - Mailer API changes between versions. Check `Mailer` and `ReactiveMailer` interfaces.

- **`quarkus-scheduler` / `quarkus-quartz`**:
  - Scheduler API and configuration property changes.

- **`quarkus-kafka-client` / `quarkus-smallrye-reactive-messaging-kafka`**:
  - Kafka client version bumps may introduce breaking changes.
  - Reactive messaging channel configuration syntax changes.

- **`quarkus-grpc`**:
  - gRPC codegen and runtime changes across versions.

- **`quarkus-cache`**:
  - Cache API changes, caffeine configuration updates.

### 6.5. Update CI, Docker, and Documentation Files

After applying all version-specific code and POM changes, scan the repository for non-POM files that reference the Java/JDK version or contain version-sensitive configuration. Update them to match the target Java version determined from the version reference table.

#### A. GitHub Actions workflow files (`.github/workflows/*.yml`)

- Scan all `.yml` files under `.github/workflows/` for `java-version:` in `actions/setup-java` steps.
- Update the `java-version` value to match the target Java version (e.g. `17` → `21` for Quarkus 3.17+).
- If `setup-java` uses an outdated action version (e.g. `@v3`), update to `@v4`.
- If the workflow sets up GraalVM (e.g. `graalvm/setup-graalvm`), update the GraalVM version to be compatible with the target Quarkus version.
- **Permissions note**: Pushing changes to `.github/workflows/` files requires the `GHAW_TOKEN` (with `workflows` scope). If the push fails due to insufficient permissions, document the required workflow file changes in the PR description as a manual step for the developer.

#### B. Dockerfiles (`**/Dockerfile`, `**/Dockerfile.*`)

- Scan all Dockerfiles for JDK base image references matching patterns like `jdk17`, `jdk-17`, `openjdk:17`, `eclipse-temurin:17`, `ubi-quarkus-mandrel`, `ubi-quarkus-graalvmce`, `quarkus-micro-image`.
- Replace the JDK version portion with the target version (e.g. `jdk17` → `jdk21`).
- If the Dockerfile uses a Quarkus-specific base image (e.g. `quay.io/quarkus/ubi-quarkus-mandrel-builder-image`), verify the image tag supports the target Quarkus version and Java version.
- If the project uses an Artifactory-hosted base image (e.g. `artifactory-ci.gm.com/docker-share/...`), use the JFrog MCP `jfrog_execute_aql_query` tool to verify the new image tag exists before updating. If not found, keep existing and document in the PR.
- Check for Quarkus native build Dockerfiles (`Dockerfile.native`, `Dockerfile.native-micro`) and update GraalVM/Mandrel base image versions.

#### C. Documentation files (`README.md`, `CONTRIBUTING.md`, docs)

- Scan `README.md`, `CONTRIBUTING.md`, and any files under a `docs/` directory for Java version prerequisites and Quarkus version references.
- Look for patterns like `Java 17`, `JDK 17`, `Quarkus 3.8`, `quarkus 3.8`.
- Update all occurrences to the target Java and Quarkus versions.

#### D. Azure Pipelines (`azure-pipelines.yml`)

- If `azure-pipelines.yml` exists, scan for Java version selection logic such as `JAVA_HOME_17_X64`, `pomJavaVersion -eq 17`, or `JAVA_HOME_17`.
- Add support for the target Java version alongside existing versions. For example, add an `elseif` block for Java 21 that sets `JAVA_HOME` to `$(JAVA_HOME_21_X64)`.
- Do not remove existing Java version branches — older versions may still be needed for other branches.

#### E. Maven plugin versions (all `pom.xml` files)

- Scan all `pom.xml` files for `jacoco-maven-plugin` with versions older than `0.8.11`. If the target Java version is 21+, update to `0.8.12` or later.
- Scan for `maven-javadoc-plugin` with versions older than `3.6.0`. Update if needed.
- Scan for `maven-compiler-plugin` — ensure version is `3.11.0`+ for Java 17 and `3.12.0`+ for Java 21.
- Scan for `maven-surefire-plugin` — ensure version is `3.1.0`+ for Quarkus 3.x compatibility.
- Scan for other plugins with known Java 21 incompatibilities and update them.

#### F. Quarkus-specific configuration files

- **`application.properties` / `application.yaml`**: If any `quarkus.*` properties were renamed in the target version, update them.
- **`src/main/resources/META-INF/resources/`**: Check for Quarkus dev UI customizations that may need updating.
- **`.env` files**: Check for Quarkus-related environment variables that reference version-specific features.

### 7. Verify Compilation (with retry loop)

**Settings and proxy**: Ensure `$MAVEN_SETTINGS` is set (e.g. `ls -la "$MAVEN_SETTINGS"` or fallback to `$GITHUB_WORKSPACE/.m2/settings.xml`). **Do not commit or push `settings.xml`** (see step 9).

#### 7.1 Compile — Attempt 1

Run:

```bash
mvn clean install -DskipTests --settings $MAVEN_SETTINGS
```

If compilation **succeeds**, proceed to Step 8.

If compilation **fails**, read the full error output, identify all errors (there may be multiple), and apply fixes using the troubleshooting guide in **7.4** below. Then continue to **7.2**.

#### 7.2 Compile — Attempt 2

After applying fixes from attempt 1, re-run:

```bash
mvn clean install -DskipTests --settings $MAVEN_SETTINGS
```

If compilation **succeeds**, proceed to Step 8.

If compilation **fails**, read the full error output again. Compare errors to attempt 1 — identify whether the previous fixes resolved some errors and whether new errors appeared. Apply fixes using **7.4**. Then continue to **7.3**.

#### 7.3 Compile — Attempt 3 (final)

After applying fixes from attempt 2, re-run:

```bash
mvn clean install -DskipTests --settings $MAVEN_SETTINGS
```

If compilation **succeeds**, proceed to Step 8.

If compilation **fails** after 3 attempts, document all remaining errors in the PR description and proceed to Step 9 (create PR). Mark the PR as a draft and list the unresolved compilation errors so the developer can address them.

#### 7.4 Compilation error troubleshooting guide

When compilation fails, check the error output against these known patterns and apply the corresponding fix:

1. **"Could not find artifact" / "cannot be resolved"**: Confirm `--settings $MAVEN_SETTINGS` is used. Check whether extension group IDs or artifact IDs were renamed (e.g. `quarkus-resteasy-reactive` → `quarkus-rest`). Verify the Quarkus BOM version is resolvable.
2. **Jakarta namespace errors**: If `javax.*` imports remain, complete the `javax` → `jakarta` migration. Use `grep -rn "import javax\.\(persistence\|validation\|servlet\|annotation\|inject\|enterprise\|ws\.rs\|json\|websocket\|transaction\)" src/` to find remaining occurrences.
3. **"cannot find symbol" for test annotations (`InjectMock`, `InjectSpy`)**: These annotations moved from `io.quarkus.test.junit.mockito` to `io.quarkus.test` in Quarkus 3.13+. Run `grep -rn "io.quarkus.test.junit.mockito" src/test/` and replace all occurrences with `io.quarkus.test`.
4. **"is not abstract and does not override abstract method" on `FileUpload` implementations**: The `org.jboss.resteasy.reactive.multipart.FileUpload` interface gained a `getHeaders()` method in newer Quarkus versions. Find all anonymous `FileUpload` implementations and custom classes implementing the interface, then add: `@Override public MultivaluedMap<String, String> getHeaders() { return new MultivaluedHashMap<>(); }`. Add imports for `jakarta.ws.rs.core.MultivaluedMap` and `jakarta.ws.rs.core.MultivaluedHashMap`.
5. **JDK or Quarkus compatibility**: Update or replace the offending dependency. For test/embedded deps, use a compatible version or in-memory/mock alternative (Docker / Testcontainers may be unavailable in CI).
6. **Hibernate / JPA errors**: Check for removed Hibernate annotations or changed API. Common: `@Type` → `@JdbcType` or `@Convert`, `@TypeDef` removed, `CriteriaBuilder` API changes.
7. **Runtime `ClassCastException: LocalDateTime cannot be cast to Timestamp`**: Hibernate 6+/7 returns `java.time.LocalDateTime` for datetime columns in native queries instead of `java.sql.Timestamp`. Replace `(Timestamp) result[index]` with `Timestamp.valueOf((LocalDateTime) result[index])`. Add `import java.time.LocalDateTime;`. Search with `grep -rn "(Timestamp)" src/` to find all occurrences.
8. **Other errors**: Read the error message carefully, identify the root cause (missing class, incompatible API, removed method), fix source or `pom.xml`.

> **Tip**: Fix ALL errors found in a single attempt before re-compiling. Do not re-compile after fixing only one error — batch all fixes together, then re-run.

> **Note**: If any `.github/workflows/` files could not be updated in step 6.5 due to permission restrictions (missing `workflows` scope on the token), the required changes will be documented in the PR description as manual steps for the developer.

### 8. Verify Tests (with retry loop)

**Attempt to fix failing tests as much as possible.** Ignoring or disabling tests (e.g. with `@Disabled`, `@Ignore`) is only acceptable as a **last resort** after applying the failure loop below and when a fix is not feasible.

#### 8.1 Test — Attempt 1

Run:

```bash
mvn test --settings $MAVEN_SETTINGS
```

(No `clean` — reuse the compiled artifacts from step 7.)

If all tests **pass**, proceed to Step 9.

If tests **fail**, read the full test output including stack traces for every failing test. Identify the root cause of each failure and apply fixes using the troubleshooting guide in **8.5** below. Then continue to **8.2**.

#### 8.2 Test — Attempt 2

After applying fixes from attempt 1, re-run:

```bash
mvn test --settings $MAVEN_SETTINGS
```

If all tests **pass**, proceed to Step 9.

If tests **fail**, compare failures to attempt 1 — confirm previous fixes worked and identify any new or remaining failures. Apply fixes using **8.5**. Then continue to **8.3**.

#### 8.3 Test — Attempt 3

After applying fixes from attempt 2, re-run:

```bash
mvn test --settings $MAVEN_SETTINGS
```

If all tests **pass**, proceed to Step 9.

If tests **fail**, apply fixes using **8.5**. Then continue to **8.4**.

#### 8.4 Test — Attempt 4 (final)

After applying fixes from attempt 3, re-run:

```bash
mvn test --settings $MAVEN_SETTINGS
```

If all tests **pass**, proceed to Step 9.

If tests still **fail** after 4 attempts, document all remaining test failures (test name, error message, stack trace summary) in the PR description and proceed to Step 9. Only as a **last resort**, add `@Disabled("TODO: fix after Quarkus upgrade — [brief reason]")` to tests that cannot be fixed, so the build is not blocked.

#### 8.5 Test failure troubleshooting guide

When tests fail, check the output against these known patterns:

1. **Jakarta namespace in tests**: Ensure all test source files also have `javax.*` → `jakarta.*` migration applied. Test resources (`persistence.xml`, `beans.xml` in `src/test/resources`) must also be updated.
2. **Test-scoped dependency incompatible with target JDK or Quarkus version**: Check for a newer version; if none exists, replace with an alternative (Docker may be unavailable in CI — use in-memory alternatives). Update test code accordingly.
3. **`@QuarkusTest` or `@QuarkusIntegrationTest` changes**: Check if test annotations, lifecycle, or configuration changed in the target version. Verify `quarkus-junit5` version aligns.
4. **Hibernate/JPA query changes**: Hibernate 6+ has stricter HQL parsing. Fix HQL queries to comply with the new parser. Common issues:
   - Implicit joins no longer allowed; use explicit `JOIN` syntax.
   - `SELECT new` queries require fully qualified class names or proper imports.
   - Native SQL queries may need dialect-specific fixes.
5. **`ClassCastException: LocalDateTime cannot be cast to Timestamp`**: Same as compilation pattern #7 — Hibernate 6+/7 returns `java.time.LocalDateTime` for datetime columns in native queries. Replace `(Timestamp) result[index]` with `Timestamp.valueOf((LocalDateTime) result[index])`.
6. **Other test failures**: Read the full stack trace, identify if the failure is upgrade-related (changed API, removed class, different behavior) vs. a pre-existing issue. Only fix upgrade-related failures.

> **Tip**: Fix ALL failing tests in a single attempt before re-running. Do not re-run after fixing only one test — batch all fixes together, then re-run.

### 9. Create Pull Request

**Never commit secrets or settings.xml.** The Maven `settings.xml` file (and the `.m2/` directory) contains credentials and **must never be committed or pushed**. Ensure **`.gitignore`** excludes `.m2/` and `**/settings.xml`.

Once compilation succeeds and any changes have been made, create a pull request:
- **Base branch**: The PR must target the branch the workflow runs on, or the repository default branch if no branch context is available.
- **Title**: `Upgrade Quarkus from [detected-current-version] to ${{ inputs.target-version }}`
- **Description**: Include:
  - Upgrade path taken (e.g. 3.8 → 3.15 → 3.17)
  - Changes made at each hop
  - Compilation status
  - Test results (total/passed/failed/skipped)
  - Links to migration guides followed
  - Java version change (if applicable)
  - Jakarta EE migration applied (if crossing 2.x → 3.x boundary)
  - Extension renames applied (list old → new)
  - Peripheral files updated (list all CI workflows, Dockerfiles, README, azure-pipelines, and Maven plugins that were modified in step 6.5)
  - **Required manual steps** (only if some files could not be updated automatically — e.g. `.github/workflows/` files that failed to push due to missing `workflows` token scope, or Dockerfile base images that could not be verified in Artifactory)
  - Document any test failures that could not be resolved

If blocking issues (e.g., unresolvable compilation failures) prevent a useful upgrade, create an issue instead with full details.

Thanks
Raj