#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-070: 不正パスへのPOSTは404を返す"""
import testlib
from testlib import Daemon, http_post, check

DESC = "/api/push 以外のパスへのPOSTは404を返す"


def main():
    """/api/push 以外へ POST し、404 / 'not found' が返ることを確認する"""
    payload = {"hostname": "h", "cpu": 1, "temp": 2, "disk_rw": 3, "mem": 4}
    with Daemon():
        status, body = http_post("/api/wrong", payload)
    check(f"不正パスへのPOSTは404である (実際={status})", status == 404)
    check(f"レスポンスボディが'not found'である (実際={body!r})", body == "not found")


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
