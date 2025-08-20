\[CHINESE] (README-zh.md)
[ENGLISH](README.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 概述

本文档介绍了如何在 WSL (Windows Subsystem for Linux) 环境中设置 `copy` 和 `paste` 别名 (alias)，以实现与 macOS 的 `pbcopy` 和 `pbpaste` 完全相同的剪贴板功能。

虽然已有许多项目和文章尝试解决 WSL 的剪贴板问题，但它们大多存在以下局限性：

1.  **多语言支持不佳**：直接使用 `clip.exe` 的方法，由于编码问题，在多语言环境下容易出现字符乱码。
2.  **需要安装不必要的程序**：依赖额外程序安装的解决方案过于繁琐。本指南仅通过简单的别名设置即可解决问题。
3.  **集成不完整**：无法与 Windows 剪贴板完美集成，导致内容常常无法正常显示在剪贴板历史记录 (`Win + V`) 中。
4.  **保留 Windows 默认文本处理方式**：沿用 Windows 的原生文本处理方式，避免了因修改系统默认设置而可能导致的其他软件文本乱码问题。

### 快速安装（推荐）

这是安装脚本。请复制以下命令并在终端中执行。

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

安装后，重启终端或执行 `source ~/.bashrc` (或 `source ~/.zshrc`)，即可立即使用 `copy` 和 `paste` 命令。

如果需要删除或重置别名，重新执行相同的命令即可。


### 核心原理：从根本上解决编码和换行问题的方法

此方法与其他解决方案的区别在于，它利用 PowerShell 的底层 I/O 功能，**从根本上解决了编码和换行符问题**。

初期曾考虑使用 `iconv` 等工具来处理韩语 `UTF-8` 和 WSL `UTF-8` 之间的转换，但这种方法在处理表情符号或泰语等特定字符集时存在乱码的局限性。这是由于 Windows 使用了复杂的编码方式。目前，Windows 同时使用用于旧版程序的代码页 (例如 `CP949`) 和用于现代系统的 `UTF-16`。

本指南的方法并非直接处理这个复杂问题，而是**直接利用 Windows 内置的 API 兼容层 (API Thunking Layer)**。也就是说，不强制转换数据编码，而是在数据流的两端进行显式处理。

*   **COPY (WSL → Windows)**：将从 WSL 管道输入的数据视为纯**字节流**而非文本。在 PowerShell 中将此字节流**明确解析为 UTF-8**，转换为 Unicode 字符串后，再保存到 Windows 剪贴板。
*   **PASTE (Windows → WSL)**：在 PowerShell 中将 Windows 剪贴板的 Unicode 文本转换为 **UTF-8 字节流**后，直接传递给 WSL 的标准输出。此过程从根本上防止了因 Windows 控制台错误解析文本而导致的编码变更。

通过这种方式，可以确保无数据丢失的完美字符串兼容性。

### 问题：WSL 与 Windows 剪贴板之间的不兼容性

Windows 和 Linux (WSL) 在处理文本数据的方式上存在两大差异，这导致在简单的剪贴板联动时可能发生数据损坏。

1.  **换行符 (Newline) 的差异**：
    *   **Windows**：行尾使用 **CRLF** (`\r\n`, Carriage Return + Line Feed) 表示。
    *   **Linux/macOS**：仅使用 **LF** (`\n`, Line Feed)。
    *   由于这种差异，从 WSL 复制文本到 Windows 或反之，可能会导致换行符损坏或插入不必要的字符，如 `^M`。

2.  **编码的差异**：
    *   WSL 终端环境默认使用 **UTF-8** 编码。
    *   但如果数据在没有明确指定编码的情况下通过管道传递给 PowerShell，系统可能会以默认编码 (例如 `UTF16`) 错误地解析。
    *   这会导致韩文、日文、表情符号等多字节字符损坏，显示为 `???` 或其他异常字符。

### 手动安装

您可以将以下代码直接添加到 `.bashrc` 或 `.zshrc` 文件的末尾：

```shell
# 添加到 .zshrc 或 .bashrc 文件
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

要使更改生效，请执行 `source ~/.bashrc` 或 `source ~/.zshrc`，或打开一个新的终端。

### 代码详解

#### `copy` (WSL -> Windows 剪贴板)

将通过管道输入的数据（例如 `cat test.txt | copy`）复制到 Windows 剪贴板。

1.  `powershell.exe ...`：执行 PowerShell 脚本。
2.  `$stdin.CopyTo($bytes)`：将从 WSL 接收的数据无损地读入为字节流。
3.  `[System.Text.Encoding]::UTF8.GetString(...)`：将读入的字节流**明确指定为 UTF-8** 进行解码，转换为文本。这是确保多语言字符不乱码的关键。
4.  `Set-Clipboard -Value $text`：将最终转换的文本保存到 Windows 剪贴板。

#### `paste` (Windows 剪贴板 -> WSL)

将 Windows 剪贴板的内容粘贴到 WSL 终端。

1.  `powershell.exe ...`：执行 PowerShell 脚本。
2.  `Get-Clipboard -Raw`：从 Windows 剪贴板获取文本数据。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`：将获取的文本**明确指定为 UTF-8 字节流**进行编码。
4.  `[Console]::OpenStandardOutput().Write(...)`：将编码后的字节流直接写入 WSL 的标准输出。
5.  `sed "s/\r$//"`：移除 PowerShell 输出数据每行末尾的 **CR** (`\r`) 字符。通过此操作，将 Windows 的 **CRLF** 转换为 Linux 的 **LF**，确保完美的兼容性。

### 测试方法


#### TEST2
确认 UTF-8 + LF 换行符是否已在 Windows 剪贴板中正确转换为 UTF-16 + CRLF。

在 Linux 中执行
```shell
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt
hello
안녕하세요shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt | xxd
00000000: 6865 6c6c 6f0a ec95 88eb 8595 ed95 98ec  hello...........
00000010: 84b8 ec9a 94                             .....
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt | copy
```


在 Windows PowerShell 中执行
分析剪贴板中最新文本文件的字节的脚本
```powershell
# 以类似 xxd 的格式输出字节数组的函数
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

            # 1. 生成偏移量 (Offset) 部分
            $offsetString = "{0:X8}:" -f $offset

            # 2. 生成十六进制 (Hex) 部分
            $hexString = ($lineBytes | ForEach-Object { "{0:X2}" -f $_ }) -join ' '
            $hexString = $hexString.PadRight($BytesPerLine * 3 - 1)

            # 3. 生成 ASCII 字符部分 (仅转换可显示字符)
            $asciiString = ($lineBytes | ForEach-Object {
                if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { '.' }
            }) -join ''

            # 合并三部分并输出
            "$offsetString $hexString  $asciiString"
        }
    }
}

# --- 主执行逻辑 (仅限文本) ---

try {
    # 使用 -Raw 选项仅获取纯文本字符串
    $clipboardText = Get-Clipboard -Raw -ErrorAction SilentlyContinue

    if ($null -ne $clipboardText) {
        Write-Host "显示剪贴板文本的原始字节 (UTF-16 LE)。" -ForegroundColor Green

        # 转换为 .NET 字符串的默认编码 UTF-16 LE (Unicode) 字节数组
        # 这是 Windows 剪贴板中“原样”的文本字节表示
        $clipboardBytes = [System.Text.Encoding]::Unicode.GetBytes($clipboardText)

        # 使用十六进制转储函数输出
        $clipboardBytes | Format-Hex
    }
    else {
        Write-Warning "剪贴板中没有文本数据。"
    }
}
catch {
    Write-Error "读取剪贴板时出错：$($_.Exception.Message)"
}
```

1.  **原始文件 (WSL 中的 sample2.txt)**
    *   `6865 6c6c 6f`: "hello" (UTF-8)
    *   `0a`: LF (Line Feed) 换行符
    *   `ec95 88eb 8595 ed95 98ec 84b8 ec9a 94`: "안녕하세요" (UTF-8)

2.  **复制到 Windows 剪贴板的结果**
    将用户提供的十六进制值重新构造成标准格式后如下所示。这是存储在 Windows 剪贴板中的实际字节值。

    *   `68 00 65 00 6c 00 6c 00 6f 00`: "hello" (UTF-16 Little Endian)
    *   `0d 00 0a 00`: CRLF (Carriage Return + Line Feed) 换行符 (UTF-16 Little Endian)
    *   `48 C5 55 B1 58 D5 38 C1 94 C6`: "안녕하세요" (UTF-16 Little Endian)

如此，原始的 LF (`0a`) 已被准确转换为 CRLF (`0d 00 0a 00`)，并且整个字符串已从 UTF-8 正确编码为 UTF-16 Little Endian。




#### TEST2

执行以下脚本，可以确认原始文件内容与经过 `copy` 和 `paste` 后的内容在字节级别上是否完全相同。
为了进行测试，当前目录中必须存在一个名为 'sample.txt' 的文件。

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
    echo "--> ✅ 两个字节序列完全匹配。"
else
    echo "--> ❌ 两个字节序列之间发现差异。"
fi
```

### 预期结果

执行测试脚本时，`diff` 命令不应产生任何输出，并且最后应显示以下成功消息。这表示原始数据与经过剪贴板的数据 100% 相同。

```
--- 原始文件 (sample.txt) 的字节序列 ---
(xxd 输出将显示在此处)

--- 从剪贴板 (paste) 获取的字节序列 ---
(xxd 输出将显示在此处 - 应与上方相同)

--- 比较两个字节序列 (diff 结果) ---

--> ✅ 两个字节序列完全匹配。
```