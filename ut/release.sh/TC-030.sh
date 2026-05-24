#!/bin/bash
# TC-030: 差分あり + S 回答でスキップ（リモートは更新されない）
source "$(dirname "$0")/testlib.sh"

DESC="差分ありでS回答するとスキップされる"

# 差分のあるファイルに S と回答すると、リモートが更新されないことを確認する
tc_main() {
    setup
    write_local  app.js "NEW-VERSION"
    write_remote /home/tester/app.js "OLD-VERSION"
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "S" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    check_eq "リモートは元の内容のままである" "$(remote_content /home/tester/app.js)" "OLD-VERSION"
    out_has "完了: リリース=0件  スキップ=1件  エラー=0件"
    check "集計がスキップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
