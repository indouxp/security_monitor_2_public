################################################################################
# 概要 : push_metrics.ps1 単体テスト（Pester 5）
#        試験対象を dot-source して関数を読み込み、OS依存のメトリクス収集関数
#        （Get-Counter / WMI 直結）を Mock で固定したうえで Main 処理を検証する。
#        OS依存の収集関数そのものは Windows 実機でのみ検証可能なため対象外とし、
#        本テストは履歴保存・JSON生成・POST送信・ログ管理を検証する。
# Created : 2026-05-22
# Author  : Tsystem
################################################################################

Describe 'push_metrics.ps1 単体テスト' {

    BeforeAll {
        # 試験対象のフルパス（ut/push_metrics.ps1/ から見た相対位置を解決）
        $SUT = (Resolve-Path (Join-Path $PSScriptRoot '../../inventory/client/win/push_metrics.ps1')).Path
        # 作業ディレクトリ（履歴・ログの出力先）
        $WorkRoot = Join-Path $PSScriptRoot 'work'
    }

    BeforeEach {
        # テスト間で環境変数が漏れないよう、毎回 PUSH_* を消去する
        foreach ($v in 'PUSH_ENDPOINT', 'PUSH_HISTORY_DIR', 'PUSH_MAX_HISTORY', 'PUSH_MAX_LOG') {
            Remove-Item "env:$v" -ErrorAction SilentlyContinue
        }
        # Linux テストホストには COMPUTERNAME が無い。Main が参照するため明示設定する
        $env:COMPUTERNAME = 'TESTHOST'
        # 作業ディレクトリを作り直す
        if (Test-Path $WorkRoot) { Remove-Item $WorkRoot -Recurse -Force }
        New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
    }

    It 'TC-010: 履歴ファイルに7フィールドの JSON が1行追記される' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        Main

        $lines = @(Get-Content $HISTORY_FILE)
        $lines.Count | Should -Be 1
        $obj = $lines[0] | ConvertFrom-Json
        $names = $obj.PSObject.Properties.Name
        foreach ($f in 'hostname', 'ts', 'cpu', 'temp', 'disk_rw', 'mem', 'mem_total') {
            $names | Should -Contain $f
        }
    }

    It 'TC-020: 履歴 JSON の各フィールドが収集値を反映する' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        Main

        $raw = @(Get-Content $HISTORY_FILE)[0]
        $obj = $raw | ConvertFrom-Json
        $obj.hostname  | Should -Be 'testhost'
        $obj.cpu       | Should -Be 12.3
        $obj.temp      | Should -Be 47.5
        $obj.disk_rw   | Should -Be 204800
        $obj.mem       | Should -Be 31.4
        $obj.mem_total | Should -Be 16384000
        # ts は ConvertFrom-Json が [datetime] へ自動変換するため、生 JSON 文字列で形式を検証する
        $raw | Should -Match '"ts":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"'
    }

    It 'TC-030: 複数回実行で履歴が追記される' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        Main; Main; Main

        @(Get-Content $HISTORY_FILE).Count | Should -Be 3
    }

    It 'TC-040: 履歴が MAX_HISTORY 行を超えないようトリミングされる' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        $env:PUSH_MAX_HISTORY = '5'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        1..7 | ForEach-Object { Main }

        @(Get-Content $HISTORY_FILE).Count | Should -Be 5
    }

    It 'TC-050: HISTORY_DIR が存在しない場合は作成される' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'newdir'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        Test-Path $HISTORY_DIR | Should -BeFalse   # 実行前は未存在
        Main
        Test-Path $HISTORY_DIR | Should -BeTrue    # Main が作成する
    }

    It 'TC-060: 収集した JSON が ENDPOINT へ POST される' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        Main

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'Post' -and $Body -match '"hostname":"testhost"'
        }
    }

    It 'TC-070: POST 失敗時も例外で落ちず処理が完了する' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { throw 'connection refused' }

        { Main } | Should -Not -Throw
    }

    It 'TC-080: POST 失敗時も履歴は保存され警告がログに記録される' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { throw 'connection refused' }

        Main

        @(Get-Content $HISTORY_FILE).Count | Should -Be 1
        (Get-Content $LOG_FILE -Raw)       | Should -Match 'POST failed'
    }

    It 'TC-090: ENDPOINT 環境変数の上書きが POST 先に反映される' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        $env:PUSH_ENDPOINT    = 'http://mock.example/api/push'
        . $SUT
        Mock Get-CpuPercent { 12.3 }
        Mock Get-CpuTempC   { 47.5 }
        Mock Get-DiskRwBps  { 204800 }
        Mock Get-MemInfo    { @{ pct = 31.4; total_kb = 16384000 } }
        Mock Invoke-RestMethod { }

        Main

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'http://mock.example/api/push'
        }
    }

    It 'TC-100: Write-Log がタイムスタンプ付きでログ行を追記する' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT
        New-Item -ItemType Directory -Path $HISTORY_DIR -Force | Out-Null

        Write-Log 'unit test message'

        $line = @(Get-Content $LOG_FILE)[-1]
        $line | Should -Match '^\d{8}\.\d{6}: unit test message$'
    }

    It 'TC-110: Trim-Log が MAX_LOG 超過時にログをトリミングする' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        $env:PUSH_MAX_LOG     = '5'
        . $SUT
        New-Item -ItemType Directory -Path $HISTORY_DIR -Force | Out-Null

        1..8 | ForEach-Object { Write-Log "line $_" }
        @(Get-Content $LOG_FILE).Count | Should -Be 8   # トリミング前は8行
        Trim-Log
        @(Get-Content $LOG_FILE).Count | Should -Be 5   # MAX_LOG(5) に収まる
    }

    It 'TC-120: Trim-Log はログファイルが無い場合に何もせずエラーにならない' {
        $env:PUSH_HISTORY_DIR = Join-Path $WorkRoot 'hist'
        . $SUT

        Test-Path $LOG_FILE | Should -BeFalse
        { Trim-Log } | Should -Not -Throw
    }
}
