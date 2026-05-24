#!/bin/bash
# TC-120: main が ts フィールドに ISO8601 形式の日時を付与する
source "$(dirname "$0")/testlib.sh"

DESC="tsフィールドがISO8601形式の日時である"

# ts フィールドが YYYY-MM-DDThh:mm:ss 形式であることを確認する
tc_main() {
    setup_mock
    run_script
    local ts; ts=$(json_field ts)                              # 出力JSONの ts 値
    [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
    check "tsがISO8601形式である (実際=${ts})" $?
}

run_tc tc_main "$0" "$DESC"
