#!/bin/bash
# TC-080: main が必須7フィールドを含むJSONを生成する
source "$(dirname "$0")/testlib.sh"

DESC="最新値JSONが必須7フィールドを含む"

# 出力JSONに hostname/ts/cpu/temp/disk_rw/mem/mem_total が揃うことを確認する
tc_main() {
    setup_mock
    run_script
    local k                                                    # 確認対象のキー名
    for k in hostname ts cpu temp disk_rw mem mem_total; do
        json_has_key "$k"
        check "JSONに ${k} フィールドが存在する" $?
    done
}

run_tc tc_main "$0" "$DESC"
