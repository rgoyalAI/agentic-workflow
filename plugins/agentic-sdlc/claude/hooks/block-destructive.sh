#!/usr/bin/env bash
# Guardrail: blocks destructive git, filesystem, and SQL operations.
# Allows build-tool lifecycle commands (mvn clean, gradle clean, etc.)
# because these only remove build artifacts, not source code.

set -euo pipefail

INPUT=""
if [ -t 0 ]; then
  INPUT="$*"
else
  INPUT="$(cat || true)"
  if [ -n "$*" ]; then
    INPUT="$INPUT $*"
  fi
fi

# Normalize for matching (lowercase)
NORM=$(printf '%s' "$INPUT" | tr '[:upper:]' '[:lower:]')

# --- Allowlist: build-tool lifecycle commands that are safe ---
is_build_tool() {
  case "$NORM" in
    *"mvn "*"clean"*|*"mvn clean"*|*"mvnw "*"clean"*) return 0 ;;
    *"mvn "*"compile"*|*"mvn compile"*|*"mvn test"*|*"mvn verify"*|*"mvn package"*|*"mvn install"*) return 0 ;;
    *"gradlew "*"clean"*|*"gradle "*"clean"*|*"gradlew clean"*|*"gradle clean"*) return 0 ;;
    *"gradlew "*"build"*|*"gradlew "*"test"*|*"gradle "*"build"*|*"gradle "*"test"*) return 0 ;;
    *"dotnet clean"*|*"dotnet build"*|*"dotnet test"*|*"dotnet publish"*) return 0 ;;
    *"go clean"*|*"go build"*|*"go test"*) return 0 ;;
    *"cargo clean"*|*"cargo build"*|*"cargo test"*) return 0 ;;
    *"npm run clean"*|*"npm run build"*|*"npm test"*|*"npm install"*) return 0 ;;
    *"pip install"*|*"poetry install"*|*"bundle install"*) return 0 ;;
  esac
  return 1
}

if is_build_tool; then
  exit 0
fi

# --- Blocklist: truly destructive patterns ---
is_blocked() {
  case "$NORM" in
    *"git push"*"--force"*|*"git push"*"-f "*|*"git push -f"*|*"push --force"*)
      return 0 ;;
    *"git reset"*"--hard"*)
      return 0 ;;
    *"rm -rf /"*|*"rm -rf /*"*|*"rm -fr /"*|*"rm -rf ~"*)
      return 0 ;;
    *"drop table"*|*"drop database"*)
      return 0 ;;
    *"truncate table"*)
      return 0 ;;
  esac
  return 1
}

if is_blocked; then
  echo "block-destructive: refused command matching destructive pattern" >&2
  echo "$INPUT" >&2
  exit 1
fi

# DELETE FROM without WHERE
if echo "$NORM" | grep -qE 'delete\s+from\s+'; then
  if ! echo "$NORM" | grep -qi '\bwhere\b'; then
    echo "block-destructive: DELETE without WHERE clause blocked" >&2
    exit 1
  fi
fi

exit 0
