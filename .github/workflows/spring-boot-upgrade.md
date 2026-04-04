---
description: |
  Upgrades Spring Boot applications in the repository from any detected (or specified) version
  to a designated target version. Reads the appropriate migration guides for each version hop,
  updates dependencies and code, verifies compilation and tests, then creates a pull request
  with all changes.

on:
  workflow_dispatch:
    inputs:
      target-version:
        description: Target Spring Boot version (e.g. 3.2, 3.3, 3.4, 3.5, 4.0)
        required: false
        default: "4.0"
      current-version:
        description: Current Spring Boot version (leave empty to auto-detect from POM)
        required: false
        default: ""
      java-version:
        description: Java version for the target Spring Boot (17 for 3.0-3.3, 21 for 3.4+/4.x; auto-selected if empty)
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
    - "docs.spring.io"
    - "api.github.com"
    - "artifactory-ci.gm.com"
    - "repo.maven.apache.org"
    - "central.sonatype.com"

engine: copilot

sandbox:
  type: default
  agent: false
strict: false

safe-outputs:
  threat-detection: false
  create-pull-request:
    draft: true
    labels: [automation, spring-boot-upgrade]
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
      java-version: ${{ inputs.java-version || (startsWith(inputs.target-version, '4.') && '21') || (startsWith(inputs.target-version, '3.4') && '21') || (startsWith(inputs.target-version, '3.5') && '21') || (startsWith(inputs.target-version, '3.') && '17') || '11' }}

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

# Spring Boot Version Upgrade

Upgrade Spring Boot applications in `${{ github.repository }}` to `${{ inputs.target-version }}`.

- **Target version**: `${{ inputs.target-version }}`
- **Current version override**: `${{ inputs.current-version }}` (blank = auto-detect)
- **Java version override**: `${{ inputs.java-version }}` (blank = auto-select based on target)

## Version reference table

| Spring Boot | Min Java | Notes |
|-------------|----------|-------|
| 2.7         | 11       | LTS maintenance |
| 3.0         | 17       | Jakarta EE 9+ migration |
| 3.2         | 17       | LTS |
| 3.3         | 17       | |
| 3.4         | 21       | Virtual threads, structured logging |
| 3.5         | 21       | Last 3.x line before 4.0; recommended stepping-stone |
| 4.0         | 21       | Spring Framework 7, Jakarta EE 11, Jackson 3 |

## Operator notes (MCP and network)

- **JFrog MCP**: `ARTIFACTORY_ACCESS_TOKEN` must authenticate Artifactory **REST** calls (AQL, repositories, package metadata). If tools register but every call returns authentication errors, ensure the token has read access for the needed repositories.
- **Network**: The workflow needs access to `docs.spring.io` for official migration guides, `artifactory-ci.gm.com` for Maven dependencies, and `repo.maven.apache.org` / `central.sonatype.com` for Maven Central.

## Steps

### 1. Detect Current Version

Examine `pom.xml` files to identify the current Spring Boot version.

1. **Read the root `pom.xml`** and any parent POM references. Look for:
   - `spring-boot-starter-parent` version in `<parent>`.
   - `spring-boot.version` or `spring-boot-dependencies` version in `<properties>` or `<dependencyManagement>`.
2. **Extract the version**: Parse the Spring Boot version from the parent POM or properties. The version format is `X.Y.Z` (e.g. `3.5.6`). Extract the major.minor (e.g. `3.5`).
3. **Validate against input**: If `${{ inputs.current-version }}` is provided, confirm it matches the detected version. If there is a mismatch, warn and use the POM-detected version as the source of truth.
4. **Record the detected current version** for use in all subsequent steps.

### 2. Determine Upgrade Path

Based on the detected current version and `${{ inputs.target-version }}`, determine the upgrade path. Some transitions require intermediate steps.

| From | To | Upgrade path |
|------|----|-------------|
| 2.7  | 3.0 | Direct: 2.7 → 3.0 |
| 2.7  | 3.2 | Direct: 2.7 → 3.2 (migration guide covers 2.7 → 3.2) |
| 2.7  | 3.3+ | Two hops: 2.7 → 3.2 → 3.3+ |
| 2.7  | 4.x | Three hops: 2.7 → 3.2 → 3.5.x → 4.x |
| 3.0  | 3.2 | Direct: 3.0 → 3.2 |
| 3.2  | 3.3 | Direct: 3.2 → 3.3 |
| 3.2  | 3.4 | May be direct or via 3.3; check official guide |
| 3.2  | 4.x | Two hops: 3.2 → 3.5.x → 4.x |
| 3.3  | 4.x | Two hops: 3.3 → 3.5.x → 4.x |
| 3.4  | 4.x | Two hops: 3.4 → 3.5.x → 4.x |
| 3.5  | 4.0 | Direct: 3.5.x → 4.0 (recommended migration path) |
| 3.x  | 3.y (y > x) | Direct if minor version gap ≤ 2; check official guide for specifics |
| 3.x  | 4.x | Always go through latest 3.5.x first; remove all deprecated API usage on 3.5 before jumping to 4.0 |

