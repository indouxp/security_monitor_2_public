#!/bin/bash
################################################################################
# 概要        : rpi4-1 自身のメトリクス収集スクリプト
#               CPU使用率・CPU温度・DiskI/O・メモリ使用率を収集し、
#               /var/www/html/data/rpi4-1.json（最新値）と
#               /var/www/html/data/rpi4-1-history.ndjson（履歴）に保存する。
#               systemd timer から 30秒間隔で呼び出す想定。
# Created     : 2026-05-09
# Author      : Tsystem
################################################################################
set -eEuo pipefail

readonly MY_NAME="${0##*/}"
MY_DIR=$(cd "$(dirname "$0")" && pwd); readonly MY_DIR

# ---- 設定 ----
DATA_DIR="${DATA_DIR:-/var/www/html/data}"        # JSON 保存先
LATEST_FILE="${DATA_DIR}/rpi4-1.json"             # 最新値ファイル
HISTORY_FILE="${DATA_DIR}/rpi4-1-history.ndjson"  # 履歴ファイル
LOG_FILE="${LOG_FILE:-${HOME:-/home/indo}/log/collect_metrics.log}"  # エラーログ
MAX_HISTORY="${MAX_HISTORY:-2880}"  # 保持最大行数（24時間分）
MAX_LOG=5000      # ログ最大行数

# ---- メトリクス取得元 ----
# 既定は実カーネルの /proc・/sys。単体テストではモックファイルへ差し替える。
# _2 系の既定値は 1回目と同一パスのため、本番では従来通り同一ファイルを2回読む。
PROC_STAT="${PROC_STAT:-/proc/stat}"                     # CPU統計（1回目サンプル）
PROC_STAT_2="${PROC_STAT_2:-$PROC_STAT}"                 # CPU統計（2回目サンプル）
PROC_DISKSTATS="${PROC_DISKSTATS:-/proc/diskstats}"      # ディスク統計（1回目サンプル）
PROC_DISKSTATS_2="${PROC_DISKSTATS_2:-$PROC_DISKSTATS}"  # ディスク統計（2回目サンプル）
PROC_MEMINFO="${PROC_MEMINFO:-/proc/meminfo}"            # メモリ情報
THERMAL_GLOB="${THERMAL_GLOB:-/sys/class/thermal/thermal_zone*/temp}"  # 温度センサー
SAMPLE_DELAY="${SAMPLE_DELAY:-1}"                        # CPU/ディスク2サンプル間の待機秒数

# rpi4-1 は mmcblk（SDカード）または USB ストレージが主
readonly DISK_PAT='^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|vd[a-z]+|hd[a-z]+)$'

# ---- トラップ ----
exit_code=0

on_err() {
    local rc=$? line=$1
    exit_code=$rc
    local cmd; cmd=$(sed -n "${line}p" "$0" 2>/dev/null || true)
    echo "$(date '+%Y%m%d.%H%M%S'): ERROR rc=${rc} line=${line}: ${cmd}" >> "$LOG_FILE" 2>/dev/null || true
}
trap 'on_err ${LINENO}' ERR

on_exit() {
    local rc=$?
    [[ $exit_code -eq 0 ]] && exit_code=$rc
    [[ $exit_code -ne 0 ]] && \
        echo "$(date '+%Y%m%d.%H%M%S'): END rc=${exit_code}" >> "$LOG_FILE" 2>/dev/null || true
    if [[ -f "$LOG_FILE" ]]; then
        local cnt; cnt=$(wc -l < "$LOG_FILE")
        if (( cnt > MAX_LOG )); then
            tail -n "$MAX_LOG" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE" || true
        fi
    fi
    exit "$exit_code"
}
trap 'on_exit' EXIT

# ---- メトリクス収集関数 ----

