[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### Overview

This document explains how to set up `copy` and `paste` aliases in a WSL (Windows Subsystem for Linux) environment to perfectly replicate the clipboard functionality of macOS's `pbcopy` and `pbpaste`.

While many existing projects and articles attempt to solve clipboard issues in WSL, most have the following limitations:

1.  **Poor Multilingual Support**: Simple methods that directly use `clip.exe` often break characters in a multilingual environment due to encoding problems.
2.  **Unnecessary Bloat**: Solutions that require installing separate programs are too heavyweight. This guide solves the problem with simple alias settings.
3.  **Incomplete Integration**: They often fail to integrate perfectly with the Windows clipboard, causing content not to appear correctly in the clipboard history (`Win + V`).
4.  **Preserves Windows' Default Text Handling**: This method uses Windows' native text processing as-is, avoiding the text corruption in other software that can occur when changing default system settings.

The method presented in this guide fundamentally solves encoding and newline character issues by leveraging PowerShell's low-level I/O capabilities. Initially, an approach using `iconv` was considered to handle `CP949` encoding for Korean, Japanese, and Chinese environments. However, it was found to break certain character sets, such as emojis and Thai characters.

Therefore, this method works on the following principles to provide a perfect solution:

*   **COPY**: It processes input piped from WSL not as text, but as a pure **byte stream**. This byte stream is explicitly interpreted as **UTF-8** to convert it into a Unicode string, which is then saved to the Windows clipboard.
*   **PASTE**: It retrieves Unicode text from the Windows clipboard, converts it into a **UTF-8 byte stream**, and outputs it directly to WSL. This process prevents the Windows console from misinterpreting the text and altering its encoding.

### The Problem: Incompatibility Between WSL and Windows Clipboard

Windows and Linux (WSL) have two major differences in how they handle text data, which can lead to data corruption during simple clipboard interactions.

1.  **Newline Character Difference**:
    *   **Windows**: Uses **CRLF** (`\r\n`, Carriage Return + Line Feed) to mark the end of a line.
    *   **Linux/macOS**: Uses only **LF** (`\n`, Line Feed).
    *   This difference can cause line breaks to be broken or unnecessary characters like `^M` to be inserted when copying text from WSL to Windows or vice versa.

2.  **Encoding Difference**:
    *   WSL terminal environments mostly use **UTF-8** encoding by default.
    *   However, when data is passed to PowerShell through a pipeline without an explicit encoding, it can be misinterpreted using the system's default encoding (e.g., `cp949`).
    *   This causes multibyte characters, such as Korean, Japanese, and emojis, to become corrupted and appear as `???` or other strange characters.

### Solution: Setting up Aliases Using PowerShell

To solve these problems, we will call Windows' `powershell.exe` directly from WSL to control the clipboard. Add the following code to the bottom of your `.bashrc` or `.zshrc` file.

```shell
# Add to your .zshrc or .bashrc
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

To apply the changes to your terminal, run `source ~/.bashrc` or `source ~/.zshrc`, or simply open a new terminal.

### Detailed Code Explanation

#### `copy` (WSL -> Windows Clipboard)

This copies data piped from an input, such as `cat test.txt | copy`, to the Windows clipboard.

1.  `sed "s/$/\r/"`: Adds a **CR** (`\r`) character to the end (`$`) of each line. This converts Linux's **LF** (`\n`) to Windows' **CRLF** (`\r\n`).
2.  `powershell.exe ...`: Executes the PowerShell script.
3.  `$stdin.CopyTo($bytes)`: Reads the data from WSL as a byte stream without corruption.
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: **Explicitly decodes** the read byte stream as **UTF-8** to convert it into text. This is the key to preventing multilingual characters from breaking.
5.  `Set-Clipboard -Value $text`: Saves the finally converted text to the Windows clipboard.

#### `paste` (Windows Clipboard -> WSL)

This pastes the content of the Windows clipboard into the WSL terminal.

1.  `powershell.exe ...`: Executes the PowerShell script.
2.  `Get-Clipboard -Raw`: Retrieves text data from the Windows clipboard.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: **Explicitly encodes** the retrieved text into a **UTF-8 byte stream**.
4.  `[Console]::OpenStandardOutput().Write(...)`: Writes the encoded byte stream directly to WSL's standard output.
5.  `sed "s/\r$//"`: Removes the **CR** (`\r`) character from the end of each line in the data output by PowerShell. This converts Windows' **CRLF** to Linux's **LF**, ensuring perfect compatibility.

### How to Test

You can run the script below to verify that the content of an original file and the content after being processed by `copy` & `paste` are perfectly identical, down to the byte level.
A file named 'sample.txt' must be present in the current directory for the test.

```shell
echo "--- Byte Sequence of Original File (sample.txt) ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- Byte Sequence from Clipboard (paste) ---"
paste | xxd
echo ""

echo "--- Comparing the Two Byte Sequences (diff result) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ The two byte sequences are perfectly identical."
else
    echo "--> ❌ A difference was found between the two byte sequences."
fi
```

### Expected Result

When you run the test script, the `diff` command should produce no output, and you should see the following success message at the end. This indicates that the original data and the data processed through the clipboard are 100% identical.

```
--- Byte Sequence of Original File (sample.txt) ---
(xxd output appears here)

--- Byte Sequence from Clipboard (paste) ---
(xxd output appears here - should be identical to the above)

--- Comparing the Two Byte Sequences (diff result) ---

--> ✅ The two byte sequences are perfectly identical.
```