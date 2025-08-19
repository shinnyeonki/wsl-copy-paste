[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 概述
本文档旨在说明如何在 WSL (适用于 Linux 的 Windows 子系统) 环境中，通过设置 `copy` 和 `paste` 别名 (alias)，实现与 macOS 的 `pbcopy` 和 `pbpaste` 功能类似的无缝剪贴板操作。该方法可以解决在 WSL 和 Windows 之间复制粘贴文本时可能出现的编码和换行符问题。

### 问题点：WSL 与 Windows 剪贴板的不兼容性
Windows 和 Linux (WSL) 在处理文本数据的方式上存在两个主要差异，这可能导致简单的剪贴板交互损坏数据。

1.  **换行符 (Newline) 差异**:
    *   **Windows**: 使用 **CRLF** (`\r\n`, Carriage Return + Line Feed) 来表示一行的结束。
    *   **Linux/macOS**: 仅使用 **LF** (`\n`, Line Feed)。
    *   由于这种差异，将 WSL 中的文本复制到 Windows，或反之，可能会导致换行符错乱，或插入不必要的字符，如 `^M`。

2.  **编码 (Encoding) 差异**:
    *   WSL 的终端环境大多默认使用 **UTF-8** 编码。
    *   然而，当数据通过管道传递给 PowerShell 时，如果未明确指定编码，数据可能会被错误地以系统默认编码（如 `cp949` 等）解析。
    *   这会导致韩文、日文、表情符号等多字节字符出现乱码，显示为 `???` 或其他异常字符。

### 解决方案：使用 PowerShell 设置别名 (Alias)
为了解决这些问题，我们可以从 WSL 中直接调用 Windows 的 `powershell.exe` 来控制剪贴板。将以下代码添加到 `.bashrc` 或 `.zshrc` 文件的末尾。

```shell
# 添加到 .zshrc 或 .bashrc
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

要使更改生效，请在终端中执行 `source ~/.bashrc` 或 `source ~/.zshrc` 命令，或者重新打开一个新的终端。

### 代码详解

#### `copy` (从 WSL 到 Windows 剪贴板)
通过管道将输入的数据（例如 `cat test.txt | copy`）复制到 Windows 剪贴板。

1.  `sed "s/$/\r/"`: 在每行的末尾 (`$`) 添加一个回车符 (**CR**, `\r`)。这样，Linux 的 **LF** (`\n`) 就被转换成了 Windows 的 **CRLF** (`\r\n`)。
2.  `powershell.exe ...`: 执行 PowerShell 脚本。
3.  `$stdin.CopyTo($bytes)`: 将从 WSL 传来的数据以字节流的形式完整读入，防止数据损坏。
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: **明确地将读取的字节流解码为 UTF-8** 格式的文本。这是确保多语言字符不乱码的关键。
5.  `Set-Clipboard -Value $text`: 最后，将转换后的文本保存到 Windows 剪贴板。

#### `paste` (从 Windows 剪贴板到 WSL)
将 Windows 剪贴板的内容粘贴到 WSL 终端。

1.  `powershell.exe ...`: 执行 PowerShell 脚本。
2.  `Get-Clipboard -Raw`: 从 Windows 剪贴板获取文本数据。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: **明确地将获取的文本编码为 UTF-8 字节流**。
4.  `[Console]::OpenStandardOutput().Write(...)`: 将编码后的字节流直接写入到 WSL 的标准输出。
5.  `sed "s/\r$//"`: 删除由 PowerShell 输出的数据中每行末尾的回车符 (`\r`)。这样，Windows 的 **CRLF** 就被转换成了 Linux 的 **LF**，从而实现完美兼容。

### 测试方法
您可以运行以下脚本，以确认源文件的内容与经过 `copy` 和 `paste` 操作后的内容在字节级别上完全一致。
测试前，请确保当前目录下存在一个名为 `sample.txt` 的文件。
```shell
echo "--- 源文件(sample.txt)的字节序列 ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- 剪贴板(paste)的字节序列 ---"
paste | xxd
echo ""

echo "--- 两个字节序列比较 (diff 结果) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 两个字节序列完全相同。"
else
    echo "--> ❌ 发现两个字节序列存在差异。"
fi
```

### 预期结果
运行测试脚本后，`diff` 命令应该不会输出任何内容，并且最后应显示以下成功消息。这表示原始数据与经过剪贴板操作后的数据 100% 一致。

```
--- 源文件(sample.txt)的字节序列 ---
(xxd 输出结果)

--- 剪贴板(paste)的字节序列 ---
(xxd 输出结果 - 应与上方完全相同)

--- 两个字节序列比较 (diff 结果) ---

--> ✅ 两个字节序列完全相同。
```