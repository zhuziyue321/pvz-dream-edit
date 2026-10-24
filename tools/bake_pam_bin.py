"""把 PVZ2 的 PAM 导出 json 烘成运行时用的 .pam.bin（PAM2 v1）。

背景
----
PVZ2 的美术是 PopAnim（`.PAM`），不是原版的 `.reanim`。本仓库**不在运行时解析 PAM**，
所以离线烘成自包含的二进制：一张图集贴图 + 一个 `.pam.bin`，运行时由
`mods_builtin/pvz2/pam/pam_animator.gd` 直接读字节画图（零解析开销）。

用法
----
    python tools/bake_pam_bin.py \
        --json  tmp/CELERYSTALKER.PAM.pam.json \
        --resources tmp/pvz2合计/pvz2-plants-image/plant1/PROPERTIES/RESOURCESPLANT1.json \
        --atlas  tmp/pvz2合计/pvz2-plants-image/plant1/ATLASES/PLANTCELERYSTALKER_1200_00.png \
        --atlas-dst mods_builtin/pvz2/celerystalker/celerystalker_atlas.png \
        --out   mods_builtin/pvz2/celerystalker/celerystalker.pam.bin \
        --texture-path res://mods_builtin/pvz2/celerystalker/celerystalker_atlas.png

    # 碎图模式：手上没有图集、只有「一个部件一张 png」时（毒液豌豆就是这种素材）
    python tools/bake_pam_bin.py \
        --json tmp/goopeashooter_pam/pvz2_anim/goopeashooter.pam.json \
        --texture-dir tmp/goopeashooter_pam/texture/goopeashooter \
        --texture-res res://mods_builtin/pvz2/goopeashooter \
        --out mods_builtin/pvz2/goopeashooter/goopeashooter.pam.bin

    # 只校验、不写盘
    python tools/bake_pam_bin.py ... --check-only

口径（与 pam_binary_reader.gd 一一对应）
----
    "PAM2" | version:u32=1 | flags:u32=0
    frame_rate:f32 | canvas_w:f32 | canvas_h:f32 | image_count:u32 | sprite_count:u32
    texture_paths: u32 n → (u16 len + utf8)
    images:         (src_rect 4×f32, u16+part_name, draw_size 2×f32, T2D 6×f32)
    states:         (u16+name, start:u32, count:u32)
    sprite names:   (u16+name)
    main timeline:  u32 frames → (u32 insts → inst)
    sprite timelines: sprite_count 份同上
    inst: index:u32 | resource:u32 | is_sprite:u8 | anim_frame:u32 | color 4×f32 | T2D 6×f32

自检（每次烘焙都会跑，`--check-only` 也跑）
----
1. 回读逐项与烘焙前数据对齐：image / states / sprite 名 / 帧数 / 实例数，以及**逐帧的
   `anim_frame` / `color` / `xform`**（只比 index/resource 的话，「帧快照被别名共享」
   那种 bug 是绿的）；
2. 打印「相邻帧完全相同占比」，> 50% 直接判失败 —— 这个值接近 100% 说明
   `flatten_frames()` 少了一次拷贝（每帧改写历史帧），运行时表现是**整株冻住几秒、
   零件一换再突然跳一下**（帧号在走、画面不动）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import struct
import sys

MAGIC = b"PAM2"
VERSION = 1
FLAGS = 0


# --------------------------------------------------------------------------- 资源表


def load_image_rects(resources_json: str, atlas_id: str | None = None) -> dict[str, dict]:
    """从 PVZ2 的 RESOURCES*.json 里抽出 `{image_id: {ax, ay, aw, ah, parent}}`。

    那份 json 是个大嵌套结构，这里递归扫所有 `type == "Image"` 且带 `ax` 的节点。

    ⚠️ **同一个 image id 会出现在多个分辨率组里**（`PlantBonkchoy_768` / `PlantBonkchoy_1536`），
    两套矩形的数值差一倍。给 [param atlas_id] 时只认 `parent == atlas_id` 的那份 ——
    否则会拿 768 的矩形去切 1536 的图集，画面是「位置全错但每块都还在图里」，很难查。
    """
    data = json.load(open(resources_json, encoding="utf-8"))
    out: dict[str, dict] = {}

    def walk(node):
        if isinstance(node, dict):
            if node.get("type") == "Image" and "id" in node and "ax" in node:
                if atlas_id and node.get("parent") != atlas_id:
                    pass
                elif node["id"] not in out:
                    out[node["id"]] = node
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(data)
    return out


def split_image_name(name: str) -> tuple[str, str]:
    """PAM 的 image name 形如 `celerystalker_69x105|IMAGE_PLANT_...`。

    返回 (碎图名, 图集 id)；没有 `|` 时两者相同。
    """
    if "|" not in name:
        return name, name
    part, image_id = name.rsplit("|", 1)
    return part, image_id


# --------------------------------------------------------------------------- 展平


def apply_transform(prev: list[float], raw) -> list[float]:
    """把 `change` 里的 transform 归一成完整的 6 元矩阵 [a, b, c, d, tx, ty]。

    PAM 的 transform 是**部分更新**，按长度区分（实测潜伏芹菜的数据只有这三种）：
      6 元 —— 完整矩阵
      3 元 —— (旋转弧度, tx, ty)，缩放沿用上一次的值
      2 元 —— (tx, ty)，旋转与缩放都沿用上一次的值（Flash 里「只挪位置」就是这个）
    """
    if not isinstance(raw, list) or not raw:
        return prev
    count = len(raw)
    if count >= 6:
        return [float(v) for v in raw[:6]]
    if count == 3:
        angle = float(raw[0])
        scale = math.hypot(prev[0], prev[1]) or 1.0
        cos_a, sin_a = math.cos(angle) * scale, math.sin(angle) * scale
        return [cos_a, sin_a, -sin_a, cos_a, float(raw[1]), float(raw[2])]
    if count == 2:
        return [prev[0], prev[1], prev[2], prev[3], float(raw[0]), float(raw[1])]
    return prev


def snapshot(inst: dict) -> dict:
    """单个实例的**独立拷贝**（与参考工程 `tmp/Core/pam_anim_state.snapshot()` 同口径）。

    ⚠️ 这里必须是拷贝，不能直接把 `active` 里的那个 dict 放进快照：`active` 里的实例会被
    后续帧**就地改写**（`change` 换掉 `xform` / `color` / `anim_frame`），同一份 dict 进了
    早先的帧就等于「往后每一帧都在改历史」。踩过的坑：`timeline.append([active[k] ...])`
    少了一次拷贝，烘出来的 bin 相邻帧 459/572 完全一样（`idle` 50 帧只剩 21 种姿态），
    运行时表现为**整株冻住几秒、零件一换再突然跳一下**（帧号在走，画面不动）。
    """
    return {
        "index": inst["index"],
        "resource": inst["resource"],
        "is_sprite": inst["is_sprite"],
        "anim_frame": inst["anim_frame"],
        "color": list(inst["color"]),
        "xform": list(inst["xform"]),
    }


def flatten_frames(frames: list[dict]) -> list[list[dict]]:
    """把 `append / remove / change` 三种帧操作压平成**每帧全量快照**。

    与运行时同口径：remove 先于 append，change 改不到已存在实例时补一个空实例，
    出帧前按 `index` 排序（index 就是绘制层级）。**每帧存的是拷贝**（见 `snapshot()`）。
    """
    active: dict[int, dict] = {}
    timeline: list[list[dict]] = []

    for frame in frames:
        for op in frame.get("remove") or []:
            active.pop(op.get("index"), None)

        for op in frame.get("append") or []:
            active[op["index"]] = {
                "index": op["index"],
                "resource": op.get("resource", 0),
                "is_sprite": bool(op.get("sprite")),
                "anim_frame": 0,
                "color": [1.0, 1.0, 1.0, 1.0],
                "xform": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
            }

        for op in frame.get("change") or []:
            inst = active.get(op["index"])
            if inst is None:
                inst = {
                    "index": op["index"],
                    "resource": 0,
                    "is_sprite": False,
                    "anim_frame": 0,
                    "color": [1.0, 1.0, 1.0, 1.0],
                    "xform": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
                }
                active[op["index"]] = inst
            inst["xform"] = apply_transform(inst["xform"], op.get("transform"))
            inst["anim_frame"] = op.get("anim_frame_num") or 0
            if op.get("color"):
                inst["color"] = op["color"]

        timeline.append([snapshot(active[k]) for k in sorted(active)])

    return timeline


def read_png_size(path: str) -> tuple[int, int]:
    """读 PNG 的 IHDR 拿像素尺寸（不引第三方库）。"""
    with open(path, "rb") as handle:
        head = handle.read(26)
    if len(head) < 26 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError("不是 PNG：%s" % path)
    return struct.unpack(">II", head[16:24])


def bake_loose(pam_json: str, texture_dir: str, texture_res: str):
    """碎图模式：一个部件一张 PNG（文件名 = PAM 里 `name` 的 `|` 前一半）。

    与图集模式的唯一区别是 `src_rect` —— 碎图是整张 PNG（`0,0,w,h`），`draw_size`
    仍取 PAM 的 `size`。⚠️ PVZ2 的碎图带了一层 padding（实测边长约为逻辑尺寸的
    1.28 倍），画的时候按 `draw_size` 缩回去，别把 PNG 像素尺寸当逻辑尺寸。
    """
    pam = json.load(open(pam_json, encoding="utf-8"))
    images = pam.get("image") or []
    sprites = pam.get("sprite") or []
    main_frames = (pam.get("main_sprite") or {}).get("frame") or []
    if not main_frames:
        raise ValueError("json 里没有 main_sprite.frame，这不是一份完整导出")

    image_defs = []
    texture_paths = []
    missing = []
    for img in images:
        part_name = split_image_name(img.get("name", ""))[0]
        part_name = part_name.replace("\\", "/").split("/")[-1]
        png_path = os.path.join(texture_dir, part_name + ".png")
        if not os.path.isfile(png_path):
            missing.append(part_name)
            continue
        width, height = read_png_size(png_path)
        size = img.get("size") or [width, height]
        image_defs.append({
            "part_name": part_name,
            "src_rect": [0.0, 0.0, float(width), float(height)],
            "draw_size": [float(size[0]), float(size[1])],
            "local_xform": img.get("transform") or [1, 0, 0, 1, 0, 0],
        })
        res_path = "%s/%s.png" % (texture_res.rstrip("/"), part_name)
        if res_path not in texture_paths:
            texture_paths.append(res_path)

    if missing:
        raise ValueError("碎图目录里找不到这些部件的 PNG（%d 张）：%s"
                         % (len(missing), missing[:5]))

    size = pam.get("size") or [390, 390]
    data = {
        "frame_rate": float(pam.get("frame_rate") or 30.0),
        "canvas": [float(size[0]), float(size[1])],
        "image_defs": image_defs,
        "states": build_states(main_frames),
        "sprite_names": [s.get("name", "") for s in sprites],
        "main_timeline": flatten_frames(main_frames),
        "sprite_timelines": [flatten_frames(s.get("frame") or []) for s in sprites],
    }
    return data, texture_paths


def build_states(frames: list[dict]) -> dict[str, list[int]]:
    """按帧上的 `label` 切出状态：一段 label 起头、后面紧跟的无 label 帧都归它。"""
    states: dict[str, list[int]] = {}
    i = 0
    total = len(frames)
    while i < total:
        label = frames[i].get("label") or ""
        if label:
            start = i
            count = 1
            i += 1
            while i < total and not (frames[i].get("label") or ""):
                count += 1
                i += 1
            states[label] = [start, count]
        else:
            i += 1
    if not states:
        states["idle"] = [0, total]
    return states


# --------------------------------------------------------------------------- 写盘


def pack_f32(values) -> bytes:
    return struct.pack("<%df" % len(values), *values)


def pack_str(text: str) -> bytes:
    raw = text.encode("utf-8")
    if len(raw) > 0xFFFF:
        raise ValueError("字符串过长： %s" % text[:32])
    return struct.pack("<H", len(raw)) + raw


def pack_xform(xf) -> bytes:
    return pack_f32([float(v) for v in xf])


def pack_timeline(timeline: list[list[dict]]) -> bytes:
    out = [struct.pack("<I", len(timeline))]
    for frame in timeline:
        out.append(struct.pack("<I", len(frame)))
        for inst in frame:
            out.append(struct.pack("<IIBI", inst["index"], inst["resource"],
                                   1 if inst["is_sprite"] else 0, inst["anim_frame"]))
            out.append(pack_f32([float(v) for v in inst["color"][:4]]))
            out.append(pack_xform(inst["xform"]))
    return b"".join(out)


def bake(pam_json: str, resources_json: str, texture_path: str, atlas_hint: str | None,
         atlas_id: str | None = None):
    pam = json.load(open(pam_json, encoding="utf-8"))
    rects = load_image_rects(resources_json, atlas_id)

    images = pam.get("image") or []
    sprites = pam.get("sprite") or []
    main_sprite = pam.get("main_sprite") or {}
    main_frames = main_sprite.get("frame") or []
    if not main_frames:
        raise ValueError("json 里没有 main_sprite.frame，这不是一份完整导出")

    image_defs = []
    missing = []
    atlases = set()
    for img in images:
        part_name, image_id = split_image_name(img.get("name", ""))
        part_name = part_name.replace("\\", "/").split("/")[-1]
        rect = rects.get(image_id)
        if rect is None:
            missing.append(image_id)
            continue
        atlases.add(rect.get("parent", ""))
        image_defs.append({
            "part_name": part_name,
            "src_rect": [rect["ax"], rect["ay"], rect["aw"], rect["ah"]],
            "draw_size": [img.get("size", [rect["aw"], rect["ah"]])[0],
                          img.get("size", [rect["aw"], rect["ah"]])[1]],
            "local_xform": img.get("transform") or [1, 0, 0, 1, 0, 0],
        })

    if missing:
        raise ValueError("这些 image 在图集资源表里找不到矩形（%d 条）：%s"
                         % (len(missing), missing[:5]))
    if atlas_hint and len(atlases) > 1:
        raise ValueError("这些 image 跨了多个图集，本格式只支持单图集：%s" % sorted(atlases))

    size = pam.get("size") or [390, 390]
    data = {
        "frame_rate": float(pam.get("frame_rate") or 30.0),
        "canvas": [float(size[0]), float(size[1])],
        "image_defs": image_defs,
        "states": build_states(main_frames),
        "sprite_names": [s.get("name", "") for s in sprites],
        "main_timeline": flatten_frames(main_frames),
        "sprite_timelines": [flatten_frames(s.get("frame") or []) for s in sprites],
    }
    return data, atlases


def serialize(data: dict, texture_paths: list[str]) -> bytes:
    parts = [MAGIC, struct.pack("<II", VERSION, FLAGS)]
    parts.append(pack_f32([data["frame_rate"], data["canvas"][0], data["canvas"][1]]))
    parts.append(struct.pack("<II", len(data["image_defs"]), len(data["sprite_names"])))

    parts.append(struct.pack("<I", len(texture_paths)))
    for path in texture_paths:
        parts.append(pack_str(path))

    for idef in data["image_defs"]:
        parts.append(pack_f32(idef["src_rect"]))
        parts.append(pack_str(idef["part_name"]))
        parts.append(pack_f32(idef["draw_size"]))
        parts.append(pack_xform(idef["local_xform"]))

    parts.append(struct.pack("<I", len(data["states"])))
    for name, (start, count) in data["states"].items():
        parts.append(pack_str(name))
        parts.append(struct.pack("<II", start, count))

    for name in data["sprite_names"]:
        parts.append(pack_str(name))

    parts.append(pack_timeline(data["main_timeline"]))
    for timeline in data["sprite_timelines"]:
        parts.append(pack_timeline(timeline))

    return b"".join(parts)


# --------------------------------------------------------------------------- 回读自检


def read_back(blob: bytes, expect: dict) -> list[str]:
    """按运行时的读法把字节读一遍，与烘焙前的数据逐项对齐；返回问题列表。"""
    problems: list[str] = []
    off = 0

    def take(fmt):
        nonlocal off
        size = struct.calcsize(fmt)
        value = struct.unpack_from(fmt, blob, off)
        off += size
        return value

    def take_str():
        nonlocal off
        (length,) = take("<H")
        text = blob[off:off + length].decode("utf-8")
        off += length
        return text

    if blob[:4] != MAGIC:
        problems.append("magic 不对")
    off = 4
    version, flags = take("<II")
    if version != VERSION:
        problems.append("version=%d" % version)
    fps, cw, ch = take("<fff")
    image_count, sprite_count = take("<II")

    (tex_count,) = take("<I")
    tex_paths = [take_str() for _ in range(tex_count)]

    images = []
    for _ in range(image_count):
        rect = take("<ffff")
        name = take_str()
        draw = take("<ff")
        xf = take("<ffffff")
        images.append((name, rect, draw, xf))

    (state_count,) = take("<I")
    states = {}
    for _ in range(state_count):
        name = take_str()
        start, count = take("<II")
        states[name] = [start, count]

    sprite_names = [take_str() for _ in range(sprite_count)]

    def take_timeline():
        nonlocal off
        (frame_count,) = take("<I")
        timeline = []
        for _ in range(frame_count):
            (inst_count,) = take("<I")
            insts = []
            for _ in range(inst_count):
                index, resource, is_sprite, anim_frame = take("<IIBI")
                color = take("<ffff")
                xf = take("<ffffff")
                insts.append((index, resource, is_sprite, anim_frame, color, xf))
            timeline.append(insts)
        return timeline

    main_timeline = take_timeline()
    sprite_timelines = [take_timeline() for _ in range(sprite_count)]

    if off != len(blob):
        problems.append("读完还剩 %d 字节（结构对不上）" % (len(blob) - off))
    if abs(fps - expect["frame_rate"]) > 1e-6:
        problems.append("frame_rate 不一致")
    if len(images) != len(expect["image_defs"]):
        problems.append("image 数不一致")
    if states != {k: v for k, v in expect["states"].items()}:
        problems.append("states 不一致")
    if sprite_names != expect["sprite_names"]:
        problems.append("sprite 名不一致")
    if len(main_timeline) != len(expect["main_timeline"]):
        problems.append("主时间轴帧数不一致")
    for fi, (got, want) in enumerate(zip(main_timeline, expect["main_timeline"])):
        if len(got) != len(want):
            problems.append("第 %d 帧实例数不一致" % fi)
            break
        for gi, wi in zip(got, want):
            if gi[0] != wi["index"] or gi[1] != wi["resource"] or gi[2] != (1 if wi["is_sprite"] else 0):
                problems.append("第 %d 帧实例字段不一致" % fi)
                break
            ## 变换 / 颜色也要逐项比：只比 index/resource 的话，
            ## 「每帧快照被别名共享」那种 bug（画面冻住）自检是绿的
            if gi[3] != wi["anim_frame"]:
                problems.append("第 %d 帧 anim_frame 不一致" % fi)
                break
            if any(abs(a - b) > 1e-4 for a, b in zip(gi[4], wi["color"])):
                problems.append("第 %d 帧实例颜色不一致" % fi)
                break
            if any(abs(a - b) > 1e-4 for a, b in zip(gi[5], wi["xform"])):
                problems.append("第 %d 帧实例变换不一致" % fi)
                break
    if len(sprite_timelines) != len(expect["sprite_timelines"]):
        problems.append("sprite 时间轴数量不一致")
    return problems


def frozen_ratio(timeline: list[list[dict]]) -> float:
    """相邻帧「实例集合 + 变换 + 颜色」完全一样的占比。

    正常动画这个值很小；接近 1 就是烘焙时**快照被别名共享**了（整株冻住、偶尔跳一下）。
    主时间轴与 sprite 时间轴都该看。
    """
    if len(timeline) < 2:
        return 0.0

    def signature(frame):
        return tuple((i["index"], i["resource"], tuple(i["xform"]), tuple(i["color"]))
                     for i in frame)

    same = sum(1 for a, b in zip(timeline, timeline[1:]) if signature(a) == signature(b))
    return same / (len(timeline) - 1)


# --------------------------------------------------------------------------- main


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="PAM json → .pam.bin（PAM2 v1）")
    parser.add_argument("--json", required=True, help="PAM 导出的 json")
    parser.add_argument("--resources", help="PVZ2 的 RESOURCES*.json（提供图集矩形；碎图模式不需要）")
    parser.add_argument("--atlas-id", help="图集资源 id（如 ATLASIMAGE_ATLAS_PLANTBONKCHOY_1536_00）；"
                                          "同一批 image 在 768/1536 组里各有一份矩形，给错会切错位置")
    parser.add_argument("--atlas", help="图集 png 源文件（会被复制到 --atlas-dst）")
    parser.add_argument("--atlas-dst", help="模组内的图集 png 目标路径")
    parser.add_argument("--texture-dir", help="碎图目录（一个部件一张 `<part_name>.png`；给出即走碎图模式）")
    parser.add_argument("--texture-res", help="写进 bin 的 res:// 贴图目录前缀（碎图模式，默认由 --texture-dir 推导）")
    parser.add_argument("--out", help=".pam.bin 输出路径")
    parser.add_argument("--texture-path", help="写进 bin 的 res:// 贴图路径（默认取 --atlas-dst）")
    parser.add_argument("--check-only", action="store_true", help="只跑校验，不写盘")
    args = parser.parse_args(argv)

    loose = bool(args.texture_dir)
    if not args.check_only and not args.out:
        parser.error("写盘模式需要 --out")
    if not loose:
        if not args.resources:
            parser.error("图集模式需要 --resources（或改用 --texture-dir 走碎图模式）")
        if not args.check_only and not (args.atlas and args.atlas_dst):
            parser.error("图集模式的写盘需要 --atlas / --atlas-dst")

    atlases = []
    if loose:
        texture_res = args.texture_res
        if not texture_res:
            texture_res = "res://" + os.path.relpath(
                args.texture_dir, os.getcwd()).replace(os.sep, "/")
        data, texture_paths = bake_loose(args.json, args.texture_dir, texture_res)
    else:
        data, atlases = bake(args.json, args.resources, args.texture_path or "", args.atlas,
                             args.atlas_id)
        texture_path = args.texture_path or (
            "res://" + os.path.relpath(args.atlas_dst, os.getcwd()).replace(os.sep, "/")
            if args.atlas_dst else "")
        texture_paths = [texture_path] if texture_path else []
    blob = serialize(data, texture_paths)

    print("PAM: %s" % args.json)
    print("  画布 %dx%d @ %.0f fps" % (data["canvas"][0], data["canvas"][1], data["frame_rate"]))
    print("  image %d / sprite %d / 主时间轴 %d 帧 / 状态 %d"
          % (len(data["image_defs"]), len(data["sprite_names"]),
             len(data["main_timeline"]), len(data["states"])))
    print("  实例总数 %d（主时间轴）+ %d（sprite 时间轴）"
          % (sum(len(f) for f in data["main_timeline"]),
             sum(len(f) for tl in data["sprite_timelines"] for f in tl)))
    if loose:
        print("  碎图 %d 张（%s）" % (len(texture_paths), texture_paths[0] if texture_paths else "-"))
    else:
        print("  图集 %s" % sorted(atlases))

    ## 冻结帧占比：烘焙时快照没拷贝的话，这里会接近 1（画面冻住、偶尔跳一下）
    ratio = frozen_ratio(data["main_timeline"])
    print("  相邻帧完全相同占比 %.1f%%（越小越好；接近 100%% = 快照没拷贝，动画会冻住）"
          % (ratio * 100.0))

    problems = read_back(blob, data)
    if problems:
        print("自检失败：")
        for p in problems:
            print("  - %s" % p)
        return 1
    if ratio > 0.5:
        print("自检失败：")
        print("  - 相邻帧完全相同占比 %.1f%% 过高（> 50%%），先查 flatten_frames 的快照拷贝"
              % (ratio * 100.0))
        return 1
    print("  自检通过（回读逐项一致），%d 字节，sha1=%s"
          % (len(blob), hashlib.sha1(blob).hexdigest()[:12]))

    if args.check_only:
        return 0

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "wb") as handle:
        handle.write(blob)
    print("  写出 bin: %s" % args.out)

    if loose:
        return 0

    if os.path.abspath(args.atlas) != os.path.abspath(args.atlas_dst):
        os.makedirs(os.path.dirname(os.path.abspath(args.atlas_dst)), exist_ok=True)
        shutil.copyfile(args.atlas, args.atlas_dst)
        print("  复制图集: %s" % args.atlas_dst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
