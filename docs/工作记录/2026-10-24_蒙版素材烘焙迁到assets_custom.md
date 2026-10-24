<!-- AGENT-DOC: record -->

# 2026-10-24_蒙版素材烘焙迁到assets_custom

> **本次任务**：把 `pak/` 里「`xxx.jpg` + `xxx_.png` 灰度蒙版」这批素材的引用全部改到 `assets_custom/` 的烘焙 RGBA PNG。
> **耗时 / 轮次**：1 轮排查 + 1 轮批量改 + 门禁（未开游戏，纯资源路径 / 像素验证）
> **推荐度**：推荐（下次遇到同类「素材迁移收尾」直接照抄）

## 目标

- 查清代码里哪些地方引用了「底图 + `_` 灰度蒙版」这一对素材；
- 引用一律指向**单张烘焙 RGBA PNG**，且产物住在 `assets_custom/`（`pak/` 保持原版素材原样）。

## 最简路径（步骤）

1. **先把配对全找出来**（仓库根目录）：

   ```powershell
   Get-ChildItem -Path "pak" -Recurse -File -Include *.png,*.jpg,*.jpeg |
     Where-Object { $_.BaseName -match '.+_$' }
   ```

   共 31 对；其中 13 对在 `pak/` 里已有同名烘焙 `.png`（迁移前的半成品状态），18 对没有。

2. **再看代码怎么引的**，分三种坏味道查：

   ```powershell
   # a) 直引黑白蒙版：画面会变成灰度剪影（最隐蔽）
   'res://(pak|assets_custom)/[^"]*_\.(png|jpg)'
   # b) 直引未合成的 jpg 底图：整块不透明
   'res://(pak|assets_custom)/[^"]*\.(jpg|jpeg)'
   # c) 引 pak 里已烘好的 png（要搬 assets_custom）
   'res://pak/[^"]*\.png'
   ```

   实测 a) 剩 8 个名字、全部在 `pak/reanim/`：`tree6_/tree7_/tree8_/tree9_/tree_grass_/tree_overlay8_/tree_overlay9_/ZombiesWon_`。

3. **确认 `assets_custom/` 里的那批烘焙图真的烘过**（别拿灰度蒙版当产物）：

   ```powershell
   ffmpeg -i <png> -vf "scale=1:1:flags=area,format=rgba" -frames:v 1 -f rawvideo -pix_fmt rgba -
   # 读第 4 个字节：255≈全不透明（未烘），明显小于 255 且 ≈ 蒙版灰度均值 ⇒ 已烘
   ```

4. **缺的才现烘**，用 `tools/merge_alpha.ps1` 的 `-Out`（本次给它加的）把产物直接落 `assets_custom/`：

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/merge_alpha.ps1 `
     -Name pak/images/options_menuback `
     -Out assets_custom/image/ui/ui_main_game_menu/options_menuback.png
   ```

5. **改引用**：`animation/**/*.tres` 里是纯 `path=` 行，按字符串批量替换即可（`animation` 目录 51 个文件一次改完）；
   `.tscn` / `data/*.tres` 里带 `uid=` 的行要**连 uid 一起换**，否则 Godot 优先认 uid、还指着 `pak/` 的老文件。

6. **补 `uid`**：先 `godot --headless --path . --import` 生成新图的 `.import`，再从 `.import` 里取 `uid` 写回 `.tres`。

7. **验证**：`test/check_scripts.ps1` 过门禁；资源可用 `godot --headless --script` 逐个 `load()`（只 load 贴图 / 数据 / 动画，**别 load 场景** —— `--script` 模式没有 autoload，引用 `Global`/`Log` 的脚本会编译失败，误报一片）。

## 弯路 / 踩坑（三段式）

- **试过**：写了个 `SceneTree` 脚本一次性 `load()` 所有受影响的 `.tscn` + `.gd` 做冒烟。
- **因为**：`--script` 启动的是裸 `SceneTree`，`project.godot` 的 autoload 不挂，`Global`/`Log`/`EventBus` 全成了未定义标识符，满屏 `Compile Error`，真正的失败被淹没。
- **结论**：`--script` 自检只 load **纯资源**；场景类的验证交回 `test/check_scripts.ps1` + 打开游戏，路径层面另用「文本里所有 `res://` 逐个 `Test-Path`」兜一道。

- **试过**：只改 `.tscn` 的 `path=`，保留原有 `uid=`。
- **因为**：以为 Godot 会按新 path 重新绑定。
- **结论**：Godot 4 优先解析 `uid`，path 只是注释 —— 老 uid 还在就仍加载 `pak/` 的老文件，画面看似没变，容易误判「改完了」。

## 推荐度与理由

推荐：整套流程是机械的，排查脚本与像素判定都能复用。要点只有两条 ——
**「`_` 结尾的文件是蒙版不是图」**、**「改 `.tscn`/`.tres` 的贴图路径必须连 uid 一起换」**。

## 补充 / 评价（事后追加，见 §5）
