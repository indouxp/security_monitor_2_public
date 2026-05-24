#!/bin/bash
# TC-050: リモート未存在（新規）+ Y 回答で新規リリース
source "$(dirname "$0")/testlib.sh"

DESC="リモート未存在のファイルはY回答で新規リリースされる"

# リモートに無いファイルが「新規リリース」として確認され、Y で転送されることを確認する
tc_main() {
    setup
    write_local app.js "BRAND-NEW"
    # リモート /home/tester/app.js は作成しない（未存在）
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    out_has "リモートにファイルが存在しません"
    check "新規リリースとして確認される" $?
    check_eq "リモートに新規ファイルが作成される" "$(remote_content /home/tester/app.js)" "BRAND-NEW"
    out_has "完了: リリース=1件  スキップ=0件  エラー=0件"
    check "集計がリリース1件である" $?
}

run_tc tc_main "$0" "$DESC"
