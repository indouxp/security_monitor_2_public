#!/bin/bash
# TC-090: main がローカル履歴ファイルへ実行ごとに7フィールドのJSONを追記する
source "$(dirname "$0")/testlib.sh"

DESC="ローカル履歴に実行ごとに7フィールドのJSONが追記される"

# 3回実行で履歴が3行になり、各レコードが必須7フィールドを含むことを確認する
tc_main() {
    setup_mock
    run_script
    run_script
    run_script
    check_eq "3回実行で履歴が3行になる" "$(hist_lines)" "3"
    local k                                                    # 確認対象のキー名
    for k in hostname ts cpu temp disk_rw mem mem_total; do
        hist_has_key "$k"
        check "履歴レコードに ${k} フィールドが存在する" $?
    done
}

run_tc tc_main "$0" "$DESC"
