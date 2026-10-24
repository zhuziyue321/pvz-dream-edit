#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复 animation/ 下 15 个二进制 .res（Animation 资源）：
  1) 把 RSCC（zstd 压缩）解成未压缩，满足「不要压缩」；
  2) ext 表里硬编码的 res://assets/... 引用，按文件名迁到 pak/（有原版）或 assets_custom/（无原版）；
  3) ext 表的 uid 统一写成 INVALID_ID（0xFFFFFFFFFFFFFFFF）；
  4) 路径变长/变短时同步平移 int_resource 的绝对偏移。

关于 (3) —— 告警的真正来源（2026-10-16 实测）：
原版 .res 每个外部资源的 uid 字段是 0（原意是「没有 uid，按 text path 解析」）。
Godot 4.6 的 ResourceLoaderBinary 只在 `uid != INVALID_ID` 时才跳过该字段，于是 0 会进
`!ResourceUID.has_id(0)` 分支，对每个外部资源打一条
    In external resource #N, invalid UID: 'uid://a' - using text path instead: ...
（`ResourceUID.id_to_text(0)` 的输出就是 `uid://a`，容易误读成文件里真写了 uid://a）。
写成 INVALID_ID 后运行期行为不变（依旧按 text path 解析），告警消失。
实测：15 个文件共 234 个外部资源，修完全部静默（`--import` 与逐文件 load 均为 0 条）。

关于 (2) 与表定位：迁移完成后 ext 表里已经全是 `res://pak/...`，所以 (2) 现在是空转；
但表定位不能用 `data.find(b"res://assets/")` 当锚点 —— 迁移完就找不到锚点了。
现在锚点是文件里最早的一条资源路径串，并用「表能自洽走完」校验。

用法：
  python tools/fix_res_refs.py            # DRY-RUN，只报告
  python tools/fix_res_refs.py --apply     # 真写盘
