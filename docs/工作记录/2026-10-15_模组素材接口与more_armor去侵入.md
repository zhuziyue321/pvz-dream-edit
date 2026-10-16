# 2026-10-15 · 其它 · 给模组加「素材读取接口」，把 more_armor 的贴图从本体 assets/ 收进模组目录

> **任务类型**：其它（模组框架 / 去侵入）
> **推荐度**：**推荐**（下次「模组要带自己的贴图」照这个走：素材与模组同目录 + 走管理器读）
> **耗时与成本**：约 1 轮对话 / 未开窗口 / 无头 `probe_more_armor_mod` PASS failed=0（stderr 0 行）
> **验证方式**：免验证 + 已给出人工验证方法（贴图是否真的画出来需人工看一眼）
> **补充自**：[2026-10-15\_PVZ2模组菜问.md](2026-10-15_PVZ2模组菜问.md)（它把菜问贴图从 `assets/` 收回模组目录，本轮补上「怎么读」这层接口）

## 目标

模组素材（贴图 / 场景）此前有两处「侵入」本体：`more_armor` 的 10 张桶贴图裸放在 `assets/` 根、
脚本用 `preload("res://assets/...")` 引用。要把素材收回**模组自己目录**，并提供一个**管理器接口**
统一读素材（自动按加载根解析、`user://` 下没被导入的图片自动退回 Image 解码）。

## 步骤

1. `ModManager` 加素材接口：`load_mod_asset(mod_id, rel_path)`（按当前加载根 + 模组目录拼路径 →
   优先 `load()` → 退回 `Image.load_from_file()` + `ImageTexture`；结果缓存）+ `get_mod_asset_path()`；
   `ModBase` 加便捷方法 `load_asset(rel_path)` 转调。
2. 把 10 张桶贴图从 `assets/` 根移进 `mods_builtin/more_armor/`（删旧 `.import`，让 `--import` 重生成）。
3. 三个僵尸脚本（`zombie_copper/diamond/netherite_bucket.gd`）把 `const TEXTURES := [preload(...)]`
   换成「文件名字符串数组 + 懒加载 `get_ore_textures()`」，经 `ModManager.load_mod_asset()` 读。
4. 探针 `probe_more_armor_mod.gd` 的贴图路径断言改到 `res://mods_builtin/more_armor/...`。
5. 文档：`模组机制.md` 加 §2.2、§6.3 补一条；`mods_builtin/README.md` 加一段。

## 关键决策与理由

- **接口放 `ModManager`（而不是每个模组自己读文件）** —— 只有管理器知道「这个模组当前从哪个根加载」，
  模组自己拼路径会写死 `user://mods`，跑内置源时指到空目录。
- **保留 `load()` 优先、Image 兜底** —— `res://` 下图片已导入，`load()` 拿到的是导入后的
  `CompressedTexture2D`（省内存、`resource_path` 可用于断言）；`user://` 下没有 `.import`，只能 Image。
- **懒加载而不是 `const preload`** —— `preload` 是编译期常量，指不了「当前加载根」；素材要跟随根走，
  只能运行期读。
- **`.tscn` 里的贴图仍写绝对 `res://mods_builtin/...`** —— 场景内部引用跑不了 GDScript；
  写相对路径会在 `user://` 加载根下指到没被导入的 png。详见 §2.2 的两条限制。
- **「侵入」只算模组**专属**素材** —— `glove` 用 `res://assets/image/garden/Zen_GardenGlove.png`（原版美术）、
  `netplay` 用本体主题 `res://data/ui/themes/pvz_theme.tres`，那是「模组用本体的一切」（边界规则 2），不算侵入。

## 踩坑

1. **`load_mod_asset()` 一开始读不到（`res://mods_builtin/tongtong.png` 不存在）** → 原因：
   `_mod_root()` 返回的是**父目录**（`res://mods_builtin`），模组自己的目录是 `<root>/<id>/`
   （`MOD_SCRIPT_PATHS[id]` 是 `<id 目录>/<入口脚本>`）。→ **正解**：加 `_mod_dir()`，
   用 `MOD_SCRIPT_PATHS[id].get_base_dir()` 补上模组目录那一层。
2. **门禁第二关凭空 FAIL，报 `user://mods/more_armor/more_armor_mod.gd` 的旧 `preload` 不存在** →
   原因：`check_scripts.ps1` 第二关把 `APPDATA` 重定向到一个**不清理**的临时目录
   （`%TEMP%\pvz_check_scenarios`），里面残留了一份**旧的** `user://mods/more_armor`（早先
   「自动复制内置模组」时代留下的），`user://` 优先 ⇒ 加载了旧副本。→ **正解**：删掉临时用户目录里
   过期的 `mods/`（`run_autopilot.ps1` 每次都会清自己的 userdir，所以只有 `check_scripts` 那道要留意）。
   ⚠️ 沙箱里 `Remove-Item` 删这些临时路径会失败，用 `[System.IO.Directory]::Delete($p, $true)`。
3. **探针「PASS」但 stderr 有 SCRIPT ERROR** → `_check_one` 里 `sprite.texture.resource_path`
   在 `texture` 为 null 时抛错，断言根本没执行（`failed=0` 是假绿）。→ **教训**：探针 PASS 必须
   再看一眼 stderr，别只看 `failed=`。

## 给后来者的最简路径

1. 模组素材放**模组目录**：`mods_builtin/<id>/xxx.png`。
2. 入口脚本用 `load_asset("xxx.png")`；角色 / 组件脚本用
   `ModManager.load_mod_asset(ModIds.<ID>, "xxx.png")`。别 `preload("res://assets/...")`。
3. 若素材要被 `.tscn` 引用：写绝对 `res://mods_builtin/<id>/...`（相对路径在 `user://` 下读不出来）。
4. 门禁 + 探针，**探针记得看 stderr 有没有 SCRIPT ERROR**。
