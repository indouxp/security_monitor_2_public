#!/bin/bash
# TC-120: main は POST 失敗時も警告ログのみで正常終了(exit 0)する
source "$(dirname "$0")/testlib.sh"

DESC="POST失敗時も警告ログのみでスクリプトは正常終了する"

# 到達不能な ENDPOINT で実行し、POST 失敗が「警告のみ」で扱われることを確認する。
# （ERRトラップ無効化漏れによる exit 7 バグの回帰防止を兼ねる）
tc_main() {
    setup_mock
    # run_script の既定 ENDPOINT は到達不能URL(即座に接続拒否)
    local rc=0                                                 # スクリプトの終了コード
    run_script || rc=$?
    check_eq "POST失敗でもスクリプトはexit 0で終了する" "$rc" "0"
    log_has "WARN POST failed"
    check "エラーログにPOST失敗の警告が記録される" $?
    check_eq "POST失敗時もローカル履歴は保存される" "$(hist_lines)" "1"
}

run_tc tc_main "$0" "$DESC"
