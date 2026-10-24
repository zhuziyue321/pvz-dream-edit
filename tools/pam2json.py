#!/usr/bin/env python3
"""PAM(PopAnim, PvZ2 的 .PAM 二进制动画) -> JSON 转换器。

格式依据: pam-viewer-cs 的 SexyFramework/WidgetsLib/PopAnim.cs
  Load() / LoadSpriteDef() 两个函数是权威读法(已逐行核对), 要点:
    · 头: magic 0xBAF01954 | version(i32) | 帧率(u8) | 矩形 x,y,w,h(4×i16, ÷20)
          | 镜像数(i16); 矩形就对应 json 的 position/size
    · 镜像: 名字(u16 长度前缀) | 宽高(i16, version>=4) | 变换 4×i32(÷1310720) + 2×i16(÷20)
          → [m00,m01,m10,m11,m02,m12]
    · sprite: 名字(>=4) | 描述(>=6) | 帧率(i32÷65536) | 帧数(i16) | 工作区(>=5, 2×i16)
          每帧: 1 字节标志位, 按位依次读 REMOVES(1) / ADDS(2) / MOVES(4) / 帧名(8) / STOP(16) / 命令(32)
             ADDS: 对象标志 u16(低 11 位=对象号, 0x8000 是 sprite, 0x4000 加色, 0x2000 预载帧,
                   0x1000 自定义名, 0x0800 时间缩放) + 资源号 u8(>=6 时 255 → i16) + 可选字段
             MOVES: 移动标志 u16(低 10 位=对象号, 0x1000 矩阵 4×i32÷65536, 0x4000 旋转 i16÷1000,
                   0x0800 长坐标 2×i32÷20 否则 2×i16÷20, 0x8000 源矩形 4×i16÷20,
                   0x2000 颜色 4×u8, 0x0400 动画帧号 i16)
             ★ 每次 MOVE 都是"新建一个变换": 有矩阵/旋转位才带线性部分, 否则线性部分回单位阵,
               平移永远来自坐标字段(旋转版本 2 时 sin 取反)。

JSON 输出对齐"完好批次"(atlantis/beach 那批)的字段方言:
    {version, frame_rate, position[2], size[2],
     image:[{name, size[2], transform[6]}],
     sprite:[{name, description, frame_rate, work_area[2],
              frame:[{label, stop, command[{command,parameter}], remove[{index}],
                      append[{index,name,resource,sprite,additive,preload_frames,timescale}],
                      change[{index,transform,color,src_rect,anim_frame_num}]}]}],
     main_sprite:{...}}
  变换的三种写法(与源文件编码对应): 纯平移 -> [tx,ty]; 旋转 -> [cos,tx,ty]; 矩阵 -> [m00,m01,m10,m11,tx,ty]

用法:
    # 单个文件 / 整个目录
    python tools/pam2json.py <xxx.PAM | 目录> [-o 输出] [--overwrite]
    # 只校验(拿同名 json 对账, 不写文件)
    python tools/pam2json.py <目录> --diff
"""
import argparse
import collections
import json
import math
import pathlib
import re
import struct
import sys

MAGIC = 0xBAF01954
FRAMEFLAGS_HAS_REMOVES = 1
FRAMEFLAGS_HAS_ADDS = 2
FRAMEFLAGS_HAS_MOVES = 4
FRAMEFLAGS_HAS_FRAME_NAME = 8
FRAMEFLAGS_HAS_STOP = 16
FRAMEFLAGS_HAS_COMMANDS = 32
MOVEFLAGS_HAS_SRCRECT = 0x8000
MOVEFLAGS_HAS_ROTATE = 0x4000
MOVEFLAGS_HAS_COLOR = 0x2000
MOVEFLAGS_HAS_MATRIX = 0x1000
MOVEFLAGS_HAS_LONGCOORDS = 0x0800
MOVEFLAGS_HAS_ANIMFRAMENUM = 0x0400
ADDFLAGS_IS_SPRITE = 0x8000
ADDFLAGS_IS_ADDITIVE = 0x4000
ADDFLAGS_HAS_PRELOAD = 0x2000
ADDFLAGS_HAS_NAME = 0x1000
ADDFLAGS_HAS_TIMESCALE = 0x0800


