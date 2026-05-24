# playwright — app.js E2E テスト

## 目的

`inventory/rpi4-1/@var@www@html@app.js` の UI 動作を Playwright（Chromium）で自動検証する。  
バックエンドには `test/mock_server2/` を使用する。WebRTC 接続は実カメラ依存のため対象外。

## 構成

```
test/playwright/
├── package.json          @playwright/test 依存定義
├── playwright.config.js  テスト設定（webServer: mock_server2, browser: Chromium）
├── gen_testdata.py       テストデータ生成（test/mock_server2/data/ へ出力）
├── tests/
│   └── app.spec.js       テストケース 8 件
├── .gitignore
└── README.md（本書）
```

## セットアップ（初回のみ）

```bash
cd test/playwright
npm install
```

システムインストールの Google Chrome（`/usr/bin/google-chrome`）を使用するため、
ブラウザの別途ダウンロードは不要。

## 実行

```bash
cd test/playwright
npx playwright test
```

実行時に以下が自動で行われる。

1. `gen_testdata.py` が `test/mock_server2/data/` にテスト用 NDJSON を生成する
2. `test/mock_server2/mock_server.py` が `http://localhost:8080` で起動する
3. Chromium がテストを実行する
4. テスト終了後にサーバーが停止する

## テストケース一覧

| ID | 確認内容 |
|---|---|
| TC-APP-010 | `#clock` に `YYYY-MM-DD HH:MM:SS` 形式の時刻が表示される |
| TC-APP-020 | `#metrics-status` が「正常」になる（NDJSON 取得成功） |
| TC-APP-030 | `chart-cpu/temp/disk/mem` の `<canvas>` 要素が存在する |
| TC-APP-040 | `#panel-metrics` クリックで全画面オーバーレイが開く |
| TC-APP-050 | オーバーレイ余白クリックで全画面オーバーレイが閉じる |
| TC-APP-060 | `#fso-back-btn` クリックで全画面オーバーレイが閉じる |
| TC-APP-070 | 未接続時にカメラパネルをクリックしても `#fullscreen-overlay` が開かない |
| TC-APP-080 | WHEP POST が 404 を返した後にカメラバッジが「切断」になる |

## 注意

- ポート 8080 が使用中の場合はサーバーを停止してから実行すること
- TC-APP-020 は Chart.js CDN（`cdn.jsdelivr.net`）へのアクセスを必要とする
