#!/bin/bash

# --- 스크립트 설정 ---
set -e # 오류 발생 시 즉시 스크립트 중단

# --- 입력 확인 ---
if [ -z "$1" ]; then
    echo "오류: 입력 파일이 필요합니다."
    echo "사용법: $0 <입력 파일>"
    exit 1
fi

INPUT_FILE="$1"
POWERSHELL_OUTPUT="powershell_bytes.bin"
ICONV_OUTPUT="iconv_bytes.bin"

echo "============================================================"
echo "파일 비교 시작: '$INPUT_FILE'"
echo "============================================================"
echo

# --- 1. PowerShell 프로세스 ---
echo "--- [1/4] PowerShell 프로세스 시작 ---"
echo "입력 파일('$INPUT_FILE')의 내용을 PowerShell을 통해 클립보드에 저장합니다..."
cat "$INPUT_FILE" | powershell.exe -noprofile -command '$stdin = [Console]::OpenStandardInput(); $bytes = [System.IO.MemoryStream]::new(); $stdin.CopyTo($bytes); $text = [System.Text.Encoding]::UTF8.GetString($bytes.ToArray()); $text = $text -replace "`n", "`r`n"; Set-Clipboard -Value $text'
echo "클립보드 저장이 완료되었습니다."
echo

echo "클립보드 내용을 UTF-16LE 바이트로 파일('$POWERSHELL_OUTPUT')에 저장합니다..."
# PowerShell에서 Get-Clipboard 후 유니코드(UTF-16LE)로 바이트를 가져옵니다.
powershell.exe -noprofile -command '$bytes = [System.Text.Encoding]::Unicode.GetBytes((Get-Clipboard -Raw)); [System.IO.File]::WriteAllBytes("'$POWERSHELL_OUTPUT'", $bytes)'
echo "파일 저장이 완료되었습니다."
echo

echo "[$POWERSHELL_OUTPUT] 파일 정보:"
ls -l "$POWERSHELL_OUTPUT"
echo "[$POWERSHELL_OUTPUT] 파일 내용 (Hex Dump):"
hexdump -C "$POWERSHELL_OUTPUT"
echo "--- PowerShell 프로세스 완료 ---"
echo
echo

# --- 2. iconv/unix2dos 프로세스 ---
echo "--- [2/4] iconv/unix2dos 프로세스 시작 ---"
echo "입력 파일('$INPUT_FILE')을 'iconv -f UTF-8 -t UTF-16 | unix2dos'로 변환하여 '$ICONV_OUTPUT'에 저장합니다..."
cat "$INPUT_FILE" | unix2dos | iconv -f UTF-8 -t UTF-16LE > "$ICONV_OUTPUT"
echo "파일 변환 및 저장이 완료되었습니다."
echo

echo "[$ICONV_OUTPUT] 파일 정보:"
ls -l "$ICONV_OUTPUT"
echo "[$ICONV_OUTPUT] 파일 내용 (Hex Dump):"
hexdump -C "$ICONV_OUTPUT"
echo "--- iconv/unix2dos 프로세스 완료 ---"
echo
echo

# --- 3. 결과 비교 ---
echo "--- [3/4] 결과 비교 시작 ---"
if cmp -s "$POWERSHELL_OUTPUT" "$ICONV_OUTPUT"; then
    echo "✅ 성공: 두 바이트열이 완전히 동일합니다."
else
    echo "❌ 실패: 두 바이트열이 다릅니다."
    echo "아래는 두 파일의 차이점입니다 (xxd | diff):"
    echo "------------------------------------------------------------"
    # diff에 색상을 입혀 가독성을 높입니다.
    # 왼쪽이 PowerShell 결과, 오른쪽이 iconv 결과입니다.
    diff --color=always -u <(xxd "$POWERSHELL_OUTPUT") <(xxd "$ICONV_OUTPUT") || true
    echo "------------------------------------------------------------"
fi
echo "--- 결과 비교 완료 ---"
echo
echo

# --- 4. 임시 파일 삭제 ---
echo "--- [4/4] 임시 파일 삭제 ---"
echo "생성된 임시 파일($POWERSHELL_OUTPUT, $ICONV_OUTPUT)을 삭제합니다."
rm "$POWERSHELL_OUTPUT" "$ICONV_OUTPUT"
echo "삭제 완료."
echo
echo "============================================================"
echo "모든 과정이 종료되었습니다."
echo "============================================================"
