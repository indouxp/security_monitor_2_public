#!/bin/bash
# TC-080: フィールド不足の行は警告し、エラーとして計上される
source "$(dirname "$0")/testlib.sh"

DESC="フィールド不足の行は警告されエラー計上される"

# release.txt の行にリモートパスが無いとき、警告されエラー扱いとなることを確認する
tc_main() {
    setup
    write_local app.js "CONTENT"
    write_list "${LOCAL}/app.js"            # リモートパスが無い（フィールド不足）

    local rc=0                                                 # release.sh の終了コード
    run_release "" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "エラーありで exit 1 する" "$rc" "1"
    out_has "フィールド不足"
    check "フィールド不足の警告が出力される" $?
    out_has "完了: リリース=0件  スキップ=0件  エラー=1件"
    check "集計がエラー1件である" $?
}

run_tc tc_main "$0" "$DESC"
