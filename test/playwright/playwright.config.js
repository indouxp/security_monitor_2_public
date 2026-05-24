/* playwright.config.js - Playwright テスト設定
 * mock_server2 を webServer として自動起動し、Chromium でテストを実行する。
 * テスト前に gen_testdata.py で既知値の NDJSON を生成する。
 */

'use strict';

const path = require('path');

module.exports = {
    testDir: './tests',

    /* タイムアウト: テスト全体 30 秒 */
    timeout: 30000,

    use: {
        channel: 'chrome',  /* システムインストールの Google Chrome を使用 */
        headless: true,
        baseURL: 'http://localhost:8080',
    },

    /* mock_server2 を自動起動する
     * gen_testdata.py でテストデータを生成してからサーバーを起動する */
    webServer: {
        command: 'python3 gen_testdata.py && python3 ../mock_server2/mock_server.py',
        cwd: path.join(__dirname),
        port: 8080,
        reuseExistingServer: true,
        timeout: 15000,
    },

    reporter: [['list']],
};