**Important**: The official Spring Boot 4.0 migration guide requires upgrading to the **latest 3.5.x** release first and resolving all deprecation warnings before migrating to 4.0. All APIs deprecated in 3.x are **removed** in 4.0.

For transitions not listed, consult the official Spring Boot migration documentation at https://docs.spring.io/spring-boot/upgrading.html and https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide to determine if intermediate hops are required.

### 3. Read Migration Guides

Read all migration guides relevant to the upgrade path determined in step 2.

- **Official guide**: Read https://docs.spring.io/spring-boot/upgrading.html — find the sections relevant to each hop in the upgrade path.
- **For 4.0 upgrades**, also read the official Spring Boot 4.0 migration guide: https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide — this is critical as 4.0 removes all APIs deprecated in the 3.x line.
- If upgrading across multiple hops (e.g. 2.7 → 3.2 → 3.5 → 4.0), read all intermediate guides and combine their requirements.

### 4. Update Parent POM Version

Update the `spring-boot-starter-parent` version in all `pom.xml` files that reference it.

1. **Find the latest release** for the target Spring Boot version. Use `web-fetch` to check https://docs.spring.io/spring-boot/upgrading.html or the Spring Boot GitHub releases page to confirm the latest patch version (e.g. for target `4.0`, the latest might be `4.0.1`).
2. **Update all `pom.xml` files** that have `spring-boot-starter-parent` as a parent:
   ```xml
   <parent>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-starter-parent</artifactId>
       <version>[TARGET_VERSION]</version>
       <relativePath />
   </parent>
   ```
3. **Update `spring-boot.version`** property if explicitly set in any POM `<properties>` section.
4. **Update Spring Cloud dependencies** if present. Check the Spring Cloud compatibility matrix at https://spring.io/projects/spring-cloud to find the Spring Cloud release train compatible with the target Spring Boot version. Update the `spring-cloud-dependencies` BOM version accordingly.

### 5. Update Third-Party Dependencies

Scan all `pom.xml` files for explicitly versioned dependencies and update them for compatibility with the target Spring Boot version:

1. **Dependencies managed by Spring Boot**: Remove explicit version overrides for dependencies that Spring Boot manages (e.g. Jackson, Hibernate, Lombok, etc.) unless a specific version is required. Let the `spring-boot-starter-parent` BOM manage them.
2. **Dependencies NOT managed by Spring Boot**: For libraries with explicit versions (e.g. Apache POI, java-cfenv-boot, commons-collections4), check Maven Central or use the JFrog MCP tools to find the latest compatible version.
3. **Spring Cloud**: Update the Spring Cloud BOM version to match the target Spring Boot version's compatibility matrix.
4. **Check for deprecated or removed dependencies**: Some dependencies may have been renamed, merged, or removed in newer versions. Replace with their successors.

### 6. Apply Version-Specific Changes

Apply changes based on the version boundary being crossed. **Only apply sections that are relevant to the detected upgrade path.** If a section does not apply to this transition, skip it.

#### 6a. Changes for crossing 2.x → 3.x boundary (applies when upgrading from any 2.x to any 3.x)

These changes apply to **any** upgrade that crosses the Spring Boot 2 → 3 major version boundary.

- **Java version**: Set `maven.compiler.source` and `maven.compiler.target` to the minimum Java version for the target (at least `17` for 3.0–3.3, `21` for 3.4+). Update `<java.version>` properties in all `pom.xml` files.
- **JDK compatibility**: If dependency compatibility issues are encountered with the JDK upgrade (e.g. unsupported class file version, use of removed/deprecated APIs, incompatible library versions), handle them by either: **(a)** updating the dependency to a compatible version, or **(b)** replacing it with a compatible alternative.
- **Jakarta migration**: Replace `javax.persistence`, `javax.validation`, `javax.servlet`, and `javax.annotation` imports with their `jakarta.*` equivalents. Leave `javax.sql`, `javax.xml`, `javax.crypto`, and `javax.security` unchanged.
- **javax.mail → jakarta.mail**: If the project uses `javax.mail:mail`, replace with `jakarta.mail:jakarta.mail-api` and `org.eclipse.angus:angus-mail` (the reference implementation). Update all `javax.mail.*` imports to `jakarta.mail.*`.
- **javax.activation → jakarta.activation**: If the project uses `javax.activation:activation`, replace with `jakarta.activation:jakarta.activation-api`. Update imports accordingly.
- **Remove Surefire overrides**: Remove `maven-failsafe-plugin.version` and `maven-surefire-plugin.version` property overrides from `pom.xml` if present.
- **Spring Security**: If the project uses `WebSecurityConfigurerAdapter`, migrate to the `SecurityFilterChain` bean pattern. Update `@PreAuthorize` annotations and security test code as needed.
- **Auto-configuration**: If the project has `spring.factories` for auto-configuration, migrate to `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`.
- **Test and embedded dependency compatibility**: Failures in tests are often caused by test-scoped dependencies that are incompatible with JDK 17+ or Spring Boot 3.x. **Problem-solving steps:**
  1. **Identify the culprit**: From the stack trace, identify the exact dependency.
  2. **Check for a compatible version**: Search for a newer version that supports JDK 17+ and Spring Boot 3.x.
  3. **If no compatible version exists — replace with an alternative**: **Docker may be unavailable in this environment**, so **Testcontainers cannot be used**. Prefer an in-memory or embedded alternative, or mock/stub the external service in tests.
  4. **Document in the PR**: Note which dependency was replaced and why.

