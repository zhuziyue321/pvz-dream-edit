<!-- AGENT-DOC: archive -->
# dlc 模组 —— DLC 植物动画容器

> **[面向 AI Agent]** ｜ **触发条件**：要把 `reanim/` 下的 DLC 植物动画转成 Godot 动画、或往本模组接植物本体
> **读完你能**：知道动画素材在哪、怎么转换、转换后路径怎么改才自包含
> **强制级别**：**参考** ｜ **不读的风险**：转换后 `.tres` 指向 `res://pak/reanim/` 导致模组不自包含、导出后在 `user://` 读不到

## 1. 这个模组是什么

收纳一份《植物大战僵尸》DLC 的植物动画（reanim → Godot 动画），并把其中 **16 株接成能种的植物**
（完整清单 / 数值 / 探针见 [DLC植物导入](../../docs/参考存档/DLC植物导入.md) §8 登记表）。

**另兼收原「水盆」模组**（2026-10-18 并入）：`waterbowl/` 里的**水盆**套的是本体花盆场景那条
`Pot_waterplants` 动画，不是 DLC 素材 —— 摆在草地 / 屋顶上、上面只接水生植物（海蘑菇 / 缠绕海草），
上层植物的影子藏掉。配方 / 图鉴条目 / 水生植物地形位补丁都在 `dlc_mod.gd`（`_build_water_bowl_recipe()` 等），
开关与 16 株共用 `[dlc]` 段。

下面两株只作形态示例（直线/抛射/近战/一次性/支援的写法都在各自目录里）：

- **环轨仙人掌**（`kingcactus/`，美术资源名仍是 KingCactus）—— **紫卡**（种在本体仙人掌上升级），
  阳光 225 / 冷却 7.5 秒；**全屏索敌** + 八方向散射：任何一行有僵尸就一轮 8 根刺（每 45° 一根，
  一根 20，攻击间隔 1.6 秒）。尖刺走「径向匀加速 + 速度方向按恒定角速度转向」，且相邻两轮的转向相反
  （`kingcactus_spike.gd`）。
- **投掷蘑菇**（`pultshroom/`，Pult-shroom）—— 普通卡，阳光 0 / 冷却 7.5 秒；本行 6 格内抛射孢子
  （一颗 20，攻击间隔 2.85 秒），**白天睡觉**（蘑菇）。孢子继承本体 `bullet_parabola_base.tscn`。

两株的场景都继承本体 `plant_base.tscn`，动画直接用转换出来的 `<角色>.tscn`。

