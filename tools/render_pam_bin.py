"""把 `.pam.bin` 的某一帧离线合成成 PNG —— 用来肉眼确认「部件对不对 / 哪个是装扮」。

为什么需要它
----
`.pam.bin` 是给运行时自绘用的，编辑器里看不到画面；而「哪个部件是装扮」**只看名字
和用法判断不出来**（毒液豌豆的 `custom_01` 在每一段动画里都在用，只有画出来才看得见
它是一顶草帽）。所以：拿 bin + 贴图离线合成一帧，把它塞进 `hidden_parts` 前后各出一张
图对比，一眼就能定。

用法
----
    # 列出状态
    python tools/render_pam_bin.py --bin mods_builtin/pvz2/goopeashooter/goopeashooter.pam.bin --list

    # 出待机第 5 帧
    python tools/render_pam_bin.py --bin mods_builtin/pvz2/goopeashooter/goopeashooter.pam.bin \
        --texture-dir mods_builtin/pvz2/goopeashooter --state idle --frame 5 --out tmp/goo.png

    # 关掉草帽再出一张（对比用）
    python tools/render_pam_bin.py ... --hide custom_01 --out tmp/goo_nohat.png

口径
----
- 读法同 `mods_builtin/pvz2/pam/pam_binary_reader.gd`：每帧是全量快照，sprite 实例再递归
  进自己的时间轴；
- 画布坐标 × `--scale` 直接落到像素（也就是整张 390×390 画布输出，不做节点原点居中）；
- `src_rect` 取整张 PNG、按 `draw_size` 缩放（碎图模式的 padding 就是靠这一步缩回去的）。
"""

from __future__ import annotations

import argparse
import os
import struct
import sys

from PIL import Image


def read_bin(path: str) -> dict:
    blob = open(path, "rb").read()
    if blob[:4] != b"PAM2":
        raise ValueError("不是 PAM2 格式：%s" % path)
    off = 4
    version, flags = struct.unpack_from("<II", blob, off); off += 8
    fps, canvas_w, canvas_h, image_count, sprite_count = struct.unpack_from("<fffII", blob, off); off += 20

    def take_str() -> str:
        nonlocal off
        (length,) = struct.unpack_from("<H", blob, off); off += 2
        text = blob[off:off + length].decode("utf-8"); off += length
        return text

    (texture_count,) = struct.unpack_from("<I", blob, off); off += 4
    textures = [take_str() for _ in range(texture_count)]

    images = []
    for _ in range(image_count):
        rect = struct.unpack_from("<ffff", blob, off); off += 16
        name = take_str()
        draw = struct.unpack_from("<ff", blob, off); off += 8
        xform = struct.unpack_from("<ffffff", blob, off); off += 24
        images.append({"name": name, "rect": rect, "draw": draw, "xform": xform})

    (state_count,) = struct.unpack_from("<I", blob, off); off += 4
    states = {}
    for _ in range(state_count):
        name = take_str()
        start, count = struct.unpack_from("<II", blob, off); off += 8
        states[name] = (start, count)

    sprite_names = [take_str() for _ in range(sprite_count)]

    def take_timeline() -> list:
        nonlocal off
        (frame_count,) = struct.unpack_from("<I", blob, off); off += 4
        timeline = []
        for _ in range(frame_count):
            (inst_count,) = struct.unpack_from("<I", blob, off); off += 4
            insts = []
            for _ in range(inst_count):
                index, resource, is_sprite, anim_frame = struct.unpack_from("<IIBI", blob, off)
                off += 13
                color = struct.unpack_from("<ffff", blob, off); off += 16
                xform = struct.unpack_from("<ffffff", blob, off); off += 24
                insts.append({"index": index, "resource": resource, "sprite": bool(is_sprite),
                              "anim_frame": anim_frame, "color": color, "xform": xform})
            timeline.append(insts)
        return timeline

    main = take_timeline()
    sprites = [take_timeline() for _ in range(sprite_count)]

    return {"fps": fps, "canvas": (canvas_w, canvas_h), "textures": textures,
            "images": images, "states": states, "sprite_names": sprite_names,
            "main": main, "sprites": sprites}


def compose(a, b) -> list:
    """两个 2D 仿射矩阵相乘（PAM 的 6 元 = [a, b, c, d, tx, ty]）。"""
    ma, mb, mc, md, mtx, mty = a
    na, nb, nc, nd, ntx, nty = b
    return [ma * na + mc * nb, mb * na + md * nb,
            ma * nc + mc * nd, mb * nc + md * nd,
            ma * ntx + mc * nty + mtx, mb * ntx + md * nty + mty]


