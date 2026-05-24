# モックサーバー E2E テスト手順

## 目的

実機（rpi4-1）なしで、Chrome からリソースモニター（Panel 4）のグラフ描画を確認する。

## 起動

```bash
cd test/mock_server
python3 gen_ndjson.py   # NDJSON データ生成（初回のみ。再生成で最新時刻に更新）
python3 mock_server.py  # Ctrl+C で停止
```

Chrome で `http://localhost:8080` を開く。

---

## 確認項目

### Panel 4（リソースモニター）グラフ

| # | 確認内容 | 期待値 |
|---|---|---|
| 1 | メトリクスステータスバッジ | **正常**（緑） |
| 2 | CPU グラフ | vostro が山型、rpi4-1 が位相ずれの山型で 2 本線 |
| 3 | temp グラフ | CPU に連動した山型 2 本線 |
| 4 | Disk I/O グラフ | 鋸歯状スパイクが見える |
| 5 | メモリグラフ | vostro 40→70%、rpi4-1 30→60% の直線上昇 |
| 6 | 凡例 | `vostro (16GB)` と `rpi4-1 (4GB)` が表示 |
| 7 | X 軸 | HH:MM 形式で 5 分刻みの目盛り |

### カメラパネル（想定動作）

| # | 確認内容 | 期待値 |
|---|---|---|
| 8 | カメラ 3 パネルのバッジ | **切断**（赤）— WebRTC サーバーがないため正常 |

---

## DevTools での確認

**Network タブ**

| リクエスト | 期待ステータス |
|---|---|
| `/api/my-history` | 200 |
| `/data/rpi4-1-history.ndjson` | 200 |

**Console タブ**

- `[metrics] fetch error` が出ないこと
- カメラの `接続エラー` ログは許容（WebRTC なし）

---

## データ仕様

`gen_ndjson.py` が生成する NDJSON のパターン。

| フィールド | vostro | rpi4-1 |
|---|---|---|
| hostname | `vostro` | `rpi4-1` |
| mem_total | 16 GB | 4 GB |
| 件数 | 60 件（過去 30 分分） | 60 件 |
| cpu | 山型 sin カーブ（20→80→20%） | 位相 π/2 ずれの山型 |
| temp | 45 + cpu × 0.3 ℃ | 同上（位相ずれ） |
| disk_rw | 10 件ごと 0→512 KB/s 鋸歯状 | 位相ずれ鋸歯状 |
| mem | 40→70%（直線） | 30→60%（直線） |

`gen_ndjson.py` を再実行するとタイムスタンプが現在時刻に更新される。

---

## エンドポイント一覧

| URL | 処理 |
|---|---|
| `GET /` | index.html |
| `GET /style.css` | style.css |
| `GET /app.js` | app.js |
| `GET /api/my-history` | `data/self_history.ndjson` |
| `GET /data/rpi4-1-history.ndjson` | `data/rpi4_history.ndjson` |
| その他 | 404 |
