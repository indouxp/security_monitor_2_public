#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_ndjson.py - 対話注入型 NDJSON テストデータ生成（mock_server2 用）

Enter 毎に 1 レコードを対話入力し、data/self_history.ndjson へ追記する。
別ターミナルで mock_server.py を起動しておくと、ブラウザのグラフが
追記のたびに伸びる様子を確認できる。

実行:
    cd test/mock_server2
    python3 gen_ndjson.py N      # N: 1=cpu 2=temp 3=disk_rw 4=mem

引数 N で対象グラフ（フィールド）を 1 つ選び、そのフィールドだけ入力値を持つ。
他の 3 フィールドは 0 とするため、指定したグラフ単独のテストになる。
（例: N=1 なら Panel 4 左上の CPU グラフのみ動き、他 3 グラフは 0 のまま）

print・例外トレースバックを含む全出力を、ログファイル（gen_ndjson.py.log）と
画面の両方へ出力する。雛形 tmp/skl.py を流用。

Created: 2026-05-19
Author:  Tsystem
"""
import sys
import json
import datetime
import traceback
from pathlib import Path

# スクリプト自身のパスと、ログ出力先（スクリプト名.log・毎回上書き）
SELF = Path(__file__).resolve()
LOG_PATH = SELF.with_name(SELF.name + ".log")

# ---- 設定 ----
DATA_DIR    = SELF.parent / "data"                  # NDJSON 出力ディレクトリ
SELF_NDJSON = DATA_DIR / "self_history.ndjson"      # 追記先（mock_server の vostro 線）
RPI4_NDJSON = DATA_DIR / "rpi4_history.ndjson"      # 起動時に空化（rpi4-1 線は出さない）

HOSTNAME  = "vostro"                                # self_history 用ホスト名（固定）
MEM_TOTAL = 16 * 1024 * 1024 * 1024                 # 凡例表示用メモリ総量 16GB（固定）
TS_FMT    = "%Y-%m-%dT%H:%M:%S"                     # ts のフォーマット（既存データと整合）
INTERVAL  = 30                                      # 日時の既定値インクリメント間隔（秒）

# 引数 N → (フィールド名, 表示名, 値の型) の対応表
FIELDS = {
    "1": ("cpu",     "CPU使用率",    float),
    "2": ("temp",    "CPU温度",      float),
    "3": ("disk_rw", "ディスクIO",   int),
    "4": ("mem",     "メモリ使用率",  float),
}


class Tee:
    """書き込みを複数のストリームへ複製するファイルライクオブジェクト"""

    def __init__(self, *streams):
        self.streams = streams                      # 複製先ストリーム群

    def write(self, text):
        # 全ストリームへ書き込み、都度フラッシュして強制終了時のログ欠落を防ぐ
        for st in self.streams:
            st.write(text)
            st.flush()

    def flush(self):
        for st in self.streams:
            st.flush()


def log(msg):
    """タイムスタンプ付きでメッセージを出力する

    引数:
        msg: 出力するメッセージ文字列
    """
    print(f"{datetime.datetime.now():%Y%m%d.%H%M%S}: {msg}")


def ask_datetime(default_dt):
    """日時を対話入力する。空入力（Enter）なら既定値 default_dt を採用する

    引数:
        default_dt: 既定値として提示する datetime（初回=現在時刻、以降=前回+INTERVAL秒）
    戻り値:
        確定した datetime
    """
    default_str = default_dt.strftime(TS_FMT)                # 既定値の表示用文字列
    while True:
        s = input(f"  日時 [{default_str}]: ").strip()
        if s == "":
            return default_dt
        try:
            return datetime.datetime.strptime(s, TS_FMT)     # 形式検証を兼ねて datetime 化
        except ValueError:
            print(f"  -> 日時の形式が不正です（{TS_FMT}）。再入力してください。")


def ask_value(disp_name, value_type, default_value):
    """対象フィールドの値を対話入力する。空入力（Enter）なら既定値を採用する

    引数:
        disp_name:     入力対象の表示名（プロンプト表示用）
        value_type:    値の型（int=disk_rw / float=cpu,temp,mem）
        default_value: 既定値として提示する値（初回=0、以降=前回確定した値）
    戻り値:
        入力値（int または float）
    """
    while True:
        s = input(f"  {disp_name} の値 [{default_value}]: ").strip()
        if s == "":
            return default_value
        try:
            num = float(s)                                   # 数値として解釈
            return int(num) if value_type is int else num
        except ValueError:
            print("  -> 数値で入力してください。再入力してください。")


def main():
    """主処理。引数で選んだフィールドのみ対話入力し、レコードを追記する

    戻り値:
        終了コード(int)。正常時 0、引数不正など異常時は 0 以外を返す
    """
    # ---- 引数チェック ----
    if len(sys.argv) != 2 or sys.argv[1] not in FIELDS:
        print(f"使い方: {SELF.name} N   (N: 1=cpu 2=temp 3=disk_rw 4=mem)")
        return 1

    field_name, disp_name, value_type = FIELDS[sys.argv[1]]
    print(f"対象グラフ: [{sys.argv[1]}] {disp_name} ({field_name})")

    # ---- 起動時クリア（data/ を作成し、両 NDJSON を空ファイルにする） ----
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    SELF_NDJSON.write_text("", encoding="utf-8")
    RPI4_NDJSON.write_text("", encoding="utf-8")
    print(f"クリア: {SELF_NDJSON}")
    print(f"クリア: {RPI4_NDJSON}")
    print("Enter 毎に 1 レコードを追記します。Ctrl+D で終了。")

    # ---- 対話ループ ----
    count = 0                                                # 追記済みレコード数
    # 既定値。日時=初回は現在時刻/以降は前回+INTERVAL秒、値=初回0/以降は前回の値
    next_dt    = datetime.datetime.now().replace(microsecond=0)
    next_value = 0
    while True:
        print(f"[{count + 1}件目]")
        try:
            ts_dt = ask_datetime(next_dt)
            value = ask_value(disp_name, value_type, next_value)
        except EOFError:
            # Ctrl+D。対話終了。正常終了する
            print()
            log(f"EOF 検出。{count} 件追記して終了します。")
            return 0

        # 選択フィールドのみ入力値、他フィールドは 0（指定グラフ単独テスト）
        record = {
            "hostname":  HOSTNAME,
            "cpu":       0,
            "temp":      0,
            "disk_rw":   0,
            "mem":       0,
            "mem_total": MEM_TOTAL,
            "ts":        ts_dt.strftime(TS_FMT),
        }
        record[field_name] = value

        # 1 行 NDJSON として追記（mock_server へ即反映させるため都度クローズ）
        line = json.dumps(record, ensure_ascii=False)
        with SELF_NDJSON.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
        count += 1
        print(f"  追記: {line}")

        # 次レコードの既定値を更新（日時=今回+INTERVAL秒、値=今回確定した値）
        next_dt    = ts_dt + datetime.timedelta(seconds=INTERVAL)
        next_value = value


if __name__ == "__main__":
    # 全出力(print・例外トレースバック)をログファイルと画面の両方へ流す
    _logf = open(LOG_PATH, "w", encoding="utf-8", buffering=1)
    sys.stdout = Tee(sys.__stdout__, _logf)
    sys.stderr = Tee(sys.__stderr__, _logf)

    log(f"START name: {SELF.name}")
    rc = 1                                          # 既定は異常終了
    try:
        rc = main()
    except SystemExit as e:
        # sys.exit() による終了。終了コードを int へ正規化する
        rc = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
    except KeyboardInterrupt:
        # Ctrl+C による中断。トレースバックは出さず中断扱い(1)とする
        print()
        rc = 1
    except BaseException:
        # 未処理例外。トレースバックは Tee 経由でログにも残る
        traceback.print_exc()
        rc = 1
    finally:
        log(f"END rc: {rc}")
        sys.stdout = sys.__stdout__                 # 標準ストリームを元に戻す
        sys.stderr = sys.__stderr__
        _logf.flush()
        _logf.close()

    sys.exit(rc)
