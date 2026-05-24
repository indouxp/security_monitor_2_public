# CREDITS

本プロジェクトは以下の OSS を利用しています。各 OSS のライセンスは、それぞれの公式リポジトリ／サイトに記載のとおりです。

---

## 同梱コード（CDN／ファイルとして配信）

| OSS | バージョン | ライセンス | 公式 |
|---|---|---|---|
| Chart.js | v4（CDN: jsdelivr.net 経由） | MIT License | https://www.chartjs.org/ |

## サーバー・ミドルウェア（rpi4-1 上で稼働）

| OSS | 用途 | ライセンス | 公式 |
|---|---|---|---|
| MediaMTX | RTSP → WebRTC(WHEP) 中継 | MIT License | https://github.com/bluenviron/mediamtx |
| nginx | WebUI 配信・API プロキシ | BSD 2-Clause License | https://nginx.org/ |
| coturn | STUN／TURN サーバー | BSD 3-Clause License | https://github.com/coturn/coturn |

## テスト・開発依存

| OSS | 用途 | ライセンス | 公式 |
|---|---|---|---|
| Playwright | app.js E2E テスト | Apache License 2.0 | https://playwright.dev/ |
| Pester | PowerShell スクリプト単体テスト | Apache License 2.0 | https://pester.dev/ |
| pytest | Python スクリプト単体テスト | MIT License | https://pytest.org/ |
| expect (Tcl) | bash スクリプト単体テスト（pty 対話） | BSD-style ／ Public Domain | https://core.tcl-lang.org/expect/ |

---

## 注記

- 上記ライセンス名は本ファイル作成時点での情報です。正確な条文・最新の状態は、各 OSS の公式リポジトリ／サイトを参照してください。
- システム標準ツール（bash、Python ランタイム、PowerShell、systemd、OpenSSH 等）の OS 同梱ソフトウェアは本一覧から除外しています。
- 本プロジェクト自体のライセンスは [LICENSE](LICENSE)（MIT License）を参照してください。
