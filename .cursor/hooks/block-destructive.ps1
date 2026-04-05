# block-destructive.ps1
# Cursor hook script.
#
# Reads JSON input from stdin and blocks shell commands that look destructive.
# Allows build-tool lifecycle commands (mvn clean, gradle clean, dotnet clean, go clean)
# because these only remove build artifacts, not source code.

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

$lower = $input.ToLowerInvariant()

# --- Allowlist: build-tool lifecycle commands that are safe ---
$allowPatterns = @(
  'mvn\s+(clean|compile|test|verify|package|install)',
  'mvn\s+[\w.:/-]+\s+clean',
  'mvnw\s+(clean|compile|test|verify|package|install)',
  'gradlew?\s+(clean|build|test|check)',
  'gradle\s+(clean|build|test|check)',
  'dotnet\s+(clean|build|test|publish)',
  'go\s+clean',
  'npm\s+run\s+(clean|build|test)',
  'cargo\s+clean'
)

foreach ($allow in $allowPatterns) {
  if ($lower -match $allow) {
    Write-Output '{"permission":"allow"}'
    exit 0
  }
}

# --- Blocklist: truly destructive patterns ---
$dangerousPatterns = @(
  @{ Pattern = 'rm\s+-rf\s+/';        Reason = 'Recursive delete from filesystem root.' }
  @{ Pattern = 'rm\s+-rf\s+~';        Reason = 'Recursive delete of home directory.' }
  @{ Pattern = 'rm\s+-fr\s+/';        Reason = 'Recursive delete from filesystem root.' }
  @{ Pattern = 'rmdir\s+/s';          Reason = 'Recursive directory removal.' }
  @{ Pattern = 'del\s+/s\s+/q';       Reason = 'Quiet recursive file deletion.' }
  @{ Pattern = 'remove-item.*-recurse.*[/\\](?:users|windows|program)'; Reason = 'Recursive delete of system directory.' }
  @{ Pattern = 'kubectl\s+delete';     Reason = 'Kubernetes resource deletion.' }
  @{ Pattern = 'drop\s+table';         Reason = 'DDL can destroy production data.' }
  @{ Pattern = 'drop\s+database';      Reason = 'Dropping a database is irreversible.' }
  @{ Pattern = 'truncate\s+table';     Reason = 'Truncates remove all rows.' }
  @{ Pattern = 'git\s+push\s+.*--force'; Reason = 'Force-push can rewrite shared history.' }
  @{ Pattern = 'git\s+push\s+-f';     Reason = 'Force-push can rewrite shared history.' }
  @{ Pattern = 'git\s+reset\s+--hard'; Reason = 'Hard reset discards local work.' }
)

foreach ($entry in $dangerousPatterns) {
  if ($lower -match $entry.Pattern) {
    Write-Output '{"permission":"deny"}'
    exit 2
  }
}

# DELETE FROM without WHERE
if ($lower -match 'delete\s+from\s+') {
  if ($lower -notmatch '\bwhere\b') {
    Write-Output '{"permission":"deny"}'
    exit 2
  }
}

Write-Output '{"permission":"allow"}'
exit 0
