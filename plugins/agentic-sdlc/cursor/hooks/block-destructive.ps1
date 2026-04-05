#requires -Version 5.1
<#
.SYNOPSIS
  preToolUse hook: blocks destructive git, shell, and SQL patterns.
  Allows build-tool lifecycle commands (mvn clean, gradle clean, etc.)
  because these only remove build artifacts, not source code.
  Reads JSON tool event from stdin; inspects command/text fields.
#>

$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

function Get-InspectableText {
    param([string]$Json)
    $text = $Json
    try {
        $o = $Json | ConvertFrom-Json -ErrorAction Stop
        if ($null -ne $o.command) { $text += " " + [string]$o.command }
        if ($null -ne $o.toolName) { $text += " " + [string]$o.toolName }
        if ($null -ne $o.name) { $text += " " + [string]$o.name }
        if ($null -ne $o.arguments) { $text += " " + ($o.arguments | ConvertTo-Json -Compress -Depth 6) }
    } catch { }
    return $text
}

$haystack = (Get-InspectableText -Json $raw).ToLowerInvariant()

# --- Allowlist: build-tool lifecycle commands that are safe ---
$buildToolPatterns = @(
    'mvn\s+(clean|compile|test|verify|package|install)',
    'mvnw\s+(clean|compile|test|verify|package|install)',
    'gradlew?\s+(clean|build|test|check|assemble)',
    'gradle\s+(clean|build|test|check|assemble)',
    'dotnet\s+(clean|build|test|publish|restore)',
    'go\s+(clean|build|test)',
    'cargo\s+(clean|build|test)',
    'npm\s+(run\s+)?(clean|build|test|install)',
    'pip\s+install',
    'poetry\s+install',
    'bundle\s+install'
)

foreach ($bp in $buildToolPatterns) {
    if ($haystack -match $bp) {
        exit 0
    }
}

# --- Blocklist: truly destructive patterns ---
$blocklist = @(
    @{ Pattern = 'git push --force'; Reason = 'Force-push can rewrite shared history.'; Alt = 'Use revert commits or a repair branch coordinated with the team.' }
    @{ Pattern = 'git push -f'; Reason = 'Short force-push can rewrite shared history.'; Alt = 'Use revert commits or a repair branch coordinated with the team.' }
    @{ Pattern = 'git reset --hard'; Reason = 'Hard reset discards local work and can confuse collaborators.'; Alt = 'Use soft/mixed reset or stash, then coordinate.' }
    @{ Pattern = 'rm -rf /'; Reason = 'Recursive delete from filesystem root is catastrophic.'; Alt = 'Target a specific subtree under your project with confirmation.' }
    @{ Pattern = 'rm -rf ~'; Reason = 'Recursive delete of home directory is catastrophic.'; Alt = 'Delete explicit paths inside the project only.' }
    @{ Pattern = 'drop table'; Reason = 'DDL can destroy production data.'; Alt = 'Require human approval and run against the correct environment with backups.' }
    @{ Pattern = 'drop database'; Reason = 'Dropping a database is irreversible without restore.'; Alt = 'Require human approval and verify connection string and backups.' }
    @{ Pattern = 'truncate table'; Reason = 'Truncates remove all rows without row-level guardrails.'; Alt = 'Use approved maintenance windows and human approval for prod.' }
)

foreach ($entry in $blocklist) {
    if ($haystack.Contains($entry.Pattern)) {
        Write-Error ("[GUARDRAIL BLOCKED] {0} Alternative: {1}" -f $entry.Reason, $entry.Alt)
        exit 2
    }
}

# DELETE FROM without WHERE (heuristic)
if ($haystack -match 'delete\s+from\s+') {
    if ($haystack -notmatch '\bwhere\b') {
        Write-Error '[GUARDRAIL BLOCKED] DELETE without WHERE can wipe a whole table. Alternative: add a WHERE clause or use an approved batch job.'
        exit 2
    }
}

exit 0
