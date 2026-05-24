#!/bin/bash
# TC-050: collect_cpu_disk が2サンプルの差分からDiskI/O量を算出する
source "$(dirname "$0")/testlib.sh"

DESC="2サンプルの差分からDiskI/O量を算出する"

# /proc/diskstats の2サンプル差分から DiskI/O 量(bytes)が算出されることを確認する
tc_main() {
    setup_mock
    # 1回目: sda 読0/書0  2回目: sda 読100/書100(セクタ)
    # DiskI/O = (100+100)*512 - (0+0)*512 = 102400 bytes
    write_diskstat 1 sda 0 0
    write_diskstat 2 sda 100 100
    run_script
    check_eq "DiskI/O量が102400である" "$(json_field disk_rw)" "102400"
}

run_tc tc_main "$0" "$DESC"
