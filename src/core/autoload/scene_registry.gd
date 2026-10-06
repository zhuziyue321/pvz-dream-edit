extends Node
## 散落的加载场景


## 花园植物格子
var PLANT_CELL_GARDEN:PackedScene= load("res://src/garden/plant_cell_garden.tscn")
## 花园需求气泡
var GARDEN_SPEECH_BUBBLE = load("res://src/garden/garden_speech_bubble.tscn")
## 花园花盆
const GARDEN_FLOWER_POT = preload("res://src/garden/garden_flower_pot.tscn")


## 戴夫
var CRAZY_DAVE:PackedScene = load("res://src/dave/crazy_dave.tscn")

## 新手教程提示条（屏幕下方的提示文本 + 指向箭头）
var TUTORIAL_ADVICE:PackedScene = load("res://src/ui/tutorial_advice_ui.tscn")

## 提示信息
const REMINDER_INFORMATION:PackedScene = preload("res://src/ui/reminder_information.tscn")

## 「开始战斗！」按钮（原版迷你游戏「坚不可摧」的布阵阶段，右下角）
const LETS_ROCK_BUTTON:PackedScene = preload("res://src/ui/main_game_ui/lets_rock_button.tscn")

## 钻石、金币、银币、
const COIN_DIAMOND:PackedScene = preload("res://src/items/drop/coin_diamond.tscn")
const COIN_GOLD:PackedScene = preload("res://src/items/drop/coin_gold.tscn")
const COIN_SILVER:PackedScene = preload("res://src/items/drop/coin_silver.tscn")
## 禅境花园的蜗牛(商店买断后才出现在花园里,见 GardenManager._init_stinky)
const STINKY:PackedScene = preload("res://src/garden/stinky.tscn")
const PRESENT:PackedScene = preload("res://src/items/drop/present.tscn")
## 种子包样式的掉落展示物（冒险模式通关拿到新植物时显示）
const SEED_PACKET:PackedScene = preload("res://src/items/drop/seed_packet.tscn")
## 僵尸掉落的巧克力（买了蜗牛之后才会掉，见 DropItemComponent.drop_chocolate）
const CHOCOLATE_DROP:PackedScene = preload("res://src/items/drop/chocolate.tscn")

## 待选卡槽
var CARD_CANDIDATE_CONTAINER = load("res://src/ui/card/card_candidate_container.tscn")
## 植物种植特效
const PLANT_START_EFFECT = preload("res://src/items/plant_effect/plant_start_effect.tscn")
const PLANT_START_EFFECT_WATER = preload("res://src/items/plant_effect/plant_start_effect_water.tscn")

## 坑洞
const DOOM_SHROOM_CRATER = preload("res://src/fx/doom_shroom_crater.tscn")

## 墓碑
var TOMBSTONE = load("res://src/items/tombstone.tscn")


## 僵王博士不在本注册表里：僵王是正式角色，走 CharacterRegistry.ZombieBossType 查场景
## （见 Global.character_registry.get_zombie_boss_info(..., BossScenes)），血条由 LevelInfo 统一管理。

## 舞王管理器
var JACKSON_MANAGER = load("res://src/entities/character/components/jackson/jackson_manager.tscn")

## 奖杯
var TROPHY = load("res://src/items/trophy.tscn")

## 锤僵尸玩法（迷你游戏 15「打僵尸」/ 冒险 2-5「打地鼠」两关共用）：
## 锤子美术常驻主场景（CanvasLayerTemp 的 RealHammer，由手持物组件 HandComponentHammer 拿着），
## 这里只登记出怪器 —— 由这两关共用的玩法规则装配（见 LevelRuleHammerZombie）
const HAMMER_ZOMBIE_SOURCE:PackedScene = preload("res://src/managers/zombie_manager/zm_hammer_zombie_manager.tscn")

## 冰冻僵尸特效
const ICE_EFFECT = preload("res://src/fx/ice_effect.tscn")
## 泳池水花场景
const SPLASH = preload("res://src/items/splash.tscn")
## 火焰特效(火爆辣椒\火焰豌豆)
var FIRE = load("res://src/fx/fire.tscn")
## 黄油特效
const BUTTER_SPLAT = preload("res://src/fx/butter_splat.tscn")

## 阳光
var SUN = load("res://src/items/sun.tscn")

## 僵尸水族馆（迷你游戏第 8 关）：入口场景（壳）→ 玩法总控 / 宠物潜水僵尸 / 喂僵尸的脑子
## 关卡走 ZOMBIQUARIUM_SCENE（见 minigame_08_zombie_aquarium）；单独预览时直接在编辑器里跑它
var ZOMBIQUARIUM_SCENE = load("res://src/zombiquarium/zombiquarium.tscn")
var ZOMBIQUARIUM = load("res://src/zombiquarium/zombiquarium_manager.tscn")
var ZOMBIQUARIUM_PET = load("res://src/zombiquarium/zombiquarium_pet.tscn")
var ZOMBIQUARIUM_BRAIN = load("res://src/zombiquarium/zombiquarium_brain.tscn")

## 泥土上升特效
const DIRT_RISE_EFFECT = preload("res://src/entities/character/item/dirt_rise_effect.tscn")

## 梯子
const LADDER = preload("res://src/items/ladder.tscn")
