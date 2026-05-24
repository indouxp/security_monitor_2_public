#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-100: Content-Lengthが上限超過のPOSTは400を返す"""
import testlib
from testlib import Daemon, http_post, check

DESC = "Content-Length が上限(4096)超過のPOSTは400を返す"


def main():
    """Content-Length に MAX_BODY(4096) 超の値を指定し、400 を確認する"""
    # ボディ本体は小さくし、Content-Length ヘッダーのみ 5000 と申告する
    with Daemon():
        status, body = http_post("/api/push", b"x",
                                 headers={"Content-Length": "5000"})
    check(f"Content-Length が4096超のPOSTは400である (実際={status})", status == 400)
    check(f"レスポンスボディが'invalid Content-Length'である (実際={body!r})",
          body == "invalid Content-Length")


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