class Reader:
    def __init__(self, data: bytes):
        self.d = data
        self.p = 0

    def u8(self) -> int:
        v = self.d[self.p]
        self.p += 1
        return v

    def i16(self) -> int:
        v = struct.unpack_from("<h", self.d, self.p)[0]
        self.p += 2
        return v

    def u16(self) -> int:
        v = struct.unpack_from("<H", self.d, self.p)[0]
        self.p += 2
        return v

    def i32(self) -> int:
        v = struct.unpack_from("<i", self.d, self.p)[0]
        self.p += 4
        return v

    def u32(self) -> int:
        v = struct.unpack_from("<I", self.d, self.p)[0]
        self.p += 4
        return v

    def boolean(self) -> bool:
        return self.u8() != 0

    def string(self) -> str:
        """u16 长度前缀 + UTF-8"""
        n = self.u16()
        raw = self.d[self.p:self.p + n]
        self.p += n
        return raw.decode("utf-8", "replace")


def read_sprite(r: Reader, version: int, file_rate: int, sprite_names: list) -> dict:
    if version >= 4:
        name = r.string()
        sprite_names.append(name)
        description = ""
        if version >= 6:
            description = r.string()
            sprite_names.append(description)
        anim_rate = r.i32() / 65536.0
    else:
        name, description = None, ""
        anim_rate = float(file_rate)
    frame_count = r.i16()
    if version >= 5:
        work_start = r.i16()
        ## 原始第二个值是"末帧下标", 完好批次 json 存的是"帧数" = 下标+1
        work_end = r.i16() + 1
    else:
        work_start, work_end = 0, frame_count
    out = {
        "name": name,
        "description": description,
        "frame_rate": anim_rate,
        "work_area": [work_start, work_end],
        "frame": [],
    }

    live = {}
    for _ in range(frame_count):
        flags = r.u8()
        frame = {
            "label": None, "stop": False, "command": [],
            "remove": [], "append": [], "change": [],
        }
        ## 本帧被 ADD / MOVE 触及的对象 -> change 列表内容(完好批次就是这么取的)
        touched = set()
        if flags & FRAMEFLAGS_HAS_REMOVES:
            n = r.u8()
            if n == 255:
                n = r.u16()
            for _ in range(n):
                obj = r.i16()
                if obj >= 2047:
                    obj = r.i32()
                live.pop(obj, None)
                frame["remove"].append({"index": obj})
        if flags & FRAMEFLAGS_HAS_ADDS:
            n = r.u8()
            if n == 255:
                n = r.u16()
            for _ in range(n):
                obj_flags = r.u16()
                obj_num = obj_flags & 2047
                if obj_num == 2047:
                    obj_num = r.i32()
                res_num = r.u8()
                if version >= 6 and res_num == 255:
                    res_num = r.i16()
                preload = r.i16() if obj_flags & ADDFLAGS_HAS_PRELOAD else 0
                obj_name = None
                if obj_flags & ADDFLAGS_HAS_NAME:
                    obj_name = r.string()
                    sprite_names.append(obj_name)
                timescale = r.i32() / 65536.0 if obj_flags & ADDFLAGS_HAS_TIMESCALE else 1.0
                live[obj_num] = {
                    "matrix": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
                    "rot": None,
                    "color": None,
                    "src_rect": None,
                    "anim_frame_num": 0,
                }
                touched.add(obj_num)
                frame["append"].append({
                    "index": obj_num,
                    "name": obj_name,
                    "resource": res_num,
                    "sprite": bool(obj_flags & ADDFLAGS_IS_SPRITE),
                    "additive": bool(obj_flags & ADDFLAGS_IS_ADDITIVE),
                    "preload_frames": preload,
                    "timescale": int(timescale) if timescale == int(timescale) else timescale,
                })
        if flags & FRAMEFLAGS_HAS_MOVES:
            n = r.u8()
            if n == 255:
                n = r.u16()
            for _ in range(n):
                move_flags = r.u16()
                obj_num = move_flags & 1023
                if obj_num == 1023:
                    obj_num = r.i32()
                linear = None
                rot = None
                if move_flags & MOVEFLAGS_HAS_MATRIX:
                    f = [r.i32() / 65536.0 for _ in range(4)]
                    ## 文件序(f0,f1,f2,f3) 与完好批次 json 的 (m00,m01,m10,m11) 差一次对调
                    linear = [f[0], f[2], f[1], f[3]]
                elif move_flags & MOVEFLAGS_HAS_ROTATE:
                    ## 完好批次把旋转写成 [原始值/1000, tx, ty], 不还原成 cos/sin 矩阵
                    rot = r.i16() / 1000.0
                if move_flags & MOVEFLAGS_HAS_LONGCOORDS:
                    tx, ty = r.i32() / 20.0, r.i32() / 20.0
                else:
                    tx, ty = r.i16() / 20.0, r.i16() / 20.0
                st = live.setdefault(obj_num, {
                    "matrix": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0], "rot": None,
                    "color": None, "src_rect": None, "anim_frame_num": 0,
                })
                ## 每次 MOVE 都是"新建变换": 没带的字段一律回默认(线性=单位阵, 颜色/源矩形=空, 帧号=0)
                lin = linear if linear is not None else [1.0, 0.0, 0.0, 1.0]
                st["matrix"] = [lin[0], lin[1], lin[2], lin[3], tx, ty]
                st["rot"] = rot
                ## 注意: 读字节的顺序是 src_rect -> color -> anim_frame_num, 不能调换
                st["src_rect"] = [r.i16() / 20.0 for _ in range(4)] \
                    if move_flags & MOVEFLAGS_HAS_SRCRECT else None
                st["color"] = [r.u8() for _ in range(4)] if move_flags & MOVEFLAGS_HAS_COLOR else None
                st["anim_frame_num"] = r.i16() if move_flags & MOVEFLAGS_HAS_ANIMFRAMENUM else 0
                touched.add(obj_num)
        if flags & FRAMEFLAGS_HAS_FRAME_NAME:
            frame["label"] = r.string()
            sprite_names.append(frame["label"])
        if flags & FRAMEFLAGS_HAS_STOP:
            frame["stop"] = True
        if flags & FRAMEFLAGS_HAS_COMMANDS:
            n = r.u8()
            for _ in range(n):
                cmd = r.string()
                param = r.string()
                sprite_names.extend([cmd, param])
                frame["command"].append({"command": cmd, "parameter": param})
        ## change 列表 = 本帧被 ADD/MOVE 触及的对象(按对象号排序), 值取该对象的累计状态
        for obj_num in sorted(touched):
            st = live.get(obj_num)
            if st is None:
                continue
            frame["change"].append({
                "index": obj_num,
                "matrix": list(st["matrix"]),
                "rot": st["rot"],
                "color": list(st["color"]) if st["color"] is not None else None,
                "src_rect": st["src_rect"],
                "anim_frame_num": st["anim_frame_num"],
            })
        out["frame"].append(frame)
    return out


