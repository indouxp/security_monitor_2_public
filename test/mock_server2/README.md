# mock_server2 — 対話注入グラフ検証

## 目的

`test/mock_server/`（sin 波で 60 件を一括生成）とは別に、**Enter 毎に 1 レコードずつ
手で値を入力**して NDJSON へ追記し、Panel 4 のグラフが 1 点ずつ伸びる様子を確認する。

引数で対象グラフを 1 つ選び、そのグラフ単独で挙動をテストできる。

## 構成

```
test/mock_server2/
├── mock_server.py   配信サーバー（test/mock_server/ からのコピー・内容同一）
├── gen_ndjson.py    対話注入ツール（本ディレクトリ独自）
├── README.md        本書
└── data/            gen_ndjson.py 実行時に生成（Git 管理外）
    ├── self_history.ndjson   注入したレコードの追記先（vostro 線）
    └── rpi4_history.ndjson   起動時に空化（rpi4-1 線は出さない）
```

## 起動手順

`gen_ndjson.py` が `data/` を作成・クリアするため、**先に `gen_ndjson.py` を起動**する。

```bash
# ターミナル2: 対話注入ツール（先に起動。data/ を生成しクリア）
cd test/mock_server2
python3 gen_ndjson.py N        # N: 1=cpu 2=temp 3=disk_rw 4=mem

# ターミナル1: 配信サーバー
cd test/mock_server2
python3 mock_server.py         # Ctrl+C で停止
```

ブラウザで `http://localhost:8080` を開き、ターミナル2でレコードを注入するたびに
対象グラフが伸びることを確認する。

## 引数 N と対象グラフ

| N | フィールド | グラフ（Panel 4） | 値の型 |
|---|---|---|---|
| 1 | `cpu`     | CPU使用率（左上） | float |
| 2 | `temp`    | CPU温度           | float |
| 3 | `disk_rw` | ディスクIO        | int   |
| 4 | `mem`     | メモリ使用率      | float |

引数なし・1〜4 以外は使い方を表示して終了コード 1 で終了する。

## 操作

`gen_ndjson.py` 起動後、1 レコードにつき 2 項目を対話入力する。

| 入力項目 | 既定値 | 操作 |
|---|---|---|
| 日時 | 初回=現在時刻、以降=前回の日時+30秒 | Enter で既定値、入力でその値。形式不正は再入力 |
| 値   | 初回=`0`、以降=前回の値 | Enter で既定値、入力でその値。数値以外は再入力 |

選択したフィールドのみ入力値を持ち、他 3 フィールドは `0` で固定される。
入力した 1 レコードは即座に `data/self_history.ndjson` へ追記される。

`Ctrl+D` で正常終了（終了コード 0）、`Ctrl+C` で中断（終了コード 1）。

## 注入されるレコード

```json
{"hostname": "vostro", "cpu": 45.5, "temp": 0, "disk_rw": 0, "mem": 0, "mem_total": 17179869184, "ts": "2026-05-19T22:30:05"}
```

`hostname` は `vostro`、`mem_total` は 16GB 固定。上記は `gen_ndjson.py 1` で
`cpu` に 45.5 を入力した例。

## ログ

実行ごとの全出力（プロンプト・追記内容・例外）を `gen_ndjson.py.log` へ
毎回上書き記録する（直近の実行分のみ保持）。
