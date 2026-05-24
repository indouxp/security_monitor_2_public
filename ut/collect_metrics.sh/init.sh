#!/bin/bash
################################################################################
# 概要        : collect_metrics.sh 単体テストの初期化スクリプト
#               試験対象の存在・構文を確認し、作業ディレクトリを作り直す。
#               collect_metrics.sh は取得元パスが環境変数化済みのため、
#               push_daemon.py 試験のような sed 改変コピーは不要。
# Created     : 2026-05-21
# Author      : Tsystem
################################################################################
set -eEuo pipefail

MY_DIR=$(cd "$(dirname "$0")" && pwd)            # ut/collect_metrics.sh/
readonly MY_DIR
readonly LOG_PATH="${MY_DIR}/init.sh.log"        # ログ（毎回上書き＝直近のみ保持）
exec > >(tee "$LOG_PATH") 2>&1                   # 全出力をログと画面の両方へ

# ---- 設定 ----
readonly SRC="${MY_DIR}/../../inventory/rpi4-1/collect_metrics.sh"  # 試験対象
readonly WORK="${MY_DIR}/work"                   # 作業ディレクトリ

# タイムスタンプ付きでメッセージを出力する
log() { echo "$(date '+%Y%m%d.%H%M%S'): $1"; }

# エラー発生時に行番号を記録する（set -e により直後に異常終了）
trap 'log "ERROR: ${LINENO}行目で失敗しました"' ERR

log "START init.sh"

# 試験対象の存在確認
[[ -f "$SRC" ]] || { log "ERROR: 試験対象が見つかりません: $SRC"; exit 1; }

# 試験対象の構文チェック
bash -n "$SRC"
log "構文チェックOK: $SRC"

# 作業ディレクトリを作り直す（モック・出力は各TCが setup_mock で生成する）
rm -rf "$WORK"
mkdir -p "$WORK"
log "作業ディレクトリ初期化: $WORK"

log "END init.sh rc: 0"
