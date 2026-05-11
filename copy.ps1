$inputStream = [Console]::OpenStandardInput();
$memoryStream = New-Object System.IO.MemoryStream;
$inputStream.CopyTo($memoryStream);
$utf8Text = [System.Text.Encoding]::UTF8.GetString($memoryStream.ToArray());
Set-Clipboard -Value $utf8Text