def parse_pam(path: pathlib.Path) -> dict:
    r = Reader(path.read_bytes())
    magic = r.u32()
    if magic != MAGIC:
        raise ValueError("不是 PAM 文件(魔术字 0x%08X)" % magic)
    version = r.i32()
    frame_rate = r.u8()
    pos = [_num(r.i16() / 20.0) for _ in range(2)]
    size = [_num(r.i16() / 20.0) for _ in range(2)]
    image_count = r.u16()
    images = []
    for _ in range(image_count):
        name = r.string()
        if version >= 4:
            ow, oh = r.i16(), r.i16()
        else:
            ow, oh = -1, -1
        if version == 1:
            angle = r.i16() / 1000.0
            m = [math.cos(angle), -math.sin(angle), math.sin(angle), math.cos(angle)]
            m += [r.i16() / 20.0, r.i16() / 20.0]
        else:
            m = [r.i32() / 1310720.0 for _ in range(4)]
            m += [r.i16() / 20.0, r.i16() / 20.0]
        images.append({"name": name, "size": [ow, oh], "transform": m})
    names = []
    sprite_count = r.i16()
    sprites = [read_sprite(r, version, frame_rate, names) for _ in range(sprite_count)]
    main = None
    if version >= 4:
        has_main = r.boolean()
        if has_main:
            main = read_sprite(r, version, frame_rate, names)
    else:
        main = read_sprite(r, version, frame_rate, names)
    return {
        "version": version,
        "frame_rate": frame_rate,
        "position": pos,
        "size": size,
        "image": images,
        "sprite": sprites,
        "main_sprite": main,
        "_parsed_bytes": r.p,
        "_total_bytes": len(r.d),
        "_sprite_names": names,
    }


