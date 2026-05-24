#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-120: GETリクエストは501を返す"""
import testlib
from testlib import Daemon, http_get, check

DESC = "GETリクエストは501を返す（do_POSTのみ実装）"


def main():
    """GET リクエストを送り、未実装メソッドとして 501 が返ることを確認する"""
    with Daemon():
        status, _ = http_get("/api/push")
    check(f"GETリクエストは501である (実際={status})", status == 501)


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
