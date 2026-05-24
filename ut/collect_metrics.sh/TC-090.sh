#!/bin/bash
# TC-090: main が最新値ファイルを毎回上書きし、常に1件のみ保持する
source "$(dirname "$0")/testlib.sh"

DESC="最新値ファイルは毎回上書きされ直近の値のみ保持する"

# 2回実行し、最新値ファイルが直近実行の値で上書きされ1行のみであることを確認する
tc_main() {
    setup_mock
    write_meminfo 4000000 3000000   # 1回目: 使用率 (4000000-3000000)/4000000*100 = 25.0
    run_script
    write_meminfo 4000000 1000000   # 2回目: 使用率 (4000000-1000000)/4000000*100 = 75.0
    run_script
    check_eq "最新値が直近(2回目)の75.0で上書きされる" "$(json_field mem)" "75.0"
    check_eq "最新値ファイルが1行のみである" "$(latest_lines)" "1"
}

run_tc tc_main "$0" "$DESC"
