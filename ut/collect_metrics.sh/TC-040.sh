#!/bin/bash
# TC-040: collect_cpu_disk が2サンプルの差分からCPU使用率を算出する
source "$(dirname "$0")/testlib.sh"

DESC="2サンプルの差分からCPU使用率を算出する"

# /proc/stat の2サンプル差分から CPU 使用率が正しく算出されることを確認する
tc_main() {
    setup_mock
    # 1回目: 全0
    # 2回目: user=100 idle=300 → 総差分=400 アイドル差分=300
    #        → CPU使用率 (400-300)/400*100 = 25.0
    write_stat 1 0 0 0 0 0 0 0 0
    write_stat 2 100 0 0 300 0 0 0 0
    run_script
    check_eq "CPU使用率が25.0である" "$(json_field cpu)" "25.0"
}

run_tc tc_main "$0" "$DESC"
