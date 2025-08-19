[ENGLISH](README.md)
[CHINA](README-zh.md)
[KOREAN](README-ko.md)
[JAPAN](README-ja.md)

### 개요

이 문서는 WSL(Windows Subsystem for Linux) 환경에서 macOS의 `pbcopy` 및 `pbpaste`와 완벽하게 동일한 클립보드 기능을 구현하기 위해 `copy`와 `paste` alias(별칭)를 설정하는 방법을 설명합니다.

WSL의 클립보드 문제를 해결하려는 기존의 많은 프로젝트와 글이 있지만, 대부분 다음과 같은 한계가 있습니다.

1.  **부실한 다국어 지원**: `clip.exe`를 단순히 직접 사용하는 방법은 인코딩 문제로 인해 다국어 환경에서 문자가 깨지기 쉽습니다.
2.  **불필요한 프로그램 설치**: 별도의 프로그램을 설치해야 하는 해결책은 너무 무겁습니다. 이 가이드는 간단한 alias 설정만으로 문제를 해결합니다.
3.  **불완전한 통합**: Windows 클립보드와 완벽하게 통합되지 않아, 클립보드 히스토리(`Win + V`)에 내용이 제대로 나타나지 않는 경우가 많습니다.
4.  **Windows 기본 텍스트 처리 방식 유지**: 시스템 기본 설정을 변경할 때 발생할 수 있는 다른 소프트웨어의 텍스트 깨짐 현상 없이, Windows의 네이티브 텍스트 처리 방식을 그대로 사용합니다.

이 가이드에서 제시하는 방법은 PowerShell의 저수준 I/O 기능을 활용하여 인코딩과 개행 문자 문제를 근본적으로 해결합니다. 처음에는 한국어, 일본어, 중국어 환경의 `CP949` 인코딩을 처리하기 위해 `iconv`를 사용하는 접근 방식을 고려했으나, 이모지나 태국어와 같은 특정 문자 집합이 깨지는 문제가 발견되었습니다.

따라서 이 방법은 완벽한 해결책을 제공하기 위해 다음 원칙에 따라 작동합니다.

*   **COPY**: WSL에서 파이프로 입력된 데이터를 텍스트가 아닌 순수한 **바이트 스트림**으로 처리합니다. 이 바이트 스트림을 **명시적으로 UTF-8**로 해석하여 유니코드 문자열로 변환한 뒤, Windows 클립보드에 저장합니다.
*   **PASTE**: Windows 클립보드에서 유니코드 텍스트를 가져와 **UTF-8 바이트 스트림**으로 변환한 후, WSL에 직접 출력합니다. 이 과정은 Windows 콘솔이 텍스트를 잘못 해석하여 인코딩을 변경하는 것을 방지합니다.

### 문제점: WSL과 Windows 클립보드 간의 비호환성

Windows와 Linux(WSL)는 텍스트 데이터를 처리하는 방식에 두 가지 큰 차이가 있으며, 이로 인해 단순한 클립보드 연동 시 데이터 손상이 발생할 수 있습니다.

1.  **개행 문자(Newline)의 차이**:
    *   **Windows**: 한 줄의 끝을 **CRLF**(`\r\n`, Carriage Return + Line Feed)로 표시합니다.
    *   **Linux/macOS**: **LF**(`\n`, Line Feed)만 사용합니다.
    *   이 차이 때문에 WSL에서 Windows로 또는 그 반대로 텍스트를 복사할 때 줄 바꿈이 깨지거나, `^M`과 같은 불필요한 문자가 삽입될 수 있습니다.

2.  **인코딩의 차이**:
    *   WSL 터미널 환경은 대부분 기본적으로 **UTF-8** 인코딩을 사용합니다.
    *   그러나 데이터가 명시적인 인코딩 없이 파이프라인을 통해 PowerShell로 전달되면, 시스템의 기본 인코딩(예: `cp949`)으로 잘못 해석될 수 있습니다.
    *   이로 인해 한글, 일본어, 이모티콘과 같은 멀티바이트 문자가 깨져서 `???`나 다른 이상한 문자로 표시됩니다.

### 해결책: PowerShell을 이용한 Alias 설정

이러한 문제들을 해결하기 위해, WSL에서 Windows의 `powershell.exe`를 직접 호출하여 클립보드를 제어합니다.

#### 빠른 설치 (권장)

사용 중인 셸을 감지하여 자동으로 alias를 추가해주는 자동 설치 스크립트를 사용하세요:

ubuntu ...
```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | bash
```

debian ...
```shell
curl -sSL https://raw.githubusercontent.com/shinnyeonki/wsl-copy-paste/master/install.sh | zsh
```

또는 이 저장소를 클론했다면:

```shell
./install.sh
```

#### 수동 설치

또는, `.bashrc` 또는 `.zshrc` 파일의 맨 아래에 다음 코드를 직접 추가할 수 있습니다:

