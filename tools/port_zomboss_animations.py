# -*- coding: utf-8 -*-
"""把参考项目 PVZ-Godot-main 的僵王博士 23 段动画资源移植到本仓库。

为什么需要这个脚本（而不是直接拷文件）：

1. **本仓库的动画是精简版**：每个部件只有 `visible` + 少数几条变换轨道，
   没有 `texture` / `self_modulate` 轨道 —— 也就是**贴图不会随动画切换**，
   reanim 帧动画的核心（贴图序列 + 颜色 / 透明度）是缺的。参考项目每个节点有 7 条轨道
   （position / rotation / scale / skew / visible / texture / self_modulate），文件也因此大 3~7 倍。
2. **参考的动画里混着 23 个 `Anim_*` 节点的轨道**（`Anim_enter` / `Anim_idle` …），
   那是它自己场景里的 AnimationPlayer 节点（它有 23 个 AnimationPlayer，本仓库只有 1 个）。
   本仓库场景**没有**这些节点，照搬会让播放时一直报 "node not found" —— 因此整组剔除。
3. **本仓库躯干场景 `zombie_boss.tscn` 用 uid 引用这 23 个 `.tres`**，
   所以转换时**必须保留本仓库文件的 uid**，只替换 `[resource]` 主体，tscn 一行都不用改。
4. **缺的贴图只报 [NG]，不再退化成别的文件**：曾经退化成 `Zombie_boss_neck_.png`
   （PVZ 原版 jpg + 黑白蒙版对里的蒙版），结果脖子 / 上身整块显示成黑白蒙版。
   这类 `xxx.jpg` + `xxx_.png` 必须先跑 `tools/merge_alpha.ps1 -Name <path>` 烘焙出
   RGBA 的 `xxx.png`，再跑本脚本。
5. 贴图 uid 以**贴图自己的 `.import`** 为准（拿不到才退回本仓库 tscn 里的映射），
   所以重跑脚本不会写回参考项目的旧 uid。

用法（在仓库根目录）：

    python tools/port_zomboss_animations.py            ## 预演：只报告会怎么改
    python tools/port_zomboss_animations.py --apply    ## 真的写文件

产出文件一律 **UTF-8 无 BOM + LF**（Godot 的文本资源解析器不认 BOM）。
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
## 参考项目 PVZ-Godot-main 不是本仓库的一部分（已在 .gitignore + .gdignore 里排除），
## 需要移植时才手动放到仓库根目录；也可以直接 --ref <目录> 指向别的副本。
DEFAULT_REF_DIR = os.path.join(ROOT, "PVZ-Godot-main", "animation", "character", "zombie", "999_zombie_boss")
DST_DIR = os.path.join(ROOT, "animation", "character", "zombie", "zombie_boss")
TSCN = os.path.join(ROOT, "src", "entities", "character", "zombie", "zombie_boss.tscn")

TRACK_RE = re.compile(r"^tracks/(\d+)/")
UID_RE = re.compile(r'uid="([^"]+)"')
PATH_RE = re.compile(r'path="([^"]+)"')
EXT_TEX_RE = re.compile(r'\[ext_resource type="Texture2D" uid="([^"]+)" path="([^"]+)"')

## 本仓库场景里没有的 AnimationPlayer 节点前缀（参考项目有 23 个，本仓库只有 1 个）
DROP_NODE_PREFIX = "Anim_"


def to_ref_name(local_stem: str) -> str:
	"""zombie_boss_rv_1 -> Zombie_boss_RV_1（参考项目 RV 是大写）"""
	suffix = local_stem[len("zombie_boss_"):]
	if suffix.startswith("rv"):
		suffix = "RV" + suffix[2:]
	return "Zombie_boss_" + suffix


def read_text(path: str) -> str:
	with open(path, "r", encoding="utf-8-sig") as f:
		return f.read()


def build_uid_map() -> dict:
	"""从本仓库躯干场景里取 贴图 path -> uid，用来重写动画里的 ext_resource"""
	uid_map = {}
	if not os.path.exists(TSCN):
		return uid_map
	for m in EXT_TEX_RE.finditer(read_text(TSCN)):
		uid_map[m.group(2)] = m.group(1)
	return uid_map


def parse_tres(text: str):
	"""拆出 header / ext_resource / resource 头部属性 / track 分组"""
	header = ""
	ext_lines = []
	head_lines = []
	groups = []
	cur = None
	cur_idx = None
	seen_resource = False

	for line in text.split("\n"):
		stripped = line.strip()
		if line.startswith("[gd_resource"):
			header = line
			continue
		if line.startswith("[ext_resource"):
			ext_lines.append(line)
			continue
		if line.startswith("[resource]"):
			seen_resource = True
			continue
		if not seen_resource:
			continue
		m = TRACK_RE.match(line)
		if m:
			idx = int(m.group(1))
			if cur is None or idx != cur_idx:
				cur = []
				cur_idx = idx
				groups.append(cur)
			cur.append(line)
			continue
		## keys = { ... } 的续行归进当前 track 分组；其余（resource_name/length/step）是头部属性
		if stripped == "" or stripped == "}" or stripped.startswith('"') or stripped.startswith("["):
			if cur is not None and stripped != "":
				cur.append(line)
			elif stripped == "":
				continue
			else:
				head_lines.append(line)
			continue
		if cur is not None:
			cur.append(line)
		else:
			head_lines.append(line)
	return header, ext_lines, head_lines, groups


def group_node_name(group) -> str:
	for line in group:
		if '/path = NodePath("' in line:
			s = line.split('NodePath("')[1]
			s = s[: s.rindex('")')]
			return s.split(":")[0]
	return ""


def import_uid(abs_path: str):
	"""从 Godot 生成的 <file>.import 里取 uid；取不到返回 None"""
	imp = abs_path + ".import"
	if not os.path.exists(imp):
		return None
	m = UID_RE.search(read_text(imp))
	return m.group(1) if m else None


def fix_ext(ext_lines, uid_map):
	"""校验贴图是否存在，并把 uid 对齐到本仓库自己的导入结果"""
	out = []
	missing = []
	uid_fixed = []
	for line in ext_lines:
		m = PATH_RE.search(line)
		if not m:
			out.append(line)
			continue
		res_path = m.group(1)
		abs_path = os.path.join(ROOT, res_path.replace("res://", "").replace("/", os.sep))
		if not os.path.exists(abs_path):
			missing.append(res_path)
			out.append(line)
			continue
		## uid 优先取贴图自己的 .import（权威），拿不到才退回仓库场景里的映射
		uid = import_uid(abs_path) or uid_map.get(res_path)
		cur = UID_RE.search(line)
		if uid and cur and cur.group(1) != uid:
			## 参考里带的 uid 指向参考项目，必须换成本仓库自己的
			line = UID_RE.sub('uid="%s"' % uid, line, count=1)
			uid_fixed.append((res_path, cur.group(1), uid))
		out.append(line)
	return out, missing, uid_fixed


def convert(local_path: str, ref_path: str, uid_map: dict):
	old_text = read_text(local_path)
	old_header, _, _, old_groups = parse_tres(old_text)
	m = UID_RE.search(old_header)
	if not m:
		return None, "本仓库文件没有 uid，跳过：" + local_path
	local_uid = m.group(1)

	ref_text = read_text(ref_path)
	_, ref_ext, ref_head, ref_groups = parse_tres(ref_text)

	kept = [g for g in ref_groups if not group_node_name(g).startswith(DROP_NODE_PREFIX)]
	dropped = len(ref_groups) - len(kept)

	new_body = []
	for i, g in enumerate(kept):
		for line in g:
			new_body.append(TRACK_RE.sub("tracks/%d/" % i, line, count=1))

	ext_lines, missing, uid_fixed = fix_ext(ref_ext, uid_map)

	m2 = re.search(r"load_steps=(\d+)", ref_text.split("\n")[0])
	load_steps = m2.group(1) if m2 else str(min(len(ext_lines) + 1, 1))

	out_lines = [
		'[gd_resource type="Animation" load_steps=%s format=3 uid="%s"]' % (load_steps, local_uid),
		"",
	]
	out_lines.extend(ext_lines)
	out_lines.append("")
	out_lines.append("[resource]")
	out_lines.extend(ref_head)
	out_lines.extend(new_body)
	out_text = "\n".join(out_lines).rstrip("\n") + "\n"

	stat = {
		"local": os.path.basename(local_path),
		"ref": os.path.basename(ref_path),
		"old_tracks": len(old_groups),
		"new_tracks": len(kept),
		"dropped": dropped,
		"ext": len(ext_lines),
		"uid_fixed": uid_fixed,
		"missing": missing,
	}
	return out_text, stat


def parse_ref_dir(argv) -> str:
	"""--ref <目录> 指定参考动画目录；缺省用 <仓库根>/PVZ-Godot-main/animation/..."""
	for i, a in enumerate(argv):
		if a == "--ref" and i + 1 < len(argv):
			return argv[i + 1]
	return DEFAULT_REF_DIR


def main():
	apply = "--apply" in sys.argv
	ref_dir = parse_ref_dir(sys.argv)
	uid_map = build_uid_map()
	if not uid_map:
		print("[WARN] 没能从 tscn 取到贴图 uid 映射，ext_resource 的 uid 将沿用参考值")
	else:
		print("贴图 uid 映射：%d 条（来自 %s）" % (len(uid_map), os.path.relpath(TSCN, ROOT)))
	print("模式：%s" % ("写入" if apply else "预演（加 --apply 才写文件）"))
	print("")

	if not os.path.isdir(ref_dir):
		print("[ERR] 找不到参考动画目录：" + ref_dir)
		print("      参考项目 PVZ-Godot-main 不随仓库发布，请自行放到仓库根目录，")
		print("      或用 python tools/port_zomboss_animations.py --ref <参考动画目录> 指定位置。")
		return 1

	total_missing = []
	rows = []
	for name in sorted(os.listdir(DST_DIR)):
		if not name.endswith(".tres"):
			continue
		local_path = os.path.join(DST_DIR, name)
		ref_name = to_ref_name(name[:-5]) + ".tres"
		ref_path = os.path.join(ref_dir, ref_name)
		if not os.path.exists(ref_path):
			print("[NG] 参考项目缺对应动画：" + ref_name)
			continue
		out_text, stat = convert(local_path, ref_path, uid_map)
		if out_text is None:
			print("[NG] " + str(stat))
			continue
		rows.append(stat)
		for p in stat["missing"]:
			total_missing.append((name, p))
		if apply:
			with open(local_path, "w", encoding="utf-8", newline="\n") as f:
				f.write(out_text)

	print("%-34s %-34s %8s %8s %7s %5s" % ("本仓库", "参考", "旧轨道", "新轨道", "剔除", "贴图"))
	for s in rows:
		print("%-34s %-34s %8d %8d %7d %5d"
			% (s["local"], s["ref"], s["old_tracks"], s["new_tracks"], s["dropped"], s["ext"]))
	print("")
	print("共 %d 段动画" % len(rows))
	all_uid_fixed = [(s["local"], p, a, b) for s in rows for (p, a, b) in s["uid_fixed"]]
	if all_uid_fixed:
		print("uid 修正（对齐到贴图自己的 .import）：")
		for local, p, a, b in all_uid_fixed:
			print("  %s: %s  %s -> %s" % (local, p, a, b))
	if total_missing:
		print("[NG] 本仓库找不到这些贴图（先修素材，再跑本脚本）：")
		for local, p in total_missing:
			print("  %s: %s" % (local, p))
		print("  提示：xxx.jpg + xxx_.png 是 jpg + 黑白蒙版对，")
		print("        先跑 tools/merge_alpha.ps1 -Name <去掉扩展名的路径> 烘焙出 xxx.png")
	else:
		print("贴图引用：全部能在本仓库找到")
	return 0


if __name__ == "__main__":
	sys.exit(main())
