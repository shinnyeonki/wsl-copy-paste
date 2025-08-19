[ENGLISH](README.md)
[中文](README-zh.md)
[韩语](README-ko.md)
[日语](README-ja.md)

### 概述

本文档介绍了如何在 WSL (Windows Subsystem for Linux) 环境中设置 `copy` 和 `paste` 别名 (alias)，以实现与 macOS 的 `pbcopy` 和 `pbpaste` 功能完全一致的剪贴板操作。

尽管已有许多项目和文章试图解决 WSL 中的剪贴板问题，但它们大多存在以下局限性：

1.  **多语言支持不足**：直接使用 `clip.exe` 的简单方法在多语言 (Multilingual) 环境下会因编码问题导致字符损坏。
2.  **过于笨重**：需要安装额外程序的方法过于繁重。本指南仅通过简单的别名 (alias) 设置即可解决问题。
3.  **集成不完整**：未能与 Windows 剪贴板完全集成，导致内容有时无法在剪贴板历史记录 (`Win + V`) 中正确显示。
4.  **保持 Windows 的默认文本处理**：本方法沿用 Windows 的默认文本处理方式（若更改此方式，可能会导致现有软件出现文本乱码）。

本指南提出的方法利用 PowerShell 的底层 (low-level) I/O 功能，从根本上解决了编码和换行符问题。最初，我们曾尝试使用 `iconv` 来处理韩语、日语、中文环境下的 `CP949` 等编码，但发现在处理表情符号或泰语等特定字符集时仍会出现乱码。

因此，本方法通过以下原理完美解决了问题：

*   **COPY**：将来自 WSL 管道的输入视为纯粹的**字节流 (byte stream)**，而非文本。然后将此字节流明确地解析为 **UTF-8**，转换为 Unicode 字符串，再存入 Windows 剪贴板。
*   **PASTE**：从 Windows 剪贴板获取 Unicode 文本，将其转换为 **UTF-8 字节流**，然后直接输出到 WSL。此过程避免了 Windows 控制台错误解析文本而改变编码的可能。

### 问题所在：WSL 与 Windows 剪贴板的兼容性问题

Windows 和 Linux (WSL) 在处理文本数据的方式上存在两个主要差异，这可能导致在简单的剪贴板交互中数据损坏。

1.  **换行符 (Newline) 差异**：
    *   **Windows**：使用 **CRLF** (`\r\n`，回车 + 换行) 来表示一行的结束。
    *   **Linux/macOS**：仅使用 **LF** (`\n`，换行)。
    *   由于这个差异，从 WSL 复制文本到 Windows 或反之，可能会导致换行符损坏或插入不必要的字符，如 `^M`。

2.  **编码 (Encoding) 差异**：
    *   WSL 的终端环境大多默认使用 **UTF-8** 编码。
    *   但是，当数据通过管道传递给 PowerShell 时，如果没有明确指定编码，系统可能会错误地以默认编码（例如 `cp949`）进行解析。
    *   这会导致中文、日文、表情符号等多字节字符损坏，显示为 `???` 或乱码。

### 解决方案：使用 PowerShell 设置别名 (Alias)

为了解决这些问题，我们从 WSL 中直接调用 Windows 的 `powershell.exe` 来控制剪贴板。请将以下代码添加到您的 `.bashrc` 或 `.zshrc` 文件末尾。

```shell
# 添加到 .zshrc 或 .bashrc
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

要应用更改，请执行 `source ~/.bashrc` 或 `source ~/.zshrc` 命令，或者重新打开一个新的终端。

### 代码详解

#### `copy` (WSL -> Windows 剪贴板)

将通过管道输入的数据（如 `cat test.txt | copy`）复制到 Windows 剪贴板。

1.  `sed "s/$/\r/"`: 在每行的末尾 (`$`) 添加一个**回车符 (CR, `\r`)**。这样，Linux 的 **LF (`\n`)** 就被转换成了 Windows 的 **CRLF (`\r\n`)**。
2.  `powershell.exe ...`: 执行 PowerShell 脚本。
3.  `$stdin.CopyTo($bytes)`: 将来自 WSL 的数据作为字节流直接读取，确保数据无损。
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: 将读取的字节流**明确指定为 UTF-8 进行解码**，并转换为文本。这是确保多语言字符不损坏的核心步骤。
5.  `Set-Clipboard -Value $text`: 将最终转换的文本保存到 Windows 剪贴板。

#### `paste` (Windows 剪贴板 -> WSL)

将 Windows 剪贴板的内容粘贴到 WSL 终端。

1.  `powershell.exe ...`: 执行 PowerShell 脚本。
2.  `Get-Clipboard -Raw`: 从 Windows 剪贴板获取文本数据。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 将获取的文本**明确编码为 UTF-8 字节流**。
4.  `[Console]::OpenStandardOutput().Write(...)`: 将编码后的字节流直接传输到 WSL 的标准输出。
5.  `sed "s/\r$//"`: 删除 PowerShell 输出数据 (CRLF) 中每行末尾的**回车符 (CR, `\r`)**。这样，Windows 的 **CRLF** 就被转换成了 Linux 的 **LF**，从而实现完美兼容。

### 测试方法

您可以运行以下脚本，来验证原始文件的内容与经过 `copy` 和 `paste` 操作后的内容在字节级别上是否完全一致。
测试前，请确保当前目录下存在一个名为 `sample.txt` 的文件。

```shell
echo "--- 原始文件 (sample.txt) 的字节序列 ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- 剪贴板 (paste) 的字节序列 ---"
paste | xxd
echo ""

echo "--- 比较两个字节序列 (diff 结果) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 两个字节序列完全一致。"
else
    echo "--> ❌ 发现两个字节序列存在差异。"
fi
```

### 预期结果

运行测试脚本后，`diff` 命令应该不会有任何输出，并且最终会显示如下成功信息。这表明原始数据与经过剪贴板操作后的数据 100% 一致。

```
--- 原始文件 (sample.txt) 的字节序列 ---
(xxd 输出结果)

--- 剪贴板 (paste) 的字节序列 ---
(xxd 输出结果 - 应与上方完全相同)

--- 比较两个字节序列 (diff 结果) ---

--> ✅ 两个字节序列完全一致。
```