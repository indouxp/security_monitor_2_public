/* ============================================================
 * app.js - セキュリティモニター メインスクリプト
 * ============================================================ */

'use strict';

/* ----------------------------------------------------------
 * カメラ定義リスト
 *   name     : MediaMTX のパス名（WHEPエンドポイントのパス要素）
 *   videoId  : 対応する <video> 要素の id
 *   statusId : 対応する接続状態バッジ要素の id
 * ---------------------------------------------------------- */
const CAMERAS = [
    { name: 'swing1',   videoId: 'video-swing1',   statusId: 'status-swing1'   },
    { name: 'atomcam2', videoId: 'video-atomcam2', statusId: 'status-atomcam2' },
    { name: 'swing2',   videoId: 'video-swing2',   statusId: 'status-swing2'   },
];

/* WHEPエンドポイントのベースURL
 * nginx のリバースプロキシ経由で MediaMTX へ接続する */
const WHEP_BASE = '/webrtc';

/* 再接続待機時間（ミリ秒） */
const RECONNECT_INTERVAL = 5000;

/* ----------------------------------------------------------
 * updateClock - 右上の時計表示を更新する
 *   書式: YYYY-MM-DD HH:MM:SS
 * ---------------------------------------------------------- */
function updateClock() {
    const now = new Date();

    /* 各フィールドをゼロ埋め2桁に整形するヘルパー */
    const pad2 = (n) => String(n).padStart(2, '0');

    const yyyy = now.getFullYear();          // 年（4桁）
    const mm   = pad2(now.getMonth() + 1);   // 月（1〜12, 0オリジン補正）
    const dd   = pad2(now.getDate());        // 日
    const hh   = pad2(now.getHours());       // 時
    const mi   = pad2(now.getMinutes());     // 分
    const ss   = pad2(now.getSeconds());     // 秒

    document.getElementById('clock').textContent =
        `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
}

/* ----------------------------------------------------------
 * setStatus - 接続状態バッジのクラスとテキストを更新する
 *   statusId : バッジ要素の id
 *   state    : 'connected' | 'connecting' | 'disconnected' | 'delayed'
 * ---------------------------------------------------------- */
function setStatus(statusId, state) {
    const el = document.getElementById(statusId); // バッジ DOM 要素

    /* 状態クラスを付け替え（CSSで色を制御） */
    el.className = 'status-badge ' + state;

    /* 状態ラベルの日本語マッピング */
    const labels = {
        connected:    '接続済み',
        connecting:   '接続中...',
        disconnected: '切断',
        delayed:      '遅延',
    };
    el.textContent = labels[state] || state;
}

/* ----------------------------------------------------------
 * startWhep - 指定カメラへの WHEP/WebRTC 接続を確立する
 *   cam : カメラ定義オブジェクト { name, videoId, statusId }
 * ---------------------------------------------------------- */
async function startWhep(cam) {
    const { name, videoId, statusId } = cam;

    const videoEl = document.getElementById(videoId); // 映像表示先 <video> 要素
    const whepUrl = `${WHEP_BASE}/${name}/whep`;       // WHEP エンドポイント URL

    setStatus(statusId, 'connecting');

    try {
        /* RTCPeerConnection を生成
         * rpi4-1 上のローカル STUN サーバーを使用（mDNS 名前解決問題を回避） */
        const pc = new RTCPeerConnection({
            iceServers: [{ urls: 'stun:192.168.0.60:3478' }],
        });

        /* ---------------------------------------------------
         * ontrack - 映像・音声トラック受信時のコールバック
         *   受信ストリームを <video> 要素へ接続し、
         *   stall検出タイマーを起動する
         * --------------------------------------------------- */
        pc.ontrack = (event) => {
            if (event.streams && event.streams[0]) {
                videoEl.srcObject = event.streams[0]; // ストリームを video に割り当て

                /* stall検出タイマーを起動（既存タイマーがあれば先にクリア） */
                startStallDetector(videoEl, statusId);
            }
        };

        /* ---------------------------------------------------
         * onconnectionstatechange - P2P 接続状態変化の監視
         *   切断・失敗時は自動再接続する
         * --------------------------------------------------- */
        pc.onconnectionstatechange = () => {
            /* ICE 接続状態の詳細ログ */
            pc.oniceconnectionstatechange = () => {
                console.log(`[${name}] ICE state: ${pc.iceConnectionState}`);
            };

            /* ICE candidate 収集状態ログ */
            pc.onicegatheringstatechange = () => {
                console.log(`[${name}] ICE gathering: ${pc.iceGatheringState}`);
            };

            /* ICE candidate 個別ログ */
            pc.onicecandidate = (event) => {
                if (event.candidate) {
                    console.log(`[${name}] candidate: ${event.candidate.candidate}`);
                }
            };

            const state = pc.connectionState; // 現在の接続状態

            if (state === 'connected') {
                setStatus(statusId, 'connected');

            } else if (['disconnected', 'failed', 'closed'].includes(state)) {
                setStatus(statusId, 'disconnected');
                pc.close(); // PeerConnection を閉じる
                /* 一定時間後に再接続を試みる */
                setTimeout(() => startWhep(cam), RECONNECT_INTERVAL);
            }
        };

        /* 受信専用トランシーバーを追加（映像） */
        const videoTransceiver = pc.addTransceiver('video', { direction: 'recvonly' });

        /* H.264 コーデックを優先設定
         * AtomCam は H.264 で配信するため先頭に配置する */
        const capabilities = RTCRtpReceiver.getCapabilities('video');
        if (capabilities) {
            /* H.264 コーデックのみ抽出 */
            const h264 = capabilities.codecs.filter(c =>
                c.mimeType.toLowerCase() === 'video/h264'
            );
            /* その他のコーデック */
            const others = capabilities.codecs.filter(c =>
                c.mimeType.toLowerCase() !== 'video/h264'
            );
            /* H.264 を先頭に並べてセット */
            if (h264.length > 0) {
                videoTransceiver.setCodecPreferences([...h264, ...others]);
            }
        }

        /* 受信専用トランシーバー（音声）は現在未使用 */
        // pc.addTransceiver('audio', { direction: 'recvonly' });

        /* SDP Offer を生成してローカルに設定 */
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        /* ICE ギャザリング完了を待つ（最大 3 秒でタイムアウト） */
        await new Promise((resolve) => {
            /* すでに完了している場合はすぐ解決 */
            if (pc.iceGatheringState === 'complete') {
                resolve();
                return;
            }
            /* complete イベントで解決 */
            pc.onicegatheringstatechange = () => {
                if (pc.iceGatheringState === 'complete') resolve();
            };
            /* タイムアウト保険（3 秒） */
            setTimeout(resolve, 3000);
        });

        /* ICE 候補を含む完全な SDP を取得 */
        const gatheredSdp = pc.localDescription.sdp;

        /* WHEP エンドポイントへ Offer を POST */
        const resp = await fetch(whepUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/sdp' },
            body: gatheredSdp,
        });

        if (!resp.ok) {
            throw new Error(`WHEP POST failed: ${resp.status}`);
        }

        /* サーバーから受け取った SDP Answer をリモートに設定 */
        const answerSdp = await resp.text();
        await pc.setRemoteDescription({
            type: 'answer',
            sdp: answerSdp,
        });

    } catch (err) {
        console.error(`[${name}] 接続エラー:`, err);
        setStatus(statusId, 'disconnected');
        /* エラー時も一定時間後に再接続を試みる */
        setTimeout(() => startWhep(cam), RECONNECT_INTERVAL);
    }
}

/* ----------------------------------------------------------
 * 初期化処理
 * ---------------------------------------------------------- */

/* 時計を1秒ごとに更新（即時呼び出しで初期表示も行う） */
setInterval(updateClock, 1000);
updateClock();

/* 全カメラの WebRTC 接続を開始 */
CAMERAS.forEach(cam => startWhep(cam));

/* ----------------------------------------------------------
 * startStallDetector - 映像フレームの停止（stall）を検出する
 *
 *   video.currentTime が STALL_THRESHOLD 秒間進まない場合を
 *   「遅延」と判定し、ステータスバッジを黄色に切り替える。
 *   再び currentTime が進み始めたら「接続済み」（緑）に戻す。
 *
 *   videoEl  : 監視対象の <video> 要素
 *   statusId : ステータスバッジ要素の id
 * ---------------------------------------------------------- */

/* フレーム停止とみなす秒数（currentTimeが進まない継続時間の閾値） */
const STALL_THRESHOLD = 3;

/* カメラごとのタイマーIDを保持するマップ（多重起動防止用） */
const stallTimers = {};

function startStallDetector(videoEl, statusId) {
    /* 既存タイマーがあればクリアして再起動（再接続時の多重起動防止） */
    if (stallTimers[statusId]) {
        clearInterval(stallTimers[statusId]);
    }

    let lastTime      = null;  // 前回チェック時の currentTime
    let stalledSec    = 0;     // currentTime が進んでいない経過秒数
    let isStalled     = false; // 現在stall状態かどうかのフラグ

    /* 1秒ごとに currentTime の進みをチェック */
    stallTimers[statusId] = setInterval(() => {
        /* 映像が再生中でない場合はチェックしない
         * （pause中・未接続中の誤検知を防ぐ） */
        if (videoEl.paused || videoEl.readyState < 2) {
            lastTime = null;
            stalledSec = 0;
            return;
        }

        const currentTime = videoEl.currentTime; // 現在の再生位置（秒）

        if (lastTime !== null) {
            if (currentTime === lastTime) {
                /* currentTime が前回と同じ → フレーム停止中 */
                stalledSec++;
            } else {
                /* currentTime が進んだ → 正常再生に戻った */
                stalledSec = 0;
            }

            if (stalledSec >= STALL_THRESHOLD && !isStalled) {
                /* STALL_THRESHOLD 秒以上停止 → 遅延状態に切り替え */
                isStalled = true;
                setStatus(statusId, 'delayed');
                console.log(`[${statusId}] stall検出: ${stalledSec}秒間フレーム停止`);

            } else if (stalledSec < STALL_THRESHOLD && isStalled) {
                /* 停止秒数が閾値未満に戻った → 接続済みに復帰 */
                isStalled = false;
                setStatus(statusId, 'connected');
                console.log(`[${statusId}] stall解消: 正常再生に復帰`);
            }
        }

        lastTime = currentTime; // 今回の値を次回比較用に保存
    }, 1000); // 1秒間隔でチェック
}

/* ----------------------------------------------------------
 * 全画面オーバーレイ制御
 * ---------------------------------------------------------- */

/* オーバーレイ関連の DOM 要素 */
const overlay      = document.getElementById('fullscreen-overlay');  // オーバーレイ本体
const overlayVideo = document.getElementById('overlay-video');       // オーバーレイ内映像要素
const overlayTitle = document.getElementById('overlay-title');       // オーバーレイ内カメラ名
const backBtn      = document.getElementById('overlay-back-btn');    // 戻るボタン

/* カメラ名の表示ラベルマッピング（data-cam属性値 → 日本語名） */
const CAM_LABELS = {
    swing1:   'ATOM Cam Swing 二階部屋左側',
    atomcam2: 'ATOM Cam 2 玄関',
    swing2:   'ATOM Cam Swing 二階部屋右側',
};

/* ----------------------------------------------------------
 * openFullscreen - 指定カメラを全画面オーバーレイで表示する
 *   camName : カメラ定義の name（data-cam属性値）
 * ---------------------------------------------------------- */
function openFullscreen(camName) {
    /* 対象カメラのグリッド側 video 要素を取得 */
    const srcVideo = document.getElementById(`video-${camName}`);
    if (!srcVideo || !srcVideo.srcObject) {
        /* ストリーム未接続の場合は何もしない */
        return;
    }

    /* オーバーレイ側 video に同じストリームを割り当て（ストリーム共有） */
    overlayVideo.srcObject = srcVideo.srcObject;

    /* カメラ名を表示 */
    overlayTitle.textContent = CAM_LABELS[camName] || camName;

    /* オーバーレイを表示 */
    overlay.classList.remove('hidden');
}

/* ----------------------------------------------------------
 * closeFullscreen - 全画面オーバーレイを閉じてグリッドに戻る
 * ---------------------------------------------------------- */
function closeFullscreen() {
    /* オーバーレイを非表示 */
    overlay.classList.add('hidden');

    /* オーバーレイ側の srcObject を解放（グリッド側は継続再生） */
    overlayVideo.srcObject = null;
}

/* 各カメラパネルにクリックイベントを設定 */
document.querySelectorAll('.camera-panel').forEach((panel) => {
    /* data-cam属性からカメラ名を取得 */
    panel.addEventListener('click', () => {
        const camName = panel.dataset.cam; // data-cam属性値
        openFullscreen(camName);
    });
});

/* オーバーレイ全体クリックで閉じる（映像クリックも含む） */
overlay.addEventListener('click', closeFullscreen);

/* 戻るボタンは伝播を止めてから閉じる（overlay click との二重呼び出し防止） */
backBtn.addEventListener('click', (e) => { e.stopPropagation(); closeFullscreen(); });

/* ============================================================
 * Panel 4: リソースモニター
 *   自クライアントと rpi4-1 の CPU/温度/DiskI/O/メモリを
 *   30秒ごとに取得して Chart.js グラフに表示する。
 * ============================================================ */

/* Chart.js CDN URL（v4 最新） */
const CHARTJS_CDN = 'https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js';

/* 表示時間幅（秒）: 通常パネル=30分、全画面=60分 */
const METRICS_DURATION    = 1800;
const METRICS_DURATION_FS = 3600;

/* 更新間隔（ミリ秒） */
const METRICS_INTERVAL = 30000;

/* ----------------------------------------------------------
 * setMetricsStatus - リソースモニターのバッジ状態を更新する
 *   state : 'fetching' | 'ok' | 'error'
 * ---------------------------------------------------------- */
function setMetricsStatus(state) {
    const map = {
        fetching: { cls: 'connecting',   text: '取得中...' },
        ok:       { cls: 'connected',    text: '正常'      },
        error:    { cls: 'disconnected', text: '取得失敗'  },
    };
    const s = map[state] || map.error;
    ['metrics-status', 'fso-status'].forEach(id => {
        const el = document.getElementById(id);
        if (!el) return;
        el.className = 'status-badge ' + s.cls;
        el.textContent = s.text;
    });
}

/* ----------------------------------------------------------
 * makeChart - Chart.js ラインチャートを生成する
 *   canvasId : canvas 要素の id
 *   yMin     : Y軸最小値（null で自動）
 *   yMax     : Y軸最大値（null で自動）
 * ---------------------------------------------------------- */
function makeChart(canvasId, yMin, yMax) {
    const ctx = document.getElementById(canvasId).getContext('2d');

    const datasetBase = {
        borderWidth: 1.5,
        pointRadius: 0,
        tension: 0.2,
        backgroundColor: 'transparent',
        spanGaps: 60,   /* 60秒未満のギャップは線で繋ぐ、60秒以上は切る */
    };

    return new Chart(ctx, {
        type: 'line',
        data: {
            datasets: [
                { ...datasetBase, label: 'self',   borderColor: '#4da6ff', data: [] },
                { ...datasetBase, label: 'rpi4-1', borderColor: '#ff8c42', data: [] },
            ],
        },
        options: {
            animation: false,
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    labels: { color: '#aaa', font: { size: 9 }, boxWidth: 10, padding: 4 },
                },
            },
            scales: {
                x: {
                    type: 'linear',
                    display: true,
                    /* Chart.js v4 は epoch(0秒) 起点で tick を生成するため
                     * stepSize:300 だと maxTicksLimit でダウンサンプリングされ
                     * 5分境界の tick がほぼ消える。
                     * afterBuildTicks で min〜max の5分刻み tick を直接生成する。 */
                    afterBuildTicks(axis) {
                        if (!axis.min || axis.min < 1000000000) return;
                        const start = Math.ceil(axis.min / 300) * 300;
                        const ticks = [];
                        for (let sec = start; sec <= axis.max; sec += 300) {
                            ticks.push({ value: sec });
                        }
                        axis.ticks = ticks;
                    },
                    ticks: {
                        color: '#aaa',
                        font: { size: 9 },
                        maxRotation: 45,
                        minRotation: 0,
                        callback(value) {
                            const d = new Date(Math.round(value) * 1000);
                            return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
                        },
                    },
                    grid: { color: '#333' },
                },
                y: {
                    min: yMin ?? undefined,
                    max: yMax ?? undefined,
                    ticks: { color: '#aaa', font: { size: 9 }, maxTicksLimit: 4 },
                    grid:  { color: '#333' },
                },
            },
        },
    });
}

/* チャートオブジェクト（Chart.js 読み込み後に生成） */
const metricsCharts = {};

/* 全画面チャートオブジェクトと最終取得データ */
const metricsChartsFS = {};
let fsoInitialized = false;
let lastSelfData   = [];
let lastRpi4Data   = [];

/* ----------------------------------------------------------
 * initMetricsCharts - 4チャートを初期化する
 * ---------------------------------------------------------- */
function initMetricsCharts() {
    metricsCharts.cpu  = makeChart('chart-cpu',  0, 100);
    metricsCharts.temp = makeChart('chart-temp', null, null);
    metricsCharts.disk = makeChart('chart-disk', 0, null);
    metricsCharts.mem  = makeChart('chart-mem',  0, 100);
}

/* ----------------------------------------------------------
 * initMetricsChartsFS - 全画面用4チャートを初期化する
 * ---------------------------------------------------------- */
function initMetricsChartsFS() {
    metricsChartsFS.cpu  = makeChart('fso-chart-cpu',  0, 100);
    metricsChartsFS.temp = makeChart('fso-chart-temp', null, null);
    metricsChartsFS.disk = makeChart('fso-chart-disk', 0, null);
    metricsChartsFS.mem  = makeChart('fso-chart-mem',  0, 100);
}

/* ----------------------------------------------------------
 * tsToUnix - ISO 8601 タイムスタンプ文字列を Unix 秒に変換する
 * ---------------------------------------------------------- */
function tsToUnix(ts) {
    return ts ? Date.parse(ts) / 1000 : -1;
}

/* ----------------------------------------------------------
 * applyDataToChartSet - チャートセットにデータを適用する
 *   chartSet    : metricsCharts または metricsChartsFS
 *   selfData    : 自クライアントの NDJSON 配列
 *   rpi4Data    : rpi4-1 の NDJSON 配列
 *   durationSec : 表示時間幅（秒）
 *
 *   X軸はデータに依存しない独立した時刻軸（Unix秒、linear スケール）。
 *   各データ点を {x: Unix秒, y: 値} で渡す。
 *   spanGaps: 60 により 60秒未満のギャップは線で繋ぎ、60秒以上は切る。
 * ---------------------------------------------------------- */
function applyDataToChartSet(chartSet, selfData, rpi4Data, durationSec) {
    const COLLECT_INTERVAL = 30;  /* 収集間隔(秒) */
    /* +15: 5分境界アライン分(最大300秒=10件)＋余裕5件 */
    const n = Math.ceil(durationSec / COLLECT_INTERVAL) + 15;

    const s = selfData.slice(-n).filter(d => d && d.ts);
    const r = rpi4Data.slice(-n).filter(d => d && d.ts);

    /* 最新 Unix タイムスタンプ(秒)を両データセットから求める */
    let endSec = -1;
    [...s, ...r].forEach(d => {
        const t = tsToUnix(d.ts);
        if (t > endSec) endSec = t;
    });
    if (endSec < 0) return;

    const startSec = endSec - durationSec;

    /* X軸範囲を設定（開始を5分境界に揃える） */
    const minSec = Math.floor(startSec / 300) * 300;
    Object.values(chartSet).forEach(c => {
        c.options.scales.x.min = minSec;
        c.options.scales.x.max = endSec;
    });

    /* 凡例設定（全チャート共通） */
    const sHost = s.length > 0 ? (s[0].hostname || 'self') : null;
    const rHost = r.length > 0 ? (r[0].hostname || 'rpi4-1') : null;
    if (sHost) Object.values(chartSet).forEach(c => { c.data.datasets[0].label = sHost; });
    if (rHost) Object.values(chartSet).forEach(c => { c.data.datasets[1].label = rHost; });

    /* メモリチャートの凡例に総メモリ量 (GB) を付加する */
    const memGB = arr => {
        const d = arr.find(x => x && x.mem_total);
        return d ? Math.round(d.mem_total / 1024 / 1024) : null;
    };
    if (chartSet.mem) {
        const sGB = memGB(s); const rGB = memGB(r);
        if (sHost && sGB) chartSet.mem.data.datasets[0].label = `${sHost} (${sGB}GB)`;
        if (rHost && rGB) chartSet.mem.data.datasets[1].label = `${rHost} (${rGB}GB)`;
    }

    /* データを {x: Unix秒, y: 値} に変換（表示範囲内のみ）
     * minSec より1区間前(65秒)まで含めることで、X軸左端より手前に
     * アンカー点を置き、Chart.jsがクリップ境界から線を描画する */
    const toXY = (data, valFn) => data
        .map(d => ({ x: tsToUnix(d.ts), y: valFn(d) }))
        .filter(p => p.x >= minSec - 65 && p.x <= endSec + 5);

    [
        { chart: chartSet.cpu,  sData: toXY(s, d => d.cpu),                         rData: toXY(r, d => d.cpu) },
        { chart: chartSet.temp, sData: toXY(s, d => d.temp),                        rData: toXY(r, d => d.temp) },
        { chart: chartSet.disk, sData: toXY(s, d => Math.round(d.disk_rw / 1024)),  rData: toXY(r, d => Math.round(d.disk_rw / 1024)) },
        { chart: chartSet.mem,  sData: toXY(s, d => d.mem),                         rData: toXY(r, d => d.mem) },
    ].forEach(({ chart, sData, rData }) => {
        chart.data.datasets[0].data = sData;
        chart.data.datasets[1].data = rData;
        chart.update('none');
    });
}

/* ----------------------------------------------------------
 * fetchNdjson - NDJSON を取得してオブジェクト配列で返す
 *   url     : フェッチ先 URL
 *   returns : Promise<Array>（404 時は空配列）
 * ---------------------------------------------------------- */
async function fetchNdjson(url) {
    const resp = await fetch(url, { cache: 'no-store' });
    if (resp.status === 404) return [];          /* 初回など履歴なし */
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const text = await resp.text();
    return text.trim().split('\n')
        .filter(line => line.trim())
        .map(line => JSON.parse(line));
}

/* ----------------------------------------------------------
 * updateMetricsCharts - 取得データで4チャートを一括更新する
 *   selfData : 自クライアントの NDJSON 配列
 *   rpi4Data : rpi4-1 の NDJSON 配列
 * ---------------------------------------------------------- */
function updateMetricsCharts(selfData, rpi4Data) {
    lastSelfData = selfData;
    lastRpi4Data = rpi4Data;
    applyDataToChartSet(metricsCharts, selfData, rpi4Data, METRICS_DURATION);
    if (fsoInitialized) {
        applyDataToChartSet(metricsChartsFS, selfData, rpi4Data, METRICS_DURATION_FS);
    }
}

/* ----------------------------------------------------------
 * refreshMetrics - メトリクス取得・チャート更新を行う
 *   30秒ごとに呼ばれる。エラー時もバッジ更新して継続。
 * ---------------------------------------------------------- */
async function refreshMetrics() {
    setMetricsStatus('fetching');
    try {
        const [selfData, rpi4Data] = await Promise.all([
            fetchNdjson('/api/my-history'),
            fetchNdjson('/data/rpi4-1-history.ndjson'),
        ]);
        updateMetricsCharts(selfData, rpi4Data);
        setMetricsStatus('ok');
    } catch (err) {
        console.error('[metrics] fetch error:', err);
        setMetricsStatus('error');
    }
}

/* ----------------------------------------------------------
 * Chart.js を CDN から動的ロードして Panel 4 を起動する
 * ---------------------------------------------------------- */
(function startMetricsPanel() {
    const script = document.createElement('script');
    script.src = CHARTJS_CDN;
    script.onload = () => {
        initMetricsCharts();
        refreshMetrics();
        setInterval(refreshMetrics, METRICS_INTERVAL);
    };
    script.onerror = () => {
        console.error('[metrics] Chart.js の読み込みに失敗しました:', CHARTJS_CDN);
        setMetricsStatus('error');
    };
    document.head.appendChild(script);
}());

/* ----------------------------------------------------------
 * openMetricsFullscreen - リソースモニターを全画面表示する
 * ---------------------------------------------------------- */
function openMetricsFullscreen() {
    document.getElementById('fullscreen-metrics-overlay').classList.remove('hidden');
    if (!fsoInitialized) {
        initMetricsChartsFS();
        fsoInitialized = true;
    }
    applyDataToChartSet(metricsChartsFS, lastSelfData, lastRpi4Data, METRICS_DURATION_FS);
}

/* ----------------------------------------------------------
 * closeMetricsFullscreen - リソースモニター全画面を閉じる
 * ---------------------------------------------------------- */
function closeMetricsFullscreen() {
    document.getElementById('fullscreen-metrics-overlay').classList.add('hidden');
}

/* パネルクリックで全画面展開 */
document.getElementById('panel-metrics').addEventListener('click', openMetricsFullscreen);

/* メトリクスオーバーレイ全体クリックで閉じる */
document.getElementById('fullscreen-metrics-overlay').addEventListener('click', closeMetricsFullscreen);

/* 戻るボタンは伝播を止めてから閉じる（overlay click との二重呼び出し防止） */
document.getElementById('fso-back-btn').addEventListener('click', function (e) {
    e.stopPropagation();
    closeMetricsFullscreen();
});
