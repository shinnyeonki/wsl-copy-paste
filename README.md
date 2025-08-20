[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### Overview
![image](image.png)
This document describes how to set up `copy` and `paste` aliases in the Windows Subsystem for Linux (WSL) environment to achieve clipboard functionality identical to `pbcopy` and `pbpaste` on macOS.

While many existing projects and articles attempt to solve clipboard issues in WSL, most have the following limitations:

1.  **Poor Multilingual Support**: Simply using `clip.exe` often leads to broken characters in multilingual environments due to encoding issues. After running a command like `cat sample.txt | clip.exe`, the pasted string appears corrupted.
2.  **Unnecessary Program Installation**: Solutions that require installing separate programs are too heavy. This guide solves the problem with a simple alias configuration.
3.  **Incomplete Integration**: Many solutions do not fully integrate with the Windows clipboard, often causing content not to appear correctly in the clipboard history (`Win + V`).
4.  **Maintains Windows Default Text Handling**: This method uses Windows' native text processing, avoiding the text corruption in other software that can occur when changing system default settings.
5.  **Faster Performance**: Maintain a fast pace compared to other projects

    ```shell
    $ time cat sample.txt | wcopy && time wpaste > /dev/null
    
    real    0m5.067s
    user    0m0.003s
    sys     0m0.000s
    
    real    0m5.069s
    user    0m0.003s
    sys     0m0.000s
    $ time cat sample.txt | copy && time paste > /dev/null
    
    real    0m0.168s
    user    0m0.001s
    sys     0m0.003s
    
    real    0m0.225s
    user    0m0.001s
    sys     0m0.003s
    ```


    

### Quick Install (Recommended)

This is an installation script. Copy the command below and run it in your terminal.

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

After installation, restart your terminal or run `source ~/.bashrc` (or `source ~/.zshrc`) to start using the `copy` and `paste` commands immediately.

If you want to uninstall or reset the alias, you can run the same command again.

### Manual Install

Since this is a simple alias, you can add the following code directly to the bottom of your `.bashrc` or `.zshrc` file:

```shell
# Add to .zshrc or .bashrc file
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

To apply the changes to the terminal, run `source ~/.bashrc` or `source ~/.zshrc`, or open a new terminal.

### Future Goals

> The goal is to fully implement all functionalities of the `man pbcopy` command when executed on a macOS system.

**Key Features and Considerations:**

- **Locale Environment Variable Reference:** Input and output encoding will be determined by referencing locale environment variables such as `LANG=en_US.UTF-8`.
- **Supported Data Types:**
  - [v] **Plain Text:** Support for basic text copy and paste operations.
  - [ ] **EPS (Encapsulated PostScript):** Implementation planned to handle EPS image data.
  - [ ] **RTF (Rich Text Format):** Implementation planned to support formatted text via RTF data.
- **Development Form:** Currently starting as an alias, but may evolve into a standalone script file or executable in the future.
- **Development Priority:** Responsiveness will be prioritized over throughput. Emphasis will be placed on immediate responsiveness and user experience.

### Core Principle: A Fundamental Solution to Encoding and Newline Issues

What distinguishes this method from other solutions is its use of PowerShell's low-level I/O features to **fundamentally resolve encoding and newline character problems**.

Initially, I considered approaches using tools like `iconv` to convert between Windows `UTF-16 or CP949` and WSL's `UTF-8`. However, this had limitations where certain character sets, such as emojis or Thai, would break in specific use cases. This is due to the complex encoding methods used by Windows. Windows currently uses both a legacy codepage (e.g., `CP949`) for older programs and `UTF-16` for modern systems.

The approach in this guide avoids dealing with this complexity directly and instead **leverages Windows' built-in API compatibility layer (API Thunking Layer)**. This means that instead of forcing encoding conversion, the data flow is handled explicitly at both ends.

*   **COPY Process (WSL → Windows)**: Data piped from WSL is treated as a pure **byte stream**, not text. This byte stream is then **explicitly interpreted as UTF-8** in PowerShell, converted to a Unicode string, and then stored in the Windows clipboard.
*   **PASTE Process (Windows → WSL)**: Unicode text from the Windows clipboard is converted to a **UTF-8 byte stream** in PowerShell and then passed directly to WSL's standard output. This process fundamentally prevents the Windows console from misinterpreting the text and changing the encoding.

This method ensures perfect string compatibility without any data loss.

### The Problem: Incompatibility Between WSL and Windows Clipboard

Windows and Linux (WSL) have two major differences in how they handle text data, which can cause data corruption with simple clipboard integration.

1.  **Difference in Newline Characters**:
    *   **Windows**: Marks the end of a line with **CRLF** (`\r\n`, Carriage Return + Line Feed).
    *   **Linux/macOS**: Uses only **LF** (`\n`, Line Feed).
    *   Because of this difference, when you copy text from WSL to Windows or vice versa, line breaks can be broken, or unnecessary characters like `^M` may be inserted.

2.  **Difference in Encoding**:
    *   The WSL terminal environment uses **UTF-8** encoding by default.
    *   However, when data is passed to PowerShell through a pipeline without an explicit encoding, it is often misinterpreted with the system's default encoding (e.g., `UTF-16`).
    *   This causes multibyte characters like Korean, Japanese, and emojis to break and appear as `???` or other strange characters.

### Detailed Code Explanation

#### `copy` (WSL -> Windows Clipboard)

Copies data piped in, such as with `cat test.txt | copy`, to the Windows clipboard.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `$stdin.CopyTo($bytes)`: Reads the data received from WSL as a byte stream without corruption.
3.  `[System.Text.Encoding]::UTF8.GetString(...)`: **Explicitly decodes** the read byte stream as **UTF-8** to convert it to text. This is the key to preventing multilingual characters from breaking.
4.  `Set-Clipboard -Value $text`: Stores the final converted text in the Windows clipboard.

#### `paste` (Windows Clipboard -> WSL)

Pastes the content of the Windows clipboard into the WSL terminal.

1.  `powershell.exe ...`: Executes a PowerShell script.
2.  `Get-Clipboard -Raw`: Retrieves text data from the Windows clipboard.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: **Explicitly encodes** the retrieved text into a **UTF-8 byte stream**.
4.  `[Console]::OpenStandardOutput().Write(...)`: Writes the encoded byte stream directly to WSL's standard output.
5.  `tr -d "\r"`: Removes the **CR** (`\r`) character from the end of each line of data output by PowerShell. This ensures perfect compatibility by converting Windows' **CRLF** to Linux's **LF**.

### How to Test

#### TEST1
```shell
bash test.sh <INPUTFILE>
```
Run this script to check if the byte array from the `copy` command is identical to the result of `unix2dos | iconv -f UTF-8 -t UTF-16LE`.

#### TEST2

Does the byte sequence of the original file remain identical after being passed through `copy` and `paste`?

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

When you run the test script, the `diff` command should produce no output, and you should see the following success message at the end. This means that the original data and the data that has passed through the clipboard are 100% identical.

```
--- Byte sequence of the original file (sample.txt) ---
(xxd output appears here)

--- Byte sequence from the clipboard (paste) ---
(xxd output appears here - should be identical to the above)

--- Comparing the two byte sequences (diff result) ---

--> ✅ The two byte sequences match perfectly.
```

### Additional Notes
This addresses a problem that occurs when trying to use these commands within a script. Alias settings only work in interactive mode, so you must either extract the command into a separate executable file or enable the `shopt -s expand_aliases` setting.