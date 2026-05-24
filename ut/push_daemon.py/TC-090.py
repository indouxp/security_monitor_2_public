#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-090: 必須フィールド欠落は400を返す"""
import testlib
from testlib import Daemon, http_post, check

DESC = "必須フィールド欠落のPOSTは400を返す"


def main():
    """必須フィールド mem を欠落させて POST し、400 / 'missing fields' を確認する"""
    payload = {"hostname": "h", "cpu": 1, "temp": 2, "disk_rw": 3}  # mem 欠落
    with Daemon():
        status, body = http_post("/api/push", payload)
    check(f"必須フィールド欠落は400である (実際={status})", status == 400)
    check(f"レスポンスボディに'missing fields'を含む (実際={body!r})",
          "missing fields" in body)


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
