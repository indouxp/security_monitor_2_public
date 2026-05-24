/* app.spec.js - app.js Playwright E2E テスト（100% カバレッジ）
 *
 * A: 基本動作       TC-APP-010〜080  8件  mock_server2 のみ
 * B: ネットワークエラー TC-APP-090〜120  4件  page.route() で経路制御
 * C: その他未通パス  TC-APP-130〜150  3件  page.evaluate() で直接呼び出し
 * D: WebRTC モック   TC-APP-160〜230  8件  addInitScript で RTCPeerConnection を差替え
 */

'use strict';

const { test, expect } = require('@playwright/test');

/* ----------------------------------------------------------
 * MockRTCPeerConnection の定義（describe D の addInitScript で注入）
 *
 *  window.__mockPCInstances[N] でカメラ順（swing1=0）にアクセスできる。
 *  setRemoteDescription() が呼ばれると 50ms 後に _connect() を起動し、
 *  ontrack / onconnectionstatechange(connected) / ICE イベントを順次発火する。
 * ---------------------------------------------------------- */
function mockRTCScript() {
    const instances = [];
    window.__mockPCInstances = instances;

    window.RTCPeerConnection = class MockPC {
        constructor() {
            this.connectionState  = 'new';
            this.iceGatheringState  = 'complete'; // ICE 待機をスキップ
            this.iceConnectionState = 'new';
            this._cbs = {};
            instances.push(this);
        }

        addTransceiver()       { return { setCodecPreferences() {} }; }
        createOffer()          { return Promise.resolve({ type: 'offer', sdp: 'v=0\r\n' }); }
        setLocalDescription()  { return Promise.resolve(); }
        get localDescription() { return { type: 'offer', sdp: 'v=0\r\n' }; }

        setRemoteDescription() {
            /* 50ms 後に接続シーケンスを起動 */
            setTimeout(() => this._connect(), 50);
            return Promise.resolve();
        }

        close() { this.connectionState = 'closed'; }

        /* コールバック setter/getter */
        set ontrack(fn)                    { this._cbs.track   = fn; }
        set onconnectionstatechange(fn)    { this._cbs.conn    = fn; }
        set onicegatheringstatechange(fn)  { this._cbs.igather = fn; }
        set oniceconnectionstatechange(fn) { this._cbs.iconn   = fn; }
        set onicecandidate(fn)             { this._cbs.cand    = fn; }
        get onicegatheringstatechange()    { return this._cbs.igather; }
        get oniceconnectionstatechange()   { return this._cbs.iconn;   }
        get onicecandidate()               { return this._cbs.cand;    }

        _connect() {
            /* 1) ontrack → srcObject 設定 → startStallDetector 起動 */
            if (this._cbs.track) {
                this._cbs.track({ streams: [new MediaStream()], track: null });
            }

            /* 2) onconnectionstatechange(connected)
             *    → 内部で ICE コールバックが登録される */
            this.connectionState = 'connected';
            if (this._cbs.conn) this._cbs.conn();

            /* 3) ICE イベント発火（登録後 10ms） */
            setTimeout(() => {
                if (this._cbs.igather) this._cbs.igather();
                if (this._cbs.iconn)   this._cbs.iconn();
                if (this._cbs.cand) {
                    /* candidate あり → if(event.candidate) true ブランチ */
                    this._cbs.cand({ candidate: { candidate: 'mock cand' } });
                    /* null → false ブランチ */
                    this._cbs.cand({ candidate: null });
                }
            }, 10);
        }
    };

    /* H.264 コーデック優先設定のために必要 */
    window.RTCRtpReceiver = {
        getCapabilities(kind) {
            if (kind !== 'video') return null;
            return { codecs: [
                { mimeType: 'video/H264', clockRate: 90000 },
                { mimeType: 'video/VP8',  clockRate: 90000 },
            ]};
        },
    };
}

/* ----------------------------------------------------------
 * ビデオ要素を「再生中・フリーズ」状態に見せるヘルパー
 *   stall 検出テストで startStallDetector の paused 分岐を通過させる
 * ---------------------------------------------------------- */
async function mockVideoPlaying(page, videoId, frozen = true) {
    await page.evaluate(({ id, frozen }) => {
        const v = document.getElementById(id);
        Object.defineProperty(v, 'paused',     { get: () => false, configurable: true });
        Object.defineProperty(v, 'readyState', { get: () => 4,     configurable: true });
        if (frozen) {
            /* currentTime が進まない → stall */
            Object.defineProperty(v, 'currentTime', { get: () => 0, configurable: true });
        } else {
            /* currentTime が毎回インクリメント → stall 解消 */
            let t = 0;
            Object.defineProperty(v, 'currentTime', { get: () => ++t, configurable: true });
        }
    }, { id: videoId, frozen });
}