"""
import os
import sys
import struct
import zstandard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAK = os.path.join(ROOT, "pak")
APPLY = "--apply" in sys.argv

## Godot 的 ResourceUID::INVALID_ID（「没有 uid」）。
UID_INVALID = 0xFFFFFFFFFFFFFFFF

RES_FILES = [
    "animation/item/lawn_mover/roof_cleaner.res",
    "animation/garden/wateringcan/zen_garden_bug_spray.res",
    "animation/garden/wateringcan/zen_garden_fertilizer.res",
    "animation/character/zombie/zombie_digger/zombie_digger_up.res",
    "animation/character/zombie/zombie_flag/zombie_death.res",
    "animation/character/zombie/zombie_flag/zombie_death2.res",
    "animation/character/zombie/zombie_flag/zombie_eat.res",
    "animation/character/zombie/zombie_flag/zombie_superlongdeath.res",
    "animation/character/zombie/zombie_flag/zombie_walk.res",
    "animation/character/zombie/zombie_flag/zombie_walk2.res",
    "animation/character/plant/grave_buster/all_anims.res",
    "animation/character/plant/pea_shooter_single/head_attack.res",
    "animation/character/plant/pea_shooter_single/head_idle.res",
    "animation/character/plant/pea_shooter_single/idle.res",
    "animation/character/plant/pumpkin/all_anims.res",
]

CAT_PREF = {"reanim": "reanim", "image": "images", "audio": "sounds", "particles": "particles"}


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def decompress_rscc(data):
    """RSCC（zstd 分块压缩）-> 未压缩内容（可能不含 RSRC 魔数）。"""
    cmode = u32(data, 4)
    bs = u32(data, 8)
    total = u32(data, 12)
    bc = total // bs + (1 if total % bs else 0)
    pos = 16
    sizes = [u32(data, pos + 4 * i) for i in range(bc)]
    pos += 4 * bc
    dctx = zstandard.ZstdDecompressor()
    out = bytearray()
    for s in sizes:
        blk = data[pos:pos + s]
        pos += s
        out += dctx.decompress(blk)
    return bytes(out), cmode, bs, total, bc


def build_pak_index():
    idx = {}
    for dp, _, fs in os.walk(PAK):
        for f in fs:
            if f.endswith(".import") or f.endswith(".uid"):
                continue
            rel = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/")
            idx.setdefault(f.lower(), []).append("res://" + rel)
    return idx


def map_target(res_path, pak_idx, misses):
    rel = res_path[len("res://assets/"):]
    bn = rel.rsplit("/", 1)[-1].lower()
    cands = pak_idx.get(bn)
    if cands:
        cat = rel.split("/")[0] if "/" in rel else ""
        pref = CAT_PREF.get(cat)
        if pref:
            for c in cands:
                if c.startswith("res://pak/" + pref + "/"):
                    return c
        return cands[0]
    misses.append(res_path)
    return "res://assets_custom/" + rel


def find_ext_table_start(data):
    """定位 ext_count 字段（ext 表起点）；找不到返回 None。

    锚点 = 文件里**最早**的一条资源路径串（ext 表在 int 表之前，故它属于 ext[0]），
    再往回收它前面的 type 串长度字段。旧版锚点写死 `res://assets/`，迁移完成后必然失效。
    """
    anchors = [p for p in (data.find(b"res://"), data.find(b"local://")) if p >= 0]
    if not anchors:
        return None
    p0 = min(anchors)
    for tl in range(1, 64):
        o = p0 - 4 - tl - 4          # type 串长度字段
        if o >= 4 and u32(data, o) == tl and data[o + 4 + tl - 1] == 0:
            return o - 4             # 再往前 4 字节就是 ext_count
    return None


def _sane(n, lo, hi):
    return lo <= n <= hi


def parse_tables(data):
    """走完 ext + int 两张表；走不通返回 None。

    返回 (exts, ints, has_uid)：
      exts = [(uid字段绝对偏移, path), ...]
      ints = [(path, offset, offset字段绝对偏移), ...]
    `has_uid`（每个 ext 条目是否带 8 字节 uid）用「两种走法哪种自洽」判定，
    不再用 `u32(uid) > 64` 猜 —— 原版文件的 uid 是 0，旧启发式会误判成「没有 uid 字段」。
    """
    start = find_ext_table_start(data)
    if start is None:
        return None
    for has_uid in (True, False):
        pos = start
        ext_count = u32(data, pos)
        pos += 4
        if not _sane(ext_count, 1, 4096):
            continue
        exts = []
        ok = True
        for _ in range(ext_count):
            tl = u32(data, pos)
            pos += 4
            if not _sane(tl, 1, 256) or pos + tl > len(data) or data[pos + tl - 1] != 0:
                ok = False
                break
            pos += tl
            pl = u32(data, pos)
            pos += 4
            if not _sane(pl, 1, 4096) or pos + pl > len(data) or data[pos + pl - 1] != 0:
                ok = False
                break
            path = data[pos:pos + pl - 1].decode("latin1")
            pos += pl
            uid_off = pos
            if has_uid:
                pos += 8
            exts.append((uid_off, path))
        if not ok or not any(e[1].startswith(("res://", "local://")) for e in exts):
            continue
        int_count = u32(data, pos)
        pos += 4
        if not _sane(int_count, 0, 4096):
            continue
        ints = []
        for _ in range(int_count):
            pl = u32(data, pos)
            pos += 4
            if not _sane(pl, 1, 4096) or pos + pl > len(data) or data[pos + pl - 1] != 0:
                ok = False
                break
            path = data[pos:pos + pl - 1].decode("latin1")
            pos += pl
            off = u64(data, pos)
            off_off = pos
            pos += 8
            if off > len(data):
                ok = False
                break
            ints.append((path, off, off_off))
        if not ok:
            continue
        return exts, ints, has_uid
    return None


def rebuild(data, pak_idx, misses, off_shift=0):
    """一次遍历重写：ext 路径迁移 + ext uid -> INVALID_ID + int offset 平移。

    返回 (新字节, [(旧路径, 新路径)], 路径总长度差 D, has_uid)。
    表走不通或格式不认识（没有 uid 字段）时原样返回，绝不乱改。
    """
    parsed = parse_tables(data)
    if parsed is None:
        return data, [], 0, False
    exts, ints, has_uid = parsed
    if not has_uid:
        return data, [], 0, False

    ## key = 输入字节偏移，value = (类型, 替换字节, 消费的输入字节数)
    events = {}
    rewrites = []
    for uid_off, path in exts:
        pl = len(path) + 1
        if path.startswith("res://assets/"):
            tgt = map_target(path, pak_idx, misses)
            new = tgt.encode("latin1")
            rewrites.append((path, tgt))
            ## pascal 串 = [u32 长度(含结尾 0)][bytes][0]，长度字段与串本体一起替换。
            events[uid_off - pl - 4] = (struct.pack("<I", len(new) + 1) + new + b"\x00", 4 + pl)
            events[uid_off] = (struct.pack("<Q", UID_INVALID), 8)
        else:
            events[uid_off] = (struct.pack("<Q", UID_INVALID), 8)
    D = sum(len(t.encode("latin1")) - len(o) for o, t in rewrites)
    for _path, _off, off_off in ints:
        events[off_off] = (struct.pack("<Q", u64(data, off_off) + D + off_shift), 8)

    out = bytearray()
    i = 0
    while i < len(data):
        ev = events.get(i)
        if ev is None:
            out += data[i:i + 1]
            i += 1
            continue
        payload, consume = ev
        out += payload
        i += consume
    return bytes(out), rewrites, D, has_uid


def main():
    pak_idx = build_pak_index()
    for rel in RES_FILES:
        fp = os.path.join(ROOT, rel)
        data = open(fp, "rb").read()
        magic = data[:4]
        if magic == b"RSCC":
            body, cmode, bs, total, bc = decompress_rscc(data)
            plain = body if body[:4] == b"RSRC" else b"RSRC" + body
            ## 解压内容用「不含魔数」坐标时补上 4 字节魔数，int offset 需整体平移。
            off_shift = 0 if body[:4] == b"RSRC" else 4
            header = "RSCC->RSRC"
        else:
            plain = data
            off_shift = 0
            header = "RSRC"
        parsed = parse_tables(plain)
        if parsed is None:
            print("%-58s %s  PARSE FAIL" % (rel, header))
            continue
        exts, ints, has_uid = parsed
        misses = []
        patched, rewrites, D, _ok = rebuild(plain, pak_idx, misses, off_shift)
        uid_old = sum(1 for uid_off, _ in exts
                      if u64(plain, uid_off) != UID_INVALID) if has_uid else 0
        print("%-58s %s ext=%d has_uid=%s paths=%d uid_fix=%d->%d bytes" % (
            rel, header, len(exts), has_uid, len(rewrites), uid_old, len(patched)))
        for old, new in rewrites:
            print("      %s -> %s" % (old, new))
        for m in misses:
            print("      [no pak] %s" % m)
        if APPLY and patched != data:
            open(fp, "wb").write(patched)


if __name__ == "__main__":
    main()
