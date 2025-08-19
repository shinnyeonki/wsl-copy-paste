[ENGLISH](README.md)
[简体中文](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 概述

本文档介绍了如何在 WSL (Windows Subsystem for Linux) 环境中设置 `copy` 和 `paste` 别名，以完美复刻 macOS 的 `pbcopy` 和 `pbpaste` 剪贴板功能。

虽然已有许多项目和文章试图解决 WSL 中的剪贴板问题，但大多数都存在以下局限性：

1.  **多语言支持不佳**：直接使用 `clip.exe` 的简单方法常因编码问题导致多语言环境下的字符损坏。
2.  **不必要的臃肿**：需要安装独立程序的解决方案过于重量级。本指南仅通过简单的别名设置即可解决问题。
3.  **集成不完整**：这些方法通常无法与 Windows 剪贴板完美集成，导致内容无法在剪贴板历史记录（`Win + V`）中正确显示。
4.  **保留 Windows 默认文本处理方式**：本方法直接使用 Windows 原生的文本处理机制，避免了因更改系统默认设置而可能导致其他软件出现文本损坏的情况。

本指南提出的方法通过利用 PowerShell 的底层 I/O 功能，从根本上解决了编码和换行符问题。最初曾考虑使用 `iconv` 来处理韩语、日语和中文环境下的 `CP949` 等编码，但发现这种方式会破坏某些字符集，例如表情符号和泰语字符。

因此，本方法基于以下原则，提供了一个完美的解决方案：

*   **COPY**：它将从 WSL 管道传入的输入不作为文本处理，而是作为纯粹的**字节流**。这个字节流被显式地以 **UTF-8** 编码解释，转换为 Unicode 字符串，然后保存到 Windows 剪贴板中。
*   **PASTE**：它从 Windows 剪贴板中检索 Unicode 文本，将其转换为 **UTF-8 字节流**，然后直接输出到 WSL。这个过程可以防止 Windows 控制台错误地解释文本并改变其编码。

### 问题所在：WSL 与 Windows 剪贴板之间的不兼容性

Windows 和 Linux (WSL) 在处理文本数据的方式上存在两大差异，这可能导致在简单的剪贴板交互过程中数据损坏。

1.  **换行符差异**：
    *   **Windows**：使用 **CRLF** (`\r\n`，回车 + 换行) 来标记行尾。
    *   **Linux/macOS**：仅使用 **LF** (`\n`，换行)。
    *   当从 WSL 复制文本到 Windows 或反之时，这种差异可能导致换行符被破坏，或者插入不必要的 `^M` 字符。

2.  **编码差异**：
    *   WSL 终端环境大多默认使用 **UTF-8** 编码。
    *   然而，当数据通过管道传递给 PowerShell 而没有显式指定编码时，它可能会被系统的默认编码（例如 `cp949`）错误地解释。
    *   这会导致多字节字符，如韩文、日文和表情符号等损坏，并显示为 `???` 或其他奇怪的字符。

### 解决方案：使用 PowerShell 设置别名

为了解决这些问题，我们将直接从 WSL 调用 Windows 的 `powershell.exe` 来控制剪贴板。

#### 快速安装 (推荐)

使用自动化安装脚本，它会自动检测您使用的 shell 并添加别名：

在 Ubuntu 等环境中使用 bash...
```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

在 Debian 等环境中使用 zsh...
```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | zsh
```

或者，如果您已经克隆了此仓库：

```shell
./install.sh
```

#### 手动安装

您也可以手动将以下代码添加到您的 `.bashrc` 或 `.zshrc` 文件的底部：

```shell
# 添加到您的 .zshrc 或 .bashrc 文件
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

要使更改在您的终端中生效，请运行 `source ~/.bashrc` 或 `source ~/.zshrc`，或者直接打开一个新的终端。

### 代码详解

#### `copy` (WSL -> Windows 剪贴板)

这将通过管道传入的数据（例如 `cat test.txt | copy`）复制到 Windows 剪贴板。

1.  `sed "s/$/\r/"`：在每行的末尾 (`$`) 添加一个 **CR** (`\r`) 字符。这将 Linux 的 **LF** (`\n`) 转换为 Windows 的 **CRLF** (`\r\n`)。
2.  `powershell.exe ...`：执行 PowerShell 脚本。
3.  `$stdin.CopyTo($bytes)`：将来自 WSL 的数据作为字节流读取，确保数据无损。
4.  `[System.Text.Encoding]::UTF8.GetString(...)`：**显式地**将读取的字节流**以 UTF-8 解码**，将其转换为文本。这是防止多语言字符损坏的关键。
5.  `Set-Clipboard -Value $text`：将最终转换的文本保存到 Windows 剪贴板。

#### `paste` (Windows 剪贴板 -> WSL)

这将 Windows 剪贴板的内容粘贴到 WSL 终端。

1.  `powershell.exe ...`：执行 PowerShell 脚本。
2.  `Get-Clipboard -Raw`：从 Windows 剪贴板检索文本数据。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`：**显式地**将检索到的文本**编码为 UTF-8 字节流**。
4.  `[Console]::OpenStandardOutput().Write(...)`：将编码后的字节流直接写入 WSL 的标准输出。
5.  `sed "s/\r$//"`：从 PowerShell 输出的数据中移除每行末尾的 **CR** (`\r`) 字符。这将 Windows 的 **CRLF** 转换为 Linux 的 **LF**，确保完美的兼容性。

### 如何测试

您可以运行以下脚本，以验证原始文件的内容与经过 `copy` 和 `paste` 处理后的内容在字节级别上完全相同。
测试前，请确保当前目录下存在一个名为 `sample.txt` 的文件。

```shell
echo "--- 原始文件 (sample.txt) 的字节序列 ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- 从剪贴板粘贴的字节序列 (paste) ---"
paste | xxd
echo ""

echo "--- 比较两个字节序列 (diff 结果) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 两个字节序列完全相同。"
else
    echo "--> ❌ 两个字节序列之间存在差异。"
fi
```

### 预期结果

当您运行测试脚本时，`diff` 命令应该不会产生任何输出，并且您应该在末尾看到以下成功消息。这表明原始数据和经过剪贴板处理的数据是 100% 相同的。

```
--- 原始文件 (sample.txt) 的字节序列 ---
(这里会显示 xxd 的输出)

--- 从剪贴板粘贴的字节序列 (paste) ---
(这里会显示 xxd 的输出 - 应与上面的完全相同)

--- 比较两个字节序列 (diff 结果) ---

--> ✅ 两个字节序列完全相同。
```