#!/bin/bash
# TC-020: 差分あり + Y 回答でバックアップ（リモート → ローカル）
source "$(dirname "$0")/testlib.sh"

DESC="差分ありでY回答するとバックアップされる"

# 差分のあるファイルに Y と回答すると、ローカルがリモート内容で更新されることを確認する
tc_main() {
    setup
    write_remote /home/tester/app.js "NEW-VERSION"
    write_local  app.js "OLD-VERSION"
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    check_eq "ローカルがリモート内容で更新される" "$(local_content app.js)" "NEW-VERSION"
    out_has "完了: バックアップ=1件  スキップ=0件  エラー=0件"
    check "集計がバックアップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
