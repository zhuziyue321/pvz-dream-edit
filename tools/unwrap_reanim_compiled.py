#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
unwrap_reanim_compiled.py

把 PopCap 的 `*.reanim.compiled` 文件剥壳成干净的 `.reanim` 二进制。

背景：
  PopCap 资源打包时给 reanim 套了一层 "compiled" 壳：
    字节 0..3  : 魔数 0xDEADFED4  (D4 FE AD DE)
    字节 4..7  : 解压后大小 (小端 uint32)
    字节 8..   : zlib 压缩流
  剥掉前 8 字节并 zlib 解压，得到的就是标准 PvZ reanim 二进制
  （含 fps=12.0、轨道名 anim_idle 等、图片引用 IMAGE_REANIM_*）。

PVZ 的 reanim 转换工具（R2Ga_PVZ 的 `PVZ_reanim2godot_animation.exe`，
该插件 2026-10-18 已移出本仓库）只认裸 `.reanim`，
所以这个脚本是把它接入现有动画管线的前置步骤。

用法：
  python tools/unwrap_reanim_compiled.py <目录> [--apply] [--recursive]

默认只打印计划（预演），加 --apply 才真的写盘。
--recursive 时递归遍历子目录。
"""
import os
import sys
import zlib

MAGIC = b"\xD4\xFE\xAD\xDE"
HEADER_LEN = 8


def unwrap_one(src_path: str) -> bytes | None:
    with open(src_path, "rb") as f:
        data = f.read()
    if data[:4] != MAGIC:
        return None
    try:
        return zlib.decompress(data[HEADER_LEN:])
    except zlib.error as e:
        print(f"  [NG] zlib 解压失败: {src_path} ({e})")
        return None


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    root = sys.argv[1]
    apply = "--apply" in sys.argv
    recursive = "--recursive" in sys.argv

    walker = os.walk(root) if recursive else [(root, [], sorted(
        f for f in os.listdir(root) if os.path.isfile(os.path.join(root, f))
    ))]

    count = 0
    ok = 0
    for dirpath, _dirs, files in walker:
        for name in files:
            if not name.lower().endswith(".reanim.compiled"):
                continue
            count += 1
            src = os.path.join(dirpath, name)
            out_name = name[: -len(".compiled")]  # PultShroom.reanim.compiled -> PultShroom.reanim
            dst = os.path.join(dirpath, out_name)
            inner = unwrap_one(src)
            if inner is None:
                print(f"  [SKIP] 非 compiled 壳或解压失败: {src}")
                continue
            if os.path.exists(dst):
                print(f"  [EXISTS] 已存在，跳过: {dst}")
                ok += 1
                continue
            if apply:
                with open(dst, "wb") as f:
                    f.write(inner)
                print(f"  [OK] {src} -> {dst} ({len(inner)} bytes)")
            else:
                print(f"  [PLAN] {src} -> {dst} ({len(inner)} bytes)")
            ok += 1

    print(f"\n扫描到 {count} 个 .reanim.compiled，可处理 {ok} 个。"
          f"{'已写盘。' if apply else '（预演，未写盘；加 --apply 执行）'}")


if __name__ == "__main__":
    main()
