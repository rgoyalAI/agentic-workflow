# Multi-stage ASP.NET Core — .NET 8 SDK build, ASP.NET Alpine runtime
# Build context: directory containing the .csproj / solution.

ARG DOTNET_VERSION=8.0
ARG APP_USER=app
ARG APP_UID=1001
ARG APP_GID=1001

# --- Build & publish ---
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS builder
WORKDIR /src

# Replace path with your API project directory and .csproj name
COPY YourApp.Api/YourApp.Api.csproj YourApp.Api/
RUN dotnet restore YourApp.Api/YourApp.Api.csproj

COPY . .
RUN dotnet publish YourApp.Api/YourApp.Api.csproj -c Release -o /app/publish \
    /p:UseAppHost=false \
    /p:PublishTrimmed=true \
    /p:TrimMode=partial

# --- Runtime ---
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION}-alpine AS runtime

ARG APP_USER
ARG APP_UID
ARG APP_GID

RUN addgroup -g ${APP_GID} ${APP_USER} \
    && adduser -u ${APP_UID} -G ${APP_USER} -D -h /app ${APP_USER}

WORKDIR /app

COPY --from=builder /app/publish .

RUN chown -R ${APP_UID}:${APP_GID} /app

USER ${APP_UID}:${APP_GID}

ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_EnableDiagnostics=0

EXPOSE 8080

ENTRYPOINT ["dotnet", "YourApp.Api.dll"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1

LABEL org.opencontainers.image.title="dotnet-api" \
      org.opencontainers.image.description="ASP.NET Core on Alpine runtime, trimmed publish"
