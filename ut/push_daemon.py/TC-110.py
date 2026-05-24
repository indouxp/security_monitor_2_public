#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-110: 履歴がMAX_HISTORY行に収まるよう古い行が削除される"""
import testlib
from testlib import Daemon, http_post, check, DATA_DIR

DESC = "履歴がMAX_HISTORY行に収まるよう古い行が削除される"


def main():
    """MAX_HISTORY=5 の変種で7回POSTし、履歴が5行に収まることを確認する"""
    payload = {"hostname": "h", "cpu": 1, "temp": 2, "disk_rw": 3, "mem": 4}
    with Daemon("push_daemon_smallhist.py"):
        for _ in range(7):
            http_post("/api/push", payload)

    hist = DATA_DIR / "127.0.0.1-history.ndjson"
    if not check("履歴ファイルが存在する", hist.is_file()):
        return
    n = len([ln for ln in hist.read_text(encoding="utf-8").splitlines() if ln.strip()])
    check(f"7回POSTでも履歴はMAX_HISTORY(5)行に収まる (実際={n}行)", n == 5)


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
