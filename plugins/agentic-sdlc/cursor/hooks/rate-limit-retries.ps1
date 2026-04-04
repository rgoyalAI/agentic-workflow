#requires -Version 5.1
<#
.SYNOPSIS
  postToolUse hook: increments retry_count on failed tool outcomes; escalates at >= 3.
  Session file: ./context/sdlc-session.json (relative to workspace root).
  Set AGENTIC_STORY_ID to isolate counters per story.
#>

$ErrorActionPreference = 'Stop'

function Get-WorkspaceRoot {
    if ($env:CURSOR_WORKSPACE_ROOT) { return $env:CURSOR_WORKSPACE_ROOT }
    return (Get-Location).Path
}

$raw = [Console]::In.ReadToEnd()
$failed = $false
if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
        $evt = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($evt.error) { $failed = $true }
        if ($evt.result -and $evt.result.error) { $failed = $true }
        if ($null -ne $evt.exitCode -and $evt.exitCode -ne 0) { $failed = $true }
        if ($null -ne $evt.success -and $evt.success -eq $false) { $failed = $true }
    } catch {
        # If payload is not JSON or lacks fields, do not count as failure
    }
}

if (-not $failed) {
    if ($env:AGENTIC_FORCE_RETRY_COUNT -eq '1') { $failed = $true } else { exit 0 }
}

$root = Get-WorkspaceRoot
$sessionPath = Join-Path $root 'context/sdlc-session.json'
$storyId = if ($env:AGENTIC_STORY_ID) { $env:AGENTIC_STORY_ID } else { 'default' }

if (-not (Test-Path -LiteralPath (Split-Path $sessionPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $sessionPath -Parent) -Force | Out-Null
}

$session = [ordered]@{ story_id = $storyId; retry_count = 0; updated_utc = (Get-Date).ToUniversalTime().ToString('o') }
if (Test-Path -LiteralPath $sessionPath) {
    try {
        $existing = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.story_id -eq $storyId -and $null -ne $existing.retry_count) {
            $session.retry_count = [int]$existing.retry_count
        }
    } catch { }
}

$session.retry_count = [int]$session.retry_count + 1
$session.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
($session | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $sessionPath -Encoding UTF8

if ([int]$session.retry_count -ge 3) {
    $msg = [ordered]@{
        type = 'RETRY_LIMIT_ESCALATION'
        story_id = $storyId
        retry_count = $session.retry_count
        instruction = 'STOP retry loop after 3 failures per story — escalate to human (GUARDRAILS Sign 3).'
    }
    ($msg | ConvertTo-Json -Depth 5) | Write-Output
    Write-Error '[GUARDRAIL] retry_count >= 3 for this story. Pause automation and escalate.'
    exit 4
}

exit 0
