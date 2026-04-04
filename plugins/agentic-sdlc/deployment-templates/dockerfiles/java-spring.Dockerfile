# Multi-stage Spring Boot (layered JAR) — Java 21 Temurin
# Build context: repository root containing the Maven/Gradle project.
#
# Maven example:
#   docker build -f deployment-templates/dockerfiles/java-spring.Dockerfile -t app:local .
#
# Gradle: adjust COPY paths and the RUN line to use ./gradlew bootJar.

ARG JAVA_VERSION=21
ARG APP_USER=appuser
ARG APP_UID=1001
ARG APP_GID=1001

# --- Build ---
FROM eclipse-temurin:${JAVA_VERSION}-jdk AS builder
WORKDIR /workspace

# Dependency layer cache (Maven)
COPY pom.xml mvnw* ./
COPY .mvn .mvn
RUN chmod +x mvnw 2>/dev/null || true

# Copy sources after deps when possible for better caching
COPY src ./src

# Layered JAR (Spring Boot 2.5+)
RUN ./mvnw -B -ntp package -DskipTests \
    && java -Djarmode=layertools -jar target/*.jar extract --destination target/layers

# --- Runtime ---
FROM eclipse-temurin:${JAVA_VERSION}-jre-alpine AS runtime

ARG APP_USER
ARG APP_UID
ARG APP_GID

RUN addgroup -g ${APP_GID} -S ${APP_USER} \
    && adduser -u ${APP_UID} -S -G ${APP_USER} -h /app -s /sbin/nologin ${APP_USER}

WORKDIR /app

COPY --from=builder /workspace/target/layers/dependencies/ ./
COPY --from=builder /workspace/target/layers/spring-boot-loader/ ./
COPY --from=builder /workspace/target/layers/snapshot-dependencies/ ./
COPY --from=builder /workspace/target/layers/application/ ./

RUN chown -R ${APP_UID}:${APP_GID} /app

USER ${APP_UID}:${APP_GID}

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

EXPOSE 8080

# Spring Boot loader main class path
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/actuator/health || exit 1

LABEL org.opencontainers.image.title="spring-boot-app" \
      org.opencontainers.image.description="Spring Boot layered JAR on Temurin JRE Alpine"
