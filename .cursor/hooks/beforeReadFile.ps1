# Empty Cursor hook sample: beforeReadFile

try {
  $stdin = [Console]::OpenStandardInput()
  $buffer = New-Object byte[] 4096
  while (($bytesRead = $stdin.Read($buffer, 0, $buffer.Length)) -gt 0) { }
} catch {
  # best-effort: never block agent execution for placeholder hooks
}

# Allow file reads (placeholder).
Write-Output '{"permission":"allow"}'
exit 0

