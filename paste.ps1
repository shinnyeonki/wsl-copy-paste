$clipboardText = Get-Clipboard -Raw;
if ($clipboardText -ne $null) {
  $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($clipboardText);
  $outputStream = [Console]::OpenStandardOutput();
  $outputStream.Write($utf8Bytes, 0, $utf8Bytes.Length);
  $outputStream.Flush();
  $outputStream.Close();
}
