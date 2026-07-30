#!/usr/bin/env python3
"""Regression summary — PASS 一行带过，FAIL 摘录原因，供 AI 读摘要免读完整 log"""

import re, sys
from pathlib import Path


def test_name(text, fname):
    m = re.search(r"\+UVM_TESTNAME=(\S+)", text)
    return m.group(1) if m else fname.name.replace("sim_", "").replace(".log", "")


def extract_fail_context(text, max_lines=8):
    """从 log 中提取 FAIL 原因：UVM_ERROR/UVM_FATAL 具体行 + SCB summary + assertion fail"""
    hits = []
    for line in text.splitlines():
        # UVM_ERROR 具体报错行（带 [TAG]，排除末尾 summary 计数行 "UVM_ERROR :  1"）
        if re.match(r"^UVM_ERROR\b", line) and "[" in line:
            hits.append(line.strip()[:200])
        # UVM_FATAL 具体报错行
        elif re.match(r"^UVM_FATAL\b", line) and "[" in line:
            hits.append(line.strip()[:200])
        # SCB summary（mismatch / pending 信息）
        elif re.search(r"Mismatches\s*:\s*[1-9]|Pending in queue\s*:\s*[1-9]", line):
            hits.append(line.strip())
        # SCB_FAIL 标记
        elif "SCB_FAIL" in line or "SCOREBOARD FAILED" in line:
            hits.append(line.strip()[:200])
        # assertion failed at
        elif re.search(r"failed at", line, re.IGNORECASE):
            hits.append(line.strip()[:200])
        # timeout
        elif "PH_TIMEOUT" in line:
            hits.append(line.strip()[:200])
    return hits[:max_lines]


def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(".").resolve()
    logs = sorted(root.glob("sim_*.log"))
    if not logs and (root / "sim.log").exists():
        logs = [root / "sim.log"]

    passed_list = []
    failed_list = []  # [(name, [cause_lines])]

    for log in logs:
        text = log.read_text(encoding="utf-8", errors="ignore")
        name = test_name(text, log)

        err_m = re.search(r"UVM_ERROR\s*:\s*(\d+)", text)
        fat_m = re.search(r"UVM_FATAL\s*:\s*(\d+)", text)
        err   = int(err_m.group(1)) if err_m else -1
        fatal = int(fat_m.group(1)) if fat_m else -1
        scb_fail  = bool(re.search(r"\bSCB_FAIL\b|SCOREBOARD FAILED", text))
        assert_fail = bool(re.search(r"failed at", text, re.IGNORECASE))
        timeout   = bool(re.search(r"PH_TIMEOUT", text))

        ok = (err == 0 and fatal == 0 and not scb_fail and not assert_fail and not timeout)

        if ok:
            passed_list.append(name)
        else:
            failed_list.append((name, extract_fail_context(text)))

    total = len(passed_list) + len(failed_list)
    out = []
    out.append(f"Regression: {len(passed_list)}/{total} PASS, {len(failed_list)} FAIL")
    out.append("")

    # PASS: 一行逗号列表
    if passed_list:
        out.append(f"PASS ({len(passed_list)}): {', '.join(passed_list)}")
    out.append("")

    # FAIL: 每个 test 列出原因
    if failed_list:
        out.append(f"FAIL ({len(failed_list)}):")
        for name, causes in failed_list:
            out.append(f"  [{name}]")
            if causes:
                for c in causes:
                    out.append(f"    {c}")
            else:
                out.append("    (no specific cause captured — check full log)")
    else:
        out.append("No failures.")

    summary = "\n".join(out) + "\n"
    (root / "regression_summary.txt").write_text(summary, encoding="utf-8")
    print(summary, end="")
    return 0 if not failed_list else 1


if __name__ == "__main__":
    raise SystemExit(main())
