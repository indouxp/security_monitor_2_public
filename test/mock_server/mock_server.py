#!/usr/bin/env python3
"""mock_server.py - E2E グラフ検証用モックサーバー

既知パターンの NDJSON を返し、Chrome でグラフ動作を確認するためのサーバー。
静的ファイルは inventory/rpi4-1/@var@www@html/ から配信する。

実行方法:
    cd test/mock_server
    python3 gen_ndjson.py   # 初回のみ（data/ を生成）
    python3 mock_server.py  # Ctrl+C で停止

確認:
    http://localhost:8080
"""

import http.server
import pathlib
import sys

# ---- 設定 ----
PORT = 8080

# このスクリプトが置かれているディレクトリ（test/mock_server/）
BASE_DIR   = pathlib.Path(__file__).parent

# inventory/rpi4-1/ ディレクトリ（静的ファイルは @var@www@html@<name> というフラット名）
INVENTORY_DIR = BASE_DIR / '../../inventory/rpi4-1'

# NDJSON データディレクトリ
DATA_DIR   = BASE_DIR / 'data'

# Content-Type マッピング
CONTENT_TYPES = {
    '.html':   'text/html; charset=utf-8',
    '.css':    'text/css',
    '.js':     'application/javascript',
    '.ndjson': 'application/x-ndjson',
    '.json':   'application/json',
}


class MockHandler(http.server.BaseHTTPRequestHandler):
    """E2E 検証用リクエストハンドラ"""

    def log_message(self, fmt, *args):
        """アクセスログを標準出力に出力する（デフォルトは stderr）"""
        print(f'{self.address_string()} - {fmt % args}', flush=True)

    def _send_file(self, path: pathlib.Path, content_type: str) -> None:
        """指定パスのファイルをレスポンスとして送信する"""
        try:
            body = path.read_bytes()
        except FileNotFoundError:
            self._send_error(404, f'not found: {path.name}')
            return

        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-cache, no-store')
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, code: int, msg: str = '') -> None:
        """エラーレスポンスを送信する"""
        body = msg.encode()
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        """GET リクエストをルーティングする"""
        path = self.path.split('?')[0]   # クエリストリングを除去

        # --- NDJSON エンドポイント ---
        if path == '/api/my-history':
            self._send_file(DATA_DIR / 'self_history.ndjson', 'application/x-ndjson')

        elif path == '/data/rpi4-1-history.ndjson':
            self._send_file(DATA_DIR / 'rpi4_history.ndjson', 'application/x-ndjson')

        # --- 静的ファイル（inventory は @var@www@html@<name> というフラット名） ---
        elif path == '/':
            self._send_file(INVENTORY_DIR / '@var@www@html@index.html', 'text/html; charset=utf-8')

        elif path in ('/style.css', '/app.js'):
            name = path.lstrip('/')
            ext  = pathlib.Path(name).suffix
            ct   = CONTENT_TYPES.get(ext, 'application/octet-stream')
            self._send_file(INVENTORY_DIR / f'@var@www@html@{name}', ct)

        # --- その他: 404（WebRTC / API は失敗させてよい） ---
        else:
            self._send_error(404, 'not found')


class ReusePortHTTPServer(http.server.HTTPServer):
    """再起動直後のポート衝突を防ぐ"""
    allow_reuse_address = True
    allow_reuse_port    = True


def main():
    # data/ の存在確認
    self_nd  = DATA_DIR / 'self_history.ndjson'
    rpi4_nd  = DATA_DIR / 'rpi4_history.ndjson'
    if not self_nd.exists() or not rpi4_nd.exists():
        print('ERROR: data/ が見つかりません。先に gen_ndjson.py を実行してください。')
        sys.exit(1)

    server = ReusePortHTTPServer(('', PORT), MockHandler)
    print(f'mock server started  http://localhost:{PORT}')
    print(f'inventory  : {INVENTORY_DIR.resolve()}')
    print(f'data dir   : {DATA_DIR.resolve()}')
    print('Ctrl+C で停止')

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nmock server stopped')
        server.server_close()


if __name__ == '__main__':
    main()
