#!/bin/bash
# TC-110: ローカルへの書き込みに失敗した行はエラーとして計上される
source "$(dirname "$0")/testlib.sh"

DESC="ローカル書き込み失敗の行はエラー計上される"

# 親ディレクトリが存在しないローカルパスへの cp は失敗し、エラー扱いとなることを確認する。
# backup.sh 固有の cp 失敗分岐（release.sh には無い）を検証する。
tc_main() {
    setup
    write_remote /home/tester/app.js "NEW-VERSION"
    # ローカルパスの親ディレクトリ nodir は作成しない（cp -p が失敗する）
    write_list "${LOCAL}/nodir/app.js /home/tester/app.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "エラーありで exit 1 する" "$rc" "1"
    out_has "ローカルへの書き込みに失敗しました"
    check "ローカル書き込み失敗のエラーが出力される" $?
    out_has "完了: バックアップ=0件  スキップ=0件  エラー=1件"
    check "集計がエラー1件である" $?
}

run_tc tc_main "$0" "$DESC"
