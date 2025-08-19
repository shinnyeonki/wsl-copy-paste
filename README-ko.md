[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 개요

이 문서는 WSL(Windows Subsystem for Linux) 환경에서 macOS의 `pbcopy`, `pbpaste`와 같이 클립보드를 완벽하게 사용하기 위한 `copy`, `paste` 별칭(alias) 설정 방법을 설명합니다.

WSL에서 클립보드 문제를 해결하려는 기존의 많은 프로젝트나 글이 있지만, 대부분 다음과 같은 한계를 가집니다.

1.  **다국어 지원 미흡**: `clip.exe`를 직접 사용하는 단순한 방식은 다국어(Multilingual) 환경에서 인코딩 문제로 문자를 깨뜨립니다.
2.  **불필요한 무거움**: 별도의 프로그램을 설치해야 하는 방식은 너무 무겁습니다. 이 가이드는 간단한 별칭(alias) 설정만으로 문제를 해결합니다.
3.  **불완전한 연동**: Windows 클립보드와 완벽히 연동되지 않아, 클립보드 히스토리(`Win + V`)에 내용이 제대로 표시되지 않는 경우가 있습니다.
4.  **윈도우의 기본 텍스트 처리 유지** 윈도우의 기본 텍스트 처리 방식을 그대로 사용함(바꿀경우 기존 소프트웨어에서 텍스트 깨짐 현상이 관찰됨)

이 가이드에서 제시하는 방법은 PowerShell의 저수준(low-level) 입출력 기능을 활용하여 인코딩 및 개행 문자 문제를 원천적으로 해결합니다. 초기에는 한국어, 일본어, 중국어 환경의 `CP949` 인코딩을 고려하여 `iconv`를 사용하는 방식을 시도했으나, 이모티콘이나 태국어 등 특정 문자 집합에서 깨지는 현상이 발견되었습니다.

따라서 이 방법은 다음과 같은 원리로 동작하여 문제를 완벽히 해결합니다.

*   **COPY**: WSL에서 파이프로 넘어오는 입력을 텍스트가 아닌 순수한 **바이트 스트림(byte stream)**으로 처리합니다. 이 바이트 스트림을 명시적으로 **UTF-8**로 해석하여 유니코드 문자열로 변환한 뒤, Windows 클립보드에 저장합니다.
*   **PASTE**: Windows 클립보드에서 가져온 유니코드 텍스트를 **UTF-8 바이트 스트림**으로 변환하여 WSL로 직접 출력합니다. 이 과정에서 Windows 콘솔이 텍스트를 잘못 해석하여 인코딩을 변경할 여지를 주지 않습니다.

### 문제점: WSL과 Windows 클립보드의 비호환성

Windows와 Linux (WSL)는 텍스트 데이터를 처리하는 방식에 두 가지 주요 차이점이 있어, 단순한 클립보드 연동 시 데이터가 손상될 수 있습니다.

1.  **개행(Newline) 문자 차이**:
    *   **Windows**: 한 줄의 끝을 나타내기 위해 **CRLF** (`\r\n`, Carriage Return + Line Feed)를 사용합니다.
    *   **Linux/macOS**: **LF** (`\n`, Line Feed)만을 사용합니다.
    *   이 차이로 인해 WSL에서 복사한 텍스트를 Windows에 붙여넣거나 그 반대의 경우, 줄바꿈이 깨지거나 `^M`과 같은 불필요한 문자가 삽입될 수 있습니다.

2.  **인코딩(Encoding) 차이**:
    *   WSL의 터미널 환경은 대부분 **UTF-8** 인코딩을 기본으로 사용합니다.
    *   하지만 파이프라인을 통해 PowerShell로 데이터를 넘길 때, 인코딩이 명시되지 않으면 시스템 기본 인코딩(예: `cp949` 등)으로 잘못 해석될 수 있습니다.
    *   이로 인해 한글, 일본어, 이모지 등 멀티바이트 문자가 깨져서 `???`나 이상한 문자로 표시되는 문제가 발생합니다.

### 해결 방법: PowerShell을 이용한 별칭(Alias) 설정

이러한 문제를 해결하기 위해, WSL에서 Windows의 `powershell.exe`를 직접 호출하여 클립보드를 제어합니다. 아래 코드를 `.bashrc` 또는 `.zshrc` 파일 하단에 추가합니다.

```shell
# .zshrc 또는 .bashrc 에 추가
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

터미널에 변경 사항을 적용하려면 `source ~/.bashrc` 또는 `source ~/.zshrc` 명령어를 실행하거나 새 터미널을 엽니다.

### 코드 상세 설명

#### `copy` (WSL -> Windows 클립보드)

`cat test.txt | copy`와 같이 파이프로 입력된 데이터를 Windows 클립보드에 복사합니다.

1.  `sed "s/$/\r/"`: 각 줄의 끝(`$`)에 **CR**(`\r`) 문자를 추가합니다. 이로써 Linux의 **LF**(`\n`)가 Windows의 **CRLF**(`\r\n`)로 변환됩니다.
2.  `powershell.exe ...`: PowerShell 스크립트를 실행합니다.
3.  `$stdin.CopyTo($bytes)`: WSL에서 넘어온 데이터를 깨짐 없이 그대로 바이트 스트림으로 읽습니다.
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: 읽어들인 바이트 스트림을 **명시적으로 UTF-8로 디코딩**하여 텍스트로 변환합니다. 이것이 다국어 문자가 깨지지 않게 하는 핵심입니다.
5.  `Set-Clipboard -Value $text`: 최종적으로 변환된 텍스트를 Windows 클립보드에 저장합니다.

#### `paste` (Windows 클립보드 -> WSL)

Windows 클립보드의 내용을 WSL 터미널로 붙여넣습니다.

1.  `powershell.exe ...`: PowerShell 스크립트를 실행합니다.
2.  `Get-Clipboard -Raw`: Windows 클립보드에서 텍스트 데이터를 가져옵니다.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 가져온 텍스트를 **명시적으로 UTF-8 바이트 스트림으로 인코딩**합니다.
4.  `[Console]::OpenStandardOutput().Write(...)`: 인코딩된 바이트 스트림을 WSL의 표준 출력으로 그대로 전달합니다.
5.  `sed "s/\r$//"`: PowerShell이 출력한 데이터(CRLF)에서 줄 끝의 **CR**(`\r`) 문자를 모두 삭제합니다. 이로써 Windows의 **CRLF**가 Linux의 **LF**로 변환되어 완벽하게 호환됩니다.

### 테스트 방법

아래 스크립트를 실행하여 원본 파일의 내용과, `copy` & `paste`를 거친 후의 내용이 바이트 단위까지 완벽하게 동일한지 확인할 수 있습니다.
테스트를 위해 'sample.txt' 파일이 현재 디렉터리에 있어야 합니다.

```shell
echo "--- 원본 파일(sample.txt)의 바이트 시퀀스 ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- 클립보드(paste)의 바이트 시퀀스 ---"
paste | xxd
echo ""

echo "--- 두 바이트 시퀀스 비교 (diff 결과) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 두 바이트 시퀀스는 완벽하게 동일합니다."
else
    echo "--> ❌ 두 바이트 시퀀스에 차이가 발견되었습니다."
fi
```

### 기대 결과

테스트 스크립트를 실행하면 `diff` 명령어에서 아무런 결과도 출력되지 않아야 하며, 최종적으로 아래와 같은 성공 메시지가 나타나야 합니다. 이는 원본 데이터와 클립보드를 거친 데이터가 100% 일치함을 의미합니다.

```
--- 원본 파일(sample.txt)의 바이트 시퀀스 ---
(xxd 결과 출력)

--- 클립보드(paste)의 바이트 시퀀스 ---
(xxd 결과 출력 - 위와 동일해야 함)

--- 두 바이트 시퀀스 비교 (diff 결과) ---

--> ✅ 두 바이트 시퀀스는 완벽하게 동일합니다.
```