extends "res://src/mods/mod_base.gd"
## 模组「DLC」：把某份《植物大战僵尸》DLC 里的植物动画搬进本作
##
## ★ 为什么做成模组：原版（PVZ1）没有这些植物，所以整件东西放进模组，
##   关掉模组 = 回到原版（场景里不会多出任何节点）。
##
## ★ 动画来源：DLC 的 `*.reanim.compiled` 是 PopCap 的 compiled 壳包着标准 reanim 二进制；
##   已用 `tools/unwrap_reanim_compiled.py` 全部剥壳成 `mods_builtin/dlc/reanim/<角色>/*.reanim`。
##   转换用编辑器插件的 R2Ga_PVZ 面板（该插件 2026-10-18 已移出仓库，需从上游取回 `addons/R2Ga_PVZ`）：选一个 `.reanim`，
##   动画输出目录指 `res://mods_builtin/dlc/animation/character/plant/<角色>/`，
##   图片输出目录指 `res://mods_builtin/dlc/reanim/<角色>/`，点运行。
##   （路线 A，见 [动画导入](../../docs/参考存档/动画导入.md) §2；
##     ⚠️ 工具写进 `.tres` 的贴图路径默认是 `res://pak/reanim/<Part>.png`，
##     转换后需把 PNG 落位 / 改路径到模组目录，保证模组自包含 —— 见本目录 `README.md`）
##
## ★ 当前进度：33 只角色的动画已导入，**已接十七株能种的植物**
##   （十六株来自 DLC 动画，另一只是套本体花盆动画的水盆，见列表最后一行）：
##   · 环轨仙人掌（美术资源名 KingCactus，紫卡，种在本体仙人掌上升级）
##   · 投掷蘑菇（PultShroom，0 阳光的抛射投手，白天睡觉）
##   · 拳击白菜（BonkChoy，150 阳光的近战出拳植物）
##   · 臼炮蘑菇（MortarShroom，75 阳光，抛射投手：贴脸的也打得到，白天睡觉）
##   · 闪电芦苇（Reed，125 阳光，短距链状闪电，自动连锁最近的僵尸）
##   · 血橙（BloodOrange，150 阳光，即炸植物，种下短暂待机后原地引爆 3×3）
##   · 电击蘑菇（VoltShroom，100 阳光，周围 3×3 放电 AOE，白天睡觉）
##   · 橡木弓箭手（OakArcher，200 阳光的本行直线射手，射箭又远又准）
##   · 蜜蜂射手（BeeShooter，100 阳光的本行直线射手，张嘴吐蜜蜂）
##   · 柠檬榴弹（Lemonade，200 阳光，樱桃炸弹变体：本格炸一下后随机弹到邻近区域连炸）
##   · 水盆（**不是 DLC 素材**：花盆的水生形态，套花盆场景的 `Pot_waterplants` 那一支；
##     摆在草地 / 屋顶上、上面只接水生植物。原水盆模组 2026-10-18 并入本模组）
##   其余角色仍只有动画；要接下一株，照本文件 `_build_kingcactus_recipe()` /
##   `_build_pultshroom_recipe()` 的写法
##   （见 [创建新角色](../../docs/参考存档/创建新角色.md) 与 pvz2 模组的 `_build_*_recipe()`）。
##
## 跨文件引用：`user://` 下脚本的 `class_name` 不会注册成全局类（实测 Godot 4.6.2），
## 所以上级目录的文件一律 preload 成常量再引用，不能写 `extends ModBase`
const ModBase := preload("res://src/mods/mod_base.gd")

## 环轨仙人掌的场景（本体 `plant_base.tscn` + DLC 动画 + 自写射手逻辑）
const KING_CACTUS_SCENE := preload("kingcactus/plant_kingcactus.tscn")
## 投掷蘑菇的场景（同上，攻击方式换成抛物线抛射）
const PULT_SHROOM_SCENE := preload("pultshroom/plant_pultshroom.tscn")
## 柠檬榴弹的场景（一次性三连炸植物，自写范围爆炸逻辑）
const LEMONADE_SCENE := preload("lemonade/plant_lemonade.tscn")
## 缩小紫罗兰的场景（本体 `plant_base.tscn` + DLC 动画 + 自写一次性缩小逻辑）
const SHRINKING_VIOLET_SCENE := preload("shrinkingviolet/plant_shrinkingviolet.tscn")
## 蜜蜂射手的场景（本体 `plant_base.tscn` + DLC 动画 + 自写直线射手逻辑）
const BEE_SHOOTER_SCENE := preload("beeshooter/plant_beeshooter.tscn")
## 飓衣甘蓝的场景（同上，攻击方式换成「一次性全场飓风：冰冻 + 击退」）
const HURRIKALE_SCENE := preload("hurrikale/plant_hurrikale.tscn")
## 橡木弓箭手的场景（本体 `plant_base.tscn` + DLC 动画 + 自写直线射手逻辑）
const OAK_ARCHER_SCENE := preload("oakarcher/plant_oakarcher.tscn")
## 光照蘑菇的场景（同上，光源辅助：夜里光域里击杀僵尸掉小阳光）
const GLOW_SHROOM_SCENE := preload("glowshroom/plant_glowshroom.tscn")
## 血橙的场景（DLC 的 BloodOrange，即炸植物：种下短暂待机后原地引爆 3×3）
const BLOOD_ORANGE_SCENE := preload("bloodorange/plant_bloodorange.tscn")
## 臼炮蘑菇的场景（攻击方式换成「抛射 + 落地溅射」；近身**不是**盲点，见 `mortarshroom_plant.gd`）
const MORTAR_SHROOM_SCENE := preload("mortarshroom/plant_mortarshroom.tscn")
## 闪电芦苇的场景（同上，攻击方式换成短距链状闪电）
const REED_SCENE := preload("reed/plant_reed.tscn")
## 拳击白菜的场景（近战：本行左右两格出拳，不用子弹）
const BONK_CHOY_SCENE := preload("bonkchoy/plant_bonkchoy.tscn")
## 芦荟的场景（支援：3×3 范围治疗，不攻击）
const ALOE_SCENE := preload("aloe/plant_aloe.tscn")
## 电击蘑菇的场景（同上，攻击方式换成周围 3×3 放电 AOE）
const VOLT_SHROOM_SCENE := preload("voltshroom/plant_voltshroom.tscn")
## 甜菜守卫的场景（高血量防御 + 近战击退，不用子弹、不造成伤害）
const CHARD_GUARD_SCENE := preload("chardguard/plant_chardguard.tscn")
## 增幅鹅河菊的场景（范围增益：给周围 3×3 植物的攻击 / 产阳光提速）
const AMPLIFLOWER_SCENE := preload("ampliflower/plant_ampliflower.tscn")
## 水盆的场景（本体花盆场景 + 打开 `is_water`，动画取花盆那条 `Pot_waterplants`）
const WATER_BOWL_SCENE := preload("waterbowl/plant_water_bowl.tscn")

#region 常量
## ⚠️ 2026-10-20 偏移重设（等待逐株微调）：
##   ① **摆放偏移**：16 株场景里 `Body/<角色>Anim.position` 统一改成 `Vector2(-38, -57.5)`
##      —— 先归零、再整体**左移半格 / 上移半格 + 再上移 10 px**
##      （格子基准 `plant_cell.tscn` 的 76×95，半格 = 38 / 47.5）；
##      6 株有出弹点的（蜜蜂 / 闪电芦苇 / 投掷 / 橡木 / 臼炮 / 环轨）`Marker2D` 同步按同一条
##      「画布点 + 动画 position」换算移了，保证子弹还是从嘴 / 篮口出去；
##   ② **卡面偏移**：下面各株的 `*_CARD_FACE_SCALE` / `*_CARD_FACE_POSITION` 全部回到配方默认
##      `Vector2(0.4, 0.4)` / `Vector2(1, 11)`（环轨仙人掌本来就没写这两项，用的就是默认值）。
##   注释里留着的「实测内容中心 ≈ …」是**归零前的旧值**，只当重调时的参考，不代表当前值。
##   重调口径见 [DLC植物导入](../../docs/参考存档/DLC植物导入.md) §6.2：摆放以运行期
##   `get_content_rect()` 对齐本体同类植物的内容底边；卡面落点 = -整株内容中心 × 缩放。
##   调完要连带改各株 `probe_dlc_*.gd` 里的摆放 / 卡面断言（归零后这两条现在必 FAIL）。
## 植物 id：字符串 id 自己起即可，本体不必再留 `PlantIds` 空槽位
const KING_CACTUS := &"dlc_kingcactus"
const PULT_SHROOM := &"dlc_pultshroom"
const LEMONADE := &"dlc_lemonade"
const SHRINKING_VIOLET := &"dlc_shrinkingviolet"
const OAK_ARCHER := &"dlc_oakarcher"
const GLOW_SHROOM := &"dlc_glowshroom"
## 血橙（即炸植物：种下短暂待机后原地引爆 3×3，炸完即走）
const BLOOD_ORANGE := &"dlc_bloodorange"
## 臼炮蘑菇
const MORTAR_SHROOM := &"dlc_mortarshroom"
const REED := &"dlc_reed"
## 芦荟（DLC 的 AloeVera）
const ALOE := &"dlc_aloe"
## 电击蘑菇
const VOLT_SHROOM := &"dlc_voltshroom"
## 甜菜守卫（高血量防御 + 近战击退）
const CHARD_GUARD := &"dlc_chardguard"
## 增幅鹅河菊（范围增益：给周围 3×3 植物的攻击 / 产阳光提速）
const AMPLIFLOWER := &"dlc_ampliflower"

## 中文名「环轨仙人掌」（DLC 里的 Orbitus；美术资源名仍叫 KingCactus，文件名不改）
## 数值对齐 DLC Edition wiki 的 Orbitus 页：售价 225 阳光、**冷却 50 秒（very slow）**
## （旧值 7.5 秒是模组自定的，与「紫卡大件」的定位不符）
const KING_CACTUS_COOL_TIME := 50.0
## 紫卡售价：225 阳光；还要先有本体仙人掌当基座，种下去会把基座顶掉
## （wiki：通关 7-4 后在疯狂戴夫那儿花 $10,000 买 —— 本模组不设解锁条件，装上就有）
const KING_CACTUS_SUN_COST := 225
## 紫卡的前置植物：本体仙人掌（经 `AllPrePlantPurple` 登记，种下去升级成环轨仙人掌）
const KING_CACTUS_PRE_PLANT := PlantIds.CACTUS

## 卡面从 DLC 动画的待机段取第 0 帧（`AnimationFrameUtil` 会自己往深里找播放器，
## 找到的是动画场景里那个装了全部四段的 `AnimLib`）
const KING_CACTUS_CARD_ANIM := &"KingCactus_idle"
## 取帧失败时借大嘴花的脸（卡面一空，手持会报「卡片静态角色为空」拿不起来）
const FALLBACK_PLANT := PlantIds.CHOMPER

