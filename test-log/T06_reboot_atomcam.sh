#!/bin/bash
# =============================================================================
# reboot_atomcam.sh - ATOMCamをSSH経由でリブートする
# Author: claude
# 使い方:
#   スクリプトとして実行: ./reboot_atomcam.sh <IPアドレス>
#     戻り値: 0=リブート指示成功, 1=失敗
#   sourceして関数として呼び出す:
#     source reboot_atomcam.sh
#     reboot_atomcam <IPアドレス>
# Last updated: 2026-04-20 21:55:53
# =============================================================================

# SSHの設定
readonly REBOOT_ATOMCAM_SSH_USER="root"                    # ATOMCamのSSHユーザー
readonly REBOOT_ATOMCAM_SSH_KEY="${HOME}/.ssh/id_ed25519"  # 使用するSSH秘密鍵
readonly REBOOT_ATOMCAM_SSH_TIMEOUT=10                     # SSH接続タイムアウト秒数
readonly REBOOT_ATOMCAM_SSH_PORT=22                        # SSHポート番号

# =============================================================================
# 指定IPアドレスのATOMCamをSSH経由でリブートする
# 引数: $1 - ATOMCamのIPアドレス
# 戻り値: 0=リブート指示成功, 1=失敗
# =============================================================================
reboot_atomcam() {
    local ip="$1"  # リブート対象のATOMCamのIPアドレス

    # IPアドレスの指定確認
    if [[ -z "$ip" ]]; then
        echo "エラー: IPアドレスを指定してください" >&2
        return 1
    fi

    # SSH鍵ファイルの存在確認
    if [[ ! -f "${REBOOT_ATOMCAM_SSH_KEY}" ]]; then
        echo "エラー: SSH鍵ファイルが見つかりません: ${REBOOT_ATOMCAM_SSH_KEY}" >&2
        return 1
    fi

    echo "ATOMCam (IP=${ip}) をリブートします..."

    # SSH経由でrebootコマンドを実行
    ssh \
        -i "${REBOOT_ATOMCAM_SSH_KEY}" \
        -p "${REBOOT_ATOMCAM_SSH_PORT}" \
        -o ConnectTimeout="${REBOOT_ATOMCAM_SSH_TIMEOUT}" \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        "${REBOOT_ATOMCAM_SSH_USER}@${ip}" \
        "reboot" 2>/dev/null

    # SSH終了コードの確認（rebootコマンドはSSH切断を引き起こすため255も正常）
    local ssh_exit=$?
    if [[ $ssh_exit -eq 0 ]] || [[ $ssh_exit -eq 255 ]]; then
        echo "リブート指示成功: IP=${ip}"
        return 0
    else
        echo "エラー: SSH接続に失敗しました (IP=${ip}, exit=${ssh_exit})" >&2
        return 1
    fi
}

# =============================================================================
# スクリプトとして直接実行された場合のエントリーポイント
# =============================================================================
# sourceされた場合は実行しない
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "$1" ]]; then
        echo "使い方: $0 <IPアドレス>" >&2
        echo "例: $0 192.168.0.12" >&2
        exit 1
    fi
    reboot_atomcam "$1"
    exit $?
fi
