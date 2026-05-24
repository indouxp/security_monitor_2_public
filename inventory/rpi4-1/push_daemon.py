#!/usr/bin/env python3
"""push_daemon.py - メトリクス受信デーモン

クライアントから POST /api/push を受け取り、
送信元 IP ごとに JSON ファイル（最新値）と NDJSON ファイル（履歴）を保存する。
nginx の proxy_pass http://127.0.0.1:9090 経由で呼び出される想定。
nginx が X-Real-IP ヘッダーを付与するため、それを優先して送信元 IP を取得する。

Created: 2026-05-09
"""

import http.server
import json
import logging
import pathlib
import signal
import sys
from datetime import datetime, timezone

# ---- 設定 ----
PORT         = 9091                                # 待受ポート (nginx がプロキシ)
DATA_DIR     = pathlib.Path('/var/www/html/data')  # JSON ファイル保存先
MAX_HISTORY  = 2880                                # 保持最大行数（24時間分）
MAX_BODY     = 4096                                # POST ボディ最大サイズ (bytes)

# 必須フィールド（検証用）
REQUIRED_FIELDS = {'hostname', 'cpu', 'temp', 'disk_rw', 'mem'}

# ---- ログ設定（systemd journald へ出力） ----
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    datefmt='%Y%m%d.%H%M%S',
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


class PushHandler(http.server.BaseHTTPRequestHandler):
    """POST /api/push を処理するハンドラ"""

    def log_message(self, fmt, *args):
        """デフォルトのアクセスログを抑制（エラー時のみ出力）"""
        pass

    def _send(self, code: int, body: bytes = b''):
        """レスポンスを送信する"""
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        """POST リクエストを処理する"""
        if self.path != '/api/push':
            self._send(404, b'not found')
            return

        # ボディ読み取り（最大 MAX_BODY bytes）
        try:
            length = int(self.headers.get('Content-Length', 0))
        except ValueError:
            self._send(400, b'bad Content-Length')
            return

        if length <= 0 or length > MAX_BODY:
            self._send(400, b'invalid Content-Length')
            return

        raw = self.rfile.read(length)

        # JSON パース
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self._send(400, b'invalid JSON')
            return

        # 必須フィールド検証
        missing = REQUIRED_FIELDS - payload.keys()
        if missing:
            self._send(400, f'missing fields: {missing}'.encode())
            return

        # 送信元 IP の取得（nginx X-Real-IP ヘッダーを優先）
        client_ip = self.headers.get('X-Real-IP') or self.client_address[0]

        # タイムスタンプが未設定の場合は付与
        if 'ts' not in payload:
            payload['ts'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S')

        # 保存先ディレクトリを保証
        DATA_DIR.mkdir(parents=True, exist_ok=True)

        # 最新値ファイル（上書き）
        latest = DATA_DIR / f'{client_ip}.json'
        latest.write_text(json.dumps(payload, ensure_ascii=False))

        # 履歴ファイル（追記 + トリミング）
        history = DATA_DIR / f'{client_ip}-history.ndjson'
        line = json.dumps(payload, ensure_ascii=False) + '\n'
        with history.open('a', encoding='utf-8') as f:
            f.write(line)

        # 行数が上限を超えたらトリミング
        text = history.read_text(encoding='utf-8')
        lines = text.splitlines()
        if len(lines) > MAX_HISTORY:
            history.write_text('\n'.join(lines[-MAX_HISTORY:]) + '\n', encoding='utf-8')

        log.info('saved %s cpu=%.1f temp=%.1f disk_rw=%s mem=%.1f',
                 client_ip,
                 payload.get('cpu', 0),
                 payload.get('temp', 0),
                 payload.get('disk_rw', 0),
                 payload.get('mem', 0))

        self._send(200, b'ok')


class ReusePortHTTPServer(http.server.HTTPServer):
    """SO_REUSEPORT を有効にして再起動直後のポート衝突を防ぐ"""
    allow_reuse_address = True
    allow_reuse_port    = True


def main():
    """デーモン起動"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    server = ReusePortHTTPServer(('127.0.0.1', PORT), PushHandler)
    log.info('push_daemon started port=%d data_dir=%s', PORT, DATA_DIR)

    # SIGTERM でクリーンシャットダウン
    def on_sigterm(signum, frame):
        log.info('push_daemon stopping (SIGTERM)')
        server.server_close()
        sys.exit(0)

    signal.signal(signal.SIGTERM, on_sigterm)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info('push_daemon stopping (KeyboardInterrupt)')
        server.server_close()


if __name__ == '__main__':
    main()
