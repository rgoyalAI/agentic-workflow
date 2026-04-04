#requires -Version 5.1
<#
.SYNOPSIS
  preToolUse hook: Tier 3 actions require explicit human approval.
  Set AGENTIC_TIER3_APPROVED=1 for the approved invocation, or create .agentic-tier3-approved in workspace root.
#>

$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

$text = $raw
try {
    $o = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($o.command) { $text += ' ' + [string]$o.command }
    if ($o.arguments) { $text += ' ' + ($o.arguments | ConvertTo-Json -Compress -Depth 6) }
} catch { }

$lower = $text.ToLowerInvariant()
$isTier3 = $false
$reason = ''

$tier3Checks = @(
    @{ Test = { param($s) $s -match '\bgh\s+pr\s+create\b' -or $s -match '\bhub\s+pull-request\b' }; Name = 'PR creation' }
    @{ Test = { param($s) $s -match '\bgit\s+push\b' }; Name = 'git push' }
    @{ Test = { param($s) $s -match '\bjira\b' -or $s -match 'createIssue' -or $s -match 'atlassian' }; Name = 'Jira/issue creation' }
    @{ Test = { param($s) $s -match '\bmigrat' -or $s -match 'flyway' -or $s -match 'liquibase' -or $s -match '\\migrations\\' }; Name = 'database migration' }
    @{ Test = { param($s) $s -match '\brm\s+-rf\b' -or $s -match 'remove-item\s+-recurse' -or $s -match '\bdel\s+/[fs]' }; Name = 'recursive file deletion' }
)

foreach ($c in $tier3Checks) {
    if (& $c.Test $lower) { $isTier3 = $true; $reason = $c.Name; break }
}

if (-not $isTier3) { exit 0 }

if ($env:AGENTIC_TIER3_APPROVED -eq '1') { exit 0 }

$ws = $env:CURSOR_WORKSPACE_ROOT
if (-not $ws) { $ws = (Get-Location).Path }
$flag = Join-Path $ws '.agentic-tier3-approved'
if (Test-Path -LiteralPath $flag) {
    Remove-Item -LiteralPath $flag -Force -ErrorAction SilentlyContinue
    exit 0
}

$req = [ordered]@{
    type = 'TIER3_APPROVAL_REQUIRED'
    action_class = $reason
    summary = 'This tool invocation matches Tier 3 (human approval required).'
    options = @(
        'Approve once: set environment variable AGENTIC_TIER3_APPROVED=1 for the next invocation.'
        'Or create an empty file .agentic-tier3-approved in the workspace root; the hook consumes it once.'
        'Or cancel and use a Tier 1/2 alternative (e.g. local branch, draft PR instructions).'
    )
    payload_excerpt = if ($text.Length -gt 500) { $text.Substring(0, 500) + '...' } else { $text }
}
($req | ConvertTo-Json -Depth 6) | Write-Output
Write-Error '[GUARDRAIL] Tier 3 action blocked pending human approval. See JSON above.'
exit 3
