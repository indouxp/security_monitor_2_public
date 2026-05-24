#!/bin/bash
# TC-100: main がローカル履歴を MAX_HISTORY 行に収まるようトリミングする
source "$(dirname "$0")/testlib.sh"

DESC="ローカル履歴がMAX_HISTORY行を超えないようトリミングされる"

# MAX_HISTORY=5 として7回実行し、古い行が削除され5行に収まることを確認する
tc_main() {
    setup_mock
    local i                                                    # 実行回数カウンタ
    for i in 1 2 3 4 5 6 7; do
        run_script MAX_HISTORY=5
    done
    check_eq "7回実行でも履歴がMAX_HISTORY(5)行に収まる" "$(hist_lines)" "5"
}

run_tc tc_main "$0" "$DESC"