#### 6b. Changes for 3.x → 3.y (applies when both current and target are 3.x)

For minor-version upgrades within the Spring Boot 3.x line (e.g. 3.0 → 3.2, 3.2 → 3.3, 3.3 → 3.4):

- **Official release notes**: Read the release notes for each minor version between current and target from https://docs.spring.io/spring-boot/upgrading.html and apply documented breaking changes.
- **Java version**: If the target requires a higher Java version (e.g. 3.4 requires Java 21), update `maven.compiler.source`, `maven.compiler.target`, and `<java.version>` accordingly.
- **Deprecated API removal**: Spring Boot removes deprecated APIs in minor releases. Search for uses of APIs deprecated in the current version and replace with the documented alternatives.
- **Property changes**: Check for renamed or removed configuration properties. Use the official property migration metadata or the `spring-boot-properties-migrator` dependency (add temporarily, run, then remove) to detect issues.
- **Dependency version bumps**: Verify that any explicitly overridden dependency versions are still compatible with the target. Update or remove overrides as needed.
- **Auto-configuration changes**: Check if any auto-configuration classes were renamed, moved, or removed between the versions.

#### 6c. Changes for upgrading to 3.4+ within 3.x (applies when target is 3.4 or 3.5)

In addition to the applicable sections above:

- **Java 21**: Ensure `maven.compiler.source`, `maven.compiler.target`, and `<java.version>` are set to `21`.
- **Virtual threads**: Spring Boot 3.4+ has enhanced virtual thread support. Check the official guide for any configuration changes related to `spring.threads.virtual.enabled`.
- **Structured logging**: Spring Boot 3.4 introduces structured logging support. Review the official release notes for any changes to logging configuration.
- **3.5.x as a stepping-stone**: If the final target is 4.0, use 3.5.x as the intermediate version. On 3.5.x, resolve **all** deprecation warnings — every API deprecated in 3.x is **removed** in 4.0. Use `mvn compile -Xlint:deprecation` to find deprecated usages and replace them with the recommended alternatives before proceeding to section 6d.

#### 6d. Changes for crossing 3.x → 4.x boundary (applies when upgrading from any 3.x to any 4.x)

These changes apply to **any** upgrade that crosses the Spring Boot 3 → 4 major version boundary. The official migration guide is at https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide.

**Pre-requisite**: You must be on the **latest 3.5.x** release with all deprecation warnings resolved before applying these changes. If the current version is earlier than 3.5, apply sections 6b/6c first to reach 3.5.x.

- **Java 21 (required)**: Set `maven.compiler.source`, `maven.compiler.target`, and `<java.version>` to `21` in all `pom.xml` files.
- **Spring Framework 7**: Spring Boot 4.0 is built on Spring Framework 7.x. Any explicit Spring Framework version overrides in the POM must be updated or removed.
- **Jakarta EE 11**: Spring Boot 4.0 upgrades from Jakarta EE 10 to Jakarta EE 11. Key changes:
  - **Servlet 6.1**: Improved async processing and virtual thread integration.
  - **JPA 3.2**: Supports Java Records as projections and improved programmatic query building. Review any JPA criteria or native query code.
  - **Bean Validation 3.1**: Enhanced container type validation (Lists, Optionals). Review custom validators.
- **Removed deprecated APIs**: All classes, methods, and properties deprecated in Spring Boot 3.x are **removed** in 4.0. Search the codebase for any remaining uses and replace them. Common removals include:
  - Deprecated configuration properties (use `spring-boot-properties-migrator` on 3.5.x to identify these before upgrading).
  - Deprecated auto-configuration classes and annotations.
  - Deprecated REST client classes (`RestTemplate` builder customizations moved; review `RestClient` usage).
- **Package relocations in Spring Boot 4.0**: Several annotations and classes have moved packages. Scan all `.java` files for the old imports and replace with the new ones:
  - `org.springframework.boot.autoconfigure.domain.EntityScan` → `org.springframework.boot.persistence.autoconfigure.EntityScan`
  - `org.springframework.boot.autoconfigure.domain.EntityScanner` → `org.springframework.boot.persistence.autoconfigure.EntityScanner`
  - `org.springframework.boot.autoconfigure.domain.EntityScanPackages` → `org.springframework.boot.persistence.autoconfigure.EntityScanPackages`
  - Consult the official 4.0 migration guide for the complete list of relocated classes.
