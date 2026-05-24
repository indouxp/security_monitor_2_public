#!/bin/bash
# TC-070: ローカルファイルが存在しない行はエラーとして計上される
source "$(dirname "$0")/testlib.sh"

DESC="ローカルファイル不在の行はエラー計上される"

# release.txt が指すローカルファイルが無いとき、エラー扱いとなることを確認する
tc_main() {
    setup
    # ローカルファイル app.js は作成しない（不在）
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "エラーありで exit 1 する" "$rc" "1"
    out_has "ローカルファイルが存在しません"
    check "ローカル不在のエラーが出力される" $?
    out_has "完了: リリース=0件  スキップ=0件  エラー=1件"
    check "集計がエラー1件である" $?
}

run_tc tc_main "$0" "$DESC"
