#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mock_recv.py - push_metrics.sh 単体テスト用モック受信サーバー

push_metrics.sh が POST するメトリクスJSONを受信し、ボディを RECV_FILE に
保存して 200/ok を返す。本番受信側 push_daemon.py の代用となる最小実装。

環境変数:
  MOCK_PORT  待受ポート（既定 19092）
  RECV_FILE  受信ボディの保存先（既定 received.json）

Created: 2026-05-21
Author:  Tsystem
"""
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("MOCK_PORT", "19092"))          # 待受ポート
RECV_FILE = os.environ.get("RECV_FILE", "received.json")  # 受信ボディ保存先


class Handler(BaseHTTPRequestHandler):
    """POST を受信しボディを RECV_FILE へ保存するハンドラ"""

    def do_POST(self):
        """POST ボディを RECV_FILE に保存し 200/ok を返す"""
        length = int(self.headers.get("Content-Length") or 0)  # ボディ長
        body = self.rfile.read(length)                         # 受信ボディ
        with open(RECV_FILE, "wb") as f:
            f.write(body)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):
        """アクセスログ出力を抑止する"""
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