def blend(canvas: Image.Image, part: Image.Image, xform: list, color) -> None:
    ma, mb, mc, md, mtx, mty = xform
    det = ma * md - mb * mc
    if abs(det) < 1e-9:
        return
    ## PIL 的 AFFINE 要「输出 → 输入」的系数，所以走逆矩阵
    coeffs = (md / det, -mc / det, (mc * mty - md * mtx) / det,
              -mb / det, ma / det, (mb * mtx - ma * mty) / det)
    layer = part.transform(canvas.size, Image.AFFINE, coeffs, resample=Image.BICUBIC)
    alpha = layer.split()[3].point(lambda value: int(value * color[3]))
    layer.putalpha(alpha)
    canvas.alpha_composite(layer)


def render(data: dict, frame_index: int, texture_dir: str, hidden: set, scale: float) -> Image.Image:
    width, height = data["canvas"]
    canvas = Image.new("RGBA", (int(width * scale), int(height * scale)), (0, 0, 0, 0))
    root = [scale, 0.0, 0.0, scale, 0.0, 0.0]
    cache: dict[str, Image.Image] = {}

    def open_texture(name: str) -> Image.Image:
        if name not in cache:
            cache[name] = Image.open(os.path.join(texture_dir, name + ".png")).convert("RGBA")
        return cache[name]

    def walk(instances: list, parent: list) -> None:
        for inst in instances:
            xform = compose(parent, inst["xform"])
            if inst["sprite"]:
                if data["sprite_names"][inst["resource"]] in hidden:
                    continue
                timeline = data["sprites"][inst["resource"]]
                if timeline:
                    walk(timeline[inst["anim_frame"] % len(timeline)], xform)
                continue
            idef = data["images"][inst["resource"]]
            if idef["name"] in hidden:
                continue
            local = compose(xform, idef["xform"])
            sx = idef["draw"][0] / (idef["rect"][2] or 1.0)
            sy = idef["draw"][1] / (idef["rect"][3] or 1.0)
            local = [local[0] * sx, local[1] * sx, local[2] * sy, local[3] * sy, local[4], local[5]]
            blend(canvas, open_texture(idef["name"]), local, inst["color"])

    walk(data["main"][frame_index], root)
    return canvas


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=".pam.bin 单帧离线合成（取证：部件 / 装扮）")
    parser.add_argument("--bin", required=True, help=".pam.bin 路径")
    parser.add_argument("--texture-dir", help="碎图目录（部件名 = 文件名去扩展名）")
    parser.add_argument("--state", help="状态名（与 --frame 二选一，帧号从状态起点算）")
    parser.add_argument("--frame", type=int, default=0, help="状态内帧号 / 绝对帧号（默认 0）")
    parser.add_argument("--absolute", action="store_true", help="--frame 当主时间轴绝对帧号")
    parser.add_argument("--hide", default="", help="不画的部件，逗号分隔（填名称）")
    parser.add_argument("--scale", type=float, default=2.0, help="输出缩放（默认 2 倍）")
    parser.add_argument("--out", help="输出 png（默认 tmp/pam_frame.png）")
    parser.add_argument("--list", action="store_true", help="只列出状态与部件名，不画图")
    args = parser.parse_args(argv)

    data = read_bin(args.bin)
    if args.list:
        print("%s：%d 帧 @ %.0f fps，画布 %dx%d"
              % (args.bin, len(data["main"]), data["fps"], data["canvas"][0], data["canvas"][1]))
        for name, (start, count) in data["states"].items():
            print("  状态 %-24s 起点 %4d 帧数 %3d" % (name, start, count))
        print("  sprite（部件）：" + ", ".join(data["sprite_names"]))
        print("  碎图（图片部件）：" + ", ".join(i["name"] for i in data["images"]))
        return 0

    if not args.texture_dir:
        parser.error("画图需要 --texture-dir")

    frame_index = args.frame
    if args.state:
        if args.state not in data["states"]:
            parser.error("没有这个状态：%s（用 --list 看有哪些）" % args.state)
        frame_index = data["states"][args.state][0] + args.frame
    elif not args.absolute:
        frame_index = args.frame

    frame_index = max(0, min(frame_index, len(data["main"]) - 1))
    hidden = {name.strip() for name in args.hide.split(",") if name.strip()}
    image = render(data, frame_index, args.texture_dir, hidden, args.scale)
    out = args.out or os.path.join("tmp", "pam_frame.png")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    image.save(out)
    print("第 %d 帧 → %s（%dx%d，隐藏 %s）"
          % (frame_index, out, image.size[0], image.size[1], sorted(hidden) or "无"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
