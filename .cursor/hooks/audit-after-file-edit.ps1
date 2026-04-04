# audit-after-file-edit.ps1
# Cursor hook script.
#
# Reads JSON input from stdin and appends a redacted audit entry to a local log.

$input = ""
try {
  $input = [Console]::In.ReadToEnd()
} catch {
  Write-Output '{}'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($input)) {
  Write-Output '{}'
  exit 0
}

$timestamp = (Get-Date).ToString("o")

# Best-effort redaction to avoid persisting common secret patterns.
$redacted = $input

# AWS Access Key ID
$redacted = [regex]::Replace($redacted, "AKIA[0-9A-Z]{16}", "[REDACTED_AWS_ACCESS_KEY]")

# JWT-like strings: 3 dot-separated base64url segments
$redacted = [regex]::Replace(
  $redacted,
  "[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+",
  "[REDACTED_JWT]"
)

$logPath = ".cursor/hooks/audit-after-file-edit.log"

try {
  # Keep the log line bounded so it doesn't explode the file.
  $maxLen = 8000
  if ($redacted.Length -gt $maxLen) {
    $redacted = $redacted.Substring(0, $maxLen) + "...[truncated]"
  }
  Add-Content -Path $logPath -Value ("[" + $timestamp + "] " + $redacted)
} catch {
  # Audit logging should never block agent work.
}

Write-Output '{}'
exit 0

