# Empty Cursor hook sample: beforeSubmitPrompt

try {
  $stdin = [Console]::OpenStandardInput()
  $buffer = New-Object byte[] 4096
  while (($bytesRead = $stdin.Read($buffer, 0, $buffer.Length)) -gt 0) { }
} catch {
  # best-effort: never block agent execution for placeholder hooks
}

# Allow the user prompt to be submitted.
Write-Output '{"continue":true}'
exit 0

