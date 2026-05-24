#!/bin/bash
################################################################################
# 概要        : push_metrics.ps1 単体テストの初期化スクリプト
#               pwsh・Pester の存在と試験対象の構文を確認し、
#               作業ディレクトリを作り直す。
# Created     : 2026-05-22
# Author      : Tsystem
################################################################################
set -eEuo pipefail

MY_DIR=$(cd "$(dirname "$0")" && pwd)            # ut/push_metrics.ps1/
readonly MY_DIR
readonly LOG_PATH="${MY_DIR}/init.sh.log"        # ログ（毎回上書き＝直近のみ保持）
exec > >(tee "$LOG_PATH") 2>&1                   # 全出力をログと画面の両方へ

# ---- 設定 ----
readonly SRC="${MY_DIR}/../../inventory/client/win/push_metrics.ps1"  # 試験対象
readonly WORK="${MY_DIR}/work"                   # 作業ディレクトリ

# pwsh の場所（PATH 優先、無ければ snap の既定パス）
PWSH=$(command -v pwsh || echo /snap/bin/pwsh); readonly PWSH

# タイムスタンプ付きでメッセージを出力する
log() { echo "$(date '+%Y%m%d.%H%M%S'): $1"; }

# エラー発生時に行番号を記録する（set -e により直後に異常終了）
trap 'log "ERROR: ${LINENO}行目で失敗しました"' ERR

log "START init.sh"

# 試験対象の存在確認
[[ -f "$SRC" ]] || { log "ERROR: 試験対象が見つかりません: $SRC"; exit 1; }

# pwsh の存在確認
[[ -x "$PWSH" ]] || { log "ERROR: pwsh が見つかりません: $PWSH"; exit 1; }
log "pwsh 確認OK: $("$PWSH" --version)"

# Pester モジュールの存在確認
if ! "$PWSH" -NoProfile -Command \
    'if (-not (Get-Module -ListAvailable Pester)) { exit 1 }'; then
    log "ERROR: Pester モジュールが見つかりません"
    exit 1
fi
log "Pester 確認OK"

# 試験対象の構文チェック（PowerShell パーサで解析）
"$PWSH" -NoProfile -Command "
\$errs = \$null
[void][System.Management.Automation.Language.Parser]::ParseFile('$SRC', [ref]\$null, [ref]\$errs)
if (\$errs.Count -gt 0) { \$errs | ForEach-Object { Write-Error \$_.Message }; exit 1 }
"
log "構文チェックOK: $SRC"

# 作業ディレクトリを作り直す
rm -rf "$WORK"
mkdir -p "$WORK"
log "作業ディレクトリ初期化: $WORK"

log "END init.sh rc: 0"
