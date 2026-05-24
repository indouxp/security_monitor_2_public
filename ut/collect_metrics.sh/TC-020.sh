#!/bin/bash
# TC-020: collect_temp が温度センサー無しの環境で 0.0 を返す
source "$(dirname "$0")/testlib.sh"

DESC="温度センサーが無い場合は0.0を返す"

# thermal_zone が1つも存在しないとき 0.0 にフォールバックすることを確認する
tc_main() {
    setup_mock
    clear_thermal               # 温度センサーモックを全削除
    run_script
    check_eq "温度が0.0である" "$(json_field temp)" "0.0"
}

run_tc tc_main "$0" "$DESC"