## 投掷蘑菇：数值照 DLC Edition 的 wiki（Pult-shroom 页）—— 0 阳光 / 冷却 7.5 秒（fast）
const PULT_SHROOM_COOL_TIME := 7.5
const PULT_SHROOM_SUN_COST := 0
const PULT_SHROOM_CARD_ANIM := &"PultShroom_idle"
## 取帧失败时借小喷菇的脸（同为蘑菇卡，形状最接近）
const PULT_SHROOM_FALLBACK_PLANT := PlantIds.PUFF_SHROOM
## 卡面缩放 / 落点：**必须用运行期 `get_content_rect(卡面)` 量到的植物本地中心**（含运行期才塞贴图的
## `PultShroom_eyes`）；拿动画画布包围盒（x[2.7,58.6] y[22.4,62.4]）算会漏掉动画节点的 position，
## 整株被推到卡左上角外。实测本地中心 ≈ (1.3, 1.35)，0.5 缩放时偏移 = -中心 × 0.5 ≈ (-0.7, -0.7)；
## 内容 29.3×41.05 px（卡底图 50×70）
const PULT_SHROOM_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const PULT_SHROOM_CARD_FACE_POSITION := Vector2(1, 11)

## 缩小紫罗兰：数值对齐 DLC Edition wiki 的 Shrinking Violet 页 —— **100 阳光 / 冷却 30 秒
## （slow）/ 射程 3×3**（旧值 0 阳光 / 7.5 秒 / 全场是模组自定的，已按 wiki 改）。
## 种下即绽放、缩小**周围 3×3**的僵尸后自身消失（施法期间无敌），与寒冰菇 / 樱桃炸弹同类。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借小喷菇的脸（同为小体型花草，形状最接近）。
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (2.25, -3.75)，
## 0.46 缩放时偏移 = -中心 × 0.46 ≈ (-1.0, 1.7)；内容 31.5×58.7 px
## （0.5 缩放时高 63.75 px，会顶出卡底图 50×70 的上沿，故收一档）
const SHRINKING_VIOLET_COOL_TIME := 30.0
const SHRINKING_VIOLET_SUN_COST := 100
const SHRINKING_VIOLET_CARD_ANIM := &"ShrinkingViolet_idle"
const SHRINKING_VIOLET_FALLBACK_PLANT := PlantIds.PUFF_SHROOM
const SHRINKING_VIOLET_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const SHRINKING_VIOLET_CARD_FACE_POSITION := Vector2(1, 11)

## 血橙：即炸植物，数值对齐 DLC Edition wiki 的 Blood Orange 页 —— **75 阳光 / 冷却 50 秒
## （very slow）/ 900 伤害 / 3×3 范围**（旧值 150 / 30 / 1800 是模组自定的，已按 wiki 改）。
## wiki 正文：它是「半价、半伤的樱桃炸弹」，且是**飞行植物**（屋顶 / 泳池裸地都能直接种），
## 另外没被炸死的僵尸会吃到 Blood Moon 加速 —— 后两条见 `_build_blood_orange_recipe()`
## 与 `bloodorange/bloodorange_plant.gd`。美术资源名 BloodOrange，有 idle / explode 两段
## （另有一套万圣节皮肤 `BloodOrangeWerewolfCostume`，本模组暂不接）。
const BLOOD_ORANGE_SUN_COST := 75
const BLOOD_ORANGE_COOL_TIME := 50.0
const BLOOD_ORANGE_CARD_ANIM := &"BloodOrange_idle"
## 取帧失败时借樱桃炸弹的脸（同为红色圆形爆炸植物，形状最接近）
const BLOOD_ORANGE_FALLBACK_PLANT := PlantIds.CHERRY_BOMB
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (0.0, -8.7)，
## 0.5 缩放时偏移 = -中心 × 0.5 ≈ (0.0, 4.4)；内容 34.4×44.7 px
const BLOOD_ORANGE_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const BLOOD_ORANGE_CARD_FACE_POSITION := Vector2(1, 11)

## 臼炮蘑菇：数值照 DLC Edition 的 wiki（Mortar-shroom 页）—— 75 阳光 / 冷却 7.5 秒（fast）
const MORTAR_SHROOM_COOL_TIME := 7.5
const MORTAR_SHROOM_SUN_COST := 75
const MORTAR_SHROOM_CARD_ANIM := &"MortarShroom_idle"
## 取帧失败时借小喷菇的脸（同为蘑菇卡，形状最接近）
const MORTAR_SHROOM_FALLBACK_PLANT := PlantIds.PUFF_SHROOM
## 卡面缩放 / 落点：实测整株内容中心（植物本地，含动画节点的 position）≈ (1.65, -12.7)，
## 0.5 缩放时偏移 = -中心 × 0.5 ≈ (-0.8, 6.4)；内容 39.4×58.7 px
const MORTAR_SHROOM_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const MORTAR_SHROOM_CARD_FACE_POSITION := Vector2(1, 11)

## 拳击白菜：数值都是**模组自己的取值**（原版没有这株，DLC Edition 也只给了个名字）
## 中文名「拳击白菜」（DLC 美术资源名 BonkChoy）
const BONK_CHOY := &"dlc_bonkchoy"
const BONK_CHOY_SUN_COST := 150
const BONK_CHOY_COOL_TIME := 7.5
const BONK_CHOY_CARD_ANIM := &"BonkChoy_idle"
## 取帧失败时借卷心菜投手的脸（同为白菜类，形状最接近）
const BONK_CHOY_FALLBACK_PLANT := PlantIds.CABBAGE_PULT
## 卡面缩放 / 落点：实测整株内容中心（植物本地，含动画节点的 position）≈ (0.0, -23.75)，
## 0.5 缩放时偏移 = -中心 × 0.5 ≈ (0.0, 11.9)；内容 42.6×55.8 px
const BONK_CHOY_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const BONK_CHOY_CARD_FACE_POSITION := Vector2(1, 11)

## 闪电芦苇：数值照 DLC Edition 的 wiki（Lightning Reed 页）—— 125 阳光 / 冷却 7.5 秒（fast）/
## 伤害 10 / 攻击间隔 1.5 秒 / 射程 Three lanes（**跨三行**，检测框已按三行铺）。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借小喷菇的脸（同为小体型植物）。
## 卡面缩放 / 落点：探针 `get_content_rect()` 量到整株包围盒 P=(-26.06,-86.79) S=(53.62,98.62)，
## 中心 (0.75,-37.48)；按「0.5 缩放时偏移取 -中心×缩放」反推，0.4 缩放 → 落点 (-0.3, 15.0)。
const REED_COOL_TIME := 7.5
const REED_SUN_COST := 125
const REED_CARD_ANIM := &"Reed_idle"
const REED_FALLBACK_PLANT := PlantIds.PUFF_SHROOM
const REED_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const REED_CARD_FACE_POSITION := Vector2(1, 11)

## 芦荟：数值照 DLC Edition 的 wiki（Aloe Vera 页）—— 50 阳光 / 冷却 7.5 秒（fast）/
## 生命 300 / 3×3 群体治疗 / 每 3 秒治疗一次 / 治疗量不叠加。
## 页面没给单次治疗量，取模组值 30（见 `aloe/aloe_plant.gd` 的 `heal_amount`）。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借向日葵的脸（同为直立的陆生支援植物）。
## 卡面缩放 / 落点：**用运行期 `get_content_rect()` 量的整株包围盒中心**（不是动画画布坐标 ——
## 取帧拿到的是挂好 `AloeVeraAnim.position` 的整株，画布坐标会差一个动画节点的位移）。
## 实测 Body 内容 rect 中心 ≈ (0.0, -37.4)；按「内容中心落在卡面挂点」反推，
## 0.5 缩放时偏移 = -中心 × 0.5 = (0, 18.7)。（与本体向日葵卡面手摆值同一条公式验证过）
const ALOE_COOL_TIME := 7.5
const ALOE_SUN_COST := 50
const ALOE_CARD_ANIM := &"AloeVera_idle"
const ALOE_FALLBACK_PLANT := PlantIds.SUN_FLOWER
const ALOE_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const ALOE_CARD_FACE_POSITION := Vector2(1, 11)

## 电击蘑菇：数值对齐 DLC Edition wiki 的 Volt-shroom 页 —— **225 阳光** / 冷却 7.5 秒（fast）/
## 伤害「单目标约 40 DPS，多个目标之间均分」/ 生命 300 / **射程 3×5** / 白天睡觉
## （旧值 100 阳光 / 一次 400 各打各的 / 3×3 是模组自定的，已按 wiki 改）。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借小喷菇的脸（同为蘑菇卡，形状最接近）。
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (6.5, -5.35)，
## 0.42 缩放时偏移 = -中心 × 0.42 ≈ (-2.7, 2.2)；内容 31.1×59.9 px
## （这株外面套着笼子，0.5 缩放时高 71.35 px，会顶出卡底图 50×70 的上下沿，故收一档）
const VOLT_SHROOM_COOL_TIME := 7.5
const VOLT_SHROOM_SUN_COST := 225
const VOLT_SHROOM_CARD_ANIM := &"VoltShroom_idle"
const VOLT_SHROOM_FALLBACK_PLANT := PlantIds.PUFF_SHROOM
const VOLT_SHROOM_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const VOLT_SHROOM_CARD_FACE_POSITION := Vector2(1, 11)

## 甜菜守卫：数值对齐 DLC Edition wiki 的 Chard Guard 页 —— **75 阳光 / 冷却 30 秒（slow）/
## 生命 1500**（旧值 100 / 25 / 1600 是模组自定的，已按 wiki 改）。
## 出拳只**击退**不造成伤害：击退 3 格（228 px）、一共 3 次（三片叶子），用完变残血墙。
## 美术资源名 ChardGuard。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借坚果墙的脸（同为防御植物，形状最接近）。
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (0.0, -13.8)，
## 0.4 缩放时偏移 = -中心 × 0.4 ≈ (0.0, 5.5)；内容 35.5×59.0 px
## （0.5 缩放时高 73.8 px，会顶出卡底图 50×70 的上沿，故收一档）
const CHARD_GUARD_COOL_TIME := 30.0
const CHARD_GUARD_SUN_COST := 75
const CHARD_GUARD_CARD_ANIM := &"ChardGuard_idle"
const CHARD_GUARD_FALLBACK_PLANT := PlantIds.WALL_NUT
const CHARD_GUARD_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const CHARD_GUARD_CARD_FACE_POSITION := Vector2(1, 11)