- **Jackson 3 migration**: Spring Boot 4.0 defaults to Jackson 3 instead of Jackson 2. Key changes:
  - **Group IDs changed**: `com.fasterxml.jackson` → `tools.jackson` (except `jackson-annotations` which retains `com.fasterxml.jackson.core`).
  - **Java imports changed**: All `com.fasterxml.jackson.*` **Java package imports** must also be updated to `tools.jackson.*`. This is a separate step from updating Maven group IDs — you must scan ALL `.java` files for `import com.fasterxml.jackson` and replace with `import tools.jackson`. Exceptions: `com.fasterxml.jackson.annotation.*` stays unchanged (annotations kept the old package). **Critical**: The Jackson 2 → 3 backward-compatible bridge works for most `com.fasterxml.jackson.databind` classes, but for serializer filter classes used with `MappingJacksonValue.setFilters()` and `AbstractMappingJacksonResponseBodyAdvice`, you must **keep** the Jackson 2 compat imports (`com.fasterxml.jackson.databind.ser.PropertyFilter`, `com.fasterxml.jackson.databind.ser.PropertyWriter`, `com.fasterxml.jackson.databind.ser.impl.SimpleBeanPropertyFilter`, `com.fasterxml.jackson.databind.ser.impl.SimpleFilterProvider`) because `MappingJacksonValue.setFilters()` expects `com.fasterxml.jackson.databind.ser.FilterProvider` — Jackson 3 types (`tools.jackson.databind.ser.std.SimpleFilterProvider`) are **not assignable** to this parameter.
  - **`@JsonFilter` and `FilterProvider` runtime fix**: Even with correct Jackson 2 compat imports, `MappingJacksonValue.setFilters()` does not reliably bridge the `FilterProvider` to Jackson 3's serializer, causing `InvalidDefinitionException: Cannot resolve PropertyFilter with id '...'; no FilterProvider configured` at runtime. **Fix**: Register a default `FilterProvider` directly on the `JsonMapper` via a `JsonMapperBuilderCustomizer` bean: ```java @Bean public JsonMapperBuilderCustomizer jsonFilterProviderCustomizer() { return builder -> { SimpleFilterProvider defaultFilters = new SimpleFilterProvider(); defaultFilters.setFailOnUnknownId(false); builder.filterProvider(defaultFilters); }; }``` This ensures Jackson 3's serializer always has a `FilterProvider` available. The `setFailOnUnknownId(false)` prevents crashes when `@JsonFilter` IDs don't have a matching filter registered. Use Jackson 3 types for this bean: import `tools.jackson.databind.ser.std.SimpleFilterProvider` and `org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer`. The builder method is `filterProvider(defaultFilters)` (not `filters()`).
  - **Class renames**: `Jackson2ObjectMapperBuilderCustomizer` → `JsonMapperBuilderCustomizer`; `JsonObjectSerializer` → `ObjectValueSerializer`; `JsonValueDeserializer` → `ObjectValueDeserializer`.
  - **Immutable `JsonMapper`**: The primary entry point shifts from mutable `ObjectMapper` to immutable `JsonMapper`. Update code that configures `ObjectMapper` directly.
  - **`jackson-datatype-hibernate6` → `jackson-datatype-hibernate7`**: Spring Boot 4.0 ships with **Hibernate 7**, which removes `org.hibernate.engine.spi.Mapping` and other Hibernate 6 APIs. The `jackson-datatype-hibernate6` module is incompatible — it will fail with `NoClassDefFoundError: org/hibernate/engine/spi/Mapping`. **Fix**: Replace the artifact in `pom.xml`:
    - Change `<artifactId>jackson-datatype-hibernate6</artifactId>` to `<artifactId>jackson-datatype-hibernate7</artifactId>` (group ID stays `tools.jackson.datatype` for Jackson 3, or `com.fasterxml.jackson.datatype` for Jackson 2).
    - Update ALL Java imports from `tools.jackson.datatype.hibernate6.Hibernate6Module` to `tools.jackson.datatype.hibernate7.Hibernate7Module` (in both `src/main` and `src/test`).
    - Update class references: `Hibernate6Module` → `Hibernate7Module`.
  - **`Hibernate7Module` instantiation**: Unlike `Hibernate6Module` in Jackson 3 (which removed its no-arg constructor), `Hibernate7Module` **does** have a public no-arg constructor. Use `new Hibernate7Module()` directly. If the code previously used `Hibernate6Module.builder().build()`, replace with `new Hibernate7Module()`.
  - **Jackson 3 ServiceLoader auto-discovery conflict**: Jackson 3 datatype modules register themselves via `ServiceLoader` (`META-INF/services/tools.jackson.databind.JacksonModule`) but may lack the required public no-arg constructor, causing `Unable to get public no-arg constructor` errors at startup. The primary fix is to switch from `jackson-datatype-hibernate6` to `jackson-datatype-hibernate7` (see above), which has a proper no-arg constructor and is compatible with Hibernate 7. **Important**: Do NOT use `spring.jackson.mapper.auto-detect-modules=false` — the `AUTO_DETECT_MODULES` enum constant was removed in Jackson 3 and this property will cause a startup failure (`No enum constant tools.jackson.databind.MapperFeature.auto-detect-modules`).
  - **Jackson 3 changed defaults for deserialization**: Several `DeserializationFeature` defaults changed from Jackson 2 to Jackson 3, which can break existing API contracts at runtime. Add the following to `application.properties` to restore Jackson 2 behavior:
    - `spring.jackson.deserialization.fail-on-null-for-primitives=false` — Jackson 3 changed this default to `true`. Without this, any JSON payload with `null` for a primitive field (`boolean`, `int`, `long`, etc.) will fail with `MismatchedInputException: Cannot map null into type boolean`. This is critical for APIs that receive partial JSON updates.
    - `spring.jackson.deserialization.fail-on-unknown-properties=false` — verify this is still set if the project relied on it.
    - Review other `DeserializationFeature` defaults if runtime deserialization errors occur.
  - **Jackson 3 enum serialization NPE with null `toString()`**: Jackson 3's `EnumSerializer` pre-computes `SerializableString` objects for every enum constant using `toString()`. If any enum constant's `toString()` returns `null`, serialization crashes with `NullPointerException: Cannot invoke "tools.jackson.core.SerializableString.appendQuotedUTF8(byte[], int)" because "text" is null`. **Fix**: Search all enum classes for constants with `null` field values that flow into `toString()` (e.g. `None(null)`). Add `@JsonValue` on the accessor method that returns the display value. `@JsonValue` bypasses the `EnumSerializer` `toString()`-based path and uses the standard value serializer which writes JSON `null` correctly. Also fix any `@JsonCreator` methods that use `.equals()` on the nullable field — replace with `Objects.equals()` to avoid NPE during deserialization.
  - **Temporary fallback**: If full Jackson 3 migration is not feasible immediately, set `spring.jackson.use-jackson2-defaults=true` and keep Jackson 2 dependencies alongside Jackson 3. Document this in the PR as requiring follow-up.
  - Update all explicit Jackson dependency declarations in `pom.xml` to use the new group IDs, or remove version overrides and let Spring Boot manage them.
