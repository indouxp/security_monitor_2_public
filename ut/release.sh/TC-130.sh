#!/bin/bash
# TC-130: 差分あり + D 回答で diff 表示 → 再プロンプト → Y でリリース
source "$(dirname "$0")/testlib.sh"

DESC="差分ありでD回答するとdiff表示後に再度プロンプトが出る"

# 差分のあるファイルに D → Y と回答し、diff が表示された上でリリースされることを確認する
tc_main() {
    setup
    write_local  app.js "NEW-VERSION"
    write_remote /home/tester/app.js "OLD-VERSION"
    write_list "${LOCAL}/app.js /home/tester/app.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "D Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    out_has "S)kip / Y)es / D)iff / C)ancel"
    check "差分時プロンプトに D)iff が含まれる" $?
    out_has "+NEW-VERSION"
    check "diff 出力に +NEW-VERSION が含まれる" $?
    # ハイフン始まりは grep -F のオプションと衝突するため、改行を挟んだ文字列で確認
    grep -q $'\n-OLD-VERSION' "$OUT" 2>/dev/null
    check "diff 出力に -OLD-VERSION が含まれる" $?
    check_eq "リモートが新内容で更新される" "$(remote_content /home/tester/app.js)" "NEW-VERSION"
    out_has "リリースしました。"
    check "リリース成功メッセージが出力される" $?
    out_has "完了: リリース=1件  スキップ=0件  エラー=0件"
    check "集計がリリース1件である" $?
}

run_tc tc_main "$0" "$DESC"
