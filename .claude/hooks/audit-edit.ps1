# audit-edit.ps1
# Claude Code hook script.
#
# Reads JSON input from stdin and appends a redacted audit entry to a local log.

$input = ""
try {
  $input = [Console]::In.ReadToEnd()
} catch {
  exit 0
}

if ([string]::IsNullOrWhiteSpace($input)) {
  exit 0
}

$timestamp = (Get-Date).ToString("o")

$redacted = $input

# AWS Access Key ID
$redacted = [regex]::Replace($redacted, "AKIA[0-9A-Z]{16}", "[REDACTED_AWS_ACCESS_KEY]")

# JWT-like strings: 3 dot-separated base64url segments
$redacted = [regex]::Replace(
  $redacted,
  "[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+",
  "[REDACTED_JWT]"
)

$logPath = Join-Path $PSScriptRoot "audit-edit.log"

try {
  $maxLen = 8000
  if ($redacted.Length -gt $maxLen) {
    $redacted = $redacted.Substring(0, $maxLen) + "...[truncated]"
  }
  Add-Content -Path $logPath -Value ("[" + $timestamp + "] " + $redacted)
} catch {
  # Never block agent work for audit logging.
}

exit 0

