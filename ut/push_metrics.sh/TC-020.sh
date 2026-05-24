#!/bin/bash
# TC-020: collect_temp が hwmon センサーも参照し全体の最大値を取得する
source "$(dirname "$0")/testlib.sh"

DESC="hwmonセンサーも参照しthermal_zoneと合わせた最大値を取得する"

# x86 PC 等の hwmon センサーが thermal_zone と共に参照されることを確認する
tc_main() {
    setup_mock
    write_thermal 0 45000       # thermal_zone 45.0℃
    write_hwmon  0 1 62000      # hwmon 62.0℃（こちらが最大）
    run_script
    check_eq "温度がhwmonの62.0である" "$(hist_field temp)" "62.0"
}

run_tc tc_main "$0" "$DESC"
