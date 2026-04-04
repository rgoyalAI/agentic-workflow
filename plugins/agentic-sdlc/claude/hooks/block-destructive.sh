#!/usr/bin/env bash
# Guardrail: blocks destructive git, filesystem, and SQL operations.
# Reads proposed command from stdin and/or CLI args; exits 1 if blocked.

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

is_blocked() {
  case "$NORM" in
    *"git push"*"--force"*|*"git push"*"-f "*|*"git push -f"*|*"git push -f "*|*"push --force"*|*" push -f "*)
      return 0
      ;;
    *"git reset"*"--hard"*)
      return 0
      ;;
    *"rm -rf /"*|*"rm -rf /*"*|*"rm -fr /"*)
      return 0
      ;;
    *"drop table"*|*"drop database"*)
      return 0
      ;;
    *"truncate table"*)
      return 0
      ;;
  esac
  return 1
}

if is_blocked; then
  echo "block-destructive: refused command matching destructive pattern" >&2
  echo "$INPUT" >&2
  exit 1
fi

exit 0
