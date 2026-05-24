#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-010: 正常POSTでHTTP 200/okが返る"""
import testlib
from testlib import Daemon, http_post, check

DESC = "正常POSTでHTTP 200/okが返る"


def main():
    """正常な JSON を POST し、200 / 'ok' が返ることを確認する"""
    payload = {"hostname": "testhost", "cpu": 12.3, "temp": 45.6,
               "disk_rw": 1024, "mem": 38.9}
    with Daemon():
        status, body = http_post("/api/push", payload)
    check(f"HTTPステータスが200である (実際={status})", status == 200)
    check(f"レスポンスボディが'ok'である (実際={body!r})", body == "ok")


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
