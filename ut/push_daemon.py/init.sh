#!/bin/bash
################################################################################
# 概要        : push_daemon.py 単体テストの初期化スクリプト
#               inventory から push_daemon.py をコピーし、試験用に sed 改変する
# Created     : 2026-05-18
# Author      : Tsystem
################################################################################
set -eEuo pipefail

MY_DIR=$(cd "$(dirname "$0")" && pwd)            # ut/push_daemon.py/
readonly MY_DIR
readonly LOG_PATH="${MY_DIR}/init.sh.log"        # ログ（毎回上書き＝直近のみ保持）
exec > >(tee "$LOG_PATH") 2>&1                   # 全出力をログと画面の両方へ

# ---- 設定 ----
readonly SRC="${MY_DIR}/../../inventory/rpi4-1/push_daemon.py"  # コピー元
readonly WORK="${MY_DIR}/work"                   # 作業ディレクトリ
readonly DATA="${WORK}/data"                     # 試験用データ保存先
readonly TEST_PORT=19091                         # 試験用ポート（testlib.py の TEST_PORT と一致させること）

# タイムスタンプ付きでメッセージを出力する
log() { echo "$(date '+%Y%m%d.%H%M%S'): $1"; }

# エラー発生時に行番号を記録する（set -e により直後に異常終了）
trap 'log "ERROR: ${LINENO}行目で失敗しました"' ERR

log "START init.sh"

# コピー元の存在確認
[[ -f "$SRC" ]] || { log "ERROR: コピー元が見つかりません: $SRC"; exit 1; }

# 作業ディレクトリを作り直す
rm -rf "$WORK"
mkdir -p "$DATA"

# 標準コピー: DATA_DIR を試験用パスへ、PORT を試験用ポートへ置換
cp "$SRC" "${WORK}/push_daemon.py"
sed -i -E "s#/var/www/html/data#${DATA}#" "${WORK}/push_daemon.py"
sed -i -E "s/^(PORT[[:space:]]*=[[:space:]]*)9091/\1${TEST_PORT}/" "${WORK}/push_daemon.py"
log "作成: work/push_daemon.py  (DATA_DIR→work/data, PORT→${TEST_PORT})"

# 履歴トリミング試験用の変種: MAX_HISTORY を 5 に縮小
cp "${WORK}/push_daemon.py" "${WORK}/push_daemon_smallhist.py"
sed -i -E "s/^(MAX_HISTORY[[:space:]]*=[[:space:]]*)2880/\15/" "${WORK}/push_daemon_smallhist.py"
log "作成: work/push_daemon_smallhist.py  (MAX_HISTORY→5)"

# 改変結果の確認表示
log "--- 改変箇所の確認 ---"
grep -nE '^(PORT|DATA_DIR|MAX_HISTORY)[[:space:]]*=' \
    "${WORK}/push_daemon.py" "${WORK}/push_daemon_smallhist.py"

log "END init.sh rc: 0"
