[ENGLISH](README.md)
[KOREAN](README-ko.md)

### Overview
![image](image.png)
This document explains how to set up `copy` and `paste` aliases in the WSL (Windows Subsystem for Linux) environment to achieve clipboard functionality perfectly identical to macOS's `pbcopy` and `pbpaste`.

While there are many existing projects and articles aimed at solving WSL clipboard issues, most have the following limitations:

1.  **Poor Multilingual Support**: Simply using `clip.exe` often leads to corrupted characters in multilingual environments due to encoding issues. For example, running `cat sample.txt | clip.exe` results in garbled text when pasted.
2.  **Unnecessary Software Installation**: Solutions that require installing separate programs are too heavy. This guide solves the problem with simple alias configurations.
3.  **Incomplete Integration**: Often, copied content doesn't appear correctly in the Windows clipboard history (`Win + V`) because it's not perfectly integrated with the Windows clipboard.
4.  **Maintaining Native Text Handling**: It uses Windows' native text processing without changing system defaults, avoiding text corruption in other software.


### Quick Installation (Recommended)

This is the installation script. Copy and run the following command in your terminal. (Supports Bash, Zsh, and Fish)

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

After installation, restart your terminal or reload your configuration file (`source ~/.bashrc`, `source ~/.zshrc`, or `source ~/.config/fish/config.fish`) to start using `copy` and `paste` commands immediately.

To uninstall or reconfigure the aliases, simply run the command again.

### Manual Installation

Since these are simple aliases, you can directly add the following code to the bottom of your shell configuration file.

#### Bash / Zsh (`.bashrc` or `.zshrc`)

```shell
# 1. Copy: Stdin(byte) -> MemoryStream -> UTF8 String -> Clipboard
alias copy='powershell.exe -noprofile -command "
  \$inputStream = [Console]::OpenStandardInput();
  \$memoryStream = New-Object System.IO.MemoryStream;
  \$inputStream.CopyTo(\$memoryStream);
  \$utf8Text = [System.Text.Encoding]::UTF8.GetString(\$memoryStream.ToArray());
  Set-Clipboard -Value \$utf8Text
"'

# 2. Paste: Clipboard -> UTF8 String -> UTF8 Bytes -> Stdout(byte)
alias paste='powershell.exe -noprofile -command "
  \$clipboardText = Get-Clipboard -Raw;
  if (\$clipboardText -ne \$null) {
    \$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes(\$clipboardText);
    \$outputStream = [Console]::OpenStandardOutput();
    \$outputStream.Write(\$utf8Bytes, 0, \$utf8Bytes.Length);
    \$outputStream.Flush();
    \$outputStream.Close();
  }
" | tr -d "\r"'
```

#### Fish (`~/.config/fish/config.fish`)

```fish
# 1. Copy
alias copy 'powershell.exe -noprofile -command "
  $inputStream = [Console]::OpenStandardInput();
  $memoryStream = New-Object System.IO.MemoryStream;
  $inputStream.CopyTo($memoryStream);
  $utf8Text = [System.Text.Encoding]::UTF8.GetString($memoryStream.ToArray());
  Set-Clipboard -Value $utf8Text
"'

# 2. Paste
alias paste 'powershell.exe -noprofile -command "
  $clipboardText = Get-Clipboard -Raw;
  if ($clipboardText -ne $null) {
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($clipboardText);
    $outputStream = [Console]::OpenStandardOutput();
    $outputStream.Write($utf8Bytes, 0, $utf8Bytes.Length);
    $outputStream.Flush();
    $outputStream.Close();
  }
" | tr -d "\r"'
```

### Future Goals

- Considering ways to integrate this tool with Wayland running within WSL.
- Exploring how to handle various MIME types on the Windows side.


### Core Principle: Fundamentally Solving Encoding and Newline Issues

This method stands out because it leverages PowerShell's low-level I/O capabilities to **fundamentally resolve encoding and newline character issues**.

Initially, approaches using tools like `iconv` to convert between Windows' `UTF-16/CP949` and WSL's `UTF-8` were considered, but they failed in certain cases with specific character sets like emojis or Thai. This is due to the complex encoding methods Windows uses.

This guide's approach avoids dealing with this complexity directly and instead **utilizes Windows' built-in API Thunking Layer**. It doesn't force encoding conversion but explicitly handles it at both ends of the data flow.

*   **COPY Process (WSL → Windows)**: Data piped from WSL is treated as a pure **byte stream**, not text. This byte stream is **explicitly interpreted as UTF-8** in PowerShell, converted to a Unicode string, and then stored in the Windows clipboard.
*   **PASTE Process (Windows → WSL)**: Unicode text from the Windows clipboard is converted into a **UTF-8 byte stream** in PowerShell and then passed directly to WSL's standard output. This prevents the Windows console from misinterpreting the text and changing the encoding mid-process.