## 光照蘑菇：数值照 DLC Edition 的 wiki（Lume-shroom 页）—— 阳光 50 / 冷却 30 秒（slow）/ 生命 300 / 白天睡觉
const GLOW_SHROOM_COOL_TIME := 30.0
const GLOW_SHROOM_SUN_COST := 50
const GLOW_SHROOM_CARD_ANIM := &"GlowShroom_idle"
## 取帧失败时借阳光菇的脸（同为产阳光的蘑菇，形状最接近）
const GLOW_SHROOM_FALLBACK_PLANT := PlantIds.SUN_SHROOM
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (16.6, -24.35)，
## 0.46 缩放时偏移 = -中心 × 0.46 ≈ (-7.6, 11.2)；内容 38.6×59.2 px
## （0.5 缩放时高 64.35 px，会顶出卡底图 50×70 的上沿，故收一档）
const GLOW_SHROOM_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const GLOW_SHROOM_CARD_FACE_POSITION := Vector2(1, 11)

## 橡木弓箭手：数值照 DLC Edition 的 wiki（Oak Archer 页）—— 200 阳光 / 冷却 7.5 秒（fast）/
## 伤害 80（普通攻击，wiki 带问号；暴击 160 未实现）/ 射程 1x9（本行 9 格）/ 攻击间隔 4.25 秒。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借豌豆射手的脸（同为直线射手，形状最接近）。
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (0.0, -52.15)，
## 0.34 缩放时偏移 = -中心 × 0.34 ≈ (0.0, 17.7)；内容 49.2×47.8 px
## （这株是整棵树带弓，0.5 缩放时 72.3×70.35 px，怎么摆都出卡，故按卡宽收一档）
const OAK_ARCHER_COOL_TIME := 7.5
const OAK_ARCHER_SUN_COST := 200
const OAK_ARCHER_CARD_ANIM := &"OakArcher_idle"
const OAK_ARCHER_FALLBACK_PLANT := PlantIds.PEA_SHOOTER_SINGLE
const OAK_ARCHER_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const OAK_ARCHER_CARD_FACE_POSITION := Vector2(1, 11)

## 蜜蜂射手：太阳照 DLC Edition wiki 的 Plants 总表（100）；伤害取 wiki 的 Projectiles 表
## （「Average / 等效 1 豌豆」= 20，与本体豌豆同档）；冷却 / 攻击间隔总表没给，
## 取豌豆口径（7.5 秒 fast；攻击间隔 2.1 秒 = 开火动画 2.0 秒 + 0.1 缓冲，不打断动作）。
const BEE_SHOOTER := &"dlc_beeshooter"
const BEE_SHOOTER_COOL_TIME := 7.5
const BEE_SHOOTER_SUN_COST := 100
## 待机取**完整姿态**那段（`BeeShooter_idle` 只有茎叶、`head_idle` 只有头，见场景文件头）
const BEE_SHOOTER_CARD_ANIM := &"BeeShooter_full_idle"
## 取帧失败时借本体豌豆射手的脸（同为直线射手，形状最接近）
const BEE_SHOOTER_FALLBACK_PLANT := PlantIds.PEA_SHOOTER_SINGLE
## 卡面缩放 / 落点：实测整株内容中心（植物本地，含动画节点的 position）≈ (5.35, -1.9)，
## 0.5 缩放时偏移 = -中心 × 0.5 ≈ (-2.7, 1.0)；内容 44.5×48.5 px
const BEE_SHOOTER_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const BEE_SHOOTER_CARD_FACE_POSITION := Vector2(1, 11)

## 飓衣甘蓝：一次性飓风控制植物。数值是**模组自己的取值**（PVZ2 的 Hurrikale：100 阳光 /
## 冷却约 30 秒 / 不造成伤害 / 冰冻 + 击退全场僵尸）。卡面从待机段取第 0 帧；取帧失败借大嘴花的脸。
## 卡面缩放 / 落点：实测本体是个大株（整株内容 174×183 px）——
## 普通 0.5 缩放会溢出卡槽，故取 0.28；落点 = -中心 × 0.28，
## 中心（植物本地）≈ (-0.26, -59.54) → (0.1, 16.7)；内容 48.7×51.3 px
const HURRIKALE := &"dlc_hurrikale"
const HURRIKALE_COOL_TIME := 30.0
const HURRIKALE_SUN_COST := 100
const HURRIKALE_CARD_ANIM := &"Hurrikale_idle"
const HURRIKALE_FALLBACK_PLANT := PlantIds.CHOMPER
const HURRIKALE_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const HURRIKALE_CARD_FACE_POSITION := Vector2(1, 11)

## 增幅鹅河菊：数值照 DLC Edition 的 wiki（Ampliflower 页）—— 200 阳光 / 冷却 30 秒（slow）/ 生命 300；
## 效果是给周围 3×3 植物增幅（攻击 / 产阳光节奏提速），wiki 未给倍率，`boost_factor` 由模组自选。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借向日葵的脸（同为花，形状最接近）。
const AMPLIFLOWER_SUN_COST := 200
const AMPLIFLOWER_COOL_TIME := 30.0
const AMPLIFLOWER_CARD_ANIM := &"Ampliflower_idle"
const AMPLIFLOWER_FALLBACK_PLANT := PlantIds.SUN_FLOWER
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (11.7, -20.25)，
## 0.46 缩放时偏移 = -中心 × 0.46 ≈ (-5.4, 9.3)；内容 41.8×59.1 px
## （0.5 缩放时高 64.25 px，会顶出卡底图 50×70 的上沿，故收一档）
const AMPLIFLOWER_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const AMPLIFLOWER_CARD_FACE_POSITION := Vector2(1, 11)

## 柠檬榴弹：数值照 DLC Edition 的 wiki（Lemon-nade 页）—— 200 阳光 / 冷却 50 秒（very slow）
## / 每次爆炸 900 伤害 / 范围 3×3 / 一次性即时 / 连炸三次（弹射落点随机）。
## 卡面从 DLC 动画的待机段取第 0 帧；取帧失败时借樱桃炸弹的脸（同为一次性爆炸植物，形状最接近）。
## 卡面缩放 / 落点：实测整株内容中心（植物本地）≈ (5.75, -25.9)，
## 0.45 缩放时偏移 = -中心 × 0.45 ≈ (-2.6, 11.7)；内容 30.8×56.5 px（整株偏高瘦，0.45 刚好放得进）
const LEMONADE_COOL_TIME := 50.0
const LEMONADE_SUN_COST := 200
const LEMONADE_CARD_ANIM := &"Lemonade_idle"
const LEMONADE_FALLBACK_PLANT := PlantIds.CHERRY_BOMB
const LEMONADE_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const LEMONADE_CARD_FACE_POSITION := Vector2(1, 11)

## 水盆：**花盆的水生形态**（不是 DLC 动画里的植物，套的是本体花盆场景里那条 `Pot_waterplants`）。
## 编号仍用本体留的槽位 `PlantIds.WATER_BOWL`（探针与老存档都在用这个 id）。
## 冷却 / 阳光与花盆一致；卡面从水盆那一支动画取第 0 帧，取帧失败借花盆那张脸。
const WATER_BOWL := PlantIds.WATER_BOWL
const WATER_BOWL_COOL_TIME := 7.5
const WATER_BOWL_SUN_COST := 25
const WATER_BOWL_CARD_ANIM := &"Pot_waterplants"
const WATER_BOWL_FALLBACK_PLANT := PlantIds.FLOWER_POT
#endregion


#region 选卡页版式
## 本模组这一页的格数：待选卡槽的网格模板是 `columns = 8` / 48 个占位 ⇒ 6 行，每行 8 格
## （见 `src/ui/card/card_slot_norm.tscn` 的 `GridContainerPlant`）
const CHOOSE_PAGE_SLOTS := 48

## 选卡页版式：**格位下标 → 植物**（没写到的格子留空，`PlantIds.NULL` 语义）
##
## ★ 版式是本模组自己的资源：想换位置只改这张表，`install()` 不再按装配顺序自动排。
##   格位下标 = 一页里从左到右、从上到下数（每行 8 格）。
##
## 第 1 行：投掷蘑菇 / 光照蘑菇 / 臼炮蘑菇 / 血橙 / 闪电芦苇 / 飓衣甘蓝 / 电击蘑菇 / （空）
## 第 2 行：蜜蜂射手 / 甜菜守卫 / 拳击白菜 / 芦荟 / 橡木弓箭手 / 缩小紫罗兰 / 柠檬榴弹 / 增幅鹅河菊
## 第 3 行：水盆
## 第 6 行第 8 格：环轨仙人掌（紫卡，摆在整页最后）
##
## ⚠️ 第 1 行第 8 格空着是给**幽灵椒**（美术资源名 GhostPepper）留的位置：
##   它的动画已导入 `mods_builtin/dlc/animation/character/plant/GhostPepper/`，
##   但还没接成能种的植物（见 [DLC植物导入](../../docs/参考存档/DLC植物导入.md) §8 登记表）。
##   接上之后把它的 id 填进 7 号格即可，别的格子都不用动。
const CHOOSE_PAGE_LAYOUT := {
	0: PULT_SHROOM,
	1: GLOW_SHROOM,
	2: MORTAR_SHROOM,
	3: BLOOD_ORANGE,
	4: REED,
	5: HURRIKALE,
	6: VOLT_SHROOM,
	## 7：幽灵椒 —— 还没接成植物，先留空
	8: BEE_SHOOTER,
	9: CHARD_GUARD,
	10: BONK_CHOY,
	11: ALOE,
	12: OAK_ARCHER,
	13: SHRINKING_VIOLET,
	14: LEMONADE,
	15: AMPLIFLOWER,
	16: WATER_BOWL,
	47: KING_CACTUS,
}
#endregion

## 已装的植物（每株一个 Kit：登记 + 卡片 + 卡面 + 解锁；卸的时候反向全撤）
var _kits: Array[PlantRuntimeKit] = []
## 本模组登记的那页选卡（句柄；-1 = 没登记）
var _choose_page := -1
## 被水盆加过地形位的水生植物（关掉时按这份名单还原）
var _patched_water_plants: Array[StringName] = []


func get_mod_id() -> StringName:
	return ModIds.DLC


func get_mod_name() -> String:
	return "DLC植物"


