#!/bin/bash
# TC-100: スラッシュを含まないローカルパスは ./ 付与で解決される
source "$(dirname "$0")/testlib.sh"

DESC="スラッシュ無しローカルパスはカレント基準で解決される"

# release.txt のローカルパスがファイル名のみのとき、./ 付与で解決されることを確認する
tc_main() {
    setup
    write_local  app.js "NEW-VERSION"
    write_remote /home/tester/app.js "OLD-VERSION"
    write_list "app.js /home/tester/app.js"    # スラッシュ無し（ファイル名のみ）

    local rc=0                                                 # release.sh の終了コード
    run_release "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    check_eq "ファイル名のみの指定でもリリースされる" "$(remote_content /home/tester/app.js)" "NEW-VERSION"
    out_has "完了: リリース=1件  スキップ=0件  エラー=0件"
    check "集計がリリース1件である" $?
}

run_tc tc_main "$0" "$DESC"
