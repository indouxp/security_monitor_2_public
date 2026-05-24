#!/usr/bin/env python3
"""gen_ndjson.py - 既知パターンの NDJSON テストデータを生成する

実行:
    cd test/mock_server
    python3 gen_ndjson.py

出力:
    data/self_history.ndjson  - 自クライアント（vostro）用
    data/rpi4_history.ndjson  - rpi4-1 用
"""

import json
import math
import pathlib
from datetime import datetime, timezone, timedelta

# ---- 出力先 ----
DATA_DIR = pathlib.Path(__file__).parent / 'data'

# ---- 生成パラメーター ----
RECORDS    = 60                    # 件数（30分 ÷ 30秒）
INTERVAL   = 30                    # 収集間隔（秒）

# self (vostro) スペック
SELF_HOST     = 'vostro'
SELF_MEM_TOTAL = 16 * 1024 * 1024 * 1024   # 16 GB in bytes

# rpi4-1 スペック
RPI4_HOST     = 'rpi4-1'
RPI4_MEM_TOTAL = 4 * 1024 * 1024 * 1024    # 4 GB in bytes


def gen_records(hostname: str, mem_total: int, phase_offset: float) -> list[dict]:
    """指定ホストの NDJSON レコードリストを生成する

    phase_offset: self と rpi4-1 のグラフを視覚的に区別するための位相ずらし（ラジアン）
    """
    now = datetime.now(timezone.utc).replace(microsecond=0)
    # 最古レコードの開始時刻（RECORDS件 × INTERVAL秒 前）
    start = now - timedelta(seconds=INTERVAL * (RECORDS - 1))

    records = []
    for i in range(RECORDS):
        ts = start + timedelta(seconds=INTERVAL * i)

        # 正規化された進行度 0.0 〜 1.0
        t = i / (RECORDS - 1)

        # CPU: 山型（sin カーブ）。self と rpi4-1 で位相をずらす
        cpu = 20 + 60 * math.sin(math.pi * t + phase_offset) ** 2
        cpu = round(max(5.0, min(99.0, cpu)), 1)

        # temp: CPU に連動
        temp = round(45 + cpu * 0.3, 1)

        # disk_rw: 10件ごとにスパイクする鋸歯状（bytes/s）
        # i % 10 で 0→9 を繰り返す、phase_offset で self/rpi4 をずらす
        sawtooth = ((i + int(phase_offset * 10 / math.pi)) % 10) / 9
        disk_rw  = int(512000 * sawtooth)

        # mem: 緩やかに直線上昇（self: 40→70、rpi4: 30→60）
        mem_base = 40 - 10 * (phase_offset > 0)   # rpi4 は 10% 低め
        mem = round(mem_base + 30 * t, 1)
        mem = max(10.0, min(95.0, mem))

        records.append({
            'hostname': hostname,
            'cpu':      cpu,
            'temp':     temp,
            'disk_rw':  disk_rw,
            'mem':      mem,
            'mem_total': mem_total,
            'ts':       ts.strftime('%Y-%m-%dT%H:%M:%S'),
        })

    return records


def write_ndjson(path: pathlib.Path, records: list[dict]) -> None:
    """レコードリストを NDJSON ファイルへ書き込む"""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
    print(f'written {len(records)} records -> {path}')


def main():
    # self (位相 0): 山型の頂点が中央
    self_records = gen_records(SELF_HOST, SELF_MEM_TOTAL, phase_offset=0.0)
    write_ndjson(DATA_DIR / 'self_history.ndjson', self_records)

    # rpi4-1 (位相 π/2): 山型の頂点を右にずらして 2 本線が交差しないようにする
    rpi4_records = gen_records(RPI4_HOST, RPI4_MEM_TOTAL, phase_offset=math.pi / 2)
    write_ndjson(DATA_DIR / 'rpi4_history.ndjson', rpi4_records)


if __name__ == '__main__':
    main()
