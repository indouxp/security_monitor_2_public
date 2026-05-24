#!/bin/bash
# TC-100: main が履歴ファイルへ実行ごとに追記する
source "$(dirname "$0")/testlib.sh"

DESC="履歴ファイルに実行ごとに1行追記される"

# 3回実行し、履歴ファイルが追記方式で3行になることを確認する
tc_main() {
    setup_mock
    run_script
    run_script
    run_script
    check_eq "3回実行で履歴が3行になる" "$(history_lines)" "3"
}

run_tc tc_main "$0" "$DESC"