- **Hibernate 7 proxy enforcement — no `final` methods on entities**: Hibernate 7 strictly enforces that getter and setter methods on lazy-loaded entity classes (`@Entity`, `@MappedSuperclass`) must NOT be `final`. Hibernate creates proxy subclasses for lazy loading, and `final` methods cannot be overridden by the proxy. The error is `HHH000305: Could not create proxy factory for: <Entity>` with `Setter methods of lazy classes cannot be final: <Entity>#<method>`. **Fix**: Search all entity classes for `public final` getter/setter methods and remove the `final` modifier. Use `grep -rn "public final.*\(get\|set\|is\)" <entity-package>` to find all occurrences. Common patterns include custom setters that enforce invariants — these should still work correctly without `final`, since only Hibernate's runtime proxy will override them.
- **Maven plugin compatibility with Java 21+**: When upgrading to Java 21, some Maven plugins may be incompatible with Java 21 bytecode:
  - **`jacoco-maven-plugin`**: Versions older than `0.8.11` do not support Java 21. Update to `0.8.12` or later in all `pom.xml` files that declare it.
  - **`maven-javadoc-plugin`**: Ensure version is `3.6.0` or later for Java 21 support.
  - **Other plugins**: If `mvn clean install` fails with `Unsupported class file major version` or checksum errors for a plugin, update that plugin to the latest stable version.
- **Incompatible third-party libraries**: Some libraries built for Spring Boot 3.x reference classes removed in Spring Boot 4.0. Check for these and remove/upgrade:
  - **`java-cfenv-boot` (Cloud Foundry)**: `io.pivotal.cfenv:java-cfenv-boot` versions 2.x are built for Spring Boot 3.x. If the project no longer runs on Cloud Foundry, remove it. It may also cause `ClassNotFoundException` for classes removed in Spring Boot 4.0 (e.g. `ConfigurableBootstrapContext`).
  - **`spring-cloud-azure-autoconfigure`**: The `KeyVaultEnvironmentPostProcessor` registered via `spring.factories` in `spring-cloud-azure-autoconfigure` will fail with `IllegalArgumentException: Unable to instantiate factory class` or `NoClassDefFoundError: org/springframework/boot/ConfigurableBootstrapContext` during startup — even with BOM version `7.1.0`. Fix: if the project only needs specific Azure service classes (e.g. `KafkaOAuth2AuthenticateCallbackHandler`), replace `spring-cloud-azure-starter` with the narrower `spring-cloud-azure-service` artifact to avoid pulling in autoconfigure. If the project truly needs Azure Key Vault property sources, upgrade to `spring-cloud-azure-dependencies` BOM `7.1.0+` and verify the autoconfigure module is compatible with the exact Spring Boot 4.0.x patch version in use.
  - **General**: Any library that registers an `EnvironmentPostProcessor` or `BeanFactoryPostProcessor` via `META-INF/spring.factories` and references removed Spring Boot 3.x classes will cause hard startup failures. Run `mvn dependency:tree` and check all third-party libraries for Spring Boot 4.0 compatibility.
