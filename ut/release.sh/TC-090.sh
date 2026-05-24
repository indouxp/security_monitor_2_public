#!/bin/bash
# TC-090: コメント行・空行は無視され処理対象にならない
source "$(dirname "$0")/testlib.sh"

DESC="コメント行・空行は無視される"

# release.txt のコメント行と空行が処理対象から除外されることを確認する
tc_main() {
    setup
    write_list "# これはコメント行" \
               "" \
               "   # 先頭空白付きコメント"

    local rc=0                                                 # release.sh の終了コード
    run_release "" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    out_has "完了: リリース=0件  スキップ=0件  エラー=0件"
    check "コメント・空行は集計されない" $?
}

run_tc tc_main "$0" "$DESC"
