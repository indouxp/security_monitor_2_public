#!/bin/bash
# TC-070: collect_cpu_disk が DISK_PAT に合致しないデバイスを集計除外する
source "$(dirname "$0")/testlib.sh"

DESC="DISK_PATに合致しないデバイスをDiskI/O集計から除外する"

# sda・nvme0n1 は集計対象、loop0 は対象外であることを確認する
tc_main() {
    setup_mock
    # 1回目: sda 0/0, nvme0n1 0/0, loop0 5000/5000(対象外なので無視されるべき)
    write_diskstat 1 sda     0 0
    add_diskstat   1 nvme0n1 0 0
    add_diskstat   1 loop0   5000 5000
    # 2回目: sda 10/0, nvme0n1 0/20, loop0 0/0
    write_diskstat 2 sda     10 0
    add_diskstat   2 nvme0n1 0 20
    add_diskstat   2 loop0   0 0
    run_script
    # 対象デバイスのみ差分 = (10+0+0+20)*512 - 0 = 15360
    # loop0 を誤って含めると 1回目が大きくなり負値になる
    check_eq "DiskI/O量が対象デバイスのみの15360である" "$(json_field disk_rw)" "15360"
}

run_tc tc_main "$0" "$DESC"