#-------------------------------------------------------------------------------
# 概要     : CPU使用率(%)とDiskI/O合計(bytes/s)を1秒差分で同時計測する
# 引数     : なし
# 出力     : "cpu_pct disk_rw_bps" を標準出力
#-------------------------------------------------------------------------------
collect_cpu_disk() {
    local s1 d1 s2 d2

    s1=$(grep '^cpu ' "$PROC_STAT")
    d1=$(awk -v pat="$DISK_PAT" \
        '$3 ~ pat && NF>=14 {r+=$6; w+=$10} END {print (r+0)*512, (w+0)*512}' \
        "$PROC_DISKSTATS")

    sleep "$SAMPLE_DELAY"

    s2=$(grep '^cpu ' "$PROC_STAT_2")
    d2=$(awk -v pat="$DISK_PAT" \
        '$3 ~ pat && NF>=14 {r+=$6; w+=$10} END {print (r+0)*512, (w+0)*512}' \
        "$PROC_DISKSTATS_2")

    local cpu_pct
    cpu_pct=$(awk -v s1="$s1" -v s2="$s2" 'BEGIN {
        n1 = split(s1, a); n2 = split(s2, b)
        t1 = 0; t2 = 0
        for (i=2; i<=n1; i++) t1 += a[i]
        for (i=2; i<=n2; i++) t2 += b[i]
        dtotal = t2 - t1
        didle = (b[5]-a[5]) + (b[6]-a[6])
        printf "%.1f", (dtotal > 0) ? (dtotal - didle) / dtotal * 100 : 0
    }')

    local disk_rw
    disk_rw=$(awk -v d1="$d1" -v d2="$d2" 'BEGIN {
        split(d1, a); split(d2, b)
        printf "%d", (b[1]+b[2]) - (a[1]+a[2])
    }')

    echo "$cpu_pct $disk_rw"
}

#-------------------------------------------------------------------------------
# 概要     : CPU温度の最大値を取得する (milli-celsius → celsius)
# 引数     : なし
# 出力     : 温度(℃, 小数点1桁)を標準出力。センサーなし時は "0.0"
#-------------------------------------------------------------------------------
collect_temp() {
    local max_t=0 t
    for f in $THERMAL_GLOB; do
        [[ -r "$f" ]] || continue
        t=$(< "$f")
        (( t > max_t )) && max_t=$t
    done
    awk -v t="$max_t" 'BEGIN { printf "%.1f", t / 1000 }'
}

#-------------------------------------------------------------------------------
# 概要     : メモリ使用率と総メモリ量を取得する
# 引数     : なし
# 出力     : "使用率(%) 総メモリ(KB)" を標準出力
#-------------------------------------------------------------------------------
collect_mem() {
    awk '
        /MemTotal/     { total = $2 }
        /MemAvailable/ { avail = $2 }
        END { printf "%.1f %d\n", (total > 0) ? (total - avail) / total * 100 : 0, total+0 }
    ' "$PROC_MEMINFO"
}

#-------------------------------------------------------------------------------
# 概要     : 主処理。メトリクスを収集してファイルに保存する
# 引数     : なし
#-------------------------------------------------------------------------------
main() {
    mkdir -p "$DATA_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    local cpu_pct disk_rw
    read -r cpu_pct disk_rw < <(collect_cpu_disk)
    local temp_c; temp_c=$(collect_temp)
    local mem_pct mem_total_kb
    read -r mem_pct mem_total_kb < <(collect_mem)

    local hostname ts
    hostname=$(hostname -s)
    ts=$(date -Iseconds)

    local json
    json=$(printf '{"hostname":"%s","ts":"%s","cpu":%s,"temp":%s,"disk_rw":%s,"mem":%s,"mem_total":%s}' \
        "$hostname" "$ts" "$cpu_pct" "$temp_c" "$disk_rw" "$mem_pct" "$mem_total_kb")

    # 最新値ファイルを上書き
    printf '%s\n' "$json" > "$LATEST_FILE"

    # 履歴ファイルに追記
    printf '%s\n' "$json" >> "$HISTORY_FILE"
    local lines; lines=$(wc -l < "$HISTORY_FILE")
    if (( lines > MAX_HISTORY )); then
        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
}

main "$@"
