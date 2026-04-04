# Empty Cursor hook sample: preToolUse

try {
  $stdin = [Console]::OpenStandardInput()
  $buffer = New-Object byte[] 4096
  while (($bytesRead = $stdin.Read($buffer, 0, $buffer.Length)) -gt 0) { }
} catch {
  # best-effort: never block agent execution for placeholder hooks
}

# Allow the tool call to proceed unchanged.
Write-Output '{"permission":"allow"}'
exit 0

