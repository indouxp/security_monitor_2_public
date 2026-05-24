#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-050: ts未指定POSTでサーバ側がtsを自動付与する"""
import testlib
from testlib import Daemon, http_post, check, read_json, DATA_DIR

DESC = "ts未指定POSTでサーバ側が ts を自動付与する"


def main():
    """ts を含めずに POST し、保存データに ts が付与されることを確認する"""
    payload = {"hostname": "h", "cpu": 1, "temp": 2, "disk_rw": 3, "mem": 4}
    with Daemon():
        status, _ = http_post("/api/push", payload)

    check(f"POSTが成功する (実際={status})", status == 200)
    latest = DATA_DIR / "127.0.0.1.json"
    if not check("最新値ファイルが存在する", latest.is_file()):
        return
    data = read_json(latest)
    check(f"ts が未指定でもサーバ側で自動付与される (実際={data.get('ts')!r})",
          bool(data.get("ts")))


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
