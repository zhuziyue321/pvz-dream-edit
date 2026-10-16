#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
【草案 / 未执行】assets/ 引用 -> pak/ 原版素材 批量迁移脚本

设计前提（来自映射分析 tools/analyze_asset_mapping.py）：
  - src/ + test/ 共 1574 条去重 res://assets/ 引用，按文件名在 pak/ 命中 1473 条，
    约 100 条（字体 / 项目原创 / BGM 原声带等）在 pak/ 无对应，需保留在 assets/。
  - pak/ 按类型分桶（images/ sounds/ reanim/ data/ particles/ properties/ compiled/），
    assets/ 是另一套层级，因此不能做「前缀替换」，必须按「整条路径 -> pak 命中路径」替换。

行为：
  - 默认 DRY-RUN：只打印将要改动的文件/引用，不写盘。
  - --apply：真正改写 .gd / .tscn 文件。
  - --scope <相对路径>：只处理该子目录（如 src/entities），用于「慢慢搬」。
  - 对 .tscn：改写 ext_resource 的 path 后，同时剥离该行失效的 uid="uid://..."，
    避免 Godot 按 uid 解析到错误/不存在的资源。
  - 仅当「文件名（含扩展名，小写）确实存在于 pak/」时才改写，
    因此 .gd 注释里的噪声（如「res://assets/image/background/*.jpg）」）天然被跳过，
    无 pak 对应的素材也保持原样留在 assets/。

注意（硬约束）：
  - 改写后必须跑 test/check_scripts.ps1 编译门禁。
  - 每搬一批建议打开游戏实测（尤其是 .tscn 资源失效会导致场景打不开）。

用法示例：
  python tools/migrate_assets_to_pak.py                 # 预览全部
  python tools/migrate_assets_to_pak.py --scope src/entities
  python tools/migrate_assets_to_pak.py --scope src/entities --apply
"""
import os
import re
import sys
import argparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
TEST = os.path.join(ROOT, "test")
ANIMATION = os.path.join(ROOT, "animation")
DATA = os.path.join(ROOT, "data")
MODS_BUILTIN = os.path.join(ROOT, "mods_builtin")
PAK = os.path.join(ROOT, "pak")

ASSET_PATH_RE = re.compile(r'res://assets/([^\s"\')]+)')
# 匹配 [ext_resource ... uid="uid://..." ...] 里的 uid 属性
TSCN_UID_RE = re.compile(r'\s+uid="uid://[^"]*"')


def build_pak_index():
    """basename(小写,含扩展名) -> pak 内所有 res:// 路径列表（用于类别优先 + 碰撞检测）。"""
    idx = {}
    for dirpath, _, files in os.walk(PAK):
        for f in files:
            if f.endswith(".import") or f.endswith(".uid"):
                continue
            low = f.lower()
            rel = "res://" + os.path.relpath(os.path.join(dirpath, f), ROOT).replace(os.sep, "/")
            idx.setdefault(low, []).append(rel)
    return idx


# assets/ 类别 -> pak/ 子目录（优先匹配，避免同名多位置选错）
CAT_PREF = {
    "image": "pak/images/",
    "reanim": "pak/reanim/",
    "audio": "pak/sounds/",
    "particles": "pak/particles/",
}


def resolve_target(asset_full, pak_idx):
    """给定 res://assets/<cat>/.../X，返回 pak 命中路径；无则返回 None。

    优先按原类别匹配 pak 子目录；该子目录无命中时回落到任意 pak 位置（并标记 fallback）。
    """
    bn = asset_full.rsplit("/", 1)[-1].lower()
    locs = pak_idx.get(bn)
    if not locs:
        return None, False
    seg = asset_full[len("res://assets/"):].split("/")[0].lower()
    pref = CAT_PREF.get(seg)
    if pref:
        needle = "res://" + pref  # 如 "res://pak/images/"
        for loc in locs:
            if loc.lower().startswith(needle):
                return loc, False
        # 优先类别无命中，回落到任意位置
        return locs[0], True
    return locs[0], False


