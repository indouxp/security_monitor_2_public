#!/bin/bash
# TC-040: 差分あり + C 回答でキャンセル（以降の行は処理されない）
source "$(dirname "$0")/testlib.sh"

DESC="C回答でキャンセルされ後続行は処理されない"

# 1行目に C と回答すると即終了し、2行目が処理されないことを確認する
tc_main() {
    setup
    write_local  one.js "NEW-1"
    write_local  two.js "NEW-2"
    write_remote /home/tester/one.js "OLD-1"
    write_remote /home/tester/two.js "OLD-2"
    write_list "${LOCAL}/one.js /home/tester/one.js" \
               "${LOCAL}/two.js /home/tester/two.js"

    local rc=0                                                 # release.sh の終了コード
    run_release "C" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    out_has "CANCEL"
    check "キャンセルメッセージが出力される" $?
    out_has "[行2]"
    check "2行目が処理されない" "$([[ $? -ne 0 ]]; echo $?)"
    check_eq "2行目のリモートは更新されない" "$(remote_content /home/tester/two.js)" "OLD-2"
}

run_tc tc_main "$0" "$DESC"
