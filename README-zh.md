好的，我已根据您的要求将文件重构和润色后的内容翻译成中文。

---

[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 概述

本文档介绍了如何在 WSL (Windows Subsystem for Linux) 环境中设置 `copy` 和 `paste` 别名（alias），以实现与 macOS 的 `pbcopy` 和 `pbpaste` 完全相同的剪贴板功能。

尽管已有许多项目和文章试图解决 WSL 的剪贴板问题，但它们大多存在以下局限性：

1.  **多语言支持不佳**：直接使用 `clip.exe` 的方法容易因编码问题导致多语言环境下出现字符乱码。
2.  **不必要的程序安装**：需要安装额外程序的解决方案过于繁琐。本指南仅通过简单的别名设置即可解决问题。
3.  **集成不完整**：未能与 Windows 剪贴板完美集成，常常导致内容无法在剪贴板历史记录（`Win + V`）中正常显示。
4.  **保留 Windows 默认文本处理方式**：本方法沿用 Windows 的原生文本处理方式，避免了因修改系统默认设置而可能导致的其他软件文本乱码问题。

### 快速安装（推荐）

这是一个安装脚本。请将以下命令复制到终端并执行。

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

安装后，重启终端或执行 `source ~/.bashrc`（或 `source ~/.zshrc`），即可立即使用 `copy` 和 `paste` 命令。

如果想要删除或重置别名，只需再次运行相同的命令即可。

### 核心原理：从根本上解决编码与换行符问题的方法

此方法与其他解决方案的区别在于，它利用 PowerShell 的底层 I/O 功能，**从根本上解决了编码和换行符问题**。

初期曾考虑使用 `iconv` 等工具来转换韩文 `UTF-8` 和 WSL 的 `UTF-8`，但在处理表情符号或泰语等特定字符集时遇到了乱码的限制。这是由于 Windows 使用了复杂的编码方式所致。目前，Windows 同时为旧版程序使用代码页（如 `CP949`），并为现代系统使用 `UTF-16`。

本指南的方法并非直接处理这个复杂问题，而是**直接利用 Windows 内置的 API 兼容层（API Thunking Layer）**。也就是说，它不强制转换数据编码，而是在数据流的两端进行明确处理。

*   **COPY (WSL → Windows)**：将从 WSL 管道输入的数据视为纯粹的**字节流**，而非文本。PowerShell 将此字节流**明确解析为 UTF-8**，转换为 Unicode 字符串后，再保存到 Windows 剪贴板。
*   **PASTE (Windows → WSL)**：PowerShell 将 Windows 剪贴板中的 Unicode 文本转换为 **UTF-8 字节流**后，直接传递给 WSL 的标准输出。此过程从源头上防止了因 Windows 控制台错误解析文本而导致的编码变更。

通过这种方式，我们确保了完美的字符串兼容性，避免了任何数据丢失。

### 问题所在：WSL与Windows剪贴板之间的不兼容性

Windows 和 Linux (WSL) 在处理文本数据的方式上存在两大差异，这导致在简单的剪贴板交互中可能发生数据损坏。

1.  **换行符（Newline）的差异**：
    *   **Windows**：使用 **CRLF**（`\r\n`，回车符 + 换行符）表示一行的结束。
    *   **Linux/macOS**：仅使用 **LF**（`\n`，换行符）。
    *   这种差异导致从 WSL 复制文本到 Windows 或反向操作时，换行可能被破坏，或插入 `^M` 等不必要的字符。

2.  **编码的差异**：
    *   WSL 终端环境默认使用 **UTF-8** 编码。
    *   然而，当数据在没有明确指定编码的情况下通过管道传递给 PowerShell 时，可能会被系统的默认编码（例如 `UTF16`）错误解析。
    *   这会导致韩文、日文、表情符号等多字节字符损坏，显示为 `???` 或其他异常字符。

### 手动安装

您可以将以下代码直接添加到 `.bashrc` 或 `.zshrc` 文件的末尾：

```shell
# 添加到 .zshrc 或 .bashrc 文件
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

要让更改在终端中生效，请执行 `source ~/.bashrc` 或 `source ~/.zshrc`，或者打开一个新的终端窗口。

### 代码详解

#### `copy` (WSL -> Windows 剪贴板)

将通过管道输入的数据（如 `cat test.txt | copy`）复制到 Windows 剪贴板。

1.  `powershell.exe ...`：执行 PowerShell 脚本。
2.  `$stdin.CopyTo($bytes)`：将从 WSL 接收的数据作为无损的字节流读入。
3.  `[System.Text.Encoding]::UTF8.GetString(...)`：将读入的字节流**明确指定为 UTF-8** 进行解码，并转换为文本。这是确保多语言字符不出现乱码的关键。
4.  `Set-Clipboard -Value $text`：将最终转换的文本保存到 Windows 剪贴板。

#### `paste` (Windows 剪贴板 -> WSL)

将 Windows 剪贴板的内容粘贴到 WSL 终端。

1.  `powershell.exe ...`：执行 PowerShell 脚本。
2.  `Get-Clipboard -Raw`：从 Windows 剪贴板获取文本数据。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`：将获取的文本**明确编码为 UTF-8 字节流**。
4.  `[Console]::OpenStandardOutput().Write(...)`：将编码后的字节流直接写入 WSL 的标准输出。
5.  `tr -d "\r"`：删除 PowerShell 输出数据每行末尾的 **CR**（`\r`）字符。通过这一步，将 Windows 的 **CRLF** 转换为 Linux 的 **LF**，从而保证了完美的兼容性。

### 测试方法

您可以运行以下脚本，以验证原始文件内容与经过 `copy` 和 `paste` 后的内容在字节级别上是否完全一致。
为了进行测试，当前目录下需要有一个名为 `sample.txt` 的文件。

```shell
echo "--- 原始文件 (sample.txt) 的字节序列 ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- 从剪贴板 (paste) 获取的字节序列 ---"
paste | xxd
echo ""

echo "--- 比较两个字节序列 (diff 结果) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 两个字节序列完全一致。"
else
    echo "--> ❌ 两个字节序列之间发现差异。"
fi
```

### 预期结果

运行测试脚本时，`diff` 命令应不产生任何输出，并且最后应显示以下成功消息。这表示原始数据与经过剪贴板处理后的数据 100% 相同。

```
--- 原始文件 (sample.txt) 的字节序列 ---
(xxd 输出将显示在此处)

--- 从剪贴板 (paste) 获取的字节序列 ---
(xxd 输出将显示在此处 - 应与上方相同)

--- 比较两个字节序列 (diff 结果) ---

--> ✅ 两个字节序列完全一致。
```