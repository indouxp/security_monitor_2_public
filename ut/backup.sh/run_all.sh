#!/bin/bash
################################################################################
# 概要        : backup.sh 単体テストの一括実行スクリプト
#               init.sh で試験環境を準備し、全 TC-*.sh を実行して結果を集計する
# Created     : 2026-05-22
# Author      : Tsystem
################################################################################
set -uo pipefail

MY_DIR=$(cd "$(dirname "$0")" && pwd)            # ut/backup.sh/
readonly MY_DIR
readonly LOG_PATH="${MY_DIR}/run_all.sh.log"     # ログ（毎回上書き＝直近のみ保持）
exec > >(tee "$LOG_PATH") 2>&1                   # 全出力をログと画面の両方へ

# タイムスタンプ付きでメッセージを出力する
log() { echo "$(date '+%Y%m%d.%H%M%S'): $1"; }

log "START run_all.sh"

# 試験環境の初期化
if ! bash "${MY_DIR}/init.sh"; then
    log "ERROR: init.sh に失敗しました"
    exit 1
fi

pass=0                                            # 成功した TC 数
fail=0                                            # 失敗した TC 数
fail_list=()                                      # 失敗した TC 名

# TC-*.sh を昇順に実行する
for tc in "${MY_DIR}"/TC-*.sh; do
    [[ -e "$tc" ]] || continue
    name=$(basename "$tc")
    log "--- 実行: ${name} ---"
    if bash "$tc"; then
        log "${name}: PASS"
        pass=$((pass + 1))
    else
        log "${name}: FAIL"
        fail=$((fail + 1))
        fail_list+=("$name")
    fi
done

log "========================================"
log "集計: TC成功=${pass}件  TC失敗=${fail}件"
(( fail > 0 )) && log "失敗TC: ${fail_list[*]}"
log "END run_all.sh"

# 1件でも失敗があれば 0 以外で終了する
(( fail == 0 ))
