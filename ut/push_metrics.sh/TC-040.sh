#!/bin/bash
# TC-040: collect_mem が MemTotal/MemAvailable から使用率と総メモリ量を算出する
source "$(dirname "$0")/testlib.sh"

DESC="メモリ使用率と総メモリ量をmeminfoから算出する"

# meminfo の MemTotal・MemAvailable から使用率(%)と総量(KB)が算出されることを確認する
tc_main() {
    setup_mock
    # 総8000000KB / 利用可能6000000KB → 使用率 (8000000-6000000)/8000000*100 = 25.0
    write_meminfo 8000000 6000000
    run_script
    check_eq "メモリ使用率が25.0である" "$(hist_field mem)" "25.0"
    check_eq "総メモリ量が8000000である" "$(hist_field mem_total)" "8000000"
}

run_tc tc_main "$0" "$DESC"
