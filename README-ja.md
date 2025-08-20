承知いたしました。ご要望に応じて、ドキュメントを再構成し、内容を洗練させます。「クイックインストール」部分を上部に移動させてユーザーがすぐに適用できるようにし、中核的な原則部分をより明確で理解しやすく再作成しました。以下に日本語訳を記載します。

---

[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 概要

このドキュメントは、WSL (Windows Subsystem for Linux) 環境で、macOSの `pbcopy` および `pbpaste` と完全に同一のクリップボード機能を実現するために、`copy` と `paste` のエイリアス(alias)を設定する方法について説明します。

WSLのクリップボード問題を解決しようとする既存の多くのプロジェクトや記事がありますが、そのほとんどが以下のような限界を抱えています。

1.  **不十分な多言語サポート**: 単純に `clip.exe` を直接使用する方法は、エンコーディングの問題により多言語環境で文字化けしやすいです。
2.  **不要なプログラムのインストール**: 別途プログラムをインストールする必要がある解決策は、重すぎます。このガイドは、簡単なエイリアス設定だけで問題を解決します。
3.  **不完全な統合**: Windowsのクリップボードと完全に統合されず、クリップボード履歴(`Win + V`)に内容が正しく表示されないことがよくあります。
4.  **Windowsのデフォルトのテキスト処理方式を維持**: システムのデフォルト設定を変更する際に発生しうる他のソフトウェアでの文字化け現象を起こさず、Windowsのネイティブなテキスト処理方式をそのまま使用します。

### クイックインストール (推奨)

インストールスクリプトです。以下のコマンドをターミナルにコピーして実行してください。

```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

インストール後、ターミナルを再起動するか、`source ~/.bashrc` (または `source ~/.zshrc`) を実行すると、すぐに `copy` と `paste` コマンドが使用できるようになります。

削除またはエイリアスを再設定したい場合は、コマンドをそのまま再実行してください。


### 中核的な原則：エンコーディングと改行の問題を根本的に解決する方法

この方法が他の解決策と差別化される理由は、PowerShellの低レベルI/O機能を活用し、**エンコーディングと改行文字の問題を根本的に解決**するからです。

初期には、韓国語の `UTF-8` とWSLの `UTF-8` 間の変換のために `iconv` のようなツールを使用するアプローチが検討されましたが、絵文字やタイ語など特定の文字セットが文字化けする限界がありました。これは、Windowsが使用する複雑なエンコーディング方式が原因です。現在のWindowsは、レガシープログラムのためのコードページ（例：`CP949`）と最新システムのための `UTF-16` を併用しています。

このガイドのアプローチは、この複雑な問題を直接扱うのではなく、**Windowsに内蔵されたAPI互換性レイヤー（API Thunking Layer）をそのまま活用**します。つまり、データのエンコーディングを無理に変換せず、データフローの両端で明示的に処理します。

*   **COPY (WSL → Windows)**: WSLからパイプで入力されたデータをテキストではなく、純粋な**バイトストリーム**として扱います。このバイトストリームをPowerShellで**明示的にUTF-8**として解釈し、ユニコード文字列に変換した後、Windowsのクリップボードに保存します。
*   **PASTE (Windows → WSL)**: WindowsクリップボードのユニコードテキストをPowerShellで**UTF-8バイトストリーム**に変換した後、WSLの標準出力に直接渡します。このプロセスは、途中でWindowsコンソールがテキストを誤って解釈し、エンコーディングを変更してしまうことを根本的に防ぎます。

このような方式により、データ損失なく完璧な文字列の互換性を保証します。

### 問題点：WSLとWindowsクリップボード間の非互換性

WindowsとLinux(WSL)は、テキストデータを処理する方法に2つの大きな違いがあり、これにより単純なクリップボード連携時にデータが破損する可能性があります。

1.  **改行文字(Newline)の違い**:
    *   **Windows**: 一行の終わりを **CRLF**(`\r\n`, Carriage Return + Line Feed)で示します。
    *   **Linux/macOS**: **LF**(`\n`, Line Feed)のみを使用します。
    *   この違いにより、WSLからWindowsへ、またはその逆でテキストをコピーする際に改行が崩れたり、`^M`のような不要な文字が挿入されたりすることがあります。

2.  **エンコーディングの違い**:
    *   WSLのターミナル環境は、基本的に **UTF-8** エンコーディングを使用します。
    *   しかし、データが明示的なエンコーディングなしにパイプラインを通じてPowerShellに渡されると、システムのデフォルトエンコーディング（例：`UTF16`）で誤って解釈されます。
    *   これにより、ハングル、日本語、絵文字のようなマルチバイト文字が文字化けし、`???`や他の奇妙な文字で表示されます。

### 手動インストール

`.bashrc` または `.zshrc` ファイルの一番下に、以下のコードを直接追加することができます：

```shell
# .zshrc または .bashrc ファイルに追加
alias copy='powershell.exe -noprofile -command "$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace \"`n\", \"`r`n\"; Set-Clipboard -Value $text"'
alias paste='powershell.exe -noprofile -command "$text = Get-Clipboard -Raw; $bytes = [System.Text.Encoding]::UTF8.GetBytes($text); [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)" | tr -d "\r"'
```

ターミナルに変更を適用するには、`source ~/.bashrc` または `source ~/.zshrc` を実行するか、新しいターミナルを開きます。

### コードの詳細な説明

#### `copy` (WSL -> Windowsクリップボード)

`cat test.txt | copy` のようにパイプで入力されたデータをWindowsクリップボードにコピーします。

1.  `powershell.exe ...`: PowerShellスクリプトを実行します。
2.  `$stdin.CopyTo($bytes)`: WSLから受け取ったデータを破損なくバイトストリームとして読み込みます。
3.  `[System.Text.Encoding]::UTF8.GetString(...)`: 読み込んだバイトストリームを**明示的にUTF-8**としてデコードし、テキストに変換します。これが多言語文字が化けないようにする核心です。
4.  `Set-Clipboard -Value $text`: 最終的に変換されたテキストをWindowsクリップボードに保存します。

#### `paste` (Windowsクリップボード -> WSL)

Windowsクリップボードの内容をWSLターミナルに貼り付けます。

1.  `powershell.exe ...`: PowerShellスクリプトを実行します。
2.  `Get-Clipboard -Raw`: Windowsクリップボードからテキストデータを取得します。
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 取得したテキストを**明示的にUTF-8バイトストリーム**としてエンコードします。
4.  `[Console]::OpenStandardOutput().Write(...)`: エンコードされたバイトストリームをWSLの標準出力に直接書き込みます。
5.  `tr -d "\r"`: PowerShellが出力したデータの各行の末尾にある**CR**(`\r`)文字を削除します。これにより、Windowsの**CRLF**をLinuxの**LF**に変換し、完璧な互換性を保証します。

### テスト方法

以下のスクリプトを実行して、元のファイルの内容と `copy` & `paste` を経た後の内容がバイトレベルまで完全に同一であることを確認できます。
テストのためには、現在のディレクトリに 'sample.txt' というファイルが必要です。

```shell
echo "--- 元のファイル(sample.txt)のバイトシーケンス ---"
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

### 期待される結果

テストスクリプトを実行した際、`diff` コマンドは何も出力せず、最後に以下のような成功メッセージが表示されるはずです。これは、元のデータとクリップボードを経たデータが100%同一であることを意味します。

```
--- 元のファイル(sample.txt)のバイトシーケンス ---
(ここにxxdの出力が表示されます)

--- クリップボード(paste)から取得したバイトシーケンス ---
(ここにxxdの出力が表示されます - 上と同一でなければなりません)

--- 2つのバイトシーケンスの比較 (diffの結果) ---

--> ✅ 2つのバイトシーケンスは完全に一致します。
```