def _num(v):
    """整数值写成 int(和完好批次一致: 颜色 [1,1,1,0] 而不是 [1.0,1.0,1.0,0.0])"""
    if isinstance(v, float) and v == int(v):
        return int(v)
    return v


## indent=2 下每个数字都独占一行, 所以按行改写科学计数法的大小写是安全的
_EXP_RE = re.compile(r"^(\s*-?\d[\d.]*)[eE]([-+]?\d+)(,?)$")
_HEX_RE = re.compile(r"\\u([0-9a-fA-F]{4})")


def dumps(data, ensure_ascii: bool = True) -> str:
    """json.dumps 的方言版(与完好批次逐字节一致):

    · 科学计数法用大写 E(原导出器是 .NET 风格)
    · \\uXXXX 的十六进制用大写
    · 默认 ensure_ascii=True, 非 ASCII 名字照样转义; 要中文原样可传 False
    """
    text = json.dumps(data, ensure_ascii=ensure_ascii, indent=2)
    if ensure_ascii:
        text = _HEX_RE.sub(lambda m: "\\u" + m.group(1).upper(), text)

    def fix(line: str) -> str:
        m = _EXP_RE.match(line)
        return "%sE%s%s" % (m.group(1), m.group(2), m.group(3)) if m else line

    return "\n".join(fix(ln) for ln in text.split("\n"))


def to_dialect(anim: dict) -> dict:
    def sprite_out(sp: dict) -> dict:
        frames = []
        for fr in sp["frame"]:
            changes = []
            for ch in fr["change"]:
                m = ch["matrix"]
                tx, ty = _num(m[4]), _num(m[5])
                lin = [m[0], m[1], m[2], m[3]]
                if ch["rot"] is not None:
                    ## 带旋转位 -> [旋转值, tx, ty]
                    transform = [_num(ch["rot"]), tx, ty]
                elif lin == [1.0, 0.0, 0.0, 1.0]:
                    ## 线性部分为单位阵 -> 纯平移 [tx, ty]
                    transform = [tx, ty]
                else:
                    transform = [_num(v) for v in m]
                color = None
                if ch["color"] is not None:
                    color = [_num(c / 255.0) for c in ch["color"]]
                changes.append({
                    "index": ch["index"],
                    "transform": transform,
                    "color": color,
                    "src_rect": None if ch["src_rect"] is None
                    else [_num(v) for v in ch["src_rect"]],
                    "anim_frame_num": ch["anim_frame_num"],
                })
            frames.append({
                "label": fr["label"],
                "stop": fr["stop"],
                "command": fr["command"],
                "remove": fr["remove"],
                "append": fr["append"],
                "change": changes,
            })
        return {
            "name": sp["name"] if sp["name"] is not None else "",
            "description": sp["description"] or "",
            "frame_rate": _num(sp["frame_rate"]),
            "work_area": sp["work_area"],
            "frame": frames,
        }

    out = {
        "version": anim["version"],
        "frame_rate": anim["frame_rate"],
        "position": anim["position"],
        "size": anim["size"],
        "image": [{
            "name": im["name"],
            "size": im["size"],
            "transform": [_num(v) for v in im["transform"]],
        } for im in anim["image"]],
        "sprite": [sprite_out(sp) for sp in anim["sprite"]],
        "main_sprite": sprite_out(anim["main_sprite"]) if anim["main_sprite"] else None,
    }
    return out


def convert_one(src: pathlib.Path, dst: pathlib.Path, overwrite: bool) -> str:
    if dst.exists() and not overwrite:
        return "跳过(已存在, 加 --overwrite 覆盖): %s" % dst.name
    anim = parse_pam(src)
    if anim["_parsed_bytes"] != anim["_total_bytes"]:
        return ("解析异常: 只消费 %d / %d 字节(格式不符), 未写出"
                % (anim["_parsed_bytes"], anim["_total_bytes"]))
    data = to_dialect(anim)
    dst.write_text(dumps(data), encoding="utf-8")
    return "写出 %s (%d 镜像, %d sprite, main=%s)" % (
        dst.name, len(data["image"]), len(data["sprite"]), bool(data["main_sprite"]))