```shell
# .zshrc 또는 .bashrc 파일에 추가
alias copy='sed "s/$/\r/" | powershell.exe -noprofile -command "\$stdin = [Console]::OpenStandardInput(); \$bytes = [System.IO.MemoryStream]::new(); \$stdin.CopyTo(\$bytes); \$text = [System.Text.Encoding]::UTF8.GetString(\$bytes.ToArray()); Set-Clipboard -Value \$text"'
alias paste='powershell.exe -noprofile -command "\$text = Get-Clipboard -Raw; \$bytes = [System.Text.Encoding]::UTF8.GetBytes(\$text); [Console]::OpenStandardOutput().Write(\$bytes, 0, \$bytes.Length)" | sed "s/\r$//"'
```

터미널에 변경 사항을 적용하려면 `source ~/.bashrc` 또는 `source ~/.zshrc`를 실행하거나, 새 터미널을 열면 됩니다.

### 코드 상세 설명

#### `copy` (WSL -> Windows 클립보드)

`cat test.txt | copy`와 같이 파이프로 입력된 데이터를 Windows 클립보드로 복사합니다.

1.  `sed "s/$/\r/"`: 각 줄의 끝(`$`)에 **CR**(`\r`) 문자를 추가합니다. 이를 통해 Linux의 **LF**(`\n`)를 Windows의 **CRLF**(`\r\n`)로 변환합니다.
2.  `powershell.exe ...`: PowerShell 스크립트를 실행합니다.
3.  `$stdin.CopyTo($bytes)`: WSL로부터 받은 데이터를 손상 없이 바이트 스트림으로 읽어들입니다.
4.  `[System.Text.Encoding]::UTF8.GetString(...)`: 읽어들인 바이트 스트림을 **명시적으로 UTF-8**로 디코딩하여 텍스트로 변환합니다. 이것이 다국어 문자가 깨지지 않게 하는 핵심입니다.
5.  `Set-Clipboard -Value $text`: 최종 변환된 텍스트를 Windows 클립보드에 저장합니다.

#### `paste` (Windows 클립보드 -> WSL)

Windows 클립보드의 내용을 WSL 터미널로 붙여넣습니다.

1.  `powershell.exe ...`: PowerShell 스크립트를 실행합니다.
2.  `Get-Clipboard -Raw`: Windows 클립보드에서 텍스트 데이터를 가져옵니다.
3.  `[System.Text.Encoding]::UTF8.GetBytes($text)`: 가져온 텍스트를 **명시적으로 UTF-8 바이트 스트림**으로 인코딩합니다.
4.  `[Console]::OpenStandardOutput().Write(...)`: 인코딩된 바이트 스트림을 WSL의 표준 출력으로 직접 씁니다.
5.  `sed "s/\r$//"`: PowerShell이 출력한 데이터의 각 줄 끝에 있는 **CR**(`\r`) 문자를 제거합니다. 이를 통해 Windows의 **CRLF**를 Linux의 **LF**로 변환하여 완벽한 호환성을 보장합니다.

### 테스트 방법

아래 스크립트를 실행하여 원본 파일의 내용과 `copy` & `paste`를 거친 후의 내용이 바이트 수준까지 완벽하게 동일한지 확인할 수 있습니다.
테스트를 위해서는 현재 디렉터리에 'sample.txt'라는 파일이 있어야 합니다.

```shell
echo "--- 원본 파일(sample.txt)의 바이트 시퀀스 ---"
cat sample.txt | xxd
echo ""

cat sample.txt | copy

echo "--- 클립보드(paste)로부터 얻은 바이트 시퀀스 ---"
paste | xxd
echo ""

echo "--- 두 바이트 시퀀스 비교 (diff 결과) ---"
diff <(cat sample.txt | xxd) <(paste | xxd)

if [ $? -eq 0 ]; then
    echo "--> ✅ 두 바이트 시퀀스가 완벽하게 일치합니다."
else
    echo "--> ❌ 두 바이트 시퀀스 간에 차이가 발견되었습니다."
fi
```

### 예상 결과

테스트 스크립트를 실행했을 때, `diff` 명령어는 아무런 출력을 내지 않아야 하며, 마지막에 다음과 같은 성공 메시지가 보여야 합니다. 이는 원본 데이터와 클립보드를 거친 데이터가 100% 동일하다는 것을 의미합니다.

```
--- 원본 파일(sample.txt)의 바이트 시퀀스 ---
(xxd 출력이 여기에 나타남)

--- 클립보드(paste)로부터 얻은 바이트 시퀀스 ---
(xxd 출력이 여기에 나타남 - 위와 동일해야 함)

--- 두 바이트 시퀀스 비교 (diff 결과) ---

--> ✅ 두 바이트 시퀀스가 완벽하게 일치합니다.
```