def rewrite_gd(text, pak_idx, changes, fallbacks):
    def repl(m):
        full = "res://assets/" + m.group(1)
        target, fb = resolve_target(full, pak_idx)
        if target:
            if fb:
                fallbacks.append((full, target))
            changes.append((full, target))
            return target
        return full
    return ASSET_PATH_RE.sub(repl, text)


def rewrite_tscn(text, pak_idx, changes, fallbacks):
    out_lines = []
    for line in text.split("\n"):
        if 'path="res://assets/' in line:
            m = ASSET_PATH_RE.search(line)
            if m:
                full = "res://assets/" + m.group(1)
                target, fb = resolve_target(full, pak_idx)
                if target:
                    line = line.replace('path="%s"' % full, 'path="%s"' % target)
                    # 剥离失效 uid，避免 Godot 按 uid 解析
                    line = TSCN_UID_RE.sub("", line)
                    if fb:
                        fallbacks.append((full, target))
                    changes.append((full, target))
        out_lines.append(line)
    return "\n".join(out_lines)


def process_file(fp, pak_idx, apply, stats, fallbacks):
    ext = os.path.splitext(fp)[1]
    if ext not in (".gd", ".tscn", ".tres"):
        return
    try:
        with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
    except Exception as e:
        print(f"[skip-read] {fp}: {e}")
        return
    if "res://assets/" not in text:
        return
    changes = []
    if ext == ".gd":
        new_text = rewrite_gd(text, pak_idx, changes, fallbacks)
    else:
        new_text = rewrite_tscn(text, pak_idx, changes, fallbacks)
    if not changes:
        return
    stats["files"] += 1
    stats["refs"] += len(changes)
    if apply:
        with open(fp, "w", encoding="utf-8") as fh:
            fh.write(new_text)
        print(f"[apply] {os.path.relpath(fp, ROOT)}  ({len(changes)} refs)")
    else:
        print(f"[preview] {os.path.relpath(fp, ROOT)}  ({len(changes)} refs)")
        for old, new in changes[:5]:
            print(f"        {old}  ->  {new}")
        if len(changes) > 5:
            print(f"        ... +{len(changes) - 5} more")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="真正写盘（默认仅预览）")
    ap.add_argument("--scope", default=None, help="只处理该相对子目录，如 src/entities")
    args = ap.parse_args()

    pak_idx = build_pak_index()
    # 碰撞：同名出现在多个 pak 位置
    collisions = {bn: locs for bn, locs in pak_idx.items() if len(locs) > 1}
    if collisions:
        print(f"[碰撞] pak/ 内 {len(collisions)} 个文件名出现在多位置，已按原类别优先选；"
              f"若回落到非优先位置会在末尾 [fallback] 列出：")
        for bn, locs in list(collisions.items())[:20]:
            print(f"        {bn}: {locs}")

    scope_abs = None
    if args.scope:
        scope_abs = os.path.join(ROOT, args.scope)
        if not os.path.isdir(scope_abs):
            print(f"[error] scope 不存在: {scope_abs}")
            sys.exit(1)

    stats = {"files": 0, "refs": 0}
    fallbacks = []
    targets = [scope_abs] if scope_abs else [SRC, TEST, ANIMATION, DATA, MODS_BUILTIN]
    for base in targets:
        for dirpath, _, files in os.walk(base):
            for f in files:
                if f.endswith((".gd", ".tscn", ".tres")):
                    process_file(os.path.join(dirpath, f), pak_idx, args.apply, stats, fallbacks)

    print("=" * 60)
    mode = "APPLY(已写盘)" if args.apply else "DRY-RUN(未写盘)"
    print(f"模式: {mode}")
    print(f"改动文件数: {stats['files']}")
    print(f"改动引用数: {stats['refs']}")
    if fallbacks:
        print(f"[fallback] {len(fallbacks)} 处：优先类别无命中，回落到其它 pak 位置，需人工核对：")
        for old, new in fallbacks[:30]:
            print(f"        {old}  ->  {new}")
    print("=" * 60)
    if not args.apply:
        print("以上为预览。确认无误后加 --apply 执行；建议配合 --scope 分批迁移。")


if __name__ == "__main__":
    main()
