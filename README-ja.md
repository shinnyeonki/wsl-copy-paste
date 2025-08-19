はい、承知いたしました。以下に、指定された韓国語のドキュメントを自然で分かりやすい日本語に完全に翻訳します。

---

[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 概要

このドキュメントは、WSL (Windows Subsystem for Linux) 環境で、macOSの`pbcopy`や`pbpaste`のようにクリップボードを完璧に利用するための`copy`および`paste`エイリアス(alias)の設定方法を説明します。

WSLのクリップボード問題を解決しようとする既存の多くのプロジェクトや記事がありますが、そのほとんどは以下のような限界を抱えています。

1.  **多言語サポートの不備**: `clip.exe`を直接使用する単純な方法では、多言語環境でエンコーディング問題により文字化けが発生します。
2.  **不要な重さ**: 別途プログラムをインストールする必要がある方法は、あまりにもヘビーです。このガイドは、簡単なエイリアス設定だけで問題を解決します。
3.  **不完全な連携**: Windowsのクリップボードと完全に連携できず、クリップボード履歴 (`Win + V`) に内容が正しく表示されない場合があります。
4.  **Windowsのデフォルトのテキスト処理を維持**: この方法はWindowsの基本的なテキスト処理方式をそのまま利用します（この方式を変更すると、既存のソフトウェアでテキストが破損する現象が確認されています）。

このガイドで提案する方法は、PowerShellの低レベル（low-level）なI/O機能を活用し、エンコーディングと改行コードの問題を根本的に解決します。当初は、韓国語、日本語、中国語環境の`CP949`や`CP932(Shift_JIS)`といったエンコーディングを考慮して`iconv`を使用する方法を試しましたが、絵文字やタイ語などの特定の文字セットで文字化けが発生することが判明しました。

そのため、この方法は以下の原理で動作し、問題を完璧に解決します。

*   **COPY**: WSLからパイプで渡された入力を、テキストではなく純粋な**バイトストリーム (byte stream)**として扱います。このバイトストリームを明示的に**UTF-8**として解釈してUnicode文字列に変換した後、Windowsのクリップボードに保存します。
*   **PASTE**: Windowsのクリップボードから取得したUnicodeテキストを**UTF-8のバイトストリーム**に変換し、WSLへ直接出力します。このプロセスにより、Windowsコンソールがテキストを誤って解釈し、エンコーディングを変更してしまう余地を与えません。

### 問題点: WSLとWindowsクリップボードの非互換性

WindowsとLinux (WSL) は、テキストデータの処理方法に2つの主要な違いがあるため、単純なクリップボード連携ではデータが破損する可能性があります。

1.  **改行 (Newline) コードの違い**:
    *   **Windows**: 行末を示すために **CRLF** (`\r\n`, Carriage Return + Line Feed) を使用します。
    *   **Linux/macOS**: **LF** (`\n`, Line Feed) のみを使用します。
    *   この違いにより、WSLからコピーしたテキストをWindowsに貼り付けたり、その逆を行ったりすると、改行が崩れたり、`^M`のような不要な文字が挿入されたりすることがあります。

2.  **エンコーディング (Encoding) の違い**:
    *   WSLのターミナル環境は、ほとんどの場合 **UTF-8** エンコーディングをデフォルトで使用します。
    *   しかし、パイプラインを通じてPowerShellにデータを渡す際、エンコーディングが明示されていないと、システムのデフォルトエンコーディング（例：日本語環境では`CP932` / `Shift_JIS`など）で誤って解釈される可能性があります。
    *   これにより、日本語、韓国語、絵文字などのマルチバイト文字が文字化けし、`???`や異常な文字で表示される問題が発生します。

### 解決策: PowerShellを利用したエイリアス(Alias)設定

これらの問題を解決するために、WSLからWindowsの`powershell.exe`を直接呼び出してクリップボードを制御します。以下のコードを`.bashrc`または`.zshrc`ファイルの末尾に追加してください。

```shell
# .zshrc または .bashrc に追加
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

ターミナルに変更を適用するには、`source ~/.bashrc`または`source ~/.zshrc`コマンドを実行するか、新しいターミナルを開いてください。

### コードの詳細説明

#### `copy` (WSL -> Windowsクリップボード)

`cat test.txt | copy`のようにパイプで渡されたデータをWindowsのクリップボードにコピーします。

1.  `sed "s/$/\r/"`: 各行の末尾(`$`)に **CR** (`\r`) 文字を追加します。これにより、Linuxの **LF** (`\n`) がWindowsの **CRLF** (`\r\n`) に変換されます。
2.  `powershell.exe ...`: PowerShellスクリプトを実行します。
3.  `$stdin.CopyTo($bytes)`: WSLから渡されたデータを破損なくそのままバイトストリームとして読み込みます。
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: 読み込んだバイトストリームを**明示的にUTF-8でデコード**し、テキストに変換します。これが多言語の文字化けを防ぐ核心部分です。
5.  `Set-Clipboard -Value $text`: 最終的に変換されたテキストをWindowsのクリップボードに保存します。

#### `paste` (Windowsクリップボード -> WSL)

Windowsクリップボードの内容をWSLターミナルに貼り付けます。

1.  `powershell.exe ...`: PowerShellスクリプトを実行します。
2.  `Get-Clipboard -Raw`: Windowsクリップボードからテキストデータを取得します。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 取得したテキストを**明示的にUTF-8のバイトストリームとしてエンコード**します。
4.  `[Console]::OpenStandardOutput().Write(...)`: エンコードされたバイトストリームをWSLの標準出力にそのまま渡します。
5.  `sed "s/\r$//"`: PowerShellが出力したデータ（CRLF）から、行末の **CR** (`\r`) 文字をすべて削除します。これにより、Windowsの **CRLF** がLinuxの **LF** に変換され、完全な互換性が保たれます。

### テスト方法

以下のスクリプトを実行することで、オリジナルファイルの内容と、`copy` & `paste`を経た後の内容がバイト単位まで完全に同一であることを確認できます。
テストには、カレントディレクトリに`sample.txt`ファイルが必要です。

```shell
echo "--- オリジナルファイル(sample.txt)のバイトシーケンス ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- クリップボード(paste)のバイトシーケンス ---"
paste | xxd
echo ""

echo "--- 2つのバイトシーケンスの比較 (diffの結果) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 2つのバイトシーケンスは完全に同一です。"
else
    echo "--> ❌ 2つのバイトシーケンスに差異が検出されました。"
fi
```

### 期待される結果

テストスクリプトを実行すると、`diff`コマンドは何も出力せず、最終的に以下のような成功メッセージが表示されるはずです。これは、オリジナルデータとクリップボードを経由したデータが100%一致することを意味します。

```
--- オリジナルファイル(sample.txt)のバイトシーケンス ---
(xxdの結果が出力)

--- クリップボード(paste)のバイトシーケンス ---
(xxdの結果が出力 - 上記と同一であるべき)

--- 2つのバイトシーケンスの比較 (diffの結果) ---

--> ✅ 2つのバイトシーケンスは完全に同一です。
```