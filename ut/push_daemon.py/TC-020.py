#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-020: 最新値ファイルが生成され送信値が保存される"""
import testlib
from testlib import Daemon, http_post, check, read_json, DATA_DIR

DESC = "最新値ファイル {IP}.json が生成され送信値が保存される"


def main():
    """POST 後に最新値ファイルが生成され、送信値が保存されることを確認する"""
    payload = {"hostname": "testhost", "cpu": 12.3, "temp": 45.6,
               "disk_rw": 1024, "mem": 38.9}
    with Daemon():
        http_post("/api/push", payload)

    latest = DATA_DIR / "127.0.0.1.json"
    if not check("最新値ファイル 127.0.0.1.json が生成される", latest.is_file()):
        return
    data = read_json(latest)
    check(f"hostname が送信値で保存される (実際={data.get('hostname')!r})",
          data.get("hostname") == "testhost")
    check(f"cpu が送信値で保存される (実際={data.get('cpu')!r})",
          data.get("cpu") == 12.3)
    check(f"mem が送信値で保存される (実際={data.get('mem')!r})",
          data.get("mem") == 38.9)


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
