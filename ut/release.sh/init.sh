#!/bin/bash
################################################################################
# 概要        : release.sh 単体テストの初期化スクリプト
#               試験対象の存在・構文、expect の有無を確認し、
#               フェイクコマンドへ実行権限を付与して作業ディレクトリを作り直す。
#               release.sh は expect で擬似端末を供給するため無改修で試験する。
# Created     : 2026-05-21
# Author      : Tsystem
################################################################################
set -eEuo pipefail

MY_DIR=$(cd "$(dirname "$0")" && pwd)            # ut/release.sh/
readonly MY_DIR
readonly LOG_PATH="${MY_DIR}/init.sh.log"        # ログ（毎回上書き＝直近のみ保持）
exec > >(tee "$LOG_PATH") 2>&1                   # 全出力をログと画面の両方へ

# ---- 設定 ----
readonly SRC="${MY_DIR}/../../inventory/release.sh"  # 試験対象
readonly BIN="${MY_DIR}/bin"                     # フェイク ssh/scp の配置先
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

# 対話入力の自動化に必要な expect の存在確認
command -v expect >/dev/null || { log "ERROR: expect が見つかりません"; exit 1; }
log "expect 確認OK: $(command -v expect)"

# フェイクコマンドへ実行権限を付与する
chmod +x "${BIN}/ssh" "${BIN}/scp"
log "フェイクコマンド実行権限付与: ${BIN}/ssh ${BIN}/scp"

# 作業ディレクトリを作り直す（モック等は各TCが setup で生成する）
rm -rf "$WORK"
mkdir -p "$WORK"
log "作業ディレクトリ初期化: $WORK"

log "END init.sh rc: 0"
