# Empty Cursor hook sample: stop

try {
  $stdin = [Console]::OpenStandardInput()
  $buffer = New-Object byte[] 4096
  while (($bytesRead = $stdin.Read($buffer, 0, $buffer.Length)) -gt 0) { }
} catch {
  # best-effort: never block agent execution for placeholder hooks
}

# No follow-up message; allow the agent loop to end normally.
Write-Output '{}'
exit 0