/* ============================================================
 * A: 基本動作テスト
 * ============================================================ */
test.describe('A: 基本動作', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('/');
    });

    /* TC-APP-010: 時計が YYYY-MM-DD HH:MM:SS 形式で表示される */
    test('TC-APP-010: 時計が YYYY-MM-DD HH:MM:SS 形式で表示される', async ({ page }) => {
        await expect(page.locator('#clock')).toHaveText(
            /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
        );
    });

    /* TC-APP-020: メトリクスステータスが「正常」になる（fso-status も更新される） */
    test('TC-APP-020: メトリクスステータスが「正常」になる', async ({ page }) => {
        await expect(page.locator('#metrics-status')).toHaveText('正常', { timeout: 15000 });
        /* setMetricsStatus は #fso-status も同時更新する */
        await expect(page.locator('#fso-status')).toHaveText('正常');
    });

    /* TC-APP-030: グラフ canvas 要素が存在する */
    test('TC-APP-030: グラフ canvas 要素が存在する', async ({ page }) => {
        await expect(page.locator('#chart-cpu')).toBeAttached();
        await expect(page.locator('#chart-temp')).toBeAttached();
        await expect(page.locator('#chart-disk')).toBeAttached();
        await expect(page.locator('#chart-mem')).toBeAttached();
    });

    /* TC-APP-040: リソースモニター全画面 - パネルクリックで開く */
    test('TC-APP-040: リソースモニター全画面 - パネルクリックで開く', async ({ page }) => {
        await expect(page.locator('#fullscreen-metrics-overlay')).toHaveClass(/hidden/);
        await page.locator('#panel-metrics').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).not.toHaveClass(/hidden/);
    });

    /* TC-APP-050: リソースモニター全画面 - overlay クリックで閉じる */
    test('TC-APP-050: リソースモニター全画面 - overlay クリックで閉じる', async ({ page }) => {
        await page.locator('#panel-metrics').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).not.toHaveClass(/hidden/);
        await page.locator('#fullscreen-metrics-overlay').click({ position: { x: 10, y: 10 } });
        await expect(page.locator('#fullscreen-metrics-overlay')).toHaveClass(/hidden/);
    });

    /* TC-APP-060: リソースモニター全画面 - 戻るボタンで閉じる */
    test('TC-APP-060: リソースモニター全画面 - 戻るボタンで閉じる', async ({ page }) => {
        await page.locator('#panel-metrics').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).not.toHaveClass(/hidden/);
        await page.locator('#fso-back-btn').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).toHaveClass(/hidden/);
    });

    /* TC-APP-070: カメラ全画面 - 未接続時はクリックしても開かない */
    test('TC-APP-070: カメラ全画面 - 未接続時はクリックしても開かない', async ({ page }) => {
        await expect(page.locator('#fullscreen-overlay')).toHaveClass(/hidden/);
        await page.locator('[data-cam="swing1"]').click();
        await expect(page.locator('#fullscreen-overlay')).toHaveClass(/hidden/);
    });

    /* TC-APP-080: カメラバッジ - WHEP POST 404 後に「切断」になる */
    test('TC-APP-080: カメラバッジが WHEP 失敗後に「切断」になる', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('切断', { timeout: 10000 });
    });
});

/* ============================================================
 * B: ネットワークエラーパス
 * ============================================================ */
