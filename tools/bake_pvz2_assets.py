"""一键重烘 PVZ2 模组的全部动画产物（五株植物：图集 + .pam.bin）

为什么需要这一份
----
PVZ2 模组的运行时只认两样东西：`<植物>/<植物>_atlas.png` 与 `<植物>/<植物>.pam.bin`。
它们都是从桌面的解包资源 `..\\2代解包资源` 离线烘出来的，**不在运行时解析 PAM**。
以前这条链路是手敲 `bake_pam_bin.py` 一条条跑出来的（参数长、容易把 768 的矩形配 1536 的图集），
本脚本把「五株 × 四步」固化成一份清单，重烘只要跑一条命令。

四步（每株）
----
1. `pam2json.py`：`.PAM`（二进制）→ `tmp/pamjson/<名字>.pam.json`
2. `rton2json.py`：`PROPERTIES/RESOURCES.RTON` → `tmp/rton/RESOURCES.json`（图集矩形表）
   —— 只在 `tmp/rton/RESOURCES.json` 不存在时跑（13 MB，跑一次几十秒）
3. `bake_pam_bin.py`：pam.json + 矩形 + 图集 → `<植物>/<植物>.pam.bin`
   ⚠️ **必须给它 `--atlas-id`**：同一批 image 在 `*_768` 与 `*_1536` 两个资源组里各有一份矩形，
   数值差一倍。给错的表现是「每块都还在图里，但位置全错」，很难查。
4. 图集 png 复制到模组目录（1536 分辨率，画的时候仍按 PAM 名义尺寸 = 1280 口径绘制，
   所以换 1536 只是更清晰，不影响场上大小）

用法
----
    python tools/bake_pvz2_assets.py                # 全烘
    python tools/bake_pvz2_assets.py bonkchoy       # 只烘一株

前置：`..\\2代解包资源` 在桌面（与仓库同级）。缺了会直接退出并提示。
产出：直接写进 `mods_builtin/pvz2/<植物>/`（会被 git 跟踪，产物请一起提交）。
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
RESOURCE_ROOT = os.path.normpath(os.path.join(REPO, "..", "2代解包资源"))
MOD_ROOT = os.path.join(REPO, "mods_builtin", "pvz2")
TMP_ROOT = os.path.join(REPO, "tmp")

#: 每株：模组目录名 / PAM 源 / 1536 图集源 / 该图集的资源 id
PLANTS = [
    {
        "name": "bonkchoy",
        "pam": "IMAGES/768/INITIAL/PLANT/BONKCHOY/BONKCHOY.PAM",
        "atlas": "ATLASES/PLANTBONKCHOY_1536_00.PNG",
        "atlas_id": "ATLASIMAGE_ATLAS_PLANTBONKCHOY_1536_00",
    },
    {
        "name": "celerystalker",
        "pam": "IMAGES/768/FULL/PLANT/CELERYSTALKER/CELERYSTALKER.PAM",
        "atlas": "ATLASES/PLANTCELERYSTALKER_1536_00.PNG",
        "atlas_id": "ATLASIMAGE_ATLAS_PLANTCELERYSTALKER_1536_00",
    },
    {
        "name": "firepeashooter",
        "pam": "IMAGES/768/INITIAL/PLANT/FIREPEASHOOTER/FIREPEASHOOTER.PAM",
        "atlas": "ATLASES/PLANTFIREPEASHOOTER_1536_00.PNG",
        "atlas_id": "ATLASIMAGE_ATLAS_PLANTFIREPEASHOOTER_1536_00",
    },
    {
        "name": "peapod",
        "pam": "IMAGES/768/FULL/PLANT/PEAPOD/PEAPOD.PAM",
        "atlas": "ATLASES/PLANTPEAPOD_1536_00.PNG",
        "atlas_id": "ATLASIMAGE_ATLAS_PLANTPEAPOD_1536_00",
    },
    {
        ## 毒液豌豆的图在 `PlantPoisonPeashooter` 组里（PVZ2 就是这么放的，别按名字去找）
        "name": "goopeashooter",
        "pam": "IMAGES/768/INITIAL/PLANT/GOOPEASHOOTER/GOOPEASHOOTER.PAM",
        "atlas": "ATLASES/PLANTPOISONPEASHOOTER_1536_00.PNG",
        "atlas_id": "ATLASIMAGE_ATLAS_PLANTPOISONPEASHOOTER_1536_00",
    },
]


def run(command: list[str]) -> int:
    print("$ " + " ".join(command))
    return subprocess.call(command, cwd=REPO)


def ensure_resources_json() -> str:
    """`RESOURCES.RTON` → `tmp/rton/RESOURCES.json`（已存在就跳过：13 MB，跑一次几十秒）"""
    out = os.path.join(TMP_ROOT, "rton", "RESOURCES.json")
    if os.path.exists(out):
        print("复用已有的矩形表：" + os.path.relpath(out, REPO))
        return out
    src = os.path.join(RESOURCE_ROOT, "PROPERTIES", "RESOURCES.RTON")
    code = run([sys.executable, os.path.join(HERE, "rton2json.py"), src, out])
    if code != 0:
        sys.exit("RESOURCES.RTON 转换失败，先修 rton2json.py")
    return out


def bake_one(plant: dict, resources_json: str) -> None:
    name = plant["name"]
    pam_src = os.path.join(RESOURCE_ROOT, plant["pam"])
    atlas_src = os.path.join(RESOURCE_ROOT, plant["atlas"])
    if not os.path.exists(pam_src) or not os.path.exists(atlas_src):
        sys.exit("找不到源素材：%s / %s" % (pam_src, atlas_src))

    ## 1) PAM → json
    json_dir = os.path.join(TMP_ROOT, "pamjson")
    code = run([sys.executable, os.path.join(HERE, "pam2json.py"), pam_src,
                "-o", json_dir, "--overwrite"])
    if code != 0:
        sys.exit("%s：pam2json 失败" % name)
    json_path = os.path.join(json_dir, os.path.splitext(os.path.basename(pam_src))[0] + ".pam.json")

    ## 2/3/4) json + 矩形 + 图集 → bin（图集一起复制进模组目录）
    target_dir = os.path.join(MOD_ROOT, name)
    os.makedirs(target_dir, exist_ok=True)
    code = run([sys.executable, os.path.join(HERE, "bake_pam_bin.py"),
                "--json", json_path,
                "--resources", resources_json,
                "--atlas-id", plant["atlas_id"],
                "--atlas", atlas_src,
                "--atlas-dst", os.path.join(target_dir, name + "_atlas.png"),
                "--out", os.path.join(target_dir, name + ".pam.bin"),
                ## 内嵌路径只是烘焙痕迹：运行时由 `pam_bridge.gd` 用 texture_override 覆盖
                "--texture-path", "res://mods_builtin/pvz2/%s/%s_atlas.png" % (name, name)])
    if code != 0:
        sys.exit("%s：bake_pam_bin 失败" % name)


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if not os.path.isdir(RESOURCE_ROOT):
        sys.exit("找不到解包资源目录：%s（应当与仓库同级）" % RESOURCE_ROOT)
    only = {a.lower() for a in argv[1:] if not a.startswith("-")}

    resources_json = ensure_resources_json()
    for plant in PLANTS:
        if only and plant["name"] not in only:
            continue
        print("\n=== %s ===" % plant["name"])
        bake_one(plant, resources_json)

    print("\n完成。产物在 %s/<植物>/*_atlas.png + <植物>.pam.bin" % os.path.relpath(MOD_ROOT, REPO))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
