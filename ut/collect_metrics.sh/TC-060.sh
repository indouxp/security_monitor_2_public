#!/bin/bash
# TC-060: collect_cpu_disk が2サンプル同値(差分0)のときCPU使用率0.0を返す
source "$(dirname "$0")/testlib.sh"

DESC="CPU統計の差分が0のとき0除算せず0.0を返す"

# 2サンプルが同値で総差分が0でも、0除算せず 0.0 を返すことを確認する
tc_main() {
    setup_mock
    # 1回目と2回目を同値にする → 総差分=0 → 0除算ガードで 0.0
    write_stat 1 100 0 50 800 50 0 0 0
    write_stat 2 100 0 50 800 50 0 0 0
    run_script
    check_eq "CPU使用率が0.0である" "$(json_field cpu)" "0.0"
}

run_tc tc_main "$0" "$DESC"
