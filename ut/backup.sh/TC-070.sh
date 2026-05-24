#!/bin/bash
# TC-070: リモートファイルが取得できない行はエラーとして計上される
source "$(dirname "$0")/testlib.sh"

DESC="リモートファイル取得失敗の行はエラー計上される"

# backup.txt が指すリモートファイルが無いとき、取得失敗でエラー扱いとなることを確認する
tc_main() {
    setup
    # リモート /home/tester/app.js は作成しない（未存在 → scp 取得失敗）
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "エラーありで exit 1 する" "$rc" "1"
    out_has "リモートファイルの取得失敗"
    check "リモート取得失敗のエラーが出力される" $?
    out_has "完了: バックアップ=0件  スキップ=0件  エラー=1件"
    check "集計がエラー1件である" $?
}

run_tc tc_main "$0" "$DESC"
