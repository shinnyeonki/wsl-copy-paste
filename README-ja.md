[英語](README.md)
[中国語](README-zh.md)
[韓国語](README-ko.md)
[日本語](README-ja.md)

### 概要

このドキュメントでは、WSL (Windows Subsystem for Linux) 環境で、macOSの `pbcopy` と `pbpaste` のクリップボード機能を完全に再現するための `copy` と `paste` エイリアス（alias）を設定する方法について説明します。

WSLでのクリップボード問題を解決しようとする既存の多くのプロジェクトや記事がありますが、ほとんどは以下のような制限がありました。

1.  **多言語サポートの不足**: 単純に `clip.exe` を使用する方法では、エンコーディングの問題で多言語環境の文字が壊れることがよくあります。
2.  **不必要な肥大化**: 別のプログラムをインストールする必要がある解決策は、重すぎます。このガイドでは、簡単なエイリアス設定だけで問題を解決します。
3.  **不完全な統合**: Windowsのクリップボードと完全に統合されず、クリップボード履歴（`Win + V`）に内容が正しく表示されない場合があります。
4.  **Windowsのデフォルトテキスト処理を維持**: この方法は、Windowsネイティブのテキスト処理をそのまま使用するため、システムのデフォルト設定を変更したときに他のソフトウェアで発生しうるテキストの破損を回避します。

このガイドで紹介する方法は、PowerShellの低レベルI/O機能を活用することで、エンコーディングと改行コードの問題を根本的に解決します。当初、韓国語、日本語、中国語環境のために `CP949` エンコーディングを処理する `iconv` を使用する方法を検討しましたが、絵文字やタイ文字など特定の文字セットが壊れることがわかりました。

そのため、この方法は以下の原則に基づいて動作し、完璧な解決策を提供します。

*   **COPY**: WSLからパイプで渡された入力をテキストとしてではなく、純粋な**バイトストリーム**として処理します。このバイトストリームを明示的に**UTF-8**として解釈し、Unicode文字列に変換してからWindowsのクリップボードに保存します。
*   **PASTE**: WindowsのクリップボードからUnicodeテキストを取得し、それを**UTF-8のバイトストリーム**に変換してWSLに直接出力します。このプロセスにより、Windowsコンソールがテキストを誤って解釈し、エンコーディングを変更するのを防ぎます。

### 問題点: WSLとWindowsクリップボードの非互換性

WindowsとLinux (WSL) は、テキストデータの扱い方に2つの大きな違いがあり、これが単純なクリップボード操作でのデータ破損を引き起こす原因となります。

1.  **改行コードの違い**:
    *   **Windows**: 行の終わりに **CRLF** (`\r\n`, Carriage Return + Line Feed) を使用します。
    *   **Linux/macOS**: **LF** (`\n`, Line Feed) のみを使用します。
    *   この違いにより、WSLからWindowsへテキストをコピーしたり、その逆を行ったりする際に、改行が壊れたり、`^M` のような不要な文字が挿入されたりすることがあります。

2.  **エンコーディングの違い**:
    *   WSLのターミナル環境は、ほとんどの場合、デフォルトで **UTF-8** エンコーディングを使用します。
    *   しかし、明示的なエンコーディング指定なしにパイプラインを通じてPowerShellにデータが渡されると、システムのデフォルトエンコーディング（例：`cp949`）で誤って解釈されることがあります。
    *   これにより、韓国語、日本語、絵文字などのマルチバイト文字が壊れて `???` や他の奇妙な文字として表示されます。

### 解決策: PowerShellを使用したエイリアスの設定

これらの問題を解決するために、WSLからWindowsの `powershell.exe` を直接呼び出してクリップボードを制御します。

#### クイックインストール（推奨）

使用しているシェルを検出し、エイリアスを自動的に追加する自動インストールスクリプトを使用してください。

ubuntu ...
```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

debian ...
```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | zsh
```

または、このリポジトリをクローンした場合：

```shell
./install.sh
```

#### 手動インストール

または、`.bashrc` や `.zshrc` ファイルの末尾に以下のコードを手動で追加することもできます。

```shell
# .zshrc または .bashrc に追加
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

変更をターミナルに適用するには、`source ~/.bashrc` または `source ~/.zshrc` を実行するか、新しいターミナルを開いてください。

### コードの詳細な説明

#### `copy` (WSL -> Windowsクリップボード)

`cat test.txt | copy` のように、入力からパイプで渡されたデータをWindowsのクリップボードにコピーします。

1.  `sed "s/$/\r/"`: 各行の末尾(`$`)に**CR** (`\r`) 文字を追加します。これにより、Linuxの**LF** (`\n`) がWindowsの**CRLF** (`\r\n`) に変換されます。
2.  `powershell.exe ...`: PowerShellスクリプトを実行します。
3.  `$stdin.CopyTo($bytes)`: WSLからのデータを破損なくバイトストリームとして読み取ります。
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: 読み取ったバイトストリームを**明示的にUTF-8としてデコード**し、テキストに変換します。これが多言語文字の破損を防ぐ鍵です。
5.  `Set-Clipboard -Value $text`: 最終的に変換されたテキストをWindowsのクリップボードに保存します。

#### `paste` (Windowsクリップボード -> WSL)

Windowsクリップボードの内容をWSLターミナルに貼り付けます。

1.  `powershell.exe ...`: PowerShellスクリプトを実行します。
2.  `Get-Clipboard -Raw`: Windowsクリップボードからテキストデータを取得します。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 取得したテキストを**明示的にUTF-8のバイトストリームにエンコード**します。
4.  `[Console]::OpenStandardOutput().Write(...)`: エンコードされたバイトストリームをWSLの標準出力に直接書き込みます。
5.  `sed "s/\r$//"`: PowerShellが出力したデータの各行の末尾にある**CR** (`\r`) 文字を削除します。これにより、Windowsの**CRLF**がLinuxの**LF**に変換され、完全な互換性が確保されます。

### テスト方法

以下のスクリプトを実行して、元のファイルの内容と `copy` & `paste` で処理された後の内容がバイトレベルで完全に一致することを確認できます。
テストを行うには、カレントディレクトリに 'sample.txt' という名前のファイルが存在する必要があります。

```shell
echo "--- 元のファイル（sample.txt）のバイトシーケンス ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- クリップボードからのバイトシーケンス（paste） ---"
paste | xxd
echo ""

echo "--- 2つのバイトシーケンスの比較（diffの結果） ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 2つのバイトシーケンスは完全に一致しました。"
else
    echo "--> ❌ 2つのバイトシーケンスに違いが見つかりました。"
fi
```

### 期待される結果

テストスクリプトを実行すると、`diff` コマンドは何も出力せず、最後に以下の成功メッセージが表示されるはずです。これは、元のデータとクリップボードを経由したデータが100%同一であることを示しています。

```
--- 元のファイル（sample.txt）のバイトシーケンス ---
(ここにxxdの出力が表示されます)

--- クリップボードからのバイトシーケンス（paste） ---
(ここにxxdの出力が表示されます - 上記と同一のはずです)

--- 2つのバイトシーケンスの比較（diffの結果） ---

--> ✅ 2つのバイトシーケンスは完全に一致しました。
```