- **Undertow removed**: Spring Boot 4.0 no longer supports Undertow as an embedded server. If the project uses `spring-boot-starter-undertow`, replace with Tomcat (default) or Jetty.
- **Removed integrations**: The following have been removed in 4.0:
  - **Embedded executable uber jar launch scripts** (fully executable JAR/WAR packaging).
  - **Spring Session Hazelcast and MongoDB** integrations.
  - **Spock testing** integration.
  - If the project uses any of these, replace with alternatives or remove.
- **spring-retry replaced**: The `spring-retry` library is replaced by a built-in retry API in `spring-core` (Spring Framework 7). Replace `@Retryable` and `RetryTemplate` usages with the new `spring-core` retry mechanism.
- **Test modularization**: Transitive test dependencies are no longer implicit in Spring Boot 4.0. If tests fail with `ClassNotFoundException` for test utilities, add explicit test starter dependencies. Review `<scope>test</scope>` dependencies.
- **`@EnableGlobalMethodSecurity` removed**: Spring Security 7 (Spring Boot 4.0) removes `@EnableGlobalMethodSecurity` and `MethodSecurityMetadataSourceAdvisor`. The app will fail at startup with `NoClassDefFoundError: org/springframework/security/access/intercept/aopalliance/MethodSecurityMetadataSourceAdvisor`. **Fix**: Search ALL `.java` files for `@EnableGlobalMethodSecurity` and replace with `@EnableMethodSecurity`. Key mapping:
  - `@EnableGlobalMethodSecurity(prePostEnabled = true)` → `@EnableMethodSecurity` (`prePostEnabled` is true by default in `@EnableMethodSecurity`, so it can be omitted)
  - `@EnableGlobalMethodSecurity(securedEnabled = true)` → `@EnableMethodSecurity(securedEnabled = true)`
  - `@EnableGlobalMethodSecurity(jsr250Enabled = true)` → `@EnableMethodSecurity(jsr250Enabled = true)`
  - Combine flags as needed. Update the import from `...configuration.EnableGlobalMethodSecurity` to `...configuration.EnableMethodSecurity`.
- **Security defaults changed**: Web applications are secured by default with stricter `SecurityFilterChain` configuration. If endpoints return 401/403:
  - Review and update `SecurityFilterChain` beans.
  - Check `@PreAuthorize` and `@Secured` annotations.
  - Update test security configurations.
- **Log4j2 vs Logback conflict after upgrade**: If the project uses Log4j2 (`spring-boot-starter-log4j2`), verify that `spring-boot-starter-logging` (Logback) is excluded from **ALL** Spring Boot and Spring Cloud starters in `pom.xml`, not just the main one. In Spring Boot 4.0, dependency tree changes may reintroduce Logback through starters that didn't pull it in before. Symptoms: Logback warnings like `Ignoring unknown property [Properties/Appenders/Loggers] in [ch.qos.logback.classic.LoggerContext]` when parsing a `log4j2*.xml` config, followed by silent startup failures (real errors hidden because logging is broken). **Fix**: Add `<exclusion>` for `spring-boot-starter-logging` to every starter dependency (`spring-boot-starter-web`, `spring-boot-starter-websocket`, `spring-boot-starter-data-jpa`, `spring-boot-starter-oauth2-resource-server`, `spring-cloud-starter-bootstrap`, `spring-cloud-starter-vault-config`, etc.).
- **Configuration properties validation**: Property validation logic has changed in 4.0. Run the application and tests to identify validation failures, then fix the property values or update validation annotations.
- **Spring Cloud compatibility**: Verify that the Spring Cloud version used is compatible with Spring Boot 4.0. Update the `spring-cloud-dependencies` BOM version to a 4.0-compatible release train. If no compatible Spring Cloud version exists yet, document in the PR.

### 6.5. Update CI, Docker, and Documentation Files

After applying all version-specific code and POM changes, scan the repository for non-POM files that reference the Java/JDK version or contain version-sensitive configuration. Update them to match the target Java version determined from the version reference table.

#### A. GitHub Actions workflow files (`.github/workflows/*.yml`)

