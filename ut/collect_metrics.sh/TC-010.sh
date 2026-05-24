#!/bin/bash
# TC-010: collect_temp が複数 thermal_zone の最大値を milli→℃ 変換して取得する
source "$(dirname "$0")/testlib.sh"

DESC="複数thermal_zoneの最大値をmilli→℃変換して取得する"

# 複数ゾーンのうち最大温度が選ばれ、milli-celsius→celsius 変換されることを確認する
tc_main() {
    setup_mock
    # zone0=42.0℃ zone1=58.0℃ zone2=51.0℃ → 最大 58000 → 58.0
    write_thermal 0 42000
    write_thermal 1 58000
    write_thermal 2 51000
    run_script
    check_eq "温度が最大ゾーンの58.0である" "$(json_field temp)" "58.0"
}

run_tc tc_main "$0" "$DESC"
