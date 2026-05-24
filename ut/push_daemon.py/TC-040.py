#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TC-040: 最新値ファイルは毎回上書きされる"""
import testlib
from testlib import Daemon, http_post, check, read_json, DATA_DIR

DESC = "最新値ファイルは毎回上書きされ直近POSTの値のみ保持する"


def main():
    """2回 POST し、最新値ファイルが直近の値で上書きされ1件のみであることを確認する"""
    with Daemon():
        http_post("/api/push", {"hostname": "h", "cpu": 1, "temp": 2,
                                "disk_rw": 3, "mem": 4})
        http_post("/api/push", {"hostname": "h", "cpu": 9, "temp": 8,
                                "disk_rw": 7, "mem": 6})

    latest = DATA_DIR / "127.0.0.1.json"
    if not check("最新値ファイルが存在する", latest.is_file()):
        return
    data = read_json(latest)
    check(f"最新値ファイルが直近POSTの値で上書きされる (cpu実際={data.get('cpu')!r})",
          data.get("cpu") == 9)
    lines = [ln for ln in latest.read_text(encoding="utf-8").splitlines() if ln.strip()]
    check(f"最新値ファイルは1件のみ (実際={len(lines)}行)", len(lines) == 1)


if __name__ == "__main__":
    testlib.run(main, __file__, DESC)
