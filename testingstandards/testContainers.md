# Test Containers

Test Containers enable development teams to perform integration or functional tests utilizing Docker containers, configured and executed within the test code. This document will provide examples on setting up test containers, migration guidance for existing K3s test configurations, and troubleshooting common issues.

With Test Containers, kubernetes and helm are no longer needed to run your functional tests since this will utilize Docker instead for the various containers spun up when executing the tests. Teams utilizing the CAF VM to run functional tests can now develop on their host machine with Docker instead of using the VM with the helm/k8s setup. See [Migrating from K3s](#migrating-from-k3s) for more information.

## Contents

- [Environment Setup](#environment-setup)
  - [Rancher Desktop](#rancher-desktop)
  - [Podman](#podman)
- [Container Setup](#container-setup)
  - [Authz](#authz)
  - [Kafka](#kafka)
  - [Oracle](#oracle)
  - [Postgres](#postgres)
  - [Pulsar](#pulsar)
  - [Redis](#redis)
  - [Solr](#solr)
  - [WireMock](#wiremock)
  - [Yugabyte](#yugabyte)
  - [Mujina](#mujina)
  - [Additional Containers](#additional-containers)
- [Migrating from K3s Configuration](#migrating-from-k3s)
  - [Identifying Containers](#identifying-containers)
  - [Configuration Data](#configuring-data)
  - [Environment Properties](#environment-properties)
  - [Running from CLI](#running-tests)
  - [Running from IDE](#running-tests)
  - [Removing Unused Files](#removing-unused-files)
- [Troubleshooting](#troubleshooting)
- [Additional Resources and Links](#additional-resources-and-links)
- [Examples](#examples)

> **Note**
>
> If migrating an application with an existing testing setup using the Maven `LOCAL` or `LOCAL-K3S` profile in conjunction with helm caf-charts installing containers to a K3s environment, please start with the [migrating from K3s configuration](#migrating-from-k3s) section.

---

## Environment Setup

Testcontainers require a Docker environment. An existing install can be checked by running `docker version`. If developing on a Linux operating system, please follow the [Docker docs](https://docs.docker.com/engine/install/) for installing.

> **Note**
>
> Windows users will need permanent Computer Enhanced Access, request through the IT Store.

### Rancher Desktop

Rancher Desktop will allow for use of Docker on Windows or MacOS. See the link for installation instructions: <https://docs.rancherdesktop.io/getting-started/installation>

**Windows / MacOS**

In order to use Rancher Desktop with Testcontainers, Kubernetes must be disabled during installation, in the settings, or via CLI.

To use the Artifactory registry, authenticate with Docker to create a `.docker/config.json` file, and use an Identity token generated from your profile for authentication:

```bash
docker login artifactory-ci.gm.com
```

To configure Rancher Desktop with the GM proxy, open **Preferences**, select the **WSL** tab, and under **Proxy** add `http://dcproxy.gm.com` with port `8080` to the proxy address.

### Podman

> **Warning**
>
> Rancher Desktop is the recommended approach to integrate Testcontainers. There are additional configurations required to set up Podman. Unexpected issues may occur, use at own risk. If using the suggested Rancher Desktop approach, please uninstall Podman as there may be conflicts.

Podman is an alternative to Rancher Desktop. GM has Colibri documentation for installing Podman on Windows, including troubleshooting steps for the most common issues. Also refer to Colibri docs for VPN configuration. Update to the latest version after installing.

When authenticating for the Artifactory registry, Podman by default creates the docker config in `.config/containers/auth.json` instead of `.docker/config.json`, and needs to have the new authfile path specified for Testcontainers:

```bash
podman login artifactory-ci.gm.com --authfile=$HOME/.docker/config.json
```

Podman can be configured to work with the GM proxy when on the network by adding the `https_proxy` and `http_proxy` environment variables into the podman machine `/etc/containers/containers.conf` file:

```bash
podman machine ssh --username=root 'sudo cat >> /etc/containers/containers.conf << EOF
env = ["http_proxy=http://naproxy.gm.com:80", "https_proxy=http://naproxy.gm.com:80", {append=true}]
EOF'
```

Restart Podman after making changes:

```bash
podman machine stop
podman machine start
```

---

## Project Setup

Add the required dependencies to the service `pom.xml` file depending on the containers you have set to enabled in your `helm-values.yaml` file under the `cicd/ephemeral` directory.

The testcontainers bill of materials in the `dependencyManagement` section of the `pom.xml` will resolve versions from any dependency from the `org.testcontainers` groupId:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>testcontainers-bom</artifactId>
      <version>1.20.3</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

---

## Container Setup

To use test containers in a test class, add a static container and start the container using a static constructor with `CONTAINER.start()`. Containers will map to a random port on startup, which can be obtained via `CONTAINER.getMappedPort(PORT)` or `CONTAINER.getFirstMappedPort()`.

If the test uses a JUnit runner or engine, add the `@Testcontainers` annotation to the top of the test class and `@Container` annotations to each container from the `org.testcontainers` `junit-jupiter` dependency with test scope:

**Maven Dependency — Version Properties**

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>junit-jupiter</artifactId>
  <version>${test-container.version}</version>
  <scope>test</scope>
</dependency>
```

See [testcontainers guides](https://testcontainers.com/guides/) for additional setup documentation. Example container setups for commonly used containers are provided below.

---

### Authz

Authz requires a `GenericContainer` for the `sec-test-token` Docker image. Add the dependency `testcontainers` from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>testcontainers</artifactId>
  <version>${test-container.version}</version>
  <scope>test</scope>
</dependency>
```

The `artifactory-ci.gm.com/docker-share/gcc/203975/sec-test-token:latest` docker image exposes port 8080 and requires the environment variable `ISSUER_URL` with value `https://localhost:8080`. It is suggested to add a wait strategy to ensure that the `/management/health` endpoint is ready before using the container.

> **Note**
>
> Docker will not pull a new image of `sec-authz-token:latest` without an image pull policy. It is recommended to set a policy during container creation so that certificates remain up to date.

```java
private static final String dockerHost = DockerClientFactory.instance().dockerHostIpAddress();
private static final int hostPort = findFreePort();

private static final GenericContainer<?> AUTHZ_CONTAINER = new GenericContainer<>(
  DockerImageName.parse("artifactory-ci.gm.com/docker-share/gcc/203975/sec-test-token:latest"))
  .withEnv("ISSUER_URL", String.format("http://%s:%d", dockerHost, hostPort))
  .withExposedPorts(8080)
  .withCreateContainerCmdModifier(cmd -> {
    cmd.getHostConfig().withPortBindings(
      new PortBinding(Ports.Binding.bindPort(hostPort),
        new ExposedPort(8080)));
  })
  .withImagePullPolicy(PullPolicy.ageBased(Duration.of(8, ChronoUnit.HOURS)))
  .waitingFor(Wait.forHttp("/management/health"));

static {
  AUTHZ_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("authz.url",
    () -> String.format("http://%s:%d", AUTHZ_CONTAINER.getHost(), AUTHZ_CONTAINER.getFirstMappedPort()));
}

private static int findFreePort() {
  try (final ServerSocket serverSocket = new ServerSocket(0)) {
    serverSocket.setReuseAddress(true);
    return serverSocket.getLocalPort();
  } catch (IOException e) {
    return 1234;
  }
}
```

The host of the Authz container can be obtained via `getHost` and port can be found with `getMappedPort(8080)` or `getFirstMappedPort()`.

> **Warning**
>
> If running other containers and plan to startup in parallel, Authz is unable to start in parallel due to a bug when using `withCreateContainerCmdModifier`. See [here](https://github.com/testcontainers/testcontainers-java/issues/4417) for more information.

---

### Kafka

[Additional Kafka Testcontainers Docs](https://java.testcontainers.org/modules/kafka/)

Add the `kafka` dependency from `org.testcontainers`:

> **Note** — The Kafka testcontainers dependency is being set to `1.20.1` explicitly due to compatibility issues.

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>kafka</artifactId>
  <version>1.20.1</version>
  <scope>test</scope>
</dependency>
```

Additionally, add the below configuration to set up the Kafka container:

```java
@Container
private static KafkaContainer kafka = new KafkaContainer(
  DockerImageName.parse("apache/kafka-native:3.8.0"));

static {
  kafka.start();

  try {
    AdasCruiseactivityFunctionalBaseTest.createTopics(kafka.getBootstrapServers());
    LOGGER.info("Successfully created Kafka Topics");
  } catch (IOException e) {
    LOGGER.info("Failed to create topics...", e);
  }
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("kafka.url", kafka::getBootstrapServers);

  // This is required since KafkaTestHelper has a method getKafkaUrl,
  // which checks system properties instead of environment properties
  // (Applications not using system properties for getKafkaUrl can ignore this)
  System.setProperty("kafka.url", kafka.getBootstrapServers());
}

private static void createTopics(String bootstrapServers) throws IOException {
  Properties config = new Properties();
  config.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

  try (AdminClient adminClient = AdminClient.create(config)) {
    Collection<NewTopic> topics = readTopicsFromFile();
    adminClient.createTopics(topics);
    verifyTopics(adminClient, topics);
  } catch (Exception e) {
    throw new IOException("Failed to create or verify topics");
  }
}

private static Collection<NewTopic> readTopicsFromFile() throws IOException {
  ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
  try (InputStream inputStream = classLoader.getResourceAsStream("kafka/topics.txt");
       BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
    return reader.lines()
      .map(line -> {
        String[] parts = line.split(":");
        String topicName = parts[0];
        int partitions = Integer.parseInt(parts[1]);
        short replicationFactor = Short.parseShort(parts[2]);
        LOGGER.info("Creating topic: {}", topicName);
        return new NewTopic(topicName, partitions, replicationFactor);
      })
      .collect(Collectors.toCollection(HashSet::new));
  } catch (Exception e) {
    throw e;
  }
}

private static void verifyTopics(AdminClient adminClient, Collection<NewTopic> expectedTopics) throws Exception {
  Set<String> expectedTopicNames = expectedTopics.stream()
    .map(NewTopic::name)
    .collect(Collectors.toSet());

  Set<String> actualTopicNames = adminClient.listTopics().names().get();

  for (String topicName : expectedTopicNames) {
    if (!actualTopicNames.contains(topicName)) {
      throw new Exception("Topic " + topicName + " was not created successfully");
    }
  }

  LOGGER.info("All topics verified successfully");
}
```

Lastly, convert the topics from your `values.yml` file to a `topics.txt` file in the `service/src/test/resources/kafka` folder so they get properly created when the above code runs. These will match the format `topicName:partitions:replicationFactor`:

```
CC-108046-VDF-TEST-LOC-SC_STATE_CHANGE:3:1
CC-108046-VDF-TEST-LOC-SC_SMRT_SYS_LEARN:3:1
CC-162609-TEST-EPG-VEH_METADATA_UPDATE_COMMAND:3:1
CC-162609-TEST-EPG-VEH_METADATA_UPDATE_RESPONSE:3:1
CC-187350-L2AUTO-TEST-EPG-ADAS-CRUISE_ACTIVITY_EVENT:3:1
```

---

### Oracle

[Additional Oracle Testcontainers Docs](https://java.testcontainers.org/modules/databases/oraclexe/)

Oracle containers use the `oracle-xe` or `oracle-free` dependency from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>oracle-xe</artifactId>
  <version>${oracle-container.version}</version>
  <scope>test</scope>
</dependency>
```

The Oracle container uses the `gvenzl/oracle-xe:21-slim-faststart` docker image and can use methods `.withUsername()` and `.withPassword()`. The `.withInitScripts()` method will run SQL scripts in the `src/test/resources` or `src/it/resources` folder at start up. Please note that while the `.withInitScripts()` can take multiple String paths arguments, each path should point to a single file and not a directory.

```java
private static final OracleContainer ORACLE_CONTAINER = new OracleContainer(
  DockerImageName.parse("gvenzl/oracle-xe:21-slim-faststart"))
  .withUsername("USERNAME")
  .withPassword("PASSWORD")
  .withInitScripts("oracle/init_script_1.sql", "oracle/init_script_2.sql");

static {
  ORACLE_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("oracle.url", ORACLE_CONTAINER::getJdbcUrl);
  registry.add("oracle.host", ORACLE_CONTAINER::getHost);
  registry.add("oracle.user", ORACLE_CONTAINER::getUsername);
  registry.add("oracle.password", ORACLE_CONTAINER::getPassword);
  registry.add("oracle.service", ORACLE_CONTAINER::getDatabaseName);
}
```

The url, host, username, password, and database name of the Oracle container can be obtained via `getJdbcUrl`, `getHost`, `getUsername`, `getPassword`, and `getDatabaseName`.

---

### Postgres

[Additional Postgres Testcontainers Docs](https://java.testcontainers.org/modules/databases/postgres/)

Postgres containers use the `postgresql` dependency from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>postgresql</artifactId>
  <version>${postgres-container.version}</version>
  <scope>test</scope>
</dependency>
```

The Postgres container uses the `pgvector/pgvector:pg16` docker image but can also use `artifactory-ci.gm.com/docker-approved/postgres:13.2` as a compatible substitute. The Postgres container has methods `.withInitScript()` to run an SQL script in `src/test/resources` or `src/it/resources` folder at start up.

```java
private static final PostgreSQLContainer POSTGRES_CONTAINER = new PostgreSQLContainer(
  DockerImageName.parse("pgvector/pgvector:pg16"))
  .withInitScript("postgres/init_script.sql");

static {
  POSTGRES_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("spring.datasource.url", POSTGRES_CONTAINER::getJdbcUrl);
  registry.add("spring.datasource.username", POSTGRES_CONTAINER::getUsername);
  registry.add("spring.datasource.password", POSTGRES_CONTAINER::getPassword);
}
```

The url, username, and password of the Postgres container can be obtained via `getJdbcUrl`, `getUsername`, and `getPassword`.

---

### Pulsar

[Additional Pulsar Testcontainers Docs](https://java.testcontainers.org/modules/pulsar/)

Pulsar containers use the `pulsar` dependency from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>pulsar</artifactId>
  <version>${test-container.version}</version>
  <scope>test</scope>
</dependency>
```

The Pulsar container uses the `apachepulsar/pulsar:3.0.2` docker image.

```java
@TestContainer
private static final PulsarContainer PULSAR_CONTAINER = new PulsarContainer(
  DockerImageName.parse("apachepulsar/pulsar:3.0.2"));

static {
  PULSAR_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("pulsar.brokerServiceUrl", PULSAR_CONTAINER::getPulsarBrokerUrl);
}
```

---

### Redis

[Additional Redis Testcontainers Docs](https://java.testcontainers.org/modules/databases/redis/)

#### JDK 11

For applications using Java 11, you will need dependency version `2.0.2` of the redis test container:

```xml
<dependency>
  <groupId>com.redis</groupId>
  <artifactId>testcontainers-redis</artifactId>
  <version>2.0.2</version>
  <scope>test</scope>
</dependency>
```

Additionally, add the below configuration to setup the Redis container:

```java
@Container
private static RedisContainer redis = new RedisContainer(
  DockerImageName.parse("redis:6.2.6"));

static {
  redis.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("redis.host", redis::getHost);
  registry.add("redis.port", redis::getFirstMappedPort);
}
```

The Redis container uses the `redis:6.2.6` docker image but can also use `artifactory-ci.gm.com/docker-approved/library/redis:6.2.1` as a compatible substitute.

---

### Solr

[Additional Solr Testcontainers Docs](https://java.testcontainers.org/modules/solr/)

Solr containers use the `solr` dependency from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>solr</artifactId>
  <version>${test-container.version}</version>
  <scope>test</scope>
</dependency>
```

The Solr container uses the `solr:8.3.0` docker image.

```java
private static final SolrContainer SOLR_CONTAINER = new SolrContainer(
  DockerImageName.parse("solr:8.3.0"));

static {
  SOLR_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("solr.url",
    () -> String.format("http://%s:%d", SOLR_CONTAINER.getHost(), SOLR_CONTAINER.getSolrPort()));
}
```

The host, solr port, and zookeeper port of the Solr container can be obtained via `getHost`, `getSolrPort`, and `getZookeeperPort`.

---

### WireMock

[Additional WireMock Testcontainers Docs](https://wiremock.org/docs/solutions/testcontainers/)

WireMock containers use the `wiremock-testcontainers-module` dependency from `org.wiremock.integrations.testcontainers`. The WireMock Testcontainers module is from `org.wiremock.integrations.testcontainers` **not** `org.testcontainers` and must be resolved manually instead of using the bill of materials. Use the latest version specified from the [Testcontainers wiremock page](https://wiremock.org/docs/solutions/testcontainers/):

```xml
<dependency>
  <groupId>org.wiremock.integrations.testcontainers</groupId>
  <artifactId>wiremock-testcontainers-module</artifactId>
  <version>1.0-alpha-13</version>
  <scope>test</scope>
</dependency>
```

The Wiremock container uses the `wiremock/wiremock:2.35.0` docker image and can use the method `.withMappingFromResource()` to provide stub definitions, with a path to a file under the `src/test/resources` or `src/it/resources` folder. Please note that `.withMappingFromResource()` can only take a single path to a single file and not a directory, but can be used multiple times for more than one stubs file.

```java
private static final WireMockContainer WIRE_MOCK_CONTAINER = new WireMockContainer(
  DockerImageName.parse("wiremock/wiremock:2.35.0"))
  .withMappingFromResource("wiremock/stubs.json")
  .withMappingFromResource("wiremock/stubs_2.json");

static {
  WIRE_MOCK_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("mock.url", WIRE_MOCK_CONTAINER::getBaseUrl);
}
```

The url for the Wiremock container can be obtained via `getBaseUrl`.

---

### Yugabyte

[Additional Yugabyte Testcontainers Docs](https://java.testcontainers.org/modules/databases/yugabytedb/)

Yugabyte containers use the `yugabyte` dependency from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>yugabytedb</artifactId>
  <version>${test-container.version}</version>
  <scope>test</scope>
</dependency>
```

Additionally, add the below configuration to setup the Yugabyte container (replace `keyspaceName`, `username`, and `password` with the ones used for your application):

```java
@Container
private static YugabyteDBYCQLContainer yugabyte = new YugabyteDBYCQLContainer(
  DockerImageName.parse("yugabytedb/yugabyte:2.14.4.0-b26"))
  .withInitScript("yugabyte/init.cql")
  .withKeyspaceName("cc_adacy_na")
  .withUsername("dummy")
  .withPassword("dummy");

static {
  yugabyte.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("yugabyte.host", yugabyte::getHost);
  registry.add("yugabyte.port", yugabyte::getFirstMappedPort);
  registry.add("yugabyte.url", AdasCruiseactivityFunctionalBaseTest::getYugabyteUrl);
}

private static String getYugabyteUrl() {
  return String.format("%s:%s", yugabyte.getHost(), yugabyte.getFirstMappedPort());
}
```

Lastly, convert your `init.cql` (or another name) script from your ConfigMap in `cicd/ephemeral/yugabyte/config-yugabyte.yaml` to a `init.cql` file in the `service/src/test/resources/yugabyte` folder so it gets properly created when the above code runs with setting an init script to run for the container.

---

### Mujina

Mujina uses a `GenericContainer` for the `mujina-idp` Docker image. Add the `testcontainers` dependency from `org.testcontainers`:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>testcontainers</artifactId>
  <version>${test-container.version}</version>
  <scope>test</scope>
</dependency>
```

The `artifactory-ci.gm.com/docker-share/gcc/161574/mujina-idp:latest` docker image exposes port 8080. The `withCreateContainerCmdModifier` method is used to bind the container's exposed port 8080 to the host's port 8080. This configuration is necessary because there is no way to dynamically inject the exposed port into the container, so the port binding must be hard-coded to ensure that the container's port is accessible on the specified host port.

```java
@Container
private static final GenericContainer<?> SAMLIDP_CONTAINER = new GenericContainer<>(
  DockerImageName.parse("artifactory-ci.gm.com/docker-share/gcc/161574/mujina-idp:latest"))
  .withExposedPorts(8080)
  .withCreateContainerCmdModifier(cmd -> cmd.withHostConfig(
    new HostConfig().withPortBindings(
      new PortBinding(Ports.Binding.bindPort(8080), new ExposedPort(8080)))));

static {
  SAMLIDP_CONTAINER.start();
}

@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("saml-idp.url",
    () -> "http://" + SAMLIDP_CONTAINER.getHost() + ":" + SAMLIDP_CONTAINER.getMappedPort(8080));
}
```

The host of the Mujina container is obtained through the `getHost()` method, while the port is derived from the `getMappedPort(8080)` method.

---

### Additional Containers

Please refer to the [Testcontainers supported modules](https://java.testcontainers.org/modules/) for a list of additional test containers. For any images without custom container implementations, a `GenericContainer` can be used with exposed ports specified with `.withExposedPorts()` and required environment variables provided via `.withEnv()`. Please refer to the [Authz container](#authz) for an example setup of a `GenericContainer`.

---

## Migrating From K3s

Applications currently using a Maven `LOCAL` or `LOCAL-K3S` profile in conjunction with helm caf-charts installing containers to a K3s environment, will need to migrate to using test containers as the latest CI/CD pipeline will not support the previous configuration. This section will provide guidance on migrating from a K3s to a Testcontainers testing configuration. When validating migration, please ensure that all tests run using `mvn clean install -P LOCAL` or `mvn clean install -P LOCAL-K3S` with the K3s configuration, execute and pass the same with Test containers.

### Identifying Containers

To identify the test containers an application's testing configuration requires, refer to the `cicd/ephemeral` directory and `helm-values.yaml`.

There is example Test container code available for reference for each of the most common images found in the `helm-values.yaml`. These examples have been validated with various projects, but will require application specific configurations. The [configuration data](#configuring-data) and [environment properties](#environment-properties) sections will provide guidance on finding these specific changes.

### Configuring Data

Under individual folders in the `cicd/ephemeral` will be configMap files with data necessary for tests.

These may need to be converted into files and moved to the `src/test/resources` or `src/it/resources` folder to be used during container initialization. For examples of how specific containers may load resource files, please refer to the sample Test container code for each container.

### Environment Properties

Maven profiles for testing with k3s are configured under the `service/pom.xml` as `LOCAL` or `LOCAL-K3S`. These are triggered when the `mvn clean install -P LOCAL` or `mvn clean install -P LOCAL-K3S` commands are executed. The `spring-boot-maven-plugin` configuration `jvmArguments`, and `maven-failsafe-plugin` configuration `systemProperties` or `systemPropertyVariables`, define application properties and variables required for application context start up.

These application properties and variables will need to be provided from Testcontainers using the `@DynamicPropertySource` annotation on a static method with a `DynamicPropertyRegistry` argument. The `.add()` method requires a string for the property, and a supplier function to populate the value using getters from the test container:

```java
@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("example.host", EXAMPLE_CONTAINER::getHost);
  registry.add("example.port", EXAMPLE_CONTAINER::getPort);
  registry.add("example.url",
    () -> String.format("http://%s:%d", EXAMPLE_CONTAINER.getHost(), EXAMPLE_CONTAINER.getFirstMappedPort()));
}
```

Code examples including property configurations are provided under the sample Test container code section. Projects may require different properties than shown in the examples, please validate which properties are required by referencing the application's `pom.xml` and `application.yml` or `application.properties` files for test profiles.

### Running Tests

Tests can be run from the **CLI** or **IDE**.

#### CLI

Once test containers migration has been complete, failsafe tests can be executed directly in CLI after a clean install:

```bash
mvn clean install
mvn clean failsafe:integration-test
```

A new Maven profile can be added, or the existing `LOCAL` or `LOCAL-K3S` profile can be modified, to trigger `maven-failsafe-plugin`. Because containers are now defined and initialized as part of the test code, additional plugins are not required for running a setup script or loading application properties.

```xml
<profile>
  <id>LOCAL</id>
  <activation>
    <activeByDefault>false</activeByDefault>
  </activation>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-failsafe-plugin</artifactId>
        <configuration>
          <additionalClasspathElements>
            <additionalClasspathElement>${project.basedir}/src/it/resources</additionalClasspathElement>
          </additionalClasspathElements>
          <redirectTestOutputToFile>true</redirectTestOutputToFile>
        </configuration>
      </plugin>
    </plugins>
  </build>
</profile>
```

If the profile `activeByDefault` is set to `true`, failsafe tests will also execute when running `mvn clean install`.

> **Note**
>
> By default the `mvn clean install` command only runs surefire tests, and does not trigger failsafe tests.

### Removing Unused Files

Once test containers migration has been completed, the `cicd` and `.run` directories and all contents should be removed.

Any Maven profiles in the `service/pom.xml` specific to K3s configuration such as `LOCAL-K3S`, `PERFORMANCE-K3S`, and/or `RUN-SERVICE-K3S` should be removed.

Any remaining Maven profile used to trigger the `maven-failsafe-plugin` should exclude `systemPropertyVariables` or `systemProperties` that are defined as part of the `@DynamicPropertySource`, and the profile should not include the `maven-resources-plugin`, `exec-maven-plugin`, `properties-maven-plugin`, or `spring-boot-maven-plugin`.

---

## Troubleshooting

- Test container start up, status, and port bindings can be displayed using the `docker ps` command.
- Container logs can be viewed using `docker logs -f CONTAINER_ID` or `docker logs -f CONTAINER_NAME`. During container startup, logs can reveal common issues such as malformed startup scripts or data files, bad paths and formatting, or missing properties and configuration.
- **Tests pass when using debugger but pass randomly when running normally and using Kafka:**
  - Verify you're not trying to build and close Kafka consumers independent of the `KafkaTestHelper` provided by CAF.
  - If using `KafkaTestHelper`, you can add a cleanup step with `@AfterEach` to use the `teardownKafka()` method in the helper class.
  - If not using `KafkaTestHelper`, you can follow the same approach above by calling the `AdminClient` class to close and `commitSync` the consumer before continuing with tests.

---

## Additional Resources and Links

- [Testcontainers Homepage](https://testcontainers.com/)
- [Testcontainer Modules](https://java.testcontainers.org/modules/)
- [Testcontainer Guides](https://testcontainers.com/guides/)
- [Getting Started in Java Spring Boot](https://testcontainers.com/guides/testing-spring-boot-rest-api-using-testcontainers/)
- [Replacing H2 with Database](https://testcontainers.com/guides/replace-h2-with-real-database-for-testing/)
- [Testing with WireMock](https://testcontainers.com/guides/testing-rest-api-integrations-using-wiremock/)
- [Testing with Kafka](https://testcontainers.com/guides/testing-spring-boot-kafka-listener-using-testcontainers/)
- [Testcontainers for Java](https://java.testcontainers.org/)
- [JUnit5 Quickstart](https://java.testcontainers.org/quickstart/junit_5_quickstart/)
- [JUnit5 Integration](https://java.testcontainers.org/test_framework_integration/junit_5/)
- [Testcontainers GitHub](https://github.com/testcontainers)
- [Testcontainers Java GitHub](https://github.com/testcontainers/testcontainers-java)
- [Spring Boot Example](https://github.com/testcontainers/testcontainers-java/tree/main/examples/spring-boot)
- [Cucumber Example](https://github.com/testcontainers/testcontainers-java/tree/main/examples/cucumber)
- [Kafka Example](https://github.com/testcontainers/testcontainers-java/tree/main/examples/kafka)

---

## Examples

### Complete Application Example

The following example demonstrates how to set up test containers for a Spring Boot application using Testcontainers.

Add the required dependencies to the service `pom.xml` file depending on the containers you have set to enabled in your `helm-values.yaml` file under the `cicd/ephemeral` directory.

The testcontainers bill of materials in the `dependencyManagement` section of the `pom.xml` will resolve versions from any dependency from the `org.testcontainers` groupId:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>testcontainers-bom</artifactId>
      <version>1.20.3</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

In this case, we'll be using redis, yugabyte, wiremock, authz, and kafka containers:

```xml
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>testcontainers</artifactId>
  <version>1.20.2</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>junit-jupiter</artifactId>
  <version>1.20.2</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>kafka</artifactId>
  <version>1.20.1</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>com.redis</groupId>
  <artifactId>testcontainers-redis</artifactId>
  <version>2.0.2</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>cassandra</artifactId>
  <version>1.20.2</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.wiremock.integrations.testcontainers</groupId>
  <artifactId>wiremock-testcontainers-module</artifactId>
  <version>1.0-alpha-13</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>yugabytedb</artifactId>
  <version>1.20.0</version>
  <scope>test</scope>
</dependency>
```

#### Configure the Application

One way to configure your application for Testcontainers is by adding the setup in the functional base test class, as done in the example below:

**`{AppName}FunctionalBaseTest.java`:**

```java
package com.gm.gcc.l2auto.adas.cruiseactivity.service.functional;

import com.github.dockerjava.api.model.ExposedPort;
import com.github.dockerjava.api.model.PortBinding;
import com.github.dockerjava.api.model.Ports;
import com.gm.gcc.l2auto.adas.cruiseactivity.service.AdasCruiseactivityMain;
import com.gm.gcc.l2auto.adas.cruiseactivity.service.functional.cassandra.FunctionalTestConfig;
import com.gm.gcc.l2auto.adas.cruiseactivity.v1.client.api.DefaultApi;
import com.redis.testcontainers.RedisContainer;
import io.cucumber.spring.CucumberContextConfiguration;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.junit.After;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.YugabyteDBYCQLContainer;
import org.testcontainers.containers.wait.strategy.HostPortWaitStrategy;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.kafka.KafkaContainer;
import org.testcontainers.lifecycle.Startable;
import org.wiremock.integrations.testcontainers.WireMockContainer;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.ServerSocket;
import java.util.*;
import java.util.stream.Collectors;

import static org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT;

@SpringBootTest(webEnvironment = RANDOM_PORT)
@ActiveProfiles("functional")
@CucumberContextConfiguration
@ContextConfiguration(
  classes = {
    ApiClientBuilder.class,
    FunctionalTestConfig.class,
    AdasCruiseactivityMain.class
  })
public abstract class AdasCruiseactivityFunctionalBaseTest {
  private static final Logger LOGGER = LoggerFactory.getLogger(AdasCruiseactivityFunctionalBaseTest.class);
  private static final String dockerHost = DockerClientFactory.instance().dockerHostIpAddress();
  private static final int hostPort = findFreePort();

  @Container
  private static RedisContainer redis = new RedisContainer(
    DockerImageName.parse("redis:6.2.6"));

  @Container
  private static YugabyteDBYCQLContainer yugabyte = new YugabyteDBYCQLContainer(
    DockerImageName.parse("yugabytedb/yugabyte:2.14.4.0-b26"))
    .withInitScript("yugabyte/init.cql")
    .withKeyspaceName("cc_adacy_na")
    .withUsername("dummy")
    .withPassword("dummy");

  @Container
  private static WireMockContainer wiremock = new WireMockContainer(
    DockerImageName.parse("wiremock/wiremock:2.35.0"))
    .waitingFor(new HostPortWaitStrategy())
    .withMappingFromResource("wiremock/mockService.json");

  @Container
  private static KafkaContainer kafka = new KafkaContainer(
    DockerImageName.parse("apache/kafka-native:3.8.0"));

  @Container
  private static final GenericContainer<?> authz = new GenericContainer<>(
    DockerImageName.parse("artifactory-ci.gm.com/docker-share/gcc/203975/sec-test-token:latest"))
    .withEnv("ISSUER_URL", String.format("http://%s:%d", dockerHost, hostPort))
    .withExposedPorts(8080)
    .withCreateContainerCmdModifier(cmd -> {
      cmd.getHostConfig().withPortBindings(
        new PortBinding(Ports.Binding.bindPort(hostPort),
          new ExposedPort(8080)));
    })
    .waitingFor(Wait.forHttp("/management/health"));

  static {
    LOGGER.info(String.format("Starting test containers at host %s", dockerHost));

    redis.start();
    yugabyte.start();
    wiremock.start();
    kafka.start();
    authz.start();

    try {
      AdasCruiseactivityFunctionalBaseTest.createTopics(kafka.getBootstrapServers());
      LOGGER.info("Successfully created Kafka Topics");
    } catch (IOException e) {
      LOGGER.info("Failed to create topics...", e);
    }
  }

  @DynamicPropertySource
  static void configureProperties(DynamicPropertyRegistry registry) {
    registry.add("redis.host", redis::getHost);
    registry.add("redis.port", redis::getFirstMappedPort);
    registry.add("yugabyte.host", yugabyte::getHost);
    registry.add("yugabyte.port", yugabyte::getFirstMappedPort);
    registry.add("yugabyte.url", AdasCruiseactivityFunctionalBaseTest::getYugabyteUrl);
    registry.add("kafka.url", kafka::getBootstrapServers);
    registry.add("mock.url", wiremock::getBaseUrl);
    registry.add("authz.url", AdasCruiseactivityFunctionalBaseTest::getAuthzUrl);

    // This is required since KafkaTestHelper has a method getKafkaUrl,
    // which checks system properties instead of environment properties
    System.setProperty("kafka.url", kafka.getBootstrapServers());
  }

  private static int findFreePort() {
    try (final ServerSocket serverSocket = new ServerSocket(0)) {
      serverSocket.setReuseAddress(true);
      return serverSocket.getLocalPort();
    } catch (IOException e) {
      return 1234;
    }
  }

  private static String getYugabyteUrl() {
    return String.format("%s:%s", yugabyte.getHost(), yugabyte.getFirstMappedPort());
  }

  private static String getAuthzUrl() {
    return "http://" + authz.getHost() + ":" + authz.getFirstMappedPort();
  }

  private static void createTopics(String bootstrapServers) throws IOException {
    Properties config = new Properties();
    config.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

    try (AdminClient adminClient = AdminClient.create(config)) {
      Collection<NewTopic> topics = readTopicsFromFile();
      adminClient.createTopics(topics);
      verifyTopics(adminClient, topics);
    } catch (Exception e) {
      throw new IOException("Failed to create or verify topics");
    }
  }

  private static Collection<NewTopic> readTopicsFromFile() throws IOException {
    ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
    try (InputStream inputStream = classLoader.getResourceAsStream("kafka/topics.txt");
         BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
      return reader.lines()
        .map(line -> {
          String[] parts = line.split(":");
          String topicName = parts[0];
          int partitions = Integer.parseInt(parts[1]);
          short replicationFactor = Short.parseShort(parts[2]);
          LOGGER.info("Creating topic: {}", topicName);
          return new NewTopic(topicName, partitions, replicationFactor);
        })
        .collect(Collectors.toCollection(HashSet::new));
    }
  }

  private static void verifyTopics(AdminClient adminClient, Collection<NewTopic> expectedTopics) throws Exception {
    Set<String> expectedTopicNames = expectedTopics.stream()
      .map(NewTopic::name)
      .collect(Collectors.toSet());

    Set<String> actualTopicNames = adminClient.listTopics().names().get();

    for (String topicName : expectedTopicNames) {
      if (!actualTopicNames.contains(topicName)) {
        throw new Exception("Topic " + topicName + " was not created successfully");
      }
    }

    LOGGER.info("All topics verified successfully");
  }

  @Autowired private ApiClientBuilder clientBuilder;

  protected DefaultApi api = new DefaultApi();

  public void setup() { api = new DefaultApi(clientBuilder.buildClient()); }

  @After
  public void cleanup() {
  }
}
```

---

### Alternative: TestExecutionListener Pattern

Alternatively, Testcontainers can be started from a test execution listener, which will start the containers before the test class is loaded and simplify the test class setup. This can be done by creating a test execution listener class and adding it to the test class using the `@TestExecutionListeners` annotation, as well as extracting the testcontainer setup code to a separate class:

**`TestContainersSetupListener.java`:**

```java
package com.gm.gcc.l2auto.adas.cruiseactivity.service.functional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.test.context.support.AbstractTestExecutionListener;

public class TestContainersSetupListener extends AbstractTestExecutionListener {
  private static final Logger LOGGER = LoggerFactory.getLogger(TestContainersSetupListener.class);

  static {
    LOGGER.info("Starting TestContainers from setup listener...");
    TestContainersManager.startContainers();
  }
}
```

**`{AppName}FunctionalBaseTest.java`:**

```java
package com.gm.gcc.l2auto.adas.cruiseactivity.service.functional;

import com.gm.gcc.l2auto.adas.cruiseactivity.service.AdasCruiseactivityMain;
import com.gm.gcc.l2auto.adas.cruiseactivity.service.functional.cassandra.FunctionalTestConfig;
import com.gm.gcc.l2auto.adas.cruiseactivity.v1.client.api.DefaultApi;
import io.cucumber.spring.CucumberContextConfiguration;
import org.junit.After;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestExecutionListeners;

import static org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT;

@SpringBootTest(webEnvironment = RANDOM_PORT)
@ActiveProfiles("functional")
@CucumberContextConfiguration
@ContextConfiguration(
  classes = {
    ApiClientBuilder.class,
    FunctionalTestConfig.class,
    AdasCruiseactivityMain.class
  })
@TestExecutionListeners(
  listeners = {
    TestContainersSetupListener.class,
  },
  mergeMode = TestExecutionListeners.MergeMode.MERGE_WITH_DEFAULTS
)
public abstract class AdasCruiseactivityFunctionalBaseTest {
  @Autowired private ApiClientBuilder clientBuilder;

  protected DefaultApi api = new DefaultApi();

  public void setup() { api = new DefaultApi(clientBuilder.buildClient()); }

  @After
  public void cleanup() {
  }

  @DynamicPropertySource
  static void configureProperties(DynamicPropertyRegistry registry) {
    TestContainersManager.configureProperties(registry);
  }
}
```

**`TestContainersManager.java`:**

```java
package com.gm.gcc.l2auto.adas.cruiseactivity.service.functional;

import com.github.dockerjava.api.model.ExposedPort;
import com.github.dockerjava.api.model.PortBinding;
import com.github.dockerjava.api.model.Ports;
import com.redis.testcontainers.RedisContainer;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.YugabyteDBYCQLContainer;
import org.testcontainers.containers.wait.strategy.HostPortWaitStrategy;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.kafka.KafkaContainer;
import org.wiremock.integrations.testcontainers.WireMockContainer;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.ServerSocket;
import java.util.*;
import java.util.stream.Collectors;

public class TestContainersManager {
  private static final Logger LOGGER = LoggerFactory.getLogger(TestContainersManager.class);
  private static final String dockerHost = DockerClientFactory.instance().dockerHostIpAddress();
  private static final int hostPort = findFreePort();

  private static RedisContainer redis = new RedisContainer(
    DockerImageName.parse("redis:6.2.6"));

  private static YugabyteDBYCQLContainer yugabyte = new YugabyteDBYCQLContainer(
    DockerImageName.parse("yugabytedb/yugabyte:2.14.4.0-b26"))
    .withInitScript("yugabyte/init.cql")
    .withKeyspaceName("cc_adacy_na")
    .withUsername("dummy")
    .withPassword("dummy");

  private static WireMockContainer wiremock = new WireMockContainer(
    DockerImageName.parse("wiremock/wiremock:2.35.0"))
    .waitingFor(new HostPortWaitStrategy())
    .withMappingFromResource("wiremock/mockService.json");

  private static KafkaContainer kafka = new KafkaContainer(
    DockerImageName.parse("apache/kafka-native:3.8.0"));

  private static final GenericContainer<?> authz = new GenericContainer<>(
    DockerImageName.parse("artifactory-ci.gm.com/docker-share/gcc/203975/sec-test-token:latest"))
    .withEnv("ISSUER_URL", String.format("http://%s:%d", dockerHost, hostPort))
    .withExposedPorts(8080)
    .withCreateContainerCmdModifier(cmd -> {
      cmd.getHostConfig().withPortBindings(
        new PortBinding(Ports.Binding.bindPort(hostPort),
          new ExposedPort(8080)));
    })
    .waitingFor(Wait.forHttp("/management/health"));

  public static void startContainers() {
    try {
      redis.start();
      yugabyte.start();
      wiremock.start();
      kafka.start();
      authz.start();

      TestContainersManager.createTopics(kafka.getBootstrapServers());
    } catch (Exception e) {
      LOGGER.error("Failed to start containers", e);
    }
  }

  @DynamicPropertySource
  static void configureProperties(DynamicPropertyRegistry registry) {
    registry.add("redis.host", redis::getHost);
    registry.add("redis.port", redis::getFirstMappedPort);
    registry.add("yugabyte.host", yugabyte::getHost);
    registry.add("yugabyte.port", yugabyte::getFirstMappedPort);
    registry.add("yugabyte.url", TestContainersManager::getYugabyteUrl);
    registry.add("kafka.url", kafka::getBootstrapServers);
    registry.add("mock.url", wiremock::getBaseUrl);
    registry.add("authz.url", TestContainersManager::getAuthzUrl);

    // This is required since KafkaTestHelper has a method getKafkaUrl,
    // which checks system properties instead of environment properties
    System.setProperty("kafka.url", kafka.getBootstrapServers());
  }

  private static int findFreePort() {
    try (final ServerSocket serverSocket = new ServerSocket(0)) {
      serverSocket.setReuseAddress(true);
      return serverSocket.getLocalPort();
    } catch (IOException e) {
      return 1234;
    }
  }

  private static String getYugabyteUrl() {
    return String.format("%s:%s", yugabyte.getHost(), yugabyte.getFirstMappedPort());
  }

  private static String getAuthzUrl() {
    return "http://" + authz.getHost() + ":" + authz.getFirstMappedPort();
  }

  public static void createKafkaTopics() {
    try {
      createTopics(kafka.getBootstrapServers());
    } catch (IOException e) {
      LOGGER.error("Failed to create Kafka topics", e);
    }
  }

  private static void createTopics(String bootstrapServers) throws IOException {
    Properties config = new Properties();
    config.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

    try (AdminClient adminClient = AdminClient.create(config)) {
      Collection<NewTopic> topics = readTopicsFromFile();
      adminClient.createTopics(topics);
      verifyTopics(adminClient, topics);
    } catch (Exception e) {
      throw new IOException("Failed to create or verify topics");
    }
  }

  private static Collection<NewTopic> readTopicsFromFile() throws IOException {
    ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
    try (InputStream inputStream = classLoader.getResourceAsStream("kafka/topics.txt");
         BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
      return reader.lines()
        .map(line -> {
          String[] parts = line.split(":");
          String topicName = parts[0];
          int partitions = Integer.parseInt(parts[1]);
          short replicationFactor = Short.parseShort(parts[2]);
          LOGGER.info("Creating topic: {}", topicName);
          return new NewTopic(topicName, partitions, replicationFactor);
        })
        .collect(Collectors.toCollection(HashSet::new));
    }
  }

  private static void verifyTopics(AdminClient adminClient, Collection<NewTopic> expectedTopics) throws Exception {
    Set<String> expectedTopicNames = expectedTopics.stream()
      .map(NewTopic::name)
      .collect(Collectors.toSet());

    Set<String> actualTopicNames = adminClient.listTopics().names().get();

    for (String topicName : expectedTopicNames) {
      if (!actualTopicNames.contains(topicName)) {
        throw new Exception("Topic " + topicName + " was not created successfully");
      }
    }

    LOGGER.info("All topics verified successfully");
  }
}
```

---

### Changes in ApiClientBuilder Class

If the `ApiClientBuilder` class is used to build the API client for functional tests, it should be updated to construct the host with the random port due to the changes with using `RANDOM_PORT` after migration to testcontainers instead of hardcoded to `8080` or the PCF dev URL.

**Before the update:**

```java
@Component
public class ApiClientBuilder {

  @Autowired
  private Environment environment;

  private RestTemplate restTemplate = new RestTemplate();

  private static final String LOCAL_HOST = "http://localhost:8080";
  private static final String CLOUD_HOST = "https://adas-cruiseactivity-dev.apps.pcfepg2wi.gm.com";
  private static final String TOKEN_SERVICE_URI = "/api/v1/oauth/test_token";

  public ApiClient buildClient() {
    String contextPath = "/adas/cruiseactivity/v1";
    ApiClient client = new ApiClient();
    client.setBasePath(determineHost() + contextPath);
    client.setApiKey(getBearerToken());
    return client;
  }

  private String getBearerToken() {
    // ... token retrieval logic
  }

  private String determineHost() {
    if (!isEmpty(environment.getProperty("pcf.app.url"))) {
      return environment.getProperty("pcf.app.url");
    }
    if (isLocalProfile() || isFunctionalProfile()) {
      return LOCAL_HOST;
    }
    return CLOUD_HOST;
  }
}
```

**After the update** — with changes made to the `determineHost` method:

```java
@Component
public class ApiClientBuilder {

  @Autowired
  private Environment environment;

  private RestTemplate restTemplate = new RestTemplate();

  private static final String TOKEN_SERVICE_URI = "/api/v1/oauth/test_token";

  public ApiClient buildClient() {
    String contextPath = "/adas/cruiseactivity/v1";
    ApiClient client = new ApiClient();
    client.setBasePath(determineHost() + contextPath);
    client.setApiKey(getBearerToken());
    return client;
  }

  private String getBearerToken() {
    // ... token retrieval logic
  }

  private String determineHost() {
    // Previously would use pcf.url or hardcoded to localhost:8080 for local/functional profiles
    // After migrating to use testcontainers the app starts up through @SpringBootTest on a RANDOM_PORT,
    // which is available through local.server.port by the time we get to this (server.port is 0 when
    // RANDOM_PORT is used)
    return String.format("http://localhost:%s", environment.getProperty("local.server.port"));
  }
}
```

---

### Post-Migration Cleanup

1. **Remove** the entire `cicd` folder from the project root. See [Removing Unused Files](#removing-unused-files).
2. **Remove** any Maven profiles under `service/pom.xml` that reference the K3S profiles and anything that injects properties from the original containers spun up with helm to `jvmArguments`. Typically, the profiles would be named `LOCAL`, `LOCAL-K3S`, `PERFORMANCE-K3S`, and/or `RUN-SERVICE-K3S`.
3. After making all the necessary changes, run the functional tests using the IntelliJ IDE or the command line. From the command line, simply run `mvn failsafe:integration-test` to run only your integration tests, as no profile is required to be specified now.

### Post-Migration Validation

Validate functional tests passed as expected. If there are errors post migration to Testcontainers, be sure to check the following:

- Verify you're not referencing the local properties from containers spun up with helm such as `${local.authz.host}` anywhere specific in the codebase or application resource files (e.g., `application.yml`, `application-functional.yml`, etc.)
- Ensure the testcontainers are started and stopped correctly at the beginning of the logs in case of docker environment errors
- Double-check your configuration classes and the profiles being set, if any, such as `@Profile({"dev","functional","cloud"})`. Be sure to use the `functional` profile when executing tests if so, which can be set in the base test class through `@ActiveProfiles` (see example above)
- If your application expects the app to be running, be sure that it starts up correctly and that your `ApiClientBuilder` class or equivalent are updated to use the correct URL
- `pcf.app.url` is no longer being used since functional tests no longer run in PCF. If your app references it, be certain to check out the `determineHost` method in the `ApiClientBuilder` class above for what to use instead. Any classes referencing the value of `pcf.app.url` will need to be updated.
- If the app isn't starting up, make sure you've added `@SpringBootTest(webEnvironment = RANDOM_PORT)` at the top of your base test class. This will start the app on a random port which we obtain during `determineHost` in the `ApiClientBuilder` class like: `environment.getProperty("local.server.port")`