func get_mod_description() -> String:
	return ("新增一份《植物大战僵尸》DLC 里的植物（投掷蘑菇 / 光照蘑菇 / 臼炮蘑菇 / 血橙 / 闪电芦苇 / 飓衣甘蓝 / 电击蘑菇 / 幽灵椒 / 火蘑菇 / 泡椒 / 电豌豆 / 蜜蜂射手 / 甜菜守卫 / 拳击白菜 / 芦荟 / 橡木弓箭手 / 缩小紫罗兰 / 柠檬榴弹 / 增幅鹅河菊 / 巨噬花 / 等离子木 / 冰豌豆 / 藤蔓胡桃 / 荆棘苔藓 / 无畏蘑菇 / 环轨仙人球 / 流星杨桃 / 火豌豆 / 等离子豌豆 / 辣椒投手 / 冰椒 / 冰胡桃 等）。动画由 R2Ga_PVZ 面板从 `reanim/` 转换而来，原版没有这些角色。当前已接成能种的：**环轨仙人掌**（紫卡，225 阳光，冷却 50 秒，种在本体仙人掌上升级）、**投掷蘑菇**（0 阳光，抛射孢子，白天睡觉）、**拳击白菜**（150 阳光，近战出拳，直拳 20 / 上勾拳 40、0.36 秒一拳，能斩杀时换上勾拳）、**闪电芦苇**（125 阳光，跨三行的短距链状闪电，连击最近的若干僵尸）、**臼炮蘑菇**（75 阳光，抛射会溅射的炮弹，白天睡觉，近身也打得到）、**血橙**（75 阳光，飞行植物：即炸，种下短暂待机后原地引爆 3×3，没炸死的僵尸被血月加速，炸完消失）、**电击蘑菇**（225 阳光，周围 3×5 持续放电、伤害在目标间均分，白天睡觉）、**橡木弓箭手**（200 阳光，本行直线射箭，一支 80 伤害，射程 9 格）、**蜜蜂射手**（100 阳光，前后双向吐蜜蜂，一只 20 伤害）、**飓衣甘蓝**（100 阳光，一次性：起手后冰冻 + 击退本行僵尸、吹走本行空中僵尸，刮完消失）、**甜菜守卫**（75 阳光，高血量 1500 + 近战击退：把右侧僵尸崩飞 3 格，共 3 次，不造成伤害）、**柠檬榴弹**（200 阳光，樱桃炸弹变体：引信后在本格炸一下，再随机弹到邻近区域连炸两下，每次 900 伤害，用完消失）、**芦荟**（50 阳光，支援：不攻击，每 3 秒给周围 3×3 范围每株受伤植物回 30 血，多株不叠加）、**光照蘑菇**（50 阳光，临时植物：夜里散开光域，光域内被击败的僵尸掉一颗小阳光，10 秒后自行消失；白天睡觉）、**缩小紫罗兰**（100 阳光，一次性控制：种下即绽放把周围 3×3 的僵尸缩小 5 秒，施法期间无敌，随后消失）、**增幅鹅河菊**（200 阳光，支援：每 8 秒给周围 3×3 的植物提速 4.25 秒）、**水盆**（25 阳光，花盆的水生形态：摆在草地 / 屋顶上、上面只接水生植物，本模组兼收原「水盆」模组）")


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_UNIT]


## 模组页面右侧：说明它当前能做什么
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"作用：收纳一份 DLC 的植物动画资源（reanim → Godot 动画），并把其中 16 株接成能种的植物；另兼收原「水盆」模组的一株（套本体花盆动画，不占 DLC 素材）"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：环轨仙人掌（紫卡）—— 225 阳光，只能种在本体仙人掌上升级；全屏索敌 + 八方向散射，一轮 8 根刺（冷却 50 秒 very slow、一根刺 20，攻击间隔 1.6 秒）"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：投掷蘑菇 —— 0 阳光，本行 6 格内抛射孢子（冷却 7.5 秒、一颗 20，攻击间隔 2.85 秒）；（蘑菇特性）白天睡觉不工作"))
	box.add_child(ModBase.create_detail_label(
		"已接植物 3：拳击白菜 —— 150 阳光，近战出拳（冷却 7.5 秒、直拳 20 / 上勾拳 40，攻击间隔 0.36 秒）；检测框覆盖本行左右两格，能斩杀时换上勾拳"))
	box.add_child(ModBase.create_detail_label(
		"已接植物 4：闪电芦苇 —— 125 阳光，短距链状闪电（冷却 7.5 秒、一段 10，攻击间隔 1.5 秒）；索敌跨三行，自动连锁最近的僵尸（首发 + 连锁 2，充能后共 5 个）"))
	box.add_child(ModBase.create_detail_label(
		"已接植物 5：血橙 —— 75 阳光，即炸植物（冷却 50 秒 very slow、900 伤害、3×3 范围）；种下后短暂待机便原地引爆，炸完这株消失。**飞行植物**：屋顶 / 泳池的裸地都能直接种（不用花盆 / 睡莲）；没被炸死的僵尸会吃到 Blood Moon 加速"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：臼炮蘑菇 —— 75 阳光，本行 6 格抛射会溅射的炮弹（冷却 7.5 秒、直接命中 40 + 落地溅射，攻击间隔 6 秒）；**近身也打得到**（wiki：敌人贴近时换目标继续打）；（蘑菇特性）白天睡觉不工作"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：电击蘑菇 —— 225 阳光，周围 3×5 放电 AOE（冷却 7.5 秒、持续放电约 40 总伤害/秒，在范围内僵尸之间**均分** —— 目标越多每个挨到的越少）；跨行索敌；（蘑菇特性）白天睡觉不工作"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：蜜蜂射手 —— 100 阳光，本行直线射手（冷却 7.5 秒、一只蜜蜂 20，攻击间隔 1.5 秒）；**前后双向**都能打，朝离自己最近的那只吐蜜蜂"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：橡木弓箭手 —— 200 阳光，本行直线射箭（冷却 7.5 秒、一支箭 80，攻击间隔 4.25 秒）；射程 1x9（本行 9 格），箭撞僵尸即命中"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：缩小紫罗兰 —— 100 阳光，一次性控制（冷却 30 秒 slow）；种下即绽放，缩小**周围 3×3**的僵尸（缩到 0.5 + 啃咬伤害减半）持续 5 秒，施法期间自身无敌，随后这株消失"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：飓衣甘蓝 —— 100 阳光，一次性飓风（冷却 30 秒）；种下稍一起手就刮风：**本行**僵尸被向后吹 3 格并冰冻 4 秒（再减速 6 秒），本行的空中僵尸（气球）直接被吹走，不造成伤害；刮完这株消失"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：甜菜守卫 —— 75 阳光，高血量防御（1500）+ 近战击退（冷却 30 秒 slow、攻击间隔 1.2 秒）；检测框铺本行右侧，僵尸凑过来就抡胳膊把它往后崩飞 3 格，共 3 次、不造成伤害，用完变残血墙"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：柠檬榴弹 —— 200 阳光，樱桃炸弹的变体（冷却 50 秒、每次爆炸 900、3×3 范围）；种下点引信，先在本格炸一下，再随机弹到邻近区域连炸两下（落点玩家不可控），用完这株消失"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：芦荟 —— 50 阳光，支援植物（冷却 7.5 秒、生命 300）；不攻击，每 3 秒给自己周围 3×3 范围内每株受伤植物 +30 生命，多株芦荟不叠加"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：光照蘑菇 —— 50 阳光，夜里的光源辅助菇（冷却 30 秒、生命 300）；白天睡觉，夜里光域内被击败的僵尸掉一颗小阳光。**临时植物**：亮满 10 秒自己就没了"))
	box.add_child(ModBase.create_detail_label(
		"已接植物：增幅鹅河菊 —— 200 阳光，范围增益（冷却 30 秒）；不攻击，每隔 8 秒 cheer 一次，给周围 3×3 的植物攻击 / 产阳光提速 2 倍、**持续 4.25 秒**（间歇生效，不是常驻光环）"))
	box.add_child(ModBase.create_detail_label(
		"另收植物：水盆 —— 25 阳光（冷却 7.5 秒），花盆的水生形态：摆在草地 / 屋顶上（与花盆同一套地形），盆里装的是水，上面只接水生植物（海蘑菇 / 缠绕海草）—— 草地上也能种海蘑菇了；上层植物的影子藏掉"))
	box.add_child(ModBase.create_detail_label(
		"动画转换：R2Ga_PVZ 插件已移出仓库，需从上游取回后在编辑器底部面板逐个选 `mods_builtin/dlc/reanim/<角色>/*.reanim` 转换"))
	box.add_child(ModBase.create_detail_label(
		"接下一株：关掉模组 = 回到原版；并行作业契约（文件归属 / dlc_mod.gd 的追加槽位 / 角色卡 / 自检表）见 docs/参考存档/DLC植物导入.md"))
	box.add_child(ModBase.create_detail_label(
		"卡位：本模组自己登记一页选卡（排在原版植物页之后），17 株按本模组的版式摆：第 1 行 投掷蘑菇 / 光照蘑菇 / 臼炮蘑菇 / 血橙 / 闪电芦苇 / 飓衣甘蓝 / 电击蘑菇（末尾一格留给还没接上的幽灵椒）；第 2 行 蜜蜂射手 / 甜菜守卫 / 拳击白菜 / 芦荟 / 橡木弓箭手 / 缩小紫罗兰 / 柠檬榴弹 / 增幅鹅河菊；第 3 行 水盆；环轨仙人掌摆在整页最后一格。关掉模组后卡片、解锁、紫卡基座登记与图鉴条目一并撤掉"))
	return box


#region 生命周期
func install() -> void:
	## 装上的植物 id（卡位在不在，登记选卡页时要按它过滤见 `_build_choose_page_entries()`）
	var installed: Dictionary[StringName, bool] = {}
	for recipe: PlantRuntimeRecipe in [_build_kingcactus_recipe(), _build_pultshroom_recipe(), _build_bonkchoy_recipe(), _build_aloe_recipe(), _build_mortarshroom_recipe(), _build_reed_recipe(), _build_blood_orange_recipe(), _build_voltshroom_recipe(), _build_glowshroom_recipe(), _build_oakarcher_recipe(), _build_beeshooter_recipe(), _build_hurrikale_recipe(), _build_chardguard_recipe(), _build_shrinkingviolet_recipe(), _build_ampliflower_recipe(), _build_lemonade_recipe(), _build_water_bowl_recipe()]:
		var kit := PlantRuntimeKit.new()
		if not kit.install(recipe):
			## 一株登记失败只跳过这一株，别让整包模组起不来
			Log.error("DLC：%s 登记失败，已跳过" % str(recipe.get_display_name()))
			continue
		installed[kit.recipe.plant_type] = true
		_kits.append(kit)
	## 注册 / 解锁都只是「这株植物存在」，还要自己登记一页选卡才进选卡界面
	## （见 AllCards.register_plant_choose_page）：版式由 `CHOOSE_PAGE_LAYOUT` 决定，不再按装配顺序自动排
	if not installed.is_empty():
		_choose_page = AllCards.register_plant_choose_page(_build_choose_page_entries(installed))
	## 水盆：把水生植物的种植条件各加一位「64 水盆」，它们才种得进去
	_open_water_plants_to_bowl()
	_register_hurrikale_almanac_entry()
	_register_kingcactus_almanac_entry()
	_register_pultshroom_almanac_entry()
	_register_bonkchoy_almanac_entry()
	_register_aloe_almanac_entry()
	_register_reed_almanac_entry()
	_register_mortarshroom_almanac_entry()
	_register_blood_orange_almanac_entry()
	_register_voltshroom_almanac_entry()
	_register_glowshroom_almanac_entry()
	_register_beeshooter_almanac_entry()
	_register_oakarcher_almanac_entry()
	_register_chardguard_almanac_entry()
	_register_shrinkingviolet_almanac_entry()
	_register_lemonade_almanac_entry()
	_register_ampliflower_almanac_entry()
	_register_water_bowl_almanac_entry()