- Scan all `.yml` files under `.github/workflows/` for `java-version:` in `actions/setup-java` steps.
- Update the `java-version` value to match the target Java version (e.g. `17` → `21` for Spring Boot 4.x).
- If `setup-java` uses an outdated action version (e.g. `@v3`), update to `@v4`.
- If `distribution` is missing or set to a non-standard value, set it to `temurin`.
- **Permissions note**: Pushing changes to `.github/workflows/` files requires the `GHAW_TOKEN` (with `workflows` scope). If the push fails due to insufficient permissions, document the required workflow file changes in the PR description as a manual step for the developer.

#### B. Dockerfiles (`**/Dockerfile`, `**/Dockerfile.*`)

- Scan all Dockerfiles for JDK base image references matching patterns like `jdk17`, `jdk-17`, `openjdk:17`, `eclipse-temurin:17`.
- Replace the JDK version portion with the target version (e.g. `jdk17` → `jdk21`, `openjdk:17` → `openjdk:21`).
- If the project uses an Artifactory-hosted base image (e.g. `artifactory-ci.gm.com/docker-share/...`), use the JFrog MCP `jfrog_execute_aql_query` tool to verify the new image tag exists before updating. If the new image tag is not found, keep the existing image and document the required change in the PR description.

#### C. Documentation files (`README.md`, `CONTRIBUTING.md`, docs)

- Scan `README.md`, `CONTRIBUTING.md`, and any files under a `docs/` directory for Java version prerequisites.
- Look for patterns like `Java 17`, `JDK 17`, `java 17`, `Java version: 17`.
- Update all occurrences to the target Java version.

#### D. Azure Pipelines (`azure-pipelines.yml`)

- If `azure-pipelines.yml` exists, scan for Java version selection logic such as `JAVA_HOME_17_X64`, `pomJavaVersion -eq 17`, or `JAVA_HOME_17`.
- Add support for the target Java version alongside existing versions. For example, add an `elseif` block for Java 21 that sets `JAVA_HOME` to `$(JAVA_HOME_21_X64)`.
- Do not remove existing Java version branches — older versions may still be needed for other branches.

#### E. Maven plugin versions (all `pom.xml` files)

- Scan all `pom.xml` files for `jacoco-maven-plugin` with versions older than `0.8.11`. If the target Java version is 21+, update to `0.8.12`.
- Scan for `maven-javadoc-plugin` with versions older than `3.6.0`. Update if needed.
- Scan for other plugins with known Java 21 incompatibilities and update them.

### 7. Verify Compilation

**Settings and proxy**: Ensure `$MAVEN_SETTINGS` is set (e.g. `ls -la "$MAVEN_SETTINGS"` or fallback to `$GITHUB_WORKSPACE/.m2/settings.xml`). **Do not commit or push `settings.xml`** (see step 9).

Use a structured **compile → diagnose → fix → recompile** loop. You have a maximum of **5 attempts** to get a clean compilation.

#### Attempt 1: Initial compilation

Run:

```bash
mvn clean install -DskipTests --settings $MAVEN_SETTINGS 2>&1 | tee /tmp/compile-attempt-1.log
echo "EXIT_CODE=$?"
```

If the exit code is `0`, compilation succeeded — skip to step 8.

#### On failure: diagnose → fix → retry (attempts 2–5)

For each failed attempt, follow this cycle before re-running the build:

1. **Capture the full error output.** Read the last 200 lines of the build log to identify every distinct compilation error (there may be multiple).
2. **Categorize each error** and apply the appropriate fix:
   - **"Could not find artifact" / "cannot be resolved"**: Confirm `--settings $MAVEN_SETTINGS` is used. Check whether dependency group IDs or artifact IDs need updating (e.g. Jackson `com.fasterxml.jackson` → `tools.jackson` for 4.x). Use the JFrog MCP tools to verify artifact availability.
   - **Import / package does not exist**: A class or package was relocated or removed. Consult the migration guide notes from step 3 and apply the correct import replacement.
   - **Symbol not found / method not found**: An API was removed or renamed in the target version. Find the replacement API in the migration guides and update the source code.
   - **Incompatible types / return-type mismatch**: A library changed its API signatures. Update calling code to match the new signatures.
   - **JDK compatibility errors** (unsupported class file version, illegal reflective access): Update or replace the offending dependency with a version compatible with the target JDK.
   - **Plugin errors**: Update the Maven plugin version (see step 6.5E).
3. **Apply all fixes** to source files and/or `pom.xml` before the next attempt — do not fix only one error per cycle.
4. **Re-run compilation**:
   ```bash
   mvn clean install -DskipTests --settings $MAVEN_SETTINGS 2>&1 | tee /tmp/compile-attempt-N.log
   echo "EXIT_CODE=$?"
   ```
   (Replace `N` with the current attempt number.)
5. **If the same error recurs** after a fix attempt, try an alternative approach (different dependency version, different API replacement, or removing the problematic dependency entirely if it is optional).

Repeat until compilation succeeds or you have exhausted all 5 attempts. **Do not proceed to step 8 until compilation succeeds.** If compilation still fails after 5 attempts, document all remaining errors in the PR description and create an issue with the full error logs.

