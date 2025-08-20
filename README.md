물론입니다. 요청하신 내용에 따라 문서를 영어로 번역했습니다.

---

[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### Overview

This document explains how to set up `copy` and `paste` aliases in a Windows Subsystem for Linux (WSL) environment to perfectly replicate the clipboard functionality of macOS's `pbcopy` and `pbpaste`.

While many existing projects and articles aim to solve WSL's clipboard issues, most have the following limitations:

1.  **Poor Multilingual Support**: Simply using `clip.exe` directly often leads to broken characters in multilingual environments due to encoding problems.
2.  **Unnecessary Program Installation**: Solutions that require installing separate programs are too heavyweight. This guide resolves the issue with a simple alias configuration.
3.  **Incomplete Integration**: Many solutions do not integrate seamlessly with the Windows clipboard, often failing to properly register content in the clipboard history (`Win + V`).
4.  **Maintains Windows Default Text Handling**: This method uses Windows' native text processing, avoiding text corruption in other software that can occur when changing system default settings.

### Quick Install (Recommended)

This is the installation script. Copy the command below and run it in your terminal.

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

After installation, restart your terminal or run `source ~/.bashrc` (or `source ~/.zshrc`), and you can immediately use the `copy` and `paste` commands.

If you wish to uninstall or reset the aliases, you can simply run the same command again.


### Core Principle: A Fundamental Solution to Encoding and Newline Issues

What sets this method apart from other solutions is its use of PowerShell's low-level I/O capabilities to **fundamentally solve encoding and newline character problems**.

Initially, approaches using tools like `iconv` were considered to convert between Korean `UTF-8` and WSL's `UTF-8`. However, these had limitations, causing certain character sets like emojis or Thai to break. This is due to the complex encoding schemes used by Windows, which currently employs both codepages for legacy programs (e.g., `CP949`) and `UTF-16` for modern systems.

This guide's approach avoids dealing with this complexity directly. Instead, it **leverages Windows' built-in API compatibility layer (API Thunking Layer)**. In other words, rather than forcing encoding conversions, it explicitly handles the data at both ends of the data flow.

*   **COPY (WSL → Windows)**: Data piped from WSL is treated not as text but as a pure **byte stream**. This byte stream is then **explicitly interpreted as UTF-8** in PowerShell, converted into a Unicode string, and saved to the Windows clipboard.
*   **PASTE (Windows → WSL)**: Unicode text from the Windows clipboard is converted into a **UTF-8 byte stream** in PowerShell and then passed directly to WSL's standard output. This process fundamentally prevents the Windows console from misinterpreting the text and altering its encoding.

This approach ensures perfect string compatibility without any data loss.

### The Problem: Incompatibility Between WSL and the Windows Clipboard

Windows and Linux (WSL) have two major differences in how they handle text data, which can cause data corruption during simple clipboard operations.

1.  **Difference in Newline Characters**:
    *   **Windows**: Marks the end of a line with **CRLF** (`\r\n`, Carriage Return + Line Feed).
    *   **Linux/macOS**: Uses only **LF** (`\n`, Line Feed).
    *   This difference can cause line breaks to be misinterpreted or unnecessary characters like `^M` to be inserted when copying text between WSL and Windows.

2.  **Difference in Encoding**:
    *   The WSL terminal environment primarily uses **UTF-8** encoding.
    *   However, when data is passed to PowerShell through a pipeline without explicit encoding, it may be misinterpreted using the system's default encoding (e.g., `UTF-16`).
    *   This causes multi-byte characters such as Korean, Japanese, and emojis to become corrupted, appearing as `???` or other strange symbols.

### Manual Installation

You can add the following code directly to the bottom of your `.bashrc` or `.zshrc` file:

```shell
# Add to your .zshrc or .bashrc file
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

To apply the changes, run `source ~/.bashrc` or `source ~/.zshrc`, or open a new terminal.

### Detailed Code Explanation

#### `copy` (WSL -> Windows Clipboard)

Copies data piped from commands like `cat test.txt | copy` to the Windows clipboard.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `$stdin.CopyTo($bytes)`: Reads the data received from WSL as a byte stream without corruption.
3.  `[System.Text.Encoding]::UTF8.GetString(...)`: **Explicitly decodes** the byte stream as **UTF-8** to convert it into text. This is the key to preventing multilingual characters from breaking.
4.  `Set-Clipboard -Value $text`: Saves the final converted text to the Windows clipboard.

#### `paste` (Windows Clipboard -> WSL)

Pastes the content of the Windows clipboard into the WSL terminal.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `Get-Clipboard -Raw`: Retrieves text data from the Windows clipboard.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: **Explicitly encodes** the retrieved text into a **UTF-8 byte stream**.
4.  `[Console]::OpenStandardOutput().Write(...)`: Writes the encoded byte stream directly to WSL's standard output.
5.  `tr -d "\r"`: Removes the **CR** (`\r`) character from the end of each line of the output from PowerShell. This ensures perfect compatibility by converting Windows' **CRLF** to Linux's **LF**.

### How to Test

You can run the script below to verify that the content of the original file and the content after passing through `copy` & `paste` are identical at the byte level.
To run the test, you must have a file named 'sample.txt' in the current directory.

```shell
echo "--- Byte sequence of the original file (sample.txt) ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- Byte sequence from the clipboard (paste) ---"
paste | xxd
echo ""

echo "--- Comparing the two byte sequences (diff result) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ The two byte sequences match perfectly."
else
    echo "--> ❌ A difference was found between the two byte sequences."
fi
```

### Expected Results

When you run the test script, the `diff` command should produce no output, and you should see the following success message at the end. This means the original data and the data passed through the clipboard are 100% identical.

```
--- Byte sequence of the original file (sample.txt) ---
(xxd output appears here)

--- Byte sequence from the clipboard (paste) ---
(xxd output appears here - should be identical to the above)

--- Comparing the two byte sequences (diff result) ---

--> ✅ The two byte sequences match perfectly.
```