## 把 `CHOOSE_PAGE_LAYOUT` 摊成登记用的格位数组（长度 = 一页的格数，没写到的格位是 `PlantIds.NULL`）
##
## [param installed] 这次真正装上的植物：版式里写了却没装上的（没卡位）那一格换成空位 ——
##   `register_plant_choose_page()` 只要有一株没卡位就整页返回 -1，不能让它把整页登记拖垮。
func _build_choose_page_entries(installed: Dictionary[StringName, bool]) -> Array[StringName]:
	var entries: Array[StringName] = []
	## `resize()` 填的是空 StringName（= `PlantIds.NULL`），正好就是「这一格留空」
	entries.resize(CHOOSE_PAGE_SLOTS)
	for slot: int in CHOOSE_PAGE_LAYOUT:
		var plant_type: StringName = CHOOSE_PAGE_LAYOUT[slot]
		if slot < 0 or slot >= CHOOSE_PAGE_SLOTS:
			Log.error("DLC：选卡页第 %d 格超出这一页的 %d 格，已忽略" % [slot, CHOOSE_PAGE_SLOTS])
			continue
		if not installed.has(plant_type):
			Log.warn("DLC：选卡页第 %d 格的 %s 没装上，这一格留空" % [slot, plant_type])
			continue
		entries[slot] = plant_type
	return entries


## 每局补一次解锁：读档会按存档记录重建 `curr_plant`（见 `SaveService._build_curr_plant`），
## 只装一次的话，玩家一读档这株就又没了
func install_to_main_game(_main_game: MainGameManager) -> void:
	for kit: PlantRuntimeKit in _kits:
		kit.unlock()


func uninstall() -> void:
	## 水盆：先把水生植物的条件换回静态表里那一份，再撤卡片
	_restore_water_plants()
	## 先撤页再卸植物：页是本模组自己登记的，Kit 不代撤
	AllCards.unregister_plant_choose_page(_choose_page)
	_choose_page = -1
	for kit: PlantRuntimeKit in _kits:
		kit.uninstall()
	_kits.clear()
	Global.global_read_data.clear_extra_almanac_entry(KING_CACTUS)
	Global.global_read_data.clear_extra_almanac_entry(PULT_SHROOM)
	Global.global_read_data.clear_extra_almanac_entry(BONK_CHOY)
	Global.global_read_data.clear_extra_almanac_entry(ALOE)
	Global.global_read_data.clear_extra_almanac_entry(REED)
	Global.global_read_data.clear_extra_almanac_entry(MORTAR_SHROOM)
	Global.global_read_data.clear_extra_almanac_entry(BLOOD_ORANGE)
	Global.global_read_data.clear_extra_almanac_entry(VOLT_SHROOM)
	Global.global_read_data.clear_extra_almanac_entry(GLOW_SHROOM)
	Global.global_read_data.clear_extra_almanac_entry(OAK_ARCHER)
	Global.global_read_data.clear_extra_almanac_entry(BEE_SHOOTER)
	Global.global_read_data.clear_extra_almanac_entry(HURRIKALE)
	Global.global_read_data.clear_extra_almanac_entry(CHARD_GUARD)
	Global.global_read_data.clear_extra_almanac_entry(SHRINKING_VIOLET)
	Global.global_read_data.clear_extra_almanac_entry(AMPLIFLOWER)
	Global.global_read_data.clear_extra_almanac_entry(LEMONADE)
	Global.global_read_data.clear_extra_almanac_entry(WATER_BOWL)
#endregion


