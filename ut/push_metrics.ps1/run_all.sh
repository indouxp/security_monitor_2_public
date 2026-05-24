#!/bin/bash
################################################################################
# 概要        : push_metrics.ps1 単体テストの一括実行スクリプト
#               init.sh で試験環境を準備し、Pester でテストを実行・集計する。
#               テストは PowerShell 標準フレームワーク Pester で記述する。
# Created     : 2026-05-22
# Author      : Tsystem
################################################################################
set -uo pipefail

MY_DIR=$(cd "$(dirname "$0")" && pwd)            # ut/push_metrics.ps1/
readonly MY_DIR
readonly LOG_PATH="${MY_DIR}/run_all.sh.log"     # ログ（毎回上書き＝直近のみ保持）
exec > >(tee "$LOG_PATH") 2>&1                   # 全出力をログと画面の両方へ

# pwsh の場所（PATH 優先、無ければ snap の既定パス）
PWSH=$(command -v pwsh || echo /snap/bin/pwsh); readonly PWSH

# タイムスタンプ付きでメッセージを出力する
log() { echo "$(date '+%Y%m%d.%H%M%S'): $1"; }

log "START run_all.sh"

# 試験環境の初期化
if ! bash "${MY_DIR}/init.sh"; then
    log "ERROR: init.sh に失敗しました"
    exit 1
fi

# Pester でテストを実行する。
# テストファイルのパスは環境変数で渡し、pwsh コマンドは単一引用で固定する。
log "--- Pester 実行 ---"
SUT_TESTS="${MY_DIR}/push_metrics.Tests.ps1" "$PWSH" -NoProfile -Command '
$cfg = New-PesterConfiguration
$cfg.Run.Path = $env:SUT_TESTS
$cfg.Run.Exit = $true                 # 失敗テスト数を終了コードに反映
$cfg.Output.Verbosity = "Detailed"    # 各テストの結果を1件ずつ表示
Invoke-Pester -Configuration $cfg
'
rc=$?                                  # Pester の終了コード（0=全PASS）

log "========================================"
if (( rc == 0 )); then
    log "集計: 全テスト PASS"
else
    log "集計: 失敗テストあり（Pester 終了コード=${rc}）"
fi
log "END run_all.sh"

(( rc == 0 ))
