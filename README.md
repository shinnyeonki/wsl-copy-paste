[ENGLISH](README.md)
[CHINESE](README-zh.md)
[KOREAN](README-ko.md)
[JAPANESE](README-ja.md)

### Overview

This document explains how to set up `copy` and `paste` aliases in a Windows Subsystem for Linux (WSL) environment to perfectly replicate the clipboard functionality of macOS's `pbcopy` and `pbpaste`.

While many existing projects and articles attempt to solve WSL's clipboard issues, most have the following limitations:

1.  **Poor Multilingual Support**: Simply using `clip.exe` directly often leads to broken characters in multilingual environments due to encoding problems.
2.  **Unnecessary Program Installation**: Solutions that require installing separate programs are too heavyweight. This guide resolves the issue with a simple alias configuration.
3.  **Incomplete Integration**: Many solutions do not fully integrate with the Windows clipboard, often causing issues where content does not appear correctly in the clipboard history (`Win + V`).
4.  **Preserves Windows Default Text Handling**: This method uses Windows' native text processing, avoiding the text corruption in other software that can occur when changing system default settings.

### Quick Install (Recommended)

This is an installation script. Copy and paste the command below into your terminal and run it.

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

After installation, restart your terminal or run `source ~/.bashrc` (or `source ~/.zshrc`), and you can immediately use the `copy` and `paste` commands.

If you want to remove or reset the aliases, you can simply run the same command again.


### Core Principle: A Fundamental Solution to Encoding and Newline Issues

What sets this method apart from other solutions is its use of PowerShell's low-level I/O capabilities to **fundamentally solve encoding and newline character problems**.

Initially, approaches using tools like `iconv` to convert between Korean `UTF-8` and WSL's `UTF-8` were considered, but they had limitations, such as breaking certain character sets like emojis or Thai. This is due to the complex encoding schemes used by Windows. Currently, Windows uses both a code page for legacy programs (e.g., `CP949`) and `UTF-16` for modern systems.

This guide's approach avoids dealing with this complexity directly by **leveraging Windows' built-in API compatibility layer (API Thunking Layer)**. In other words, instead of forcing encoding conversions, it explicitly handles the data at both ends of the data stream.

*   **COPY (WSL → Windows)**: Data piped from WSL is treated as a pure **byte stream**, not as text. This byte stream is then **explicitly interpreted as UTF-8** in PowerShell, converted to a Unicode string, and stored in the Windows clipboard.
*   **PASTE (Windows → WSL)**: Unicode text from the Windows clipboard is converted into a **UTF-8 byte stream** in PowerShell and then passed directly to WSL's standard output. This process fundamentally prevents the Windows console from misinterpreting the text and altering its encoding.

This method ensures perfect string compatibility without any data loss.

### The Problem: Incompatibility Between WSL and Windows Clipboard

Windows and Linux (WSL) have two major differences in how they handle text data, which can lead to data corruption during simple clipboard operations.

1.  **Difference in Newline Characters**:
    *   **Windows**: Marks the end of a line with **CRLF** (`\r\n`, Carriage Return + Line Feed).
    *   **Linux/macOS**: Uses only **LF** (`\n`, Line Feed).
    *   This difference can cause line breaks to be mangled or unnecessary characters like `^M` to be inserted when copying text between WSL and Windows.

2.  **Difference in Encoding**:
    *   The WSL terminal environment defaults to **UTF-8** encoding.
    *   However, when data is passed through a pipeline to PowerShell without explicit encoding, it may be misinterpreted using the system's default encoding (e.g., `UTF-16`).
    *   This causes multibyte characters like Korean, Japanese, and emojis to become corrupted, appearing as `???` or other strange characters.

### Manual Installation

You can manually add the following code to the bottom of your `.bashrc` or `.zshrc` file:

```shell
# Add to your .zshrc or .bashrc file
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

To apply the changes to your terminal, run `source ~/.bashrc` or `source ~/.zshrc`, or open a new terminal.

### Detailed Code Explanation

#### `copy` (WSL -> Windows Clipboard)

Copies data piped from a command, such as `cat test.txt | copy`, to the Windows clipboard.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `$stdin.CopyTo($bytes)`: Reads the data from WSL as a byte stream without corruption.
3.  `[System.Text.Encoding]::UTF8.GetString(...)`: **Explicitly decodes** the byte stream as **UTF-8** to convert it into text. This is the key to preventing multilingual characters from breaking.
4.  `Set-Clipboard -Value $text`: Stores the final converted text in the Windows clipboard.

#### `paste` (Windows Clipboard -> WSL)

Pastes the content of the Windows clipboard into the WSL terminal.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `Get-Clipboard -Raw`: Retrieves text data from the Windows clipboard.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: **Explicitly encodes** the retrieved text into a **UTF-8 byte stream**.
4.  `[Console]::OpenStandardOutput().Write(...)`: Writes the encoded byte stream directly to WSL's standard output.
5.  `tr -d "\r"`: Removes the **CR** (`\r`) character from the end of each line of the output from PowerShell. This ensures perfect compatibility by converting Windows' **CRLF** to Linux's **LF**.

### How to Test


#### TEST 2
Verify that UTF-8 + LF newlines are correctly converted to UTF-16 + CRLF in the Windows clipboard.

Run in Linux:
```shell
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt
hello
안녕하세요
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt | xxd
00000000: 6865 6c6c 6f0a ec95 88eb 8595 ed95 98ec  hello...........
00000010: 84b8 ec9a 94                             .....
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt | copy
```


Run in Windows PowerShell:
A script to analyze the bytes of the latest text in the clipboard.
```powershell
# Function to output a byte array in a format similar to xxd
function Format-Hex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [byte[]]$InputObject,

        [int]$BytesPerLine = 16
    )
    process {
        for ($offset = 0; $offset -lt $InputObject.Length; $offset += $BytesPerLine) {
            $length = [System.Math]::Min($BytesPerLine, $InputObject.Length - $offset)
            $lineBytes = $InputObject[$offset..($offset + $length - 1)]

            # 1. Create the Offset part
            $offsetString = "{0:X8}:" -f $offset

            # 2. Create the Hex part
            $hexString = ($lineBytes | ForEach-Object { "{0:X2}" -f $_ }) -join ' '
            $hexString = $hexString.PadRight($BytesPerLine * 3 - 1)

            # 3. Create the ASCII character part (only printable characters)
            $asciiString = ($lineBytes | ForEach-Object {
                if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { '.' }
            }) -join ''

            # Combine the three parts into one line for output
            "$offsetString $hexString  $asciiString"
        }
    }
}

# --- Main execution logic (text only) ---

try {
    # Use the -Raw option to get only the pure text string
    $clipboardText = Get-Clipboard -Raw -ErrorAction SilentlyContinue

    if ($null -ne $clipboardText) {
        Write-Host "Displaying the raw bytes (UTF-16 LE) of the clipboard text." -ForegroundColor Green

        # Convert to a byte array in UTF-16 LE (Unicode), the default encoding for .NET strings
        # This is the 'as-is' byte representation of the text in the Windows clipboard
        $clipboardBytes = [System.Text.Encoding]::Unicode.GetBytes($clipboardText)

        # Output using the hex dump function
        $clipboardBytes | Format-Hex
    }
    else {
        Write-Warning "There is no text data on the clipboard."
    }
}
catch {
    Write-Error "An error occurred while reading the clipboard: $($_.Exception.Message)"
}
```

1.  **Original File (sample2.txt in WSL)**
    *   `6865 6c6c 6f`: "hello" (UTF-8)
    *   `0a`: LF (Line Feed) newline character
    *   `ec95 88eb 8595 ed95 98ec 84b8 ec9a 94`: "안녕하세요" (UTF-8)

2.  **Result Copied to Windows Clipboard**
    Reconstructing the Hex value provided by the user into a standard format gives the following. This is the actual byte value stored in the Windows clipboard.

    *   `68 00 65 00 6c 00 6c 00 6f 00`: "hello" (UTF-16 Little Endian)
    *   `0d 00 0a 00`: CRLF (Carriage Return + Line Feed) newline character (UTF-16 Little Endian)
    *   `48 C5 55 B1 58 D5 38 C1 94 C6`: "안녕하세요" (UTF-16 Little Endian)

As you can see, the original LF (`0a`) has been correctly converted to CRLF (`0d 00 0a 00`), and the entire string has been properly encoded from UTF-8 to UTF-16 Little Endian.




#### TEST 2

Run the script below to verify that the content of the original file and the content after going through `copy` & `paste` are identical at the byte level.
To run this test, a file named 'sample.txt' must be present in the current directory.

```shell
echo "--- Byte sequence of the original file (sample.txt) ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- Byte sequence obtained from the clipboard (paste) ---"
paste | xxd
echo ""

echo "--- Comparison of the two byte sequences (diff result) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ The two byte sequences match perfectly."
else
    echo "--> ❌ A difference was found between the two byte sequences."
fi
```

### Expected Results

When you run the test script, the `diff` command should produce no output, and you should see the following success message at the end. This means that the original data and the data that passed through the clipboard are 100% identical.

```
--- Byte sequence of the original file (sample.txt) ---
(xxd output appears here)

--- Byte sequence obtained from the clipboard (paste) ---
(xxd output appears here - should be identical to the above)

--- Comparison of the two byte sequences (diff result) ---

--> ✅ The two byte sequences match perfectly.
```