This ensures perfect string compatibility without data loss.

### Problems: Incompatibility between WSL and Windows Clipboard

There are two major differences in how Windows and Linux (WSL) handle text data, which can cause data corruption during simple clipboard operations:

1.  **Newline Character Difference**:
    *   **Windows**: Uses **CRLF** (`\r\n`, Carriage Return + Line Feed).
    *   **Linux/macOS**: Uses only **LF** (`\n`, Line Feed).
    *   This can lead to broken line breaks or unnecessary `^M` characters when copying between WSL and Windows.

2.  **Encoding Difference**:
    *   WSL terminal environments use **UTF-8** by default.
    *   However, if data is passed through a pipeline to PowerShell without explicit encoding, it might be misinterpreted as the system's default encoding (e.g., `UTF-16`).
    *   This causes multi-byte characters like Korean, Japanese, and emojis to break, appearing as `???` or other strange characters.


### Detailed Explanation

#### `copy` (WSL -> Windows Clipboard)

Copies data piped into it (e.g., `cat test.txt | copy`) to the Windows clipboard.

1.  `powershell.exe ...`: Executes the PowerShell script.
2.  `$inputStream = [Console]::OpenStandardInput()`: Opens standard input to read data from WSL as a byte stream.
3.  `$memoryStream.CopyTo(...)`: Copies the input data to a memory stream without loss.
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: Decodes the byte array stored in the memory stream **explicitly as UTF-8**. This is the key to preventing multilingual character corruption.
5.  `Set-Clipboard -Value $utf8Text`: Stores the final converted text in the Windows clipboard.

#### `paste` (Windows Clipboard -> WSL)

Pastes content from the Windows clipboard to the WSL terminal.

1.  `powershell.exe ...`: Executes the PowerShell script.
2.  `Get-Clipboard -Raw`: Retrieves raw text data from the Windows clipboard.
3.  `if ($clipboardText -ne $null)`: Checks if the clipboard is empty.
4.  `[System.Text.Encoding]::UTF8.GetBytes(...)`: Encodes the retrieved text **explicitly as a UTF-8 byte stream**.
5.  `$outputStream.Write(...)`: Writes the encoded byte stream directly to WSL's standard output.
6.  `tr -d "\r"`: Removes **CR** (`\r`) characters from the output data. This converts Windows' **CRLF** to Linux's **LF**, ensuring perfect compatibility.

### Testing Methods

#### TEST1
A script to verify if the byte array resulting from running `copy` with `bash test.sh <INPUTFILE>` is identical to the result of `unix2dos | iconv -f UTF-8 -t UTF-16LE`.

#### TEST2

Does the byte sequence of the original file remain the same after going through `copy` and `paste`?

```shell
echo "--- Byte sequence of original file (sample.txt) ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- Byte sequence obtained from clipboard (paste) ---"
paste | xxd
echo ""

echo "--- Comparing two byte sequences (diff result) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ The two byte sequences match perfectly."
else
    echo "--> ❌ A difference was found between the two byte sequences."
fi
```

### Expected Results

When running the test script, the `diff` command should produce no output, and the success message should appear at the end. This means the original data and the data that passed through the clipboard are 100% identical.

```
--- Byte sequence of original file (sample.txt) ---
(xxd output appears here)

--- Byte sequence obtained from clipboard (paste) ---
(xxd output appears here - should match above)

--- Comparing two byte sequences (diff result) ---

--> ✅ The two byte sequences match perfectly.
```


### Additional Notes
This addresses an issue when trying to use these commands within a script. Since alias settings only work in interactive mode, you should either move them to separate executable files or use the `shopt -s expand_aliases` setting.

### Vim Integration

To conveniently use the system clipboard (`copy`, `paste`) within Vim, add the following configuration to your `.vimrc` file.

```vim
" WSL Clipboard Integration (using copy/paste aliases)
vnoremap y :w !copy<CR><CR>
nnoremap p :read !paste<CR>
```

With this configuration, pressing `y` in Vim's visual mode will copy the selection to the Windows clipboard, and pressing `p` in normal mode will insert the clipboard content after the current line.

> **Note**: Aliases may not be directly recognized by Vim's `system()` or `!` commands. In such cases, you might need to map the full command or ensure aliases are expanded in your shell. For more stable usage, it is recommended to save `copy` and `paste` as separate executable files in your `$PATH`.

