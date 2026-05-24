#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-030: 履歴ファイルに複数POSTで追記される"""
import testlib
from testlib import Daemon, http_post, check, DATA_DIR

DESC = "履歴ファイル {IP}-history.ndjson に複数POSTで追記される"


def main():
    """3回 POST し、履歴ファイルが3行に追記されることを確認する"""
    payload = {"hostname": "h", "cpu": 1, "temp": 2, "disk_rw": 3, "mem": 4}
    with Daemon():
        http_post("/api/push", payload)
        http_post("/api/push", payload)
        http_post("/api/push", payload)

    hist = DATA_DIR / "127.0.0.1-history.ndjson"
    if not check("履歴ファイル 127.0.0.1-history.ndjson が生成される", hist.is_file()):
        return
    n = len([ln for ln in hist.read_text(encoding="utf-8").splitlines() if ln.strip()])
    check(f"3回POSTで履歴が3行になる (実際={n}行)", n == 3)


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
