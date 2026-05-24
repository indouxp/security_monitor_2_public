#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-080: 不正なJSONボディは400を返す"""
import testlib
from testlib import Daemon, http_post, check

DESC = "不正なJSONボディは400を返す"


def main():
    """JSON として解釈できないボディを POST し、400 / 'invalid JSON' を確認する"""
    with Daemon():
        status, body = http_post("/api/push", "this is not json{")
    check(f"不正JSONは400である (実際={status})", status == 400)
    check(f"レスポンスボディが'invalid JSON'である (実際={body!r})",
          body == "invalid JSON")


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
