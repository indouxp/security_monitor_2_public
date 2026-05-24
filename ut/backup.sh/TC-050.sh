#!/bin/bash
# TC-050: ローカル未存在（新規）+ Y 回答で新規バックアップ
source "$(dirname "$0")/testlib.sh"

DESC="ローカル未存在のファイルはY回答で新規バックアップされる"

# ローカルに無いファイルが「新規バックアップ」として確認され、Y で取得されることを確認する
tc_main() {
    setup
    write_remote /home/tester/app.js "BRAND-NEW"
    # ローカル app.js は作成しない（未存在）
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    out_has "ローカルにファイルが存在しません"
    check "新規バックアップとして確認される" $?
    check_eq "ローカルに新規ファイルが作成される" "$(local_content app.js)" "BRAND-NEW"
    out_has "完了: バックアップ=1件  スキップ=0件  エラー=0件"
    check "集計がバックアップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