**另带两张 DLC 新地图的演示关**（`levels/`，见 [§8](#8-演示关levels)）：
`moon_roof_demo`（月夜屋顶 + 血月）与 `woods_demo`（郊外营地 + 灌木丛），
演示「新地图怎么接进关卡」的**最小写法**：`map_data` + `scene_name` 两行。
其余角色仍只有动画。要接下一株：**并行作业契约 + 填空式角色卡见 [DLC植物导入](../../docs/参考存档/DLC植物导入.md)**
（§1 文件归属矩阵与 `dlc_mod.gd` 的 5 个追加槽位、§5 角色卡、§7 自检表），通用挂组件见
[创建新角色](../../docs/参考存档/创建新角色.md)。
关掉模组 = 回到原版。

### 接植物本体时的一个坑：动画在哪个播放器里

转换工具把**每段动画各放进一个独立 `AnimationPlayer`**（`Anim_KingCactus_idle` / `_shooting` / `_blink` / `_face`），
而场景里那个 `AnimLib` 的库里**只有一条 `ALL_ANIMS` 合并动画** —— 既不是分段名、也没法按段播。

所以接植物时**不要**直接 `play("KingCactus_idle")`，要在自己的植物场景里覆盖 `AnimLib` 的 `libraries`：
把对应的几段 `.tres` 合成一个 `AnimationLibrary` 挂上去（写法见 `kingcactus/plant_kingcactus.tscn`）。
这样脚本只控制一个播放器，卡面取帧（`AnimationFrameUtil` 找的也是第一个 `AnimationPlayer`）也能取到分段动画。

## 2. 素材在哪

- 输入（reanim + 逐部件 PNG）：`mods_builtin/dlc/reanim/<角色>/`（已用 `tools/unwrap_reanim_compiled.py` 从 DLC 的 `.compiled` 壳剥出 reanim，PNG 也从 DLC 目录拷来）。
- 输出（转换后的 `.tres`）：`mods_builtin/dlc/animation/character/plant/<角色>/`（目录已预建）。

## 3. 转换步骤（在编辑器里做）

1. 先备插件：`addons/R2Ga_PVZ/` 已于 2026-10-18 从本仓库移除，从 [上游仓库](https://github.com/hsk-dream/PVZ_reanim2godot_animation) 取回后在「项目设置 → 插件」启用。
2. 打开 Godot 工程 → 底部面板 `R2Ga_PVZ`（路线 A，见 [动画导入](../../docs/参考存档/动画导入.md) §2）。
3. 对每个 `<角色>`：
   - 文件：选 `res://mods_builtin/dlc/reanim/<角色>/*.reanim`
   - 动画输出目录：`res://mods_builtin/dlc/animation/character/plant/<角色>/`
   - 图片输出目录：`res://mods_builtin/dlc/reanim/<角色>/`
   - 点运行（面板 `OS.execute` 拉起 `PVZ_reanim2godot_animation.exe`）。
4. 产物：每段动画一个 `.tres` + 每部件一张 PNG。

## 4. 路径自包含（好消息：无需事后改路径）

`PVZ_reanim2godot_animation.exe` 写进 `.tres` 的贴图路径**不是写死的**——它用的是你传入的「素材文件夹」那个 `res://` 路径（见官方文档命令格式 `r2ga <reanim> <动画文件夹> <素材文件夹> <mode>`）。所以只要按下面 §3 把素材目录填成 `res://mods_builtin/dlc/reanim/<角色>/`，`.tres` 就自引用模组目录，天然自包含，导出后在 `user://mods/` 也能读到，**不用事后批量替换路径**。

（之前担心硬编码 `res://pak/reanim/` 是误判——那只是现役 `.tres` 当初被人把素材目录填成了 `pak/reanim` 而已。）

## 5. ⚠️ PNG 命名 / 找不到图的排查

- DLC 的 reanim **不内嵌图**（PultShroom 解压才 ~41KB，装不下 15 张图），图是按名引用的；素材 PNG 已由整理脚本放进 `mods_builtin/dlc/reanim/<角色>/`，也就是 §3 推荐的素材目录，工具直接能在那儿读到。
- 工具从 `IMAGE_REANIM_PULTSHROOM_BODY-1` 推导期望的 PNG 名（去 `IMAGE_REANIM_` 前缀、小写、保留 `-1` 这类变体后缀）。DLC 原 PNG 正是 `PultShroom_body-1.png` 这种命名，作者用的就是同一套工具链，**大概率已经对上**（Windows 路径不区分大小写，大小写也不怕）。
- 若某株转换时报「找不到图」：就是命名对不上（多见于变体后缀 `-1` / `_c1` 的差异）。拿那一株如 `PultShroom` 先试转，看 `reanim/` 里工具实际期望的 PNG 名，再把 DLC 原 PNG 重命名成它要的名即可。

## 6. 产物落在哪

`auto` 模式每个 reanim 产出：每段动画一个 `.tres`（如 `pultshroom_idle.tres`）+ 一个 `<reanim名>.tscn`。这些和 PNG 一起都在 `mods_builtin/dlc/` 下 → 模组自包含。后续接植物本体时，角色场景直接 `preload` 这些 `.tscn` / `.tres`。

## 7. 音效与特效素材（不走 `reanim/`，别混进去）

> 这两批是**表现层**素材（2026-10-18 补进来的），与 §2 的逐部件素材不是一回事 ——
> `reanim/` 下的 PNG 会被当成角色部件，这些图放进去会乱。

| 类别 | 放哪 | 怎么接 |
|---|---|---|
| 音效 `.ogg` | `audio/`（模组共用一份） | 脚本里 `preload("../audio/<名字>.ogg")`，播放走 `SoundManager.play_sfx_with_pool()`（autoload 现成的池 + 25 物理帧去重）**不要**用 `play_character_SFX()` —— 那个只认本体 `SFXCharacterMap` 里登记的名字 |
| 特效 PNG | `<植物小写>/`（与该植物的 `.tscn` / `.gd` 同目录） | 横向序列帧用 `dlc_sprite_fx.gd`（`new()` + `add_child` + `setup(贴图, 帧数, fps)`）；子弹命中特效走 `BulletEffect` 节点 + `GPUParticles2D` 的 `particles_animation`（本体既有路子，**样板见 `kingcactus/kingcactus_spike.tscn`**，`is_bullet_effect = true` 要显式写）。⚠️ 别照抄 `pultshroom/bullet_pultshroom_spore.tscn` 与 `mortarshroom/bullet_mortarshroom_shell.tscn`：那两份用的是 21×21 **单帧**烟，刻意没开 `particles_animation`（理由见 §7.1 末尾） |

### 7.1 素材规格（美术按这套给的，别自己换）

- 命名全小写 + 下划线；**横向单行序列帧**（`dlc_sprite_fx.gd` 只按横向切帧）；同组单帧尺寸一致。
- 各图的帧数（改图就要同步改调用处的帧数常量）：

| 图 | 单帧 | 帧数 | 用在哪 |
|---|---|---|---|
| `lemonade/lemonade_blast.png` | 128×128 | 6 | 柠檬榴弹三次爆炸 |
| `aloe/aloe_heal.png` | 64×64 | 4 | 芦荟治疗，落在**被治疗的植物**身上 |
| `ampliflower/ampliflower_aura.png` | 128×128 | 1 | 增幅鹅河菊的增益标记（挂在被增幅的植物身上） |
| `ampliflower/ampliflower_note.png` | 32×32 | 3 | 同上，循环飘的小音符 |
| `glowshroom/glow_particle1.png` | 3×3 | 1 | 光照蘑菇光晕里上升的小光点（DLC 原件，`Gloweffect.reanim` 的 `Glow_particle1` 轨道同款）。⚠️ 与 `pak/particles/glow_particle1.png` 是同一张图的**两份拷贝**：模组内这份是为了自包含（§4），保留双份；换图时两边一起改，只改一边就会「模组版与本体版不一致」 |
| `mortarshroom/mortarshroom_shell.png` | 32×32 | 1 | 臼炮蘑菇的炮弹贴图（原来借投掷蘑菇的孢子） |
| `kingcactus/kingcactus_spike.png` | 20×20 | 1 | 环轨仙人掌的尖刺（原来借本体 `ProjectileCactus.png`） |
| `beeshooter/beeshooter_bee_fly.png` | 61×46 | 3 | 蜜蜂振翅（改 `BulletBody.region_rect` 切帧） |
| `beeshooter/beeshooter_hit.png` | 32×32 | 3 | 蜜蜂命中 |
| `oakarcher/oakarcher_hit.png` | 32×32 | 3 | 箭命中 |
| `kingcactus/kingcactus_hit.png` | 32×32 | 3 | 尖刺命中 |
| `chardguard/chardguard_knock.png` | 48×48 | 3 | 甜菜守卫击退，落在**被崩飞的僵尸**身上 |
| `shrinkingviolet/shrinkingviolet_wave.png` | 128×128 | 6 | 缩小紫罗兰施法波（放大 6 倍铺开） |
| `reanim/PultShroom/PultShroom_spore-1.png` | 29×28 | 1 | 投掷蘑菇的孢子（直接拿 reanim 部件图当子弹贴图，场景里缩到 0.6） |
| `reanim/OakArcher/oak_archer_arrow.png` | 115×18 | 1 | 橡木弓箭手的箭（同上，reanim 部件图） |

⚠️ **命中烟是唯一的例外**：投掷蘑菇 / 臼炮蘑菇的命中（溅射）烟借的是本体
`pak/particles/PuffShroom_puff2.png`，它是 **21×21 的单帧图**（DLC 包里
`MortarShroomMuzzle` / `MortarShroomSplat` / `MortarShroomTrail` 指向的
`IMAGE_PUFFSHROOM_PUFF2` 也是这张）。所以这两处 **不能开**
`CanvasItemMaterial.particles_animation` —— 一开就按 `h_frames = 3` 把单帧烟横切成
3 条 7×21 的细条并循环跳帧。蜜蜂 / 尖刺 / 箭那三张 96×32 的命中图才是真三帧，别互相照抄。
（代价是引用了 `res://pak/`，与 §4 的自包含口径有出入；等有 DLC 自有多帧烟图再换掉。）

### 7.2 音效接线条（哪株用哪一条）

| 音效 | 接在哪 |
|---|---|
| `mortarimpact` / `mortarimpact2` | 臼炮蘑菇炮弹落地（`bullet_mortarshroom_shell.gd` 的 `attack_once`） |
| `reed_zap` / `reed_zap2` / `reed_zap3` | 闪电芦苇放电 |
| `lightning` / `lightning2` / `lightning3` | 闪电芦苇**充能后**叠的远距雷声 |
| `voltage` / `electric_zap` | 电击蘑菇放电 |
| `bee_1` / `bee_2` | 蜜蜂射手吐蜜蜂 |
| `bonk1` / `bonk2` | 拳击白菜直拳 / 上勾拳 |
| `shrinkingviolet` | 缩小紫罗兰绽放 |
| `bloodexplosion` | 血橙引爆 |
| `fuse1` / `fuse2` | 血橙 / 柠檬榴弹种下时点引信 |
| `shootingstar` | **暂未接线**：海杨桃（AngelStarfruit / Shootingstar）还没接成能种的植物，等接上再挂发射 |

> 其余几株（环轨仙人掌 / 投掷蘑菇 / 橡木弓箭手 / 甜菜守卫 / 光照蘑菇 / 飓衣甘蓝 / 芦荟 / 增幅鹅河菊）
> DLC 包里没有专属音效，继续借本体的 `Throw` / `CherryBomb` / `PlantGrow`，别硬套。

---

## 8. 演示关（`levels/`）

DLC 版移植进来两张新地图（月夜屋顶 / 郊外营地），各配一关**演示关**放在本目录的 `levels/` 下，
由「自制关卡」模组扫描（各模组目录下的 `levels/`，一个子目录 = 一关，关卡 id = 目录名，
不论本模组启用与否都扫 —— 但选关页要开「自制关卡」模组才进得去）：

| 关卡 id | 演示什么 | 最小写法 |
|---|---|---|
| `moon_roof_demo` | 月夜屋顶（第 6 章 Moon）+ 旗帜波血月 | `map_data = preload("res://data/map/map_moonroof.tres")` + `scene_name = SceneSettingRegistry.SCENE_MOON_ROOF` |
| `woods_demo` | 郊外营地（第 7 章 Woods）+ 灌木丛 | `map_data = preload("res://data/map/map_woods.tres")` + `scene_name = SceneSettingRegistry.SCENE_WOODS` |

**两张图都不在 `MainSceneRegistry.DEFAULT_MAP_PATHS` 里**（它们与屋顶 / 前院同几何，只换底图与
背景子场景），所以 `map_data` 必须由关卡自己指定 —— 只写 `scene_name` 会落到默认图上。
两关的出怪表只点名本体僵尸，**不依赖任何模组开关**（关掉 DLC 模组照样能打）。

新增同款演示关：复制一个目录 → 改 `map_data` / `scene_name` / 波数即可；
关卡格式（属性写在 `_init()`、流程写在 `run_flow()`）见 `mods_builtin/custom_level/levels/fog_50_waves/level.gd`。
