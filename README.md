[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### Overview
This document explains how to set up `copy` and `paste` aliases in a WSL (Windows Subsystem for Linux) environment to achieve seamless clipboard functionality, similar to macOS's `pbcopy` and `pbpaste`. This method resolves encoding and newline character issues that can occur when copying and pasting text between WSL and Windows.

### The Problem: Incompatibility Between WSL and the Windows Clipboard
Windows and Linux (WSL) have two key differences in how they handle text data, which can lead to data corruption during simple clipboard interactions.

1.  **Newline Character Differences**:
    *   **Windows**: Uses **CRLF** (`\r\n`, Carriage Return + Line Feed) to mark the end of a line.
    *   **Linux/macOS**: Uses only **LF** (`\n`, Line Feed).
    *   This discrepancy can cause broken line breaks or the insertion of unwanted characters like `^M` when pasting text from WSL to Windows, or vice versa.

2.  **Encoding Differences**:
    *   Most WSL terminal environments use **UTF-8** encoding by default.
    *   However, when data is piped to PowerShell without explicit encoding, it can be misinterpreted using the system's default encoding (e.g., `cp949`).
    *   This leads to issues where multibyte characters, such as Korean, Japanese, or emojis, become corrupted and appear as `???` or other garbled text.

### Solution: Setting Up Aliases Using PowerShell
To solve these problems, we can directly call Windows's `powershell.exe` from WSL to control the clipboard. Add the following code to the bottom of your `.bashrc` or `.zshrc` file.

```shell
# Add to your .zshrc or .bashrc
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

To apply the changes, run `source ~/.bashrc` or `source ~/.zshrc`, or simply open a new terminal.

### Detailed Code Explanation

#### `copy` (WSL to Windows Clipboard)
This copies data piped from commands (e.g., `cat test.txt | copy`) to the Windows clipboard.

1.  `sed "s/$/\r/"`: Appends a **CR** (`\r`) character to the end (`$`) of each line. This converts the Linux **LF** (`\n`) to the Windows **CRLF** (`\r\n`).
2.  `powershell.exe ...`: Executes a PowerShell script.
3.  `$stdin.CopyTo($bytes)`: Reads the incoming data from WSL as a raw byte stream, preventing any corruption.
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: **Explicitly decodes** the byte stream as **UTF-8** to convert it into text. This is the key to ensuring multilingual characters are not broken.
5.  `Set-Clipboard -Value $text`: Finally, saves the correctly converted text to the Windows clipboard.

#### `paste` (Windows Clipboard to WSL)
This pastes the content of the Windows clipboard into the WSL terminal.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `Get-Clipboard -Raw`: Retrieves the text data from the Windows clipboard.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: **Explicitly encodes** the retrieved text into a **UTF-8 byte stream**.
4.  `[Console]::OpenStandardOutput().Write(...)`: Writes the encoded byte stream directly to WSL's standard output.
5.  `sed "s/\r$//"`: Removes the trailing **CR** (`\r`) character from the end of each line. This converts the Windows **CRLF** back to the Linux-compatible **LF**, ensuring perfect compatibility.

### How to Test
You can run the following script to verify that the content of an original file and the content after a `copy` & `paste` cycle are perfectly identical, byte for byte.
A file named `sample.txt` must exist in the current directory for this test.
```shell
echo "--- Byte Sequence of Original File (sample.txt) ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- Byte Sequence from Clipboard (paste) ---"
paste | xxd
echo ""

echo "--- Comparison of the Two Byte Sequences (diff result) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ The two byte sequences are perfectly identical."
else
    echo "--> ❌ A difference was found between the two byte sequences."
fi
```

### Expected Result
When you run the test script, the `diff` command should produce no output, and the final success message should be displayed as follows. This indicates that the original data and the data passed through the clipboard are 100% identical.

```
--- Byte Sequence of Original File (sample.txt) ---
(xxd output appears here)

--- Byte Sequence from Clipboard (paste) ---
(xxd output appears here - should be identical to the above)

--- Comparison of the Two Byte Sequences (diff result) ---

--> ✅ The two byte sequences are perfectly identical.
```
