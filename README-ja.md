[ENGLISH](README.md)
[CHINESE](README-zh.md)
[KOREAN](README-ko.md)
[JAPANESE](README-ja.md)

### 概要

このドキュメントでは、WSL (Windows Subsystem for Linux) 環境で、macOSの`pbcopy`および`pbpaste`と完全に同じクリップボード機能を実現するために、`copy`と`paste`のエイリアス(alias)を設定する方法について説明します。

WSLのクリップボード問題を解決しようとする既存の多くのプロジェクトや記事がありますが、そのほとんどは次のような限界があります。

1.  **不十分な多言語サポート**: 単純に`clip.exe`を直接使用する方法では、エンコーディングの問題で多言語環境で文字化けが発生しやすくなります。
2.  **不要なプログラムのインストール**: 別途プログラムをインストールする必要がある解決策は、あまりにもヘビーです。このガイドでは、簡単なエイリアス設定だけで問題を解決します。
3.  **不完全な統合**: Windowsのクリップボードと完全に統合されず、クリップボード履歴(`Win + V`)に内容が正しく表示されないことがよくあります。
4.  **Windowsのデフォルトのテキスト処理方式を維持**: システムのデフォルト設定を変更する際に発生しうる他のソフトウェアでのテキストの文字化けを起こすことなく、Windowsのネイティブなテキスト処理方式をそのまま使用します。

### クイックインストール (推奨)

インストールスクリプトです。以下のコマンドをターミナルにコピーして実行してください。

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

インストール後、ターミナルを再起動するか、`source ~/.bashrc` (または `source ~/.zshrc`) を実行すると、すぐに`copy`と`paste`コマンドが使用できます。

削除またはエイリアスを再設定したい場合は、コマンドをそのまま再実行してください。


### 中核となる原則：エンコーディングと改行の問題を根本的に解決する方法

この方法が他の解決策と異なる点は、PowerShellの低レベルI/O機能を活用して、**エンコーディングと改行文字の問題を根本的に解決する**点です。

当初は、韓国語の`UTF-8`とWSLの`UTF-8`間の変換のために`iconv`のようなツールを使用するアプローチが検討されましたが、絵文字やタイ語など特定の文字セットが文字化けするという限界がありました。これは、Windowsが使用する複雑なエンコーディング方式が原因です。現在、Windowsはレガシープログラムのためのコードページ（例：`CP949`）と最新システムのための`UTF-16`を併用しています。

このガイドのアプローチは、この複雑な問題を直接扱うのではなく、**Windowsの組み込みAPI互換性レイヤー（API Thunking Layer）をそのまま活用**します。つまり、データのエンコーディングを無理に変換せず、データフローの両端で明示的に処理します。

*   **COPY (WSL → Windows)**: WSLからパイプで入力されたデータをテキストではなく、純粋な**バイトストリーム**として扱います。このバイトストリームをPowerShellで**明示的にUTF-8**として解釈し、Unicode文字列に変換した後、Windowsのクリップボードに保存します。
*   **PASTE (Windows → WSL)**: WindowsクリップボードのUnicodeテキストをPowerShellで**UTF-8バイトストリーム**に変換した後、WSLの標準出力に直接渡します。このプロセスは、途中でWindowsコンソールがテキストを誤って解釈し、エンコーディングを変更することを根本的に防ぎます。

この方式により、データ損失なく完全な文字列の互換性が保証されます。

### 問題点：WSLとWindowsクリップボード間の非互換性

WindowsとLinux(WSL)は、テキストデータの処理方法に2つの大きな違いがあり、これにより単純なクリップボード連携時にデータが破損する可能性があります。

1.  **改行文字(Newline)の違い**:
    *   **Windows**: 一行の終わりを**CRLF**(`\r\n`, Carriage Return + Line Feed)で表します。
    *   **Linux/macOS**: **LF**(`\n`, Line Feed)のみを使用します。
    *   この違いにより、WSLからWindowsへ、またはその逆にテキストをコピーする際に改行が崩れたり、`^M`のような不要な文字が挿入されたりすることがあります。

2.  **エンコーディングの違い**:
    *   WSLターミナル環境は、基本的に**UTF-8**エンコーディングを使用します。
    *   しかし、データが明示的なエンコーディングなしにパイプラインを通じてPowerShellに渡されると、システムのデフォルトエンコーディング（例：`UTF16`）で誤って解釈されます。
    *   これにより、韓国語、日本語、絵文字などのマルチバイト文字が文字化けし、`???`や他の奇妙な文字で表示されます。

### 手動インストール

`.bashrc`または`.zshrc`ファイルの末尾に、次のコードを直接追加することができます。

