#!/bin/bash
# TC-100: スラッシュを含まないローカルパスは ./ 付与で解決される
source "$(dirname "$0")/testlib.sh"

DESC="スラッシュ無しローカルパスはカレント基準で解決される"

# backup.txt のローカルパスがファイル名のみのとき、./ 付与で解決されることを確認する
tc_main() {
    setup
    write_remote /home/tester/app.js "NEW-VERSION"
    write_local  app.js "OLD-VERSION"
    write_list "app.js /home/tester/app.js"    # スラッシュ無し（ファイル名のみ）

    local rc=0                                                 # backup.sh の終了コード
    run_backup "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    check_eq "ファイル名のみの指定でもバックアップされる" "$(local_content app.js)" "NEW-VERSION"
    out_has "完了: バックアップ=1件  スキップ=0件  エラー=0件"
    check "集計がバックアップ1件である" $?
}

run_tc tc_main "$0" "$DESC"
