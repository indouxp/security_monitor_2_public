#!/usr/bin/env python3
"""gen_testdata.py - Playwright テスト用 NDJSON データ生成

test/mock_server2/data/ に self_history.ndjson と rpi4_history.ndjson を生成する。
既知の固定値を使用するため、テスト結果が安定する。

生成データ:
  self_history.ndjson : hostname=vostro, cpu=50.0, temp=60.0, disk_rw=204800, mem=70.0
  rpi4_history.ndjson : hostname=rpi4-1, cpu=30.0, temp=50.0, disk_rw=102400, mem=40.0
  各 60 件（30 分分）、現在時刻から 30 秒間隔で逆算生成
"""

import json
import pathlib
from datetime import datetime, timedelta, timezone

# 出力先: test/mock_server2/data/
DATA_DIR = pathlib.Path(__file__).parent.parent / 'mock_server2' / 'data'

# 各ホストの固定値
HOSTS = [
    {
        'file':      'self_history.ndjson',
        'hostname':  'vostro',
        'cpu':       50.0,
        'temp':      60.0,
        'disk_rw':   204800,
        'mem':       70.0,
        'mem_total': 17179869184,  # 16GB
    },
    {
        'file':      'rpi4_history.ndjson',
        'hostname':  'rpi4-1',
        'cpu':       30.0,
        'temp':      50.0,
        'disk_rw':   102400,
        'mem':       40.0,
        'mem_total': 8589934592,   # 8GB
    },
]

RECORD_COUNT    = 60   # 生成するレコード数（30 分分）
INTERVAL_SEC    = 30   # 収集間隔（秒）


def generate():
    """テストデータを生成して data/ に書き出す"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # 現在時刻を基準にタイムスタンプを逆算（秒単位で切り捨て）
    now = datetime.now(timezone.utc).replace(microsecond=0)

    for host in HOSTS:
        records = []
        for i in range(RECORD_COUNT - 1, -1, -1):
            ts = now - timedelta(seconds=i * INTERVAL_SEC)
            record = {
                'hostname':  host['hostname'],
                'cpu':       host['cpu'],
                'temp':      host['temp'],
                'disk_rw':   host['disk_rw'],
                'mem':       host['mem'],
                'mem_total': host['mem_total'],
                'ts':        ts.strftime('%Y-%m-%dT%H:%M:%S'),
            }
            records.append(json.dumps(record, ensure_ascii=False))

        out_path = DATA_DIR / host['file']
        out_path.write_text('\n'.join(records) + '\n', encoding='utf-8')
        print(f'generated: {out_path}  ({len(records)} records)')


if __name__ == '__main__':
    generate()