```shell
# .zshrc または .bashrc ファイルに追加
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

ターミナルに変更を適用するには、`source ~/.bashrc`または`source ~/.zshrc`を実行するか、新しいターミナルを開いてください。

### コードの詳細説明

#### `copy` (WSL -> Windowsクリップボード)

`cat test.txt | copy`のようにパイプで入力されたデータをWindowsクリップボードにコピーします。

1.  `powershell.exe ...`: PowerShellスクリプトを実行します。
2.  `$stdin.CopyTo($bytes)`: WSLから受け取ったデータを破損なくバイトストリームとして読み込みます。
3.  `[System.Text.Encoding]::UTF8.GetString(...)`: 読み込んだバイトストリームを**明示的にUTF-8**としてデコードし、テキストに変換します。これが多言語の文字が化けないようにする核心部分です。
4.  `Set-Clipboard -Value $text`: 最終的に変換されたテキストをWindowsクリップボードに保存します。

#### `paste` (Windowsクリップボード -> WSL)

Windowsクリップボードの内容をWSLターミナルに貼り付けます。

1.  `powershell.exe ...`: PowerShellスクリプトを実行します。
2.  `Get-Clipboard -Raw`: Windowsクリップボードからテキストデータを取得します。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 取得したテキストを**明示的にUTF-8バイトストリーム**としてエンコードします。
4.  `[Console]::OpenStandardOutput().Write(...)`: エンコードされたバイトストリームをWSLの標準出力に直接書き込みます。
5.  `sed "s/\r$//"`: PowerShellが出力したデータの各行の末尾にある**CR**(`\r`)文字を削除します。これにより、Windowsの**CRLF**をLinuxの**LF**に変換し、完全な互換性を保証します。

### テスト方法


#### TEST2
UTF-8 + LF改行がWindowsクリップボードでUTF-16 + CRLFに正しく変換されたかを確認します。

linuxで実行
```shell
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt
hello
안녕하세요shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt | xxd
00000000: 6865 6c6c 6f0a ec95 88eb 8595 ed95 98ec  hello...........
00000010: 84b8 ec9a 94                             .....
shinnk@DESKTOP-KRSG68U:~/project/wsl-copy-paste$ cat sample2.txt | copy
```


window側のpowershellで実行
クリップボードの最新のテキストファイルのバイトを分析するスクリプト
```powershell
# xxdと類似した形式でバイト配列を出力する関数
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

            # 1. オフセット (Offset) 部分の生成
            $offsetString = "{0:X8}:" -f $offset

            # 2. 16進数 (Hex) 部分の生成
            $hexString = ($lineBytes | ForEach-Object { "{0:X2}" -f $_ }) -join ' '
            $hexString = $hexString.PadRight($BytesPerLine * 3 - 1)

            # 3. ASCII文字部分の生成 (表示可能な文字のみ変換)
            $asciiString = ($lineBytes | ForEach-Object {
                if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { '.' }
            }) -join ''

            # 3つの部分を結合して一行で出力
            "$offsetString $hexString  $asciiString"
        }
    }
}

# --- メイン実行ロジック (テキスト専用) ---

try {
    # -Rawオプションで純粋なテキスト文字列のみを取得
    $clipboardText = Get-Clipboard -Raw -ErrorAction SilentlyContinue

    if ($null -ne $clipboardText) {
        Write-Host "クリップボードテキストのオリジナルバイト(UTF-16 LE)を表示します。" -ForegroundColor Green

        # .NET文字列のデフォルトエンコーディングであるUTF-16 LE(Unicode)バイト配列に変換
        # これがWindowsクリップボードの「そのまま」のテキストバイト表現
        $clipboardBytes = [System.Text.Encoding]::Unicode.GetBytes($clipboardText)

        # ヘックスダンプ関数で出力
        $clipboardBytes | Format-Hex
    }
    else {
        Write-Warning "クリップボードにテキストデータがありません。"
    }
}
catch {
    Write-Error "クリップボードの読み込み中にエラーが発生しました: $($_.Exception.Message)"
}
```

1.  **オリジナルファイル (sample2.txt in WSL)**
    *   `6865 6c6c 6f`: "hello" (UTF-8)
    *   `0a`: LF (Line Feed) 改行文字
    *   `ec95 88eb 8595 ed95 98ec 84b8 ec9a 94`: "안녕하세요" (アンニョンハセヨ - UTF-8)

2.  **Windowsクリップボードにコピーされた結果**
    提示されたHex値を標準形式に再構成すると以下のようになります。これはWindowsクリップボードに保存された実際のバイト値です。

    *   `68 00 65 00 6c 00 6c 00 6f 00`: "hello" (UTF-16 Little Endian)
    *   `0d 00 0a 00`: CRLF (Carriage Return + Line Feed) 改行文字 (UTF-16 Little Endian)
    *   `48 C5 55 B1 58 D5 38 C1 94 C6`: "안녕하세요" (アンニョンハセヨ - UTF-16 Little Endian)

このように、オリジナルのLF(`0a`)がCRLF(`0d 00 0a 00`)に正確に変換され、文字列全体がUTF-8からUTF-16 Little Endianに正しくエンコードされていることが確認できます。




#### TEST2

以下のスクリプトを実行して、オリジナルファイルの内容と`copy` & `paste`を経た後の内容がバイトレベルまで完全に同一であるかを確認できます。
テストを行うには、現在のディレクトリに'sample.txt'というファイルが必要です。

```shell
echo "--- オリジナルファイル(sample.txt)のバイトシーケンス ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- クリップボード(paste)から取得したバイトシーケンス ---"
paste | xxd
echo ""

echo "--- 2つのバイトシーケンスの比較 (diffの結果) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 2つのバイトシーケンスは完全に一致します。"
else
    echo "--> ❌ 2つのバイトシーケンス間に差異が発見されました。"
fi
```

### 予想される結果

テストスクリプトを実行した際、`diff`コマンドは何も出力せず、最後に次のような成功メッセージが表示されるはずです。これは、オリジナルデータとクリップボードを経由したデータが100%同一であることを意味します。

```
--- オリジナルファイル(sample.txt)のバイトシーケンス ---
(xxdの出力がここに表示されます)

--- クリップボード(paste)から取得したバイトシーケンス ---
(xxdの出力がここに表示されます - 上と同一であるべきです)

--- 2つのバイトシーケンスの比較 (diffの結果) ---

--> ✅ 2つのバイトシーケンスは完全に一致します。
```