test.describe('B: ネットワークエラー', () => {

    /* TC-APP-090: fetchNdjson 404 → [] → status「正常」 */
    test('TC-APP-090: fetchNdjson 404 → [] → metrics-status 正常', async ({ page }) => {
        await page.route('/api/my-history',
            route => route.fulfill({ status: 404 })
        );
        await page.goto('/');
        /* 404 は [] を返すので status は 'ok' になる */
        await expect(page.locator('#metrics-status')).toHaveText('正常', { timeout: 15000 });
    });

    /* TC-APP-100: fetchNdjson 500 → throw → refreshMetrics catch → 「取得失敗」 */
    test('TC-APP-100: fetchNdjson 500 → refreshMetrics catch → 取得失敗', async ({ page }) => {
        await page.route('/api/my-history',
            route => route.fulfill({ status: 500 })
        );
        await page.goto('/');
        /* 500 は throw → catch → setMetricsStatus('error') */
        await expect(page.locator('#metrics-status')).toHaveText('取得失敗', { timeout: 15000 });
        await expect(page.locator('#fso-status')).toHaveText('取得失敗');
    });

    /* TC-APP-110: CDN abort → script.onerror → 「取得失敗」 */
    test('TC-APP-110: Chart.js CDN abort → script.onerror → 取得失敗', async ({ page }) => {
        await page.route('https://cdn.jsdelivr.net/**',
            route => route.abort()
        );
        await page.goto('/');
        /* onerror → setMetricsStatus('error') */
        await expect(page.locator('#metrics-status')).toHaveText('取得失敗', { timeout: 10000 });
    });

    /* TC-APP-120: 両 NDJSON 404 → applyDataToChartSet endSec<0 early return */
    test('TC-APP-120: 両 NDJSON 404 → endSec<0 early return → データなし', async ({ page }) => {
        await page.route('/api/my-history',
            route => route.fulfill({ status: 404 })
        );
        await page.route('/data/rpi4-1-history.ndjson',
            route => route.fulfill({ status: 404 })
        );
        await page.goto('/');
        /* 両データ空でも status は 'ok'（early return でもクラッシュしない） */
        await expect(page.locator('#metrics-status')).toHaveText('正常', { timeout: 15000 });
        /* グラフデータが空であることを確認 */
        const hasData = await page.evaluate(() => {
            const chart = window.Chart && window.Chart.getChart('chart-cpu');
            return chart ? chart.data.datasets.some(ds => ds.data.length > 0) : false;
        });
        expect(hasData).toBe(false);
    });
});

/* ============================================================
 * C: その他未通パス
 * ============================================================ */
test.describe('C: その他未通パス', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('/');
    });

    /* TC-APP-130: setStatus 未知の state → labels fallback で raw string 表示 */
    test('TC-APP-130: setStatus 未知 state → raw string 表示', async ({ page }) => {
        await page.evaluate(() =>
            window.setStatus('status-swing1', 'unknown-state')
        );
        await expect(page.locator('#status-swing1')).toHaveText('unknown-state');
    });

    /* TC-APP-140: openMetricsFullscreen 2回目（fsoInitialized=true パス） */
    test('TC-APP-140: openMetricsFullscreen 2回目（fsoInitialized=true）', async ({ page }) => {
        await expect(page.locator('#metrics-status')).toHaveText('正常', { timeout: 15000 });
        /* 1回目 open → close */
        await page.locator('#panel-metrics').click();
        await page.locator('#fso-back-btn').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).toHaveClass(/hidden/);
        /* 2回目 open（fsoInitialized=true → initMetricsChartsFS をスキップして
         * applyDataToChartSet(metricsChartsFS, ...) を直接呼ぶパス） */
        await page.locator('#panel-metrics').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).not.toHaveClass(/hidden/);
        await expect(page.locator('#fso-chart-cpu')).toBeAttached();
    });

    /* TC-APP-150: overlay 開放中に refreshMetrics エラー → fso-status も「取得失敗」 */
    test('TC-APP-150: overlay 開放中に refreshMetrics エラー → fso-status 取得失敗', async ({ page }) => {
        await expect(page.locator('#metrics-status')).toHaveText('正常', { timeout: 15000 });
        /* FSO overlay を開く */
        await page.locator('#panel-metrics').click();
        await expect(page.locator('#fullscreen-metrics-overlay')).not.toHaveClass(/hidden/);
        /* /api/my-history を 500 にしてから refreshMetrics を手動呼び出し */
        await page.route('/api/my-history',
            route => route.fulfill({ status: 500 })
        );
        await page.evaluate(() => window.refreshMetrics());
        /* overlay 内の fso-status も「取得失敗」に更新されること */
        await expect(page.locator('#fso-status')).toHaveText('取得失敗', { timeout: 5000 });
    });
});

/* ============================================================
 * D: WebRTC モックテスト
 * ============================================================ */
