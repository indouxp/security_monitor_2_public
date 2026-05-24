#!/bin/bash
# TC-110: main が収集したメトリクスJSONを rpi4-1 へ POST する
source "$(dirname "$0")/testlib.sh"

DESC="収集したメトリクスJSONをエンドポイントへPOSTする"

# モック受信サーバーを起動し、POST されたJSONが収集値と一致することを確認する
tc_main() {
    setup_mock
    write_thermal 0 55000           # 温度 55.0℃
    write_meminfo 8000000 6000000   # メモリ使用率 25.0
    if ! start_recv; then
        check "モック受信サーバーが起動する" 1
        return
    fi
    # ENDPOINT をモック受信サーバーへ向けて実行（既定の到達不能URLを上書き）
    run_script ENDPOINT="http://127.0.0.1:${RECV_PORT}/api/push"
    stop_recv

    check "モック受信サーバーがPOSTボディを受信する" "$([[ -f "$RECV_FILE" ]]; echo $?)"
    local k                                                    # 確認対象のキー名
    for k in hostname ts cpu temp disk_rw mem mem_total; do
        recv_has_key "$k"
        check "受信JSONに ${k} フィールドが存在する" $?
    done
    check_eq "受信JSONの温度が収集値55.0である" "$(recv_field temp)" "55.0"
    check_eq "受信JSONのメモリ使用率が収集値25.0である" "$(recv_field mem)" "25.0"
    check_eq "POST成功時もローカル履歴が1行保存される" "$(hist_lines)" "1"
}

run_tc tc_main "$0" "$DESC"
