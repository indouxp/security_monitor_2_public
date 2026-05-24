#!/bin/bash
# TC-060: リモート未存在（新規）+ S 回答でスキップ
source "$(dirname "$0")/testlib.sh"

DESC="リモート未存在のファイルはS回答でスキップされる"

# 新規リリースの確認に S と回答すると、リモートに作成されないことを確認する
tc_main() {
    setup
    write_local app.js "BRAND-NEW"
    # リモート /home/tester/app.js は作成しない（未存在）
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "S" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    remote_exists /home/tester/app.js
    check "リモートにファイルが作成されない" "$([[ $? -ne 0 ]]; echo $?)"
    out_has "完了: リリース=0件  スキップ=1件  エラー=0件"
    check "集計がスキップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
