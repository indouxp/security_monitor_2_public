#!/bin/bash
# TC-120: 複数行混在時の完了カウント集計（バックアップ/スキップ/エラー）
source "$(dirname "$0")/testlib.sh"

DESC="複数行混在時の完了カウントが正しく集計される"

# 差分あり・差分なし・リモート取得失敗を1リストに混在させ、集計が正しいことを確認する
tc_main() {
    setup
    write_remote /home/tester/rel.js "NEW"  # 1行目: 差分あり → Y でバックアップ
    write_local  rel.js "OLD"
    write_remote /home/tester/skp.js "SAME" # 2行目: 差分なし → スキップ
    write_local  skp.js "SAME"
    # 3行目: リモート未存在 → 取得失敗エラー
    write_list "${LOCAL}/rel.js /home/tester/rel.js" \
               "${LOCAL}/skp.js /home/tester/skp.js" \
               "${LOCAL}/missing.js /home/tester/missing.js"

    local rc=0                                                 # backup.sh の終了コード
    run_backup "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "エラーありで exit 1 する" "$rc" "1"
    out_has "完了: バックアップ=1件  スキップ=1件  エラー=1件"
    check "集計がバックアップ1/スキップ1/エラー1である" $?
    check_eq "バックアップ対象は更新される" "$(local_content rel.js)" "NEW"
}

run_tc tc_main "$0" "$DESC"
