# block-destructive.ps1
# Cursor hook script.
#
# Reads JSON input from stdin and blocks shell commands that look destructive.

$input = ""
try {
  $input = [Console]::In.ReadToEnd()
} catch {
  # If we can't read stdin, fail open (do not block).
  Write-Output '{"permission":"allow"}'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($input)) {
  Write-Output '{"permission":"allow"}'
  exit 0
}

# Best-effort detection. This is a template: tighten matchers to fit your environment.
$dangerousPatterns = @(
  "rm",
  "rmdir",
  "del",
  "Remove-Item",
  "kubectl delete",
  "DROP",
  "TRUNCATE"
)

$matched = $false
foreach ($pat in $dangerousPatterns) {
  if ($input -match [regex]::Escape($pat)) {
    $matched = $true
    break
  }
}

if ($matched) {
  # Exit code 2 blocks the action.
  Write-Output '{"permission":"deny"}'
  exit 2
}

Write-Output '{"permission":"allow"}'
exit 0