> **Note**: If any `.github/workflows/` files could not be updated in step 6.5 due to permission restrictions (missing `workflows` scope on the token), the required changes will be documented in the PR description as manual steps for the developer.

### 8. Verify Tests run and pass

**Attempt to fix failing tests as much as possible.** Ignoring or disabling tests (e.g. with `@Disabled`, `@Ignore`) is only acceptable as a **last resort** after applying the failure loop below and when a fix is not feasible.

Use a structured **test → diagnose → fix → retest** loop. You have a maximum of **5 attempts** to get all tests passing.

#### Attempt 1: Initial test run

Run tests (no `clean` — reuse the compiled artifacts from step 7):

```bash
mvn test --settings $MAVEN_SETTINGS 2>&1 | tee /tmp/test-attempt-1.log
echo "EXIT_CODE=$?"
```

If the exit code is `0`, all tests passed — skip to step 9.

#### On failure: diagnose → fix → retry (attempts 2–5)

For each failed attempt, follow this cycle:

1. **Capture and parse the failure output.** Identify every distinct failing test and its root cause from the stack traces. Group failures by root cause — multiple test failures often share the same underlying issue.
2. **Categorize each failure** and apply the appropriate fix:
   - **`ClassNotFoundException` / `NoClassDefFoundError` in tests**: A test-scoped dependency is incompatible with the target JDK or Spring Boot version. Find a newer compatible version; if none exists, replace with an alternative (no Testcontainers — Docker unavailable).
   - **`NoSuchMethodError` / `NoSuchFieldError`**: An API changed between versions. Update the test code to use the new API.
   - **Spring context failures** (`BeanCreationException`, `UnsatisfiedDependencyException`): A bean configuration or auto-configuration changed. Review the migration guide and update configuration classes or properties.
   - **Assertion failures due to behavior changes**: A library or framework changed its default behavior (e.g. Jackson serialization defaults, security defaults). Update the test expectations or add configuration to restore the previous behavior where appropriate.
   - **Connection / timeout / resource errors**: These are typically environment-related, not upgrade-related. If a test requires an external service that is unavailable, mock or stub it.
3. **Apply all fixes** to test files, source files, configuration files, and/or `pom.xml` before the next attempt — fix as many distinct failures as possible in each cycle.
4. **Re-run the build and tests together** to ensure fixes did not break compilation:
   ```bash
   mvn clean install --settings $MAVEN_SETTINGS 2>&1 | tee /tmp/test-attempt-N.log
   echo "EXIT_CODE=$?"
   ```
   (Replace `N` with the current attempt number. Using `clean install` here ensures compilation is still valid after test fixes.)
5. **If a test keeps failing** after two fix attempts with different approaches, and no viable fix exists:
   - Add `@Disabled("TODO: Fix after Spring Boot upgrade — <brief reason>")` to the test as a last resort.
   - Record the test name and failure reason for the PR description.
6. **If new compilation errors appear** after test fixes, go back to the Step 7 fix cycle before re-running tests.

Repeat until all tests pass (or only explicitly `@Disabled` tests remain) or you have exhausted all 5 attempts.

#### After the loop

- **Record final test results**: Run `mvn test --settings $MAVEN_SETTINGS` one final time if any fixes were applied in the last attempt, and capture the summary (total/passed/failed/skipped).
- **Document any remaining failures** in the PR description with the test name, stack trace summary, and reason the fix was not feasible.
- Only if a fix is not feasible after following the full loop, document the remaining failures in the PR.

### 9. Create Pull Request

**Never commit secrets or settings.xml.** The Maven `settings.xml` file (and the `.m2/` directory) contains credentials and **must never be committed or pushed**. Ensure **`.gitignore`** excludes `.m2/` and `**/settings.xml`.

Once compilation succeeds and any changes have been made, create a pull request:
- **Base branch**: The PR must target the branch the workflow runs on, or the repository default branch if no branch context is available.
- **Title**: `Upgrade Spring Boot from [detected-current-version] to ${{ inputs.target-version }}`
- **Description**: Include:
  - Upgrade path taken (e.g. 3.5 → 4.0)
  - Changes made at each hop
  - Compilation status
  - Test results (total/passed/failed/skipped)
  - Links to migration guides followed
  - Java version change (if applicable)
  - Spring Cloud version change (if applicable)
  - Peripheral files updated (list all CI workflows, Dockerfiles, README, azure-pipelines, and Maven plugins that were modified in step 6.5)
  - **Required manual steps** (only if some files could not be updated automatically — e.g. `.github/workflows/` files that failed to push due to missing `workflows` token scope, or Dockerfile base images that could not be verified in Artifactory)
  - Document any test failures that could not be resolved

If blocking issues (e.g., unresolvable compilation failures) prevent a useful upgrade, create an issue instead with full details.

Thanks
Raj