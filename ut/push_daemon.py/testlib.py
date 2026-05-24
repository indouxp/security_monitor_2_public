#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""testlib.py - push_daemon.py 単体テスト共通ライブラリ

各テストケース TC-XXX.py から import して使用する。
- 試験用 push_daemon の起動・停止（Daemon クラス）
- HTTP リクエスト送信（http_post / http_get）
- 確認事項の判定・記録（check）
- 全出力のログ採取とエラー時 0 以外終了（run）

skl.py の方式に準拠し、TC ごとに「TC-XXX.py.log」へ全出力を記録する。

Created: 2026-05-18
Author:  Tsystem
"""
import sys
import json
import time
import socket
import shutil
import datetime
import traceback
import subprocess
import http.client
from pathlib import Path

# ---- 設定（init.sh の sed 値と一致させること） ----
TEST_PORT = 19091                                 # 試験用デーモンの待受ポート
UT_DIR    = Path(__file__).resolve().parent       # ut/push_daemon.py/
WORK_DIR  = UT_DIR / "work"                       # init.sh が用意する作業ディレクトリ
DATA_DIR  = WORK_DIR / "data"                     # デーモンの JSON 保存先

# テスト結果（check で蓄積）
_results = []                                     # [(確認事項, 成否bool), ...]


class Tee:
    """書き込みを複数ストリームへ複製するファイルライクオブジェクト"""

    def __init__(self, *streams):
        self.streams = streams

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


def check(desc, ok):
    """確認事項の成否を記録・表示する

    引数:
        desc: 確認事項の説明
        ok:   判定結果（True=PASS）
    戻り値:
        ok の bool 値
    """
    ok = bool(ok)
    _results.append((desc, ok))
    log(f"  [{'PASS' if ok else 'FAIL'}] {desc}")
    return ok


def _wait_port(port, timeout=5.0):
    """指定ポートが待受開始するまで待つ。タイムアウトで RuntimeError

    引数:
        port:    待受確認するポート番号
        timeout: 最大待機秒数
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.3):
                return
        except OSError:
            time.sleep(0.05)
    raise RuntimeError(f"デーモンがポート {port} で待受状態になりません")


class Daemon:
    """試験用 push_daemon を起動・停止するコンテキストマネージャ

    使用例:
        with Daemon():                            # work/push_daemon.py を起動
        with Daemon("push_daemon_smallhist.py"):  # 変種を起動
    """

    def __init__(self, script="push_daemon.py"):
        self.script = WORK_DIR / script           # 起動対象スクリプト
        self.proc = None                          # デーモンプロセス

    def _drain(self, header):
        """デーモンの出力を取得しログへ記録する"""
        try:
            out, _ = self.proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            out, _ = self.proc.communicate()
        if out and out.strip():
            log(header)
            for line in out.rstrip().splitlines():
                log(f"  | {line}")

    def __enter__(self):
        if not self.script.is_file():
            raise RuntimeError(f"試験用スクリプトがありません（init.sh 未実行?）: {self.script}")
        # データディレクトリをクリアして毎回 fresh な状態にする
        if DATA_DIR.exists():
            shutil.rmtree(DATA_DIR)
        DATA_DIR.mkdir(parents=True)
        # デーモン起動（出力はまとめて取得しログへ流す）
        self.proc = subprocess.Popen(
            [sys.executable, str(self.script)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )
        try:
            _wait_port(TEST_PORT)
        except Exception:
            # 起動失敗時はデーモン出力をログへ残してから送出する
            self.proc.kill()
            self._drain("--- デーモン出力（起動失敗） ---")
            raise
        return self

    def __exit__(self, *exc):
        # SIGTERM で停止し、デーモン出力をログへ記録する
        self.proc.terminate()
        self._drain("--- デーモン出力 ---")
        return False


def http_post(path, body, headers=None):
    """POST リクエストを送り (status, body文字列) を返す

    引数:
        path:    リクエストパス（例: /api/push）
        body:    dict/list は JSON 化、str は encode、bytes はそのまま送信
        headers: 追加ヘッダー（dict）
    戻り値:
        (HTTPステータスコード, レスポンスボディ文字列)
    """
    if isinstance(body, (dict, list)):
        body = json.dumps(body, ensure_ascii=False)
    if isinstance(body, str):
        body = body.encode("utf-8")
    conn = http.client.HTTPConnection("127.0.0.1", TEST_PORT, timeout=5)
    try:
        conn.request("POST", path, body=body, headers=dict(headers or {}))
        resp = conn.getresponse()
        text = resp.read().decode("utf-8", errors="replace")
        return resp.status, text
    finally:
        conn.close()


def http_get(path):
    """GET リクエストを送り (status, body文字列) を返す

    引数:
        path: リクエストパス
    戻り値:
        (HTTPステータスコード, レスポンスボディ文字列)
    """
    conn = http.client.HTTPConnection("127.0.0.1", TEST_PORT, timeout=5)
    try:
        conn.request("GET", path)
        resp = conn.getresponse()
        text = resp.read().decode("utf-8", errors="replace")
        return resp.status, text
    finally:
        conn.close()


def read_json(path):
    """JSON ファイルを読み込んで dict を返す"""
    return json.loads(Path(path).read_text(encoding="utf-8"))


def run(main_func, script_file, desc=""):
    """テストケースを実行する

    全出力を「script_file + .log」へ Tee で記録し、
    確認事項に FAIL があれば 0 以外で終了する。

    引数:
        main_func:   テスト本体の関数
        script_file: 呼び出し元 TC の __file__
        desc:        テストケースの説明
    """
    _results.clear()
    log_path = Path(script_file).resolve()
    log_path = log_path.with_name(log_path.name + ".log")
    logf = open(log_path, "w", encoding="utf-8", buffering=1)
    sys.stdout = Tee(sys.__stdout__, logf)
    sys.stderr = Tee(sys.__stderr__, logf)

    tc_name = Path(script_file).name
    log(f"START {tc_name}: {desc}")
    rc = 1
    try:
        main_func()
        passed = sum(1 for _, ok in _results if ok)
        failed = sum(1 for _, ok in _results if not ok)
        log(f"結果: PASS={passed} FAIL={failed}")
        rc = 0 if (failed == 0 and passed > 0) else 1
    except SystemExit as e:
        rc = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
    except BaseException:
        traceback.print_exc()
        rc = 1
    finally:
        log(f"END {tc_name} rc: {rc}")
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        logf.flush()
        logf.close()
    sys.exit(rc)
