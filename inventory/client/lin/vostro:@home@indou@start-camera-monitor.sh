#!/bin/bash
# 防犯カメラモニター起動スクリプト
# Last updated: 2026-06-04
# 更新履歴:
#   2026-05-02: --mute-audio 追加（WebRTC音声がPipeWireに流れてスピーカーから
#               大音量が発生する問題の対策）
#   2026-06-04: --disable-extensions / --disable-component-update 追加
#               （拡張機能の更新画面がキオスク表示中に出る問題の対策）

# スクリーンセーバー・画面オフを無効化
xset s off
xset -dpms
xset s noblank

# Chromeをキオスクモード（フルスクリーン）で起動
# --mute-audio: WebRTC音声をPipeWireに送信しない（PipeWire unmute時の大音量防止）
google-chrome-stable \
    --kiosk \
    --mute-audio \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --no-first-run \
    --start-fullscreen \
    --password-store=basic \
    --disable-extensions \
    --disable-component-update \
    http://rpi4-1.tsystem.gr.jp/

# --disable-extensions:      インストール済み拡張機能を全て無効化し、更新承認画面を抑止
# --disable-component-update: Chrome内蔵コンポーネントの自動更新を抑止（更新由来のポップアップ防止）
