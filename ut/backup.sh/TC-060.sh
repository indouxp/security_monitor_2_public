#!/bin/bash
# TC-060: ローカル未存在（新規）+ S 回答でスキップ
source "$(dirname "$0")/testlib.sh"

DESC="ローカル未存在のファイルはS回答でスキップされる"

# 新規バックアップの確認に S と回答すると、ローカルに作成されないことを確認する
tc_main() {
    setup
    write_remote /home/tester/app.js "BRAND-NEW"
    # ローカル app.js は作成しない（未存在）
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "S" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    local_exists app.js
    check "ローカルにファイルが作成されない" "$([[ $? -ne 0 ]]; echo $?)"
    out_has "完了: バックアップ=0件  スキップ=1件  エラー=0件"
    check "集計がスキップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