test.describe('D: WebRTC モック', () => {
    test.beforeEach(async ({ page }) => {
        /* MockRTCPeerConnection をページロード前に注入 */
        await page.addInitScript(mockRTCScript);
        /* WHEP エンドポイントはモック SDP を返す */
        await page.route('/webrtc/*/whep', route =>
            route.fulfill({
                status: 200,
                contentType: 'application/sdp',
                body: 'v=0\r\n',
            })
        );
        /* domcontentloaded で返す: app.js 実行後だが Chart.js CDN を待たない
         * WebRTC テストはメトリクスに依存しないため CDN 待ちは不要 */
        await page.goto('/', { waitUntil: 'domcontentloaded' });
    });

    /* TC-APP-160: startWhep 成功 → 接続済み（ICE イベント含む） */
    test('TC-APP-160: startWhep 成功 → 接続済みバッジ', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
    });

    /* TC-APP-170: stall 検出 → 遅延バッジ */
    test('TC-APP-170: stall 検出 → 遅延バッジ', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        /* video を「再生中・フリーズ」に見せる */
        await mockVideoPlaying(page, 'video-swing1', true);
        /* STALL_THRESHOLD(3秒) 経過後に「遅延」になる */
        await expect(page.locator('#status-swing1')).toHaveText('遅延', { timeout: 6000 });
    });

    /* TC-APP-180: stall 解消 → 接続済みに復帰 */
    test('TC-APP-180: stall 解消 → 接続済みに復帰', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        /* stall を起こす */
        await mockVideoPlaying(page, 'video-swing1', true);
        await expect(page.locator('#status-swing1')).toHaveText('遅延', { timeout: 6000 });
        /* currentTime を進める → stall 解消 */
        await mockVideoPlaying(page, 'video-swing1', false);
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 5000 });
    });

    /* TC-APP-190: startStallDetector 多重起動防止（clearInterval ブランチ） */
    test('TC-APP-190: startStallDetector 多重起動防止（clearInterval）', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        /* 2回目の呼び出しで stallTimers[statusId] が存在 → clearInterval を通る */
        await page.evaluate(() => {
            const video = document.getElementById('video-swing1');
            window.startStallDetector(video, 'status-swing1');
        });
        /* 再起動後も stall 検出が正常に動作すること */
        await mockVideoPlaying(page, 'video-swing1', true);
        await expect(page.locator('#status-swing1')).toHaveText('遅延', { timeout: 6000 });
    });

    /* TC-APP-200: openFullscreen 成功（srcObject あり） */
    test('TC-APP-200: openFullscreen 成功 → カメラ全画面 overlay 表示', async ({ page }) => {
        /* 接続後は srcObject が設定されている */
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        await expect(page.locator('#fullscreen-overlay')).toHaveClass(/hidden/);
        await page.locator('[data-cam="swing1"]').click();
        await expect(page.locator('#fullscreen-overlay')).not.toHaveClass(/hidden/);
    });

    /* TC-APP-210: closeFullscreen via overlay click */
    test('TC-APP-210: closeFullscreen - overlay クリックで閉じる', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        await page.locator('[data-cam="swing1"]').click();
        await expect(page.locator('#fullscreen-overlay')).not.toHaveClass(/hidden/);
        /* overlay 本体をクリック → closeFullscreen() */
        await page.locator('#fullscreen-overlay').click({ position: { x: 10, y: 10 } });
        await expect(page.locator('#fullscreen-overlay')).toHaveClass(/hidden/);
    });

    /* TC-APP-220: closeFullscreen via back button */
    test('TC-APP-220: closeFullscreen - 戻るボタンで閉じる', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        await page.locator('[data-cam="swing1"]').click();
        await expect(page.locator('#fullscreen-overlay')).not.toHaveClass(/hidden/);
        /* 戻るボタン（stopPropagation → closeFullscreen）*/
        await page.locator('#overlay-back-btn').click();
        await expect(page.locator('#fullscreen-overlay')).toHaveClass(/hidden/);
    });

    /* TC-APP-230: onconnectionstatechange disconnected → pc.close() / 切断バッジ */
    test('TC-APP-230: WebRTC disconnection → pc.close() / 切断バッジ', async ({ page }) => {
        await expect(page.locator('#status-swing1')).toHaveText('接続済み', { timeout: 10000 });
        /* __mockPCInstances[0] = swing1 の PC に disconnected を注入 */
        await page.evaluate(() => {
            const pc = window.__mockPCInstances[0];
            pc.connectionState = 'disconnected';
            if (pc._cbs.conn) pc._cbs.conn();
        });
        /* setStatus('disconnected') → 「切断」 */
        await expect(page.locator('#status-swing1')).toHaveText('切断', { timeout: 3000 });
        /* pc.close() が呼ばれた → connectionState === 'closed' */
        const isClosed = await page.evaluate(
            () => window.__mockPCInstances[0].connectionState === 'closed'
        );
        expect(isClosed).toBe(true);
    });
});
