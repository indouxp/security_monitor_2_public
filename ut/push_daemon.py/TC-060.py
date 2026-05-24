#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-060: X-Real-IPヘッダーで送信元IPが決まる"""
import testlib
from testlib import Daemon, http_post, check, DATA_DIR

DESC = "X-Real-IP ヘッダーのIPでファイル名が決まる"


def main():
    """X-Real-IP を付けて POST し、そのIPでファイルが作られることを確認する"""
    payload = {"hostname": "h", "cpu": 1, "temp": 2, "disk_rw": 3, "mem": 4}
    with Daemon():
        status, _ = http_post("/api/push", payload,
                              headers={"X-Real-IP": "10.20.30.40"})

    check(f"POSTが成功する (実際={status})", status == 200)
    f_xreal = DATA_DIR / "10.20.30.40.json"
    f_local = DATA_DIR / "127.0.0.1.json"
    check("X-Real-IP のIPでファイルが作られる (10.20.30.40.json)", f_xreal.is_file())
    check("接続元IP(127.0.0.1)ではファイルが作られない", not f_local.is_file())


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
