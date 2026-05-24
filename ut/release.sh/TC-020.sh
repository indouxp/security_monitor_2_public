#!/bin/bash
# TC-020: 差分あり + Y 回答でリリース（ホームディレクトリ宛は直接 scp）
source "$(dirname "$0")/testlib.sh"

DESC="差分ありでY回答するとリリースされる"

# 差分のあるファイルに Y と回答すると、リモートが更新されることを確認する
tc_main() {
    setup
    write_local  app.js "NEW-VERSION"
    write_remote /home/tester/app.js "OLD-VERSION"
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    check_eq "リモートが新内容で更新される" "$(remote_content /home/tester/app.js)" "NEW-VERSION"
    out_has "完了: リリース=1件  スキップ=0件  エラー=0件"
    check "集計がリリース1件である" $?
    calls_has "sudo mv"
    local has_sudo=$?                                          # sudo mv 呼び出しの有無
    check "ホーム宛は直接 scp され sudo mv は使われない" "$([[ $has_sudo -ne 0 ]]; echo $?)"
}

run_tc tc_main "$0" "$DESC"
