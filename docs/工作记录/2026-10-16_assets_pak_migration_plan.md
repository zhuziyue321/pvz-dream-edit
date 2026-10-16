<!-- AGENT-DOC: work-record -->
# 工作记录：素材统一切换到 pak/ 原版素材（映射方案）

> 面向 AI Agent：本文是「把 assets/ 引用逐步迁到 pak/ 原版素材」的方案与数据底座，**尚未执行批量改写**。
> 执行前请先审本方案 + 两个工具脚本；执行时按 `--scope` 分批、每批跑编译门禁并实测。
> 关联：README.md 顶部已加 `pak/` 原版素材版权警告。

## 1. 背景与决策

- 仓库现有两套素材：`assets/`（替换 / AI 生成素材，5000+ 文件，原版缺失时的替代）与 `pak/`（从原版安装包解包的原始素材，3000+ 文件）。
- 决策：**统一改用 `pak/` 原版素材**。但**不做一次性全量迁移**，而是让两个目录并存、引用逐批从 `res://assets/...` 迁到 `res://pak/...`，未迁的仍走 `assets/`、已迁的走 `pak/`，全程游戏不崩（即「两个加载通道都可以用，慢慢搬」）。
- ⚠️ 版权：README 已声明 `pak/` 原版素材版权归 PopCap/EA，不随本仓库许可二次分发。

## 2. 映射分析数据（tools/analyze_asset_mapping.py，只读）

扫描 `src/` + `test/` 的 `.gd`/`.tscn`：

| 指标 | 数值 |
| --- | --- |
| 总引用次数（含重复） | 3041 |
| 去重引用条数 | 1574 |
| 去重文件名数 | 1561 |
| 在 `pak/` 按文件名命中 | 1473 |
| 在 `pak/` 未命中（保留在 assets/） | 101（约 100 个文件名） |

- 命中率 93.6%，映射基本是 **1:1 按文件名**。
- 未命中的主要是：`fonts/`（simsun.ttc、方正少儿_gbk.ttf、bake_soda.otf，pak 无 fonts 目录）、BGM 原声带（*.mp3）、项目原创/宽屏素材（*_mask.png、selectorscreen_*、challenge_thumbnail_*、store_car.png、tree6-9.png 等）。这些**留在 assets/**。
- 明细：`tools/asset_mapping_report.csv`、`tools/asset_mapping_miss.txt`。

## 3. 关键风险：pak/ 内文件名碰撞（16 个）

同名文件出现在多个 pak 位置，例如 `doom.png`(images vs particles)、`finalwave.png`(images vs reanim)、`treefood.png`(images vs reanim)。纯「按文件名取首个」会选错。

**策略：按原引用类别优先匹配**（`tools/migrate_assets_to_pak.py` 内 `CAT_PREF`）：
`assets/image/*→pak/images`、`assets/reanim/*→pak/reanim`、`assets/audio/*→pak/sounds`、`assets/particles/*→pak/particles`。
优先类别无命中时回落到任意 pak 位置，并在 `[fallback]` 列出供人工核对。实测 `src/items` 仅 7 处 fallback，且均为「原路径归在 image 类、文件实则在 pak/particles/」的良性回落。

## 4. 迁移脚本草案（tools/migrate_assets_to_pak.py，未执行）

核心逻辑：
- 按「整条 `res://assets/.../X` → `pak` 命中路径」替换（**不是前缀替换**，因目录结构不同）。
- 仅当文件名（含扩展名，小写）确实存在于 `pak/` 才改写，天然跳过 `.gd` 注释噪声与无对应素材。
- 对 `.tscn`：改写 `ext_resource` 的 `path` 后**剥离失效的 `uid="uid://..."`**，避免 Godot 按 uid 解析到错误资源。
- 默认 **DRY-RUN（不写盘）**；`--apply` 才真写；`--scope <子目录>` 支持分批。

用法：
```powershell
python tools/migrate_assets_to_pak.py                      # 预览全部
python tools/migrate_assets_to_pak.py --scope src/entities  # 预览某目录
python tools/migrate_assets_to_pak.py --scope src/entities --apply  # 执行某目录
```

## 5. 验证（硬约束 §1-7）

每搬一批后：
1. 跑编译门禁：`powershell -ExecutionPolicy Bypass -File test/check_scripts.ps1`，要求 `real compile errors = 0`。
2. 打开游戏实测：重点查改写过的 `.tscn` 场景能正常打开、贴图/音频/动画不丢失（`.tscn` 资源失效会直接导致场景打不开）。
3. 留意 `[fallback]` 列出的条目，确认目标路径是想要的那一个。

## 6. 关于「两个加载通道」的实现说明（重要约束）

Godot 的 `preload("res://...")` 是**编译期固化**路径，无法运行时拦截；`.tscn` 的 `ext_resource` 也按字面路径+uid 加载。因此**无法在不重构全部加载调用的情况下做「运行时一键切换 assets/pak」**。

本方案采用的「两个通道」= **两个目录都保留在磁盘，引用逐条迁移**——这天然满足「慢慢搬且中途可运行」。若你确实需要「运行时开关在两套素材间切换」，那是另一项更大的重构（需把所有 `preload/load` 改走运行时解析器、并为 `.tscn` 外链资源做重定向），请另开任务。

## 7. 下一步（待你确认后执行）

1. 审阅本方案 + `tools/migrate_assets_to_pak.py` 草案。
2. 从低风险、引用集中的目录开始（如 `src/items` 已验证 dry-run 通过），用 `--scope` 逐批 `--apply`。
3. 每批跑编译门禁 + 游戏实测，再继续下一批。
