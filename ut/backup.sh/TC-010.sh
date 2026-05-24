#!/bin/bash
# TC-010: リモートとローカルに差分が無い場合はスキップする
source "$(dirname "$0")/testlib.sh"

DESC="差分なしのファイルはスキップされる"

# リモートとローカルが同一内容のとき、確認なしでスキップされることを確認する
tc_main() {
    setup
    write_remote /home/tester/app.js "SAME-CONTENT"
    write_local  app.js "SAME-CONTENT"
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    out_has "差分なし"
    check "差分なしと判定され出力される" $?
    out_has "完了: バックアップ=0件  スキップ=1件  エラー=0件"
    check "集計がスキップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