def _deep_diff(exp, got, path: str, out: list, limit: int) -> None:
    """把 exp(完好 json) 与 got(本次转换) 的差异收集进 out(最多 limit 条)。"""
    if len(out) >= limit:
        return
    if type(exp) is not type(got):
        ## int/float 混写视为"数值相同"(例如 1 与 1.0)
        if isinstance(exp, (int, float)) and isinstance(got, (int, float)) and exp == got:
            return
        out.append("%s: 类型 %s -> %s" % (path, type(exp).__name__, type(got).__name__))
        return
    if isinstance(exp, dict):
        for k in exp:
            if k not in got:
                out.append("%s.%s: 缺少(exp=%s)" % (path, k, json.dumps(exp[k], ensure_ascii=False)[:80]))
            else:
                _deep_diff(exp[k], got[k], "%s.%s" % (path, k), out, limit)
        for k in got:
            if k not in exp:
                out.append("%s.%s: 多出(got=%s)" % (path, k, json.dumps(got[k], ensure_ascii=False)[:80]))
        return
    if isinstance(exp, list):
        if len(exp) != len(got):
            out.append("%s: 长度 %d -> %d" % (path, len(exp), len(got)))
            return
        for i, (a, b) in enumerate(zip(exp, got)):
            _deep_diff(a, b, "%s[%d]" % (path, i), out, limit)
        return
    if exp != got:
        out.append("%s: %s -> %s" % (path, json.dumps(exp, ensure_ascii=False)[:80],
                                     json.dumps(got, ensure_ascii=False)[:80]))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", help=".PAM 文件或目录")
    ap.add_argument("-o", "--out", help="输出目录(默认: 与源同目录同名 .pam.json)")
    ap.add_argument("--overwrite", action="store_true")
    ap.add_argument("--diff", action="store_true", help="只和同名 json 对账, 不写文件")
    ap.add_argument("--diff-limit", type=int, default=20, help="每个文件最多打印几处差异")
    ap.add_argument("-q", "--quiet", action="store_true", help="只打印出错与汇总")
    args = ap.parse_args()

    src = pathlib.Path(args.src)
    is_dir = src.is_dir()
    targets = sorted(src.rglob("*.PAM")) if is_dir else [src]
    if not targets:
        print("没找到 .PAM")
        return 1
    out_root = pathlib.Path(args.out) if args.out else None
    stat = collections.Counter()
    for t in targets:
        if not args.quiet:
            print("  %s" % t.name, end="")
        try:
            anim = parse_pam(t)
        except Exception as e:
            stat["解析失败"] += 1
            print("\n✗ %s: %s" % (t, e))
            continue
        if anim["_parsed_bytes"] != anim["_total_bytes"]:
            stat["字节数不符"] += 1
            print("\n✗ %s: 只消费 %d/%d 字节" % (t, anim["_parsed_bytes"], anim["_total_bytes"]))
            continue
        if args.diff:
            ref = t.with_suffix(".pam.json")
            if not ref.exists():
                stat["无对账文件"] += 1
                print("  (无同名 json)")
                continue
            exp = json.loads(ref.read_text(encoding="utf-8"))
            diffs = []
            _deep_diff(exp, to_dialect(anim), "$", diffs, args.diff_limit)
            if diffs:
                stat["对账有差异"] += 1
                print("\n   对账差异 %d 处:" % len(diffs))
                for d in diffs:
                    print("     %s" % d)
            else:
                stat["对账一致"] += 1
                print("  一致 ✓")
            continue
        if out_root is not None:
            dst = (out_root / t.relative_to(src)).with_suffix(".pam.json") if is_dir \
                else (out_root / t.with_suffix(".pam.json").name)
        else:
            dst = t.with_suffix(".pam.json")
        if dst.exists() and not args.overwrite:
            stat["跳过(已存在)"] += 1
            if not args.quiet:
                print("  跳过(已存在)")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(dumps(to_dialect(anim)), encoding="utf-8")
        stat["写出"] += 1
        if not args.quiet:
            print("  写出 %s (%d 镜像 / %d sprite / main %d 帧)"
                  % (dst.name, len(anim["image"]), len(anim["sprite"]),
                     len(anim["main_sprite"]["frame"]) if anim["main_sprite"] else 0))
    print("\n共 %d 个文件:" % len(targets))
    for k in ("写出", "跳过(已存在)", "对账一致", "对账有差异", "无对账文件", "字节数不符", "解析失败"):
        if stat[k]:
            print("  %-14s %d" % (k, stat[k]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
