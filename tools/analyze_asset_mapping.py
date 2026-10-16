#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
只读分析工具：统计 src/ 与 test/ 里对 res://assets/ 的引用，
并按「文件名（不含目录）」在 pak/ 各子目录里寻找原版素材对应。

输出：
  - 控制台：总引用数、去重引用数、去重文件名数、在 pak/ 命中数、未命中数
  - tools/asset_mapping_report.csv：每条去重引用的 原路径 -> pak 命中路径（或空）

本脚本不修改任何文件，仅用于产出「迁移映射方案」的数据底座。
"""
import os
import re
import csv
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
TEST = os.path.join(ROOT, "test")
PAK = os.path.join(ROOT, "pak")

ASSET_RE = re.compile(r'res://assets/([^\s"\'\)]+)')

def scan_refs():
    """返回 dict: 规范化 res://assets/ 路径 -> 出现次数"""
    refs = {}
    for base in (SRC, TEST):
        for dirpath, _, files in os.walk(base):
            for f in files:
                if not (f.endswith(".gd") or f.endswith(".tscn")):
                    continue
                fp = os.path.join(dirpath, f)
                try:
                    with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
                        text = fh.read()
                except Exception:
                    continue
                for m in ASSET_RE.finditer(text):
                    p = "res://assets/" + m.group(1)
                    refs[p] = refs.get(p, 0) + 1
    return refs

def build_pak_index():
    """返回 dict: 文件名(小写) -> pak 内相对 res:// 路径（取第一个命中）"""
    idx = {}
    for dirpath, _, files in os.walk(PAK):
        for f in files:
            # 跳过 Godot 生成的 .import / .uid，按真实文件名索引
            if f.endswith(".import") or f.endswith(".uid"):
                continue
            low = f.lower()
            rel = "res://" + os.path.relpath(os.path.join(dirpath, f), ROOT).replace(os.sep, "/")
            if low not in idx:
                idx[low] = rel
    return idx

def main():
    refs = scan_refs()
    pak_idx = build_pak_index()

    # 去重引用
    uniq = sorted(refs.keys())
    # 文件名（不含目录）
    def basename_of(p):
        return p.rsplit("/", 1)[-1].lower()

    rows = []
    hit = 0
    miss = 0
    for p in uniq:
        bn = basename_of(p)
        pak_path = pak_idx.get(bn, "")
        if pak_path:
            hit += 1
        else:
            miss += 1
        rows.append((p, bn, pak_path, refs[p]))

    total = sum(refs.values())
    print("=" * 60)
    print("assets/ 引用映射分析（按文件名匹配 pak/）")
    print("=" * 60)
    print(f"总引用次数（含重复） : {total}")
    print(f"去重引用条数        : {len(uniq)}")
    print(f"去重文件名数        : {len(set(basename_of(p) for p in uniq))}")
    print(f"在 pak/ 命中（有原版）: {hit}")
    print(f"在 pak/ 未命中       : {miss}")
    print("=" * 60)

    # 输出 CSV
    out = os.path.join(ROOT, "tools", "asset_mapping_report.csv")
    with open(out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["asset_ref", "basename", "pak_target", "ref_count"])
        for r in rows:
            w.writerow(r)
    print(f"明细已写入: {out}")

    # 额外：列出未命中的文件名（assets/ 独有，多半是 AI 生成宽屏/原创素材）
    miss_names = sorted(set(r[1] for r in rows if not r[2]))
    miss_file = os.path.join(ROOT, "tools", "asset_mapping_miss.txt")
    with open(miss_file, "w", encoding="utf-8") as fh:
        for n in miss_names:
            fh.write(n + "\n")
    print(f"未命中文件名清单已写入: {miss_file} （共 {len(miss_names)} 个）")

if __name__ == "__main__":
    main()
