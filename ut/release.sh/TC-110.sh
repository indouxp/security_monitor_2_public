#!/bin/bash
# TC-110: 非ホームディレクトリ宛は リモート /tmp 経由 sudo mv で転送する
source "$(dirname "$0")/testlib.sh"

DESC="非ホーム宛はリモート/tmp経由sudo mvで転送される"

# /home 以外のリモートパスは mkdir -p → scp → sudo mv の経路を通ることを確認する
tc_main() {
    setup
    write_local  nginx.conf "NEW-CONF"
    write_remote /etc/nginx/nginx.conf "OLD-CONF"
    write_list "${LOCAL}/nginx.conf /etc/nginx/nginx.conf"

    local rc=0                                                 # release.sh の終了コード
    run_release "Y" -c "$LIST" "tester@mockhost" || rc=$?

    check_eq "exit 0 で終了する" "$rc" "0"
    calls_has "ssh .* mkdir -p"
    check "リモート一時ディレクトリ作成(ssh mkdir -p)が呼ばれる" $?
    calls_has "ssh .* sudo mv"
    check "sudo mv による正式パスへの移動が呼ばれる" $?
    check_eq "非ホーム宛のリモートが更新される" "$(remote_content /etc/nginx/nginx.conf)" "NEW-CONF"
}

run_tc tc_main "$0" "$DESC"