#region 图鉴条目
## 飓衣甘蓝的图鉴条目：与下面各株同一套口径（自己登记、关掉模组自己摘）
func _register_hurrikale_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(HURRIKALE, {
		"名字": "飓衣甘蓝",
		"描述": "飓衣甘蓝是某份《植物大战僵尸》DLC 里的一次性植物：种下去稍一起手，就刮起一阵旋风，把全场僵尸沿来路向后吹，并顺势冻住它们一小会儿；风过之后，它自己也消失了。",
		"参数": {
			"阳光": "100",
			"冷却": "30 秒",
			"伤害": "无（只做控制，不造成伤害）",
			"效果": "全场击退 3 格 + 冰冻 4 秒（解冻后再减速 6 秒）",
			"特点": "一次性：刮完风这株消失、腾出格子"
		},
		"简介": "“深呼吸。”飓衣甘蓝把叶子拢成一束，“然后——呼——”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})

## 环轨仙人掌的图鉴条目：**自己登记，自己摘**
##
## ★ 为什么不写进本体的 `almanac_data.json`：本体不认识任何一个模组（硬约束），
##   图鉴的「扩展植物」页只认运行期登记的条目（`GlobalReadData.register_extra_almanac_entry`）。
##   关掉模组就把条目摘掉 —— 没装模组时不该在图鉴里看见一只谁都种不出来的植物。
func _register_kingcactus_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(KING_CACTUS, {
		"名字": "环轨仙人掌",
		"描述": "环轨仙人掌是某份《植物大战僵尸》DLC 里的升级植物：由本体仙人掌长成，周身一圈刺座，一开火就同时朝 8 个方向甩出尖刺。",
		"参数": {
			"阳光": "225",
			"冷却": "7.5 秒",
			"伤害": "每根刺 20（一轮 8 根）",
			"弹道": "径向匀加速；速度方向按恒定角速度转向（越飞越快、越转越大圈）；相邻两轮弯向相反",
			"索敌": "全屏（任何一行有僵尸就开火）",
			"攻击间隔": "1.6 秒（略长于开火动画 1.42 秒，不打断动作）",
			"特点": "紫卡：只能种植在本体仙人掌上（种下去顶掉基座）"
		},
		"简介": "“我不是换了个名字，是长高了。”环轨仙人掌把刺一圈圈盘起来，“沿着这条轨道，谁也别想绕过去。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 投掷蘑菇的图鉴条目：与上面同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Pult-shroom 页）：0 阳光 / 冷却 7.5 秒 / 20 伤害 /
## 攻击间隔 2.85 秒 / 抛射·中等（1×6 格）/ 白天睡觉。
func _register_pultshroom_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(PULT_SHROOM, {
		"名字": "投掷蘑菇",
		"描述": "投掷蘑菇是某份《植物大战僵尸》DLC 里的抛射植物：把孢子装在篮子里甩出去，价格便宜、射程中等，打得到带盾的僵尸。",
		"参数": {
			"阳光": "0",
			"冷却": "7.5 秒",
			"伤害": "一颗孢子 20",
			"射程": "抛射 · 中等（本行 6 格）",
			"攻击间隔": "2.85 秒（略长于开火动画 1.58 秒，不打断动作）",
			"特点": "蘑菇：白天睡觉，夜里才工作"
		},
		"简介": "“我曾经想跟一只草坪地精交朋友。”投掷蘑菇有点不好意思，“后来发现它只是一块很有耐心的石头。我们现在偶尔还聊天——它不太会听人说话，但氛围感很棒。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 拳击白菜的图鉴条目：与上面两株同一套口径（自己登记、关掉模组自己摘）
##
## 数值是模组自己的取值（原版没有这株，DLC Edition 只给了个名字）：150 阳光 / 冷却 7.5 秒 /
## 近战直拳 15、能斩杀时换上勾拳 35 / 检测框覆盖本行左右两格。
func _register_bonkchoy_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(BONK_CHOY, {
		"名字": "拳击白菜",
		"描述": "拳击白菜是某份《植物大战僵尸》DLC 里的近战植物：把两只拳头举得老高，等僵尸走到跟前就一拳一拳地砸过去，这一拳能把对方直接放倒时还会补一记上勾拳。",
		"参数": {
			"阳光": "150",
			"冷却": "7.5 秒",
			"伤害": "直拳 15 / 上勾拳 35（能斩杀时换上勾拳）",
			"射程": "近战 · 本行左右两格",
			"攻击间隔": "0.95 秒（略长于出拳动画 0.92 秒，不打断动作）",
			"特点": "近战：不用子弹，拳到即伤"
		},
		"简介": "“我数过，”拳击白菜把拳头捏得咯咯响，“左勾拳、右勾拳、再来一记上勾拳——够你喝一壶了。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 芦荟的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Aloe Vera 页）：50 阳光 / 冷却 7.5 秒（fast）/ 生命 300 /
## 3×3 群体治疗 / 每 3 秒治疗一次 / 治疗量不叠加；单次治疗量 wiki 未给，取模组值 30。
func _register_aloe_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(ALOE, {
		"名字": "芦荟",
		"描述": "芦荟是某份《植物大战僵尸》DLC 里的支援植物：它不打架，只安安静静地待在地里，慢慢把身边一圈受伤的植物养回精神，是整条防线的后勤医生。",
		"参数": {
			"阳光": "50",
			"冷却": "7.5 秒",
			"生命": "300",
			"治疗": "每 3 秒，3×3 范围内每株受伤植物 +30 生命",
			"范围": "周围 3×3 格",
			"特点": "多株芦荟的治疗量不叠加；不攻击僵尸"
		},
		"简介": "“别急着谢我，”芦荟把叶子舒展了一下，“我只是把你们掉的这一口气，慢慢补回来而已。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 闪电芦苇的图鉴条目：与前面三株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Reed 页）：125 阳光 / 冷却 5 秒（fast）/ 15 伤害（light）/
## 链状闪电（首发 + 连锁 2，充能后 +2）/ 短距（约 3 格）/ 生命 300。
func _register_reed_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(REED, {
		"名字": "闪电芦苇",
		"描述": "闪电芦苇是某份《植物大战僵尸》DLC 里的电系植物：把身体里攒的电顺着最近的僵尸放出去，再一路跳到附近的僵尸身上，像一条游走的闪电链。打的次数够多还会进入「充能」状态，一次电到更多目标。",
		"参数": {
			"阳光": "125",
			"冷却": "5 秒",
			"伤害": "一段 15（首发 + 连锁 2，共 3 个；充能后共 5 个）",
			"射程": "短距 · 本行约 3 格",
			"攻击间隔": "1.1 秒（略长于开火动画 0.71 秒，不打断动作）",
			"特点": "链状闪电：自动连锁最近的若干个僵尸"
		},
		"简介": "“别靠太近，”闪电芦苇周身噼啪作响，“我这一串电下去，挨着的都得抖三抖。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 臼炮蘑菇的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Mortar-shroom 页）：75 阳光 / 冷却 7.5 秒（fast）/ 直接命中 40（moderate）
## + 落地溅射 / 攻击间隔 6 秒（1/4x）/ 抛射·Lobbed（约 6 格；**近身不是盲点**，贴脸也打）/ 生命 300 / 白天睡觉。
func _register_mortarshroom_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(MORTAR_SHROOM, {
		"名字": "臼炮蘑菇",
		"描述": "臼炮蘑菇是某份《植物大战僵尸》DLC 里的抛射植物：把炮弹甩向本行的僵尸，落点炸开一圈。它像一只小号的西瓜投手；敌人贴到近处时它会换一个目标接着轰，而不是看不见。",
		"参数": {
			"阳光": "75",
			"冷却": "7.5 秒",
			"伤害": "直接命中 40 + 落地溅射",
			"射程": "抛射 · 本行约 6 格（**近身不是盲点**，贴脸也打）",
			"攻击间隔": "6 秒（略长于开火动画 1.42 秒，不打断动作）",
			"特点": "蘑菇：白天睡觉，夜里才工作"
		},
		"简介": "“远处的交给我。”臼炮蘑菇把炮筒一横，“近处的？一样轰。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Night"
	})


## 血橙的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值是模组自己的取值（对齐「樱桃炸弹」那一档）：150 阳光 / 冷却 30 秒 / 1800 伤害 /
## 3 行范围 / 即炸（种下后短暂待机引爆，炸完这株消失）。
func _register_blood_orange_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(BLOOD_ORANGE, {
		"名字": "血橙",
		"描述": "血橙是某份《植物大战僵尸》DLC 里的即炸植物：长得像颗鼓胀的橙子，种下后短暂待机便原地炸开，用飞溅的果肉与泡沫把周围一圈僵尸掀翻。",
		"参数": {
			"阳光": "150",
			"冷却": "30 秒",
			"伤害": "1800（一次性，灰烬炸弹口径）",
			"射程": "3×3（以自身为中心，覆盖上下各一行）",
			"特点": "即炸：种下后短暂待机引爆，炸完这株消失"
		},
		"简介": "“别咬我。”血橙把汁水憋在果皮里，“等我自己炸的时候，那才叫一个场面。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 电击蘑菇的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值是模组自己的取值（对齐原版电击蘑菇：100 阳光 / 400 伤害 / 3×3 放电 / 白天睡觉；
## DLC Edition 的 wiki 没有 VoltShroom 单页）。
func _register_voltshroom_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(VOLT_SHROOM, {
		"名字": "电击蘑菇",
		"描述": "电击蘑菇是某份《植物大战僵尸》DLC 里的电系植物：蹲在笼子里攒电，周围约一格内的僵尸一旦挨近，就噼里啪啦放出一圈强电，把贴身的僵尸一并撂倒。",
		"参数": {
			"阳光": "100",
			"冷却": "7.5 秒",
			"伤害": "一次放电 400（范围内每个僵尸各一下）",
			"射程": "周围 1 格（约 3×3，跨行）",
			"攻击间隔": "7.5 秒（略长于 蓄电+放电+收尾 约 1.33 秒，不打断动作）",
			"特点": "蘑菇：白天睡觉，夜里才工作"
		},
		"简介": "“别围着我转。”电击蘑菇把电攒得滋滋响，“一下、一下，全都得躺下。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Night"
	})


## 光照蘑菇的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Lume-shroom 页）：阳光 50 / 冷却 30 秒（slow）/ 生命 300 /
## 范围「huge area」/ 白天睡觉。功能是「光域里被击败的僵尸掉落小阳光」；wiki 还写了「清除僵尸
## 增益（血月等）」，本仓当前没有僵尸增益系统，那一半暂不实现（见 `glowshroom_plant.gd` 说明）。
func _register_glowshroom_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(GLOW_SHROOM, {
		"名字": "光照蘑菇",
		"描述": "光照蘑菇是某份《植物大战僵尸》DLC 里的光源辅助植物：种下后安安静静地待着，到了夜里便亮起一大片光，光照范围内的僵尸一旦被击败，就会掉落一颗小阳光。",
		"参数": {
			"阳光": "50",
			"冷却": "30 秒",
			"伤害": "无（不攻击）",
			"范围": "光域 · 巨大（罩住大半个场）",
			"阳光产出": "光域里每只被击败的僵尸掉一颗小阳光（15）",
			"特点": "蘑菇：白天睡觉，夜里才亮灯工作"
		},
		"简介": "“我不是很能打。”光照蘑菇把身子里的光捂了捂，“可只要我亮着，倒下的每一个都会留下点光给你。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Night"
	})


## 橡木弓箭手的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Oak Archer 页）：阳光 200 / 冷却 7.5 秒（fast）/ 伤害 80（普通攻击，
## wiki 带问号；暴击 160 未实现）/ 射程 1x9（本行 9 格）/ 攻击间隔 4.25 秒 / 生命 300。
func _register_oakarcher_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(OAK_ARCHER, {
		"名字": "橡木弓箭手",
		"描述": "橡木弓箭手是某份《植物大战僵尸》DLC 里的射手植物：长成一棵结实的橡树，抬手张弓，把一支支箭射向本行的僵尸，射得又远又准。",
		"参数": {
			"阳光": "200",
			"冷却": "7.5 秒",
			"伤害": "一支箭 80（普通攻击）",
			"射程": "直线 · 本行 9 格",
			"攻击间隔": "4.25 秒（略长于开火动画 0.92 秒，不打断动作）",
			"特点": "本行直线射手：一支箭水平往右飞，撞僵尸即命中"
		},
		"简介": "“站稳了，看仔细。”橡木弓箭手把弓拉满，“我这箭飞得远，也落得准——一棵树该有的耐心，我都有。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 蜜蜂射手的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Plants 总表 + Projectiles 表）：100 阳光 / 伤害「Average」
## （等效 1 豌豆 = 20）/ 冷却取 fast 7.5 秒 / 攻击间隔取 2.1 秒（总表未给，取豌豆口径；
## 开火动画 2.0 秒，间隔略长于它才不打断动作）。
func _register_beeshooter_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(BEE_SHOOTER, {
		"名字": "蜜蜂射手",
		"描述": "蜜蜂射手是某份《植物大战僵尸》DLC 里的直线射手：叶子和茎是豌豆的老底子，脑袋换成了会cos蜜蜂的脑袋。本行右侧一出现僵尸，它就张开嘴把蜜蜂一只只吐出去，命中第一只僵尸才罢休。",
		"参数": {
			"阳光": "100",
			"冷却": "7.5 秒",
			"伤害": "一只蜜蜂 20",
			"射程": "直线 · 本行",
			"攻击间隔": "2.1 秒（略长于开火动画 2.0 秒，不打断动作）",
			"特点": "直线射手：蜜蜂沿本行水平飞行，命中第一只僵尸"
		},
		"简介": "“嗡嗡只是伪装，其实是精准打击。”蜜蜂射手吹了声口哨，“我的信使从不迟到，也从不空手。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 甜菜守卫的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值是模组自己的取值（原版没有这株，对齐「坚果墙」那一档的高血量防御）：100 阳光 /
## 冷却 25 秒 / 高血量（1600）/ 近战击退 3 次（不造成伤害）/ 用完变残血墙。
func _register_chardguard_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(CHARD_GUARD, {
		"名字": "甜菜守卫",
		"描述": "甜菜守卫是某份《植物大战僵尸》DLC 里的防御植物：把自己长成一道厚实的绿色城墙，僵尸凑过来想啃它时，它就抡起胳膊把对方往后崩飞一截。一共能崩三次，三次之后就只剩一身厚皮硬扛了。",
		"参数": {
			"阳光": "100",
			"冷却": "25 秒",
			"伤害": "无（只击退，不造成伤害）",
			"击退": "近战 · 把右边最近的僵尸往后崩飞一截，共 3 次",
			"生命": "1600（高血量防御）",
			"特点": "防御植物：3 次击退用完变残血墙，之后只能硬扛被啃"
		},
		"简介": "“站在这儿，就别想过去。”甜菜守卫把胳膊抡得呼呼响，“我崩你三次——三次之后，咱俩就只能耗了。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 缩小紫罗兰的图鉴条目：与前面几株同一套口径（自己登记、关掉模组自己摘）
##
## 数值是模组自己的取值（对齐 PvZ2「一次性控制」那一档）：0 阳光 / 冷却 7.5 秒；
## 种下即绽放，缩小全场僵尸（缩小到 0.5、啃咬伤害减半）持续 5 秒，随后这株消失。
func _register_shrinkingviolet_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(SHRINKING_VIOLET, {
		"名字": "缩小紫罗兰",
		"描述": "缩小紫罗兰是某份《植物大战僵尸》DLC 里的一次性控制植物：种下后绽放，把场上所有僵尸一起缩小，让它们变小、啃咬也没那么疼，过一会儿才恢复原状。",
		"参数": {
			"阳光": "0",
			"冷却": "7.5 秒",
			"伤害": "无（不攻击，只控制）",
			"效果": "缩小全场僵尸：缩到 0.5 倍 + 啃咬伤害减半，持续 5 秒",
			"特点": "一次性：种下即绽放并缩小全场僵尸，随后这株消失"
		},
		"简介": "“别看我小。”缩小紫罗兰把花瓣收拢又张开，“我这一绽放，你们个个都得矮一截。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 增幅鹅河菊的图鉴条目：与前面各株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Ampliflower 页）：200 阳光 / 冷却 30 秒（slow）/ 生命 300 / 3×3 范围；
## 效果是给周围植物的攻击 / 产阳光节奏提速，wiki 未给倍率，`boost_factor`（默认 2.0）由模组自选。
func _register_ampliflower_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(AMPLIFLOWER, {
		"名字": "增幅鹅河菊",
		"描述": "增幅鹅河菊是某份《植物大战僵尸》DLC 里的支援植物：安安静静地开着花，却能把周围一圈同伴的节奏带快——在它身边的攻击植物出手更利索，产阳光的也转得更勤。",
		"参数": {
			"阳光": "200",
			"冷却": "30 秒",
			"伤害": "无（不攻击，只增幅同伴）",
			"范围": "周围 3×3（以自身为中心，含自身格）",
			"效果": "范围内除自己外的植物，攻击 / 产阳光节奏提速（默认 2 倍）",
			"特点": "支援：进范围即增幅、离开或本株死亡即恢复"
		},
		"简介": "“靠近点。”增幅鹅河菊把花瓣张成一个小喇叭，“我这一开嗓，你们个个都得跟上拍子。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 柠檬榴弹的图鉴条目：与前面各株同一套口径（自己登记、关掉模组自己摘）
##
## 数值照 DLC Edition 的 wiki（Lemon-nade 页）：200 阳光 / 冷却 50 秒（very slow）/
## 每次爆炸 900 伤害 / 范围 3×3 / 一次性即时 / 连炸三次（弹射落点随机、玩家不可控）。
func _register_lemonade_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(LEMONADE, {
		"名字": "柠檬榴弹",
		"描述": "柠檬榴弹是某份《植物大战僵尸》DLC 里的一次性爆炸植物，樱桃炸弹的变体：种下后连炸三次，每一次都随机弹到附近的一块地，把范围内的僵尸炸成灰烬。",
		"参数": {
			"阳光": "200",
			"冷却": "50 秒",
			"伤害": "每次爆炸 900",
			"范围": "3×3（以爆炸点为中心，覆盖上下各一行）",
			"特点": "一次性、即时：连炸三次，弹射落点随机、玩家不可控"
		},
		"简介": "“生活给你柠檬，你就该把它砸向僵尸！”柠檬榴弹自称资深的柠檬鉴赏家，“于是乎，一切都变得又酸又爽，还有点妙。”",
		"提示": "由模组「DLC植物」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})


## 水盆的图鉴条目：与前面各株同一套口径（自己登记、关掉模组自己摘）
##
## 水盆不是 DLC 素材：它是花盆的水生形态（原「水盆」模组 2026-10-18 并入本模组）。
func _register_water_bowl_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(WATER_BOWL, {
		"名字": "水盆",
		"描述": "水盆是花盆的水生形态：摆在草地 / 屋顶上，盆里装的是水，上面只接水生植物（海蘑菇 / 缠绕海草）。",
		"参数": {
			"强度": "同花盆",
			"可种在": "草地 / 屋顶",
			"上面只接": "水生植物（海蘑菇 / 缠绕海草）"
		},
		"简介": "“我跟花盆是同一只盆，”水盆说，“只不过我比较想得开 —— 别人装土，我装水，于是草地上也有了海。”",
		"提示": "由模组「DLC植物」提供（兼收原「水盆」模组）：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Pool"
	})
#endregion


#region 配方
## 环轨仙人掌：与本体植物的差别只有「场景 / 卡面 / 数值 / 紫卡前置」，
## 被啃、被铲、被蹦极偷、手套搬运、睡觉、模仿者材质这些全在 `Plant000Base` 那一份里。
func _build_kingcactus_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = KING_CACTUS
	recipe.plant_name = &"KingCactus"
	recipe.plant_scene = KING_CACTUS_SCENE
	recipe.cool_time = KING_CACTUS_COOL_TIME
	recipe.sun_cost = KING_CACTUS_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 紫卡（升级卡）：只能种在本体仙人掌上，种下去把基座顶掉换成自己。
	## `AllPrePlantPurple` 的登记 / 撤销由 `PlantRuntimeKit` 按这两个字段自己做，
	## 且排在插卡之前（卡片一 `_ready` 就要判「现在能不能种」，缺 key 会崩）
	recipe.is_purple_card = true
	recipe.purple_pre_plant = KING_CACTUS_PRE_PLANT
	## 卡面从待机动画的第 0 帧取（模组没有手摆的卡面形象，只能取帧）；
	## 取帧失败时退回大嘴花那张脸
	recipe.card_face_anim = KING_CACTUS_CARD_ANIM
	recipe.card_face_fallback_plant = FALLBACK_PLANT
	return recipe


## 投掷蘑菇：与环轨仙人掌的差别只有「场景 / 卡面 / 数值」，而且这株是**普通卡**
## （不是紫卡，0 阳光直接种在草地上）。
func _build_pultshroom_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = PULT_SHROOM
	recipe.plant_name = &"PultShroom"
	recipe.plant_scene = PULT_SHROOM_SCENE
	recipe.cool_time = PULT_SHROOM_COOL_TIME
	recipe.sun_cost = PULT_SHROOM_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回小喷菇那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释）
	recipe.card_face_anim = PULT_SHROOM_CARD_ANIM
	recipe.card_face_fallback_plant = PULT_SHROOM_FALLBACK_PLANT
	recipe.card_face_scale = PULT_SHROOM_CARD_FACE_SCALE
	recipe.card_face_position = PULT_SHROOM_CARD_FACE_POSITION
	return recipe


## 臼炮蘑菇：与投掷蘑菇的差别只在「场景 / 卡面 / 数值 / 攻击方式」——普通卡（75 阳光直接种在草地上），
## 攻击方式换成「抛射 + 落地溅射」（见 `mortarshroom_plant.gd` / `bullet_mortarshroom_shell.gd`）。
func _build_mortarshroom_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = MORTAR_SHROOM
	recipe.plant_name = &"MortarShroom"
	recipe.plant_scene = MORTAR_SHROOM_SCENE
	recipe.cool_time = MORTAR_SHROOM_COOL_TIME
	recipe.sun_cost = MORTAR_SHROOM_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回小喷菇那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释）
	recipe.card_face_anim = MORTAR_SHROOM_CARD_ANIM
	recipe.card_face_fallback_plant = MORTAR_SHROOM_FALLBACK_PLANT
	recipe.card_face_scale = MORTAR_SHROOM_CARD_FACE_SCALE
	recipe.card_face_position = MORTAR_SHROOM_CARD_FACE_POSITION
	return recipe


## 拳击白菜：与前面两株的差别只有「场景 / 卡面 / 数值」，是**普通卡**（150 阳光直接种在草地上）。
## 攻击方式走脚本里的近战出拳（见 `bonkchoy_plant.gd`），不用子弹。
func _build_bonkchoy_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = BONK_CHOY
	recipe.plant_name = &"BonkChoy"
	recipe.plant_scene = BONK_CHOY_SCENE
	recipe.cool_time = BONK_CHOY_COOL_TIME
	recipe.sun_cost = BONK_CHOY_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回卷心菜投手那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释，随摆放微调）
	recipe.card_face_anim = BONK_CHOY_CARD_ANIM
	recipe.card_face_fallback_plant = BONK_CHOY_FALLBACK_PLANT
	recipe.card_face_scale = BONK_CHOY_CARD_FACE_SCALE
	recipe.card_face_position = BONK_CHOY_CARD_FACE_POSITION
	return recipe


## 芦荟：**普通卡**（50 阳光直接种在草地上），不攻击，走脚本里的 3×3 范围治疗
## （见 `aloe/aloe_plant.gd` 与 `aloe/aloe_heal_area_component.gd`），不用子弹、不挂检测组件。
func _build_aloe_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = ALOE
	recipe.plant_name = &"AloeVera"
	recipe.plant_scene = ALOE_SCENE
	recipe.cool_time = ALOE_COOL_TIME
	recipe.sun_cost = ALOE_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回向日葵那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点 (24,30)」反推（见常量注释）
	recipe.card_face_anim = ALOE_CARD_ANIM
	recipe.card_face_fallback_plant = ALOE_FALLBACK_PLANT
	recipe.card_face_scale = ALOE_CARD_FACE_SCALE
	recipe.card_face_position = ALOE_CARD_FACE_POSITION
	return recipe


## 闪电芦苇：与前面几株的差别只有「场景 / 卡面 / 数值」，是**普通卡**（125 阳光直接种在草地上）。
## 攻击方式走脚本里的短距链状闪电（见 `reed_plant.gd`），不用子弹。
func _build_reed_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = REED
	recipe.plant_name = &"Reed"
	recipe.plant_scene = REED_SCENE
	recipe.cool_time = REED_COOL_TIME
	recipe.sun_cost = REED_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回小喷菇那张脸。
	## 缩放 / 落点待运行期 `get_content_rect()` 实测包围盒后回填（见常量注释）
	recipe.card_face_anim = REED_CARD_ANIM
	recipe.card_face_fallback_plant = REED_FALLBACK_PLANT
	recipe.card_face_scale = REED_CARD_FACE_SCALE
	recipe.card_face_position = REED_CARD_FACE_POSITION
	return recipe


## 血橙：与前面几株的差别只有「场景 / 卡面 / 数值 / 地形」，是**普通卡**（75 阳光种在草地上）。
## 攻击方式走脚本里的即炸（种下 → 短暂待机 → 原地引爆 3×3 → 这株消失），不用子弹、不索敌。
## ★ 地形是这株唯一特殊的地方：wiki 标了 `Fly = Yes`（飞行植物），**屋顶 / 泳池的裸地都能
##   直接种，不需要花盆 / 睡莲** —— 所以在陆生那套位上再或上裸水（8）与裸屋顶（32）。
##   （睡莲位 / 花盆位仍保留：铺过底座的格子照样能种）
func _build_blood_orange_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = BLOOD_ORANGE
	recipe.plant_name = &"BloodOrange"
	recipe.plant_scene = BLOOD_ORANGE_SCENE
	recipe.cool_time = BLOOD_ORANGE_COOL_TIME
	recipe.sun_cost = BLOOD_ORANGE_SUN_COST
	## 飞行植物（wiki `Fly = Yes`）：草地 / 花盆 / 睡莲 + **裸水 + 裸屋顶**
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM \
		| PlantConditionBits.WATER \
		| PlantConditionBits.ROOF
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回樱桃炸弹那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释，随摆放微调）
	recipe.card_face_anim = BLOOD_ORANGE_CARD_ANIM
	recipe.card_face_fallback_plant = BLOOD_ORANGE_FALLBACK_PLANT
	recipe.card_face_scale = BLOOD_ORANGE_CARD_FACE_SCALE
	recipe.card_face_position = BLOOD_ORANGE_CARD_FACE_POSITION
	return recipe


## 电击蘑菇：与前面几株的差别只有「场景 / 卡面 / 数值」，是**普通卡**（100 阳光直接种在草地上）。
## 攻击方式走脚本里的周围 3×3 放电 AOE（见 `voltshroom_plant.gd`），不用子弹。
func _build_voltshroom_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = VOLT_SHROOM
	recipe.plant_name = &"VoltShroom"
	recipe.plant_scene = VOLT_SHROOM_SCENE
	recipe.cool_time = VOLT_SHROOM_COOL_TIME
	recipe.sun_cost = VOLT_SHROOM_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回小喷菇那张脸。
	## 缩放 / 落点待运行期 `get_content_rect()` 实测包围盒后回填（见常量注释）
	recipe.card_face_anim = VOLT_SHROOM_CARD_ANIM
	recipe.card_face_fallback_plant = VOLT_SHROOM_FALLBACK_PLANT
	recipe.card_face_scale = VOLT_SHROOM_CARD_FACE_SCALE
	recipe.card_face_position = VOLT_SHROOM_CARD_FACE_POSITION
	return recipe


## 橡木弓箭手：与前面几株的差别只有「场景 / 卡面 / 数值 / 攻击方式」，是**普通卡**
## （200 阳光直接种在草地上）。攻击方式走脚本里的本行直线射箭（见 `oakarcher_plant.gd`），
## 子弹是模组自己的直线箭（`bullet_oakarcher_arrow.tscn`，继承本体 `bullet_cactus.tscn`）。
func _build_oakarcher_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = OAK_ARCHER
	recipe.plant_name = &"OakArcher"
	recipe.plant_scene = OAK_ARCHER_SCENE
	recipe.cool_time = OAK_ARCHER_COOL_TIME
	recipe.sun_cost = OAK_ARCHER_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回豌豆射手那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释）
	recipe.card_face_anim = OAK_ARCHER_CARD_ANIM
	recipe.card_face_fallback_plant = OAK_ARCHER_FALLBACK_PLANT
	recipe.card_face_scale = OAK_ARCHER_CARD_FACE_SCALE
	recipe.card_face_position = OAK_ARCHER_CARD_FACE_POSITION
	return recipe


## 蜜蜂射手：与前面几株的差别只有「场景 / 卡面 / 数值 / 攻击方式」，是**普通卡**
## （100 阳光直接种在草地上）。攻击方式走脚本里的本行直线吐蜜蜂
## （见 `beeshooter_plant.gd`），子弹是模组自己的直线蜜蜂（`bullet_beeshooter_bee.tscn`，
## 继承本体 `bullet_linear_base.tscn`）。
func _build_beeshooter_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = BEE_SHOOTER
	recipe.plant_name = &"BeeShooter"
	recipe.plant_scene = BEE_SHOOTER_SCENE
	recipe.cool_time = BEE_SHOOTER_COOL_TIME
	recipe.sun_cost = BEE_SHOOTER_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回豌豆射手那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释）
	recipe.card_face_anim = BEE_SHOOTER_CARD_ANIM
	recipe.card_face_fallback_plant = BEE_SHOOTER_FALLBACK_PLANT
	recipe.card_face_scale = BEE_SHOOTER_CARD_FACE_SCALE
	recipe.card_face_position = BEE_SHOOTER_CARD_FACE_POSITION
	return recipe


## 飓衣甘蓝：与前面几株的差别只有「场景 / 卡面 / 数值」，是**普通卡**（100 阳光直接种在草地上）。
## 攻击方式走脚本里的「一次性全场飓风」（种下 → 起手 → 冰冻 + 击退全场僵尸 → 这株消失），
## 不用子弹、不索敌（见 `hurrikale_plant.gd`）。
func _build_hurrikale_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = HURRIKALE
	recipe.plant_name = &"Hurrikale"
	recipe.plant_scene = HURRIKALE_SCENE
	recipe.cool_time = HURRIKALE_COOL_TIME
	recipe.sun_cost = HURRIKALE_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回大嘴花那张脸。
	## 缩放 / 落点待运行期 `get_content_rect()` 实测包围盒后回填（见常量注释）
	recipe.card_face_anim = HURRIKALE_CARD_ANIM
	recipe.card_face_fallback_plant = HURRIKALE_FALLBACK_PLANT
	recipe.card_face_scale = HURRIKALE_CARD_FACE_SCALE
	recipe.card_face_position = HURRIKALE_CARD_FACE_POSITION
	return recipe


## 甜菜守卫：与前面几株的差别只有「场景 / 卡面 / 数值」，是**普通卡**（100 阳光直接种在草地上）。
## 攻击方式走脚本里的「高血量防御 + 近战击退」（不用子弹、不造成伤害，见 `chardguard_plant.gd`）。
func _build_chardguard_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = CHARD_GUARD
	recipe.plant_name = &"ChardGuard"
	recipe.plant_scene = CHARD_GUARD_SCENE
	recipe.cool_time = CHARD_GUARD_COOL_TIME
	recipe.sun_cost = CHARD_GUARD_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回坚果墙那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释，随摆放微调）
	recipe.card_face_anim = CHARD_GUARD_CARD_ANIM
	recipe.card_face_fallback_plant = CHARD_GUARD_FALLBACK_PLANT
	recipe.card_face_scale = CHARD_GUARD_CARD_FACE_SCALE
	recipe.card_face_position = CHARD_GUARD_CARD_FACE_POSITION
	return recipe


## 缩小紫罗兰：与前面几株的差别只有「场景 / 卡面 / 数值 / 攻击方式」，是**普通卡**
## （100 阳光 / 冷却 30 s，见 `SHRINKING_VIOLET_SUN_COST`）。攻击方式走脚本里的
## 「一次性绽放 → 缩小全场僵尸 → 自身消失」
## （见 `shrinkingviolet_plant.gd`），不用子弹、不索敌。
func _build_shrinkingviolet_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = SHRINKING_VIOLET
	recipe.plant_name = &"ShrinkingViolet"
	recipe.plant_scene = SHRINKING_VIOLET_SCENE
	recipe.cool_time = SHRINKING_VIOLET_COOL_TIME
	recipe.sun_cost = SHRINKING_VIOLET_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回小喷菇那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释，随摆放微调）
	recipe.card_face_anim = SHRINKING_VIOLET_CARD_ANIM
	recipe.card_face_fallback_plant = SHRINKING_VIOLET_FALLBACK_PLANT
	recipe.card_face_scale = SHRINKING_VIOLET_CARD_FACE_SCALE
	recipe.card_face_position = SHRINKING_VIOLET_CARD_FACE_POSITION
	return recipe


## 光照蘑菇：与前面几株的差别只有「场景 / 卡面 / 数值」，是**普通卡**（50 阳光直接种在草地上）。
## 攻击方式走脚本里的光源辅助（夜里光域里击杀僵尸掉小阳光，见 `glowshroom_plant.gd`），不索敌、不用子弹。
func _build_glowshroom_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = GLOW_SHROOM
	recipe.plant_name = &"GlowShroom"
	recipe.plant_scene = GLOW_SHROOM_SCENE
	recipe.cool_time = GLOW_SHROOM_COOL_TIME
	recipe.sun_cost = GLOW_SHROOM_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回阳光菇那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释）
	recipe.card_face_anim = GLOW_SHROOM_CARD_ANIM
	recipe.card_face_fallback_plant = GLOW_SHROOM_FALLBACK_PLANT
	recipe.card_face_scale = GLOW_SHROOM_CARD_FACE_SCALE
	recipe.card_face_position = GLOW_SHROOM_CARD_FACE_POSITION
	return recipe


## 增幅鹅河菊：与前面几株的差别只有「场景 / 卡面 / 数值 / 机制」，是**普通卡**
## （200 阳光直接种在草地上）。机制是范围增益：给周围 3×3 植物的攻击 / 产阳光提速
## （走 `update_speed_factor` 的 `Ampliflower` 来源键，见 `ampliflower_plant.gd`），不索敌、不用子弹。
func _build_ampliflower_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = AMPLIFLOWER
	recipe.plant_name = &"Ampliflower"
	recipe.plant_scene = AMPLIFLOWER_SCENE
	recipe.cool_time = AMPLIFLOWER_COOL_TIME
	recipe.sun_cost = AMPLIFLOWER_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回向日葵那张脸。
	## 缩放 / 落点待运行期 `get_content_rect()` 实测包围盒后回填（见常量注释）
	recipe.card_face_anim = AMPLIFLOWER_CARD_ANIM
	recipe.card_face_fallback_plant = AMPLIFLOWER_FALLBACK_PLANT
	recipe.card_face_scale = AMPLIFLOWER_CARD_FACE_SCALE
	recipe.card_face_position = AMPLIFLOWER_CARD_FACE_POSITION
	return recipe


## 柠檬榴弹：与前面几株的差别只有「场景 / 卡面 / 数值 / 攻击方式」，是**普通卡**
## （200 阳光直接种在草地上）。攻击方式走脚本里的「一次性三连炸」（种下 → 引信 → 本格炸一下
## → 随机弹到邻近区域再炸两下 → 这株消失），不用子弹、不持续索敌（见 `lemonade_plant.gd`）。
func _build_lemonade_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = LEMONADE
	recipe.plant_name = &"Lemonade"
	recipe.plant_scene = LEMONADE_SCENE
	recipe.cool_time = LEMONADE_COOL_TIME
	recipe.sun_cost = LEMONADE_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取；取帧失败时退回樱桃炸弹那张脸。
	## 缩放 / 落点按「画布包围盒中心落在卡面挂点」算（见常量注释，随摆放微调）
	recipe.card_face_anim = LEMONADE_CARD_ANIM
	recipe.card_face_fallback_plant = LEMONADE_FALLBACK_PLANT
	recipe.card_face_scale = LEMONADE_CARD_FACE_SCALE
	recipe.card_face_position = LEMONADE_CARD_FACE_POSITION
	return recipe


## 水盆（原「水盆」模组并入）：与花盆的**差别**只有「地形位」和「卡面取哪一帧」，
## 冷却 / 阳光 / 占下层这些跟花盆一样的值都写在配方里，其余（被啃被铲被偷、承载上层植物）
## 由植物脚本继承本体的 `Plant000DownBase`，一行都不用写。
func _build_water_bowl_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = WATER_BOWL
	recipe.plant_name = &"WaterBowl"
	recipe.plant_scene = WATER_BOWL_SCENE
	recipe.cool_time = WATER_BOWL_COOL_TIME
	recipe.sun_cost = WATER_BOWL_SUN_COST
	## 摆在陆地上（草地 / 屋顶），水池行种不了 —— 与花盆同一套
	recipe.condition_bits = PlantConditionBits.GRASS | PlantConditionBits.ROOF
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Down
	## 水盆这个形态只存在于动画里（卡面借不到现成的手摆形象），所以卡面从动画取帧；
	## 取帧失败时退回花盆那张脸（卡面一空，手持会报「卡片静态角色为空」拿不起来）
	recipe.card_face_anim = WATER_BOWL_CARD_ANIM
	recipe.card_face_fallback_plant = WATER_BOWL_FALLBACK_PLANT
	return recipe
#endregion


#region 水盆：水生植物可以种进去
## 水生植物额外认「水盆」这一位
##
## 「哪些是水生植物」是**按地形位查**出来的（条件 = 8 水、占普通位 → 现在只有海蘑菇与缠绕海草），
## 不写死两张卡：将来再加纯水生的植物，不用回头改本模组。
## 加位走 `add_runtime_plant_condition_bit()`（在它们原有条件上按位或），
## 不整份换掉 —— 换要自己抄一遍原条件，抄漏一位就丢一种地形。
func _open_water_plants_to_bowl() -> void:
	_patched_water_plants = Global.character_registry.collect_plant_types_by_condition(
		PlantConditionBits.WATER)
	for plant_type in _patched_water_plants:
		Global.character_registry.add_runtime_plant_condition_bit(
			plant_type, PlantConditionBits.WATER_BOWL)
	Log.info("水盆：可以种进水盆的水生植物 = %s" % str(_patched_water_plants))


## 关掉模组：把水生植物的条件换回静态表里那一份
func _restore_water_plants() -> void:
	for plant_type in _patched_water_plants:
		Global.character_registry.clear_runtime_plant_condition(plant_type)
	_patched_water_plants.clear()
#endregion
