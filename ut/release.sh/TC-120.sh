#!/bin/bash
# TC-120: 複数行混在時の完了カウント集計（リリース/スキップ/エラー）
source "$(dirname "$0")/testlib.sh"

DESC="複数行混在時の完了カウントが正しく集計される"

# 差分あり・差分なし・ローカル不在を1リストに混在させ、集計が正しいことを確認する
tc_main() {
    setup
    write_local  rel.js "NEW"               # 1行目: 差分あり → Y でリリース
    write_remote /home/tester/rel.js "OLD"
    write_local  skp.js "SAME"              # 2行目: 差分なし → スキップ
    write_remote /home/tester/skp.js "SAME"
    # 3行目: ローカル不在 → エラー
    write_list "${LOCAL}/rel.js /home/tester/rel.js" \
               "${LOCAL}/skp.js /home/tester/skp.js" \
               "${LOCAL}/missing.js /home/tester/missing.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "エラーありで exit 1 する" "$rc" "1"
    out_has "完了: リリース=1件  スキップ=1件  エラー=1件"
    check "集計がリリース1/スキップ1/エラー1である" $?
    check_eq "リリース対象は更新される" "$(remote_content /home/tester/rel.js)" "NEW"
}

run_tc tc_main "$0" "$DESC"
