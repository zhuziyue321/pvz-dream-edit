extends RefCounted
class_name ConstBeghouled
## 僵尸迷阵（Beghouled）玩法常量
##
## 数据来源: Plants vs Zombies Wiki(https://plantsvszombies.wiki.gg/wiki/Beghouled) —— 一代原版口径：
##   夜间前院、开局草坪已铺满植物（僵尸入场那一列留空）、植物不能铲、
##   完成 **75 次配对** 通关、3 连 25 阳光 / 4 连 50 / 5 连及以上 100、
##   升级 豌豆射手→双重射手 1000、小喷菇→大喷菇 500、坚果→高坚果 250、
##   植物被啃掉留弹坑、花 200 阳光填坑、没有小推车（一只僵尸进屋即输）
##
## 待核实: 手动「重置植物」的价格 —— wiki 只写「有 100 阳光就能立刻手动重置」，这里按 100 落地

## 通关所需配对次数
const TARGET_MATCH_NUM := 75

## 一条连线长度 → 阳光奖励；超过表内长度（5 连及以上）一律按 SUN_CHAIN_MAX 给
const SUN_BY_CHAIN_LEN := {
	3: 25,
	4: 50,
}
## 长连线的阳光奖励上限
const SUN_CHAIN_MAX := 100
## 一颗掉落阳光的面值：奖励 50 / 100 时按它拆成多颗一起掉（Sun 按面值缩放，单颗 100 的贴图会过大）
const SUN_UNIT_VALUE := 25

## 三消棋盘上的基础植物（原版六种，见 wiki「The six plants are all different colors」；
## 策略段提到的植物即这六种：豌豆射手 / 坚果 / 寒冰射手 / 小喷菇 / 星星果 / 磁力菇）
const BASE_PLANT_TYPES: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P001PeaShooterSingle,
	CharacterRegistry.PlantType.P004WallNut,
	CharacterRegistry.PlantType.P006SnowPea,
	CharacterRegistry.PlantType.P009PuffShroom,
	CharacterRegistry.PlantType.P030StarFruit,
	CharacterRegistry.PlantType.P032MagnetShroom,
]

## 升级项：把场上所有 from 换成 to（原版三档，价格见文件头来源注释）
## sun —— 购买价格；name —— 按钮上显示的升级目标名
const UPGRADE_LIST: Array[Dictionary] = [
	{
		"from": CharacterRegistry.PlantType.P001PeaShooterSingle,
		"to": CharacterRegistry.PlantType.P008PeaShooterDouble,
		"sun": 1000,
		"name": "双重射手",
	},
	{
		"from": CharacterRegistry.PlantType.P009PuffShroom,
		"to": CharacterRegistry.PlantType.P011FumeShroom,
		"sun": 500,
		"name": "大喷菇",
	},
	{
		"from": CharacterRegistry.PlantType.P004WallNut,
		"to": CharacterRegistry.PlantType.P024TallNut,
		"sun": 250,
		"name": "高坚果",
	},
]

## 手动重置植物（洗牌）所需阳光
const SHUFFLE_SUN := 100
## 填补一个弹坑所需阳光
const CRATER_FILL_SUN := 200

## 刷新 / 填坑两张自定义种子包的整卡贴图：从 seeds.png 裁出来的专用卡面（50×70 整张，
## 图案已画好，直接当卡面用，**不再往上叠任何东西**）
## 僵尸迷阵（迷你 05）与僵尸迷阵 旋风（迷你 09）的卡槽第 4 / 第 5 格共用这两张
const PACKET_REFRESH_TEXTURE: Texture2D = preload("res://assets/image/ui/ui_card/SeedPacket_Beghouled_Refresh.png")
const PACKET_FILL_TEXTURE: Texture2D = preload("res://assets/image/ui/ui_card/SeedPacket_Beghouled_Fill.png")

## 死局提示：原版刷新前没有文案，这里为了让玩家明白「为什么盘面突然变了」，
## 提示出现后停留 NO_MOVE_TIP_WAIT 秒再刷新整盘（自定义，非 wiki 口径）
## 显示位置沿用全项目唯一那条屏幕下方的教程提示条（TutorialAdviceUI），不另做一块提示 label
const NO_MOVE_TIP_TEXT := "没有配对的植物了！"
const NO_MOVE_TIP_WAIT := 4.0

## 棋盘最右侧留空的列数（原版：僵尸入场那一列是空的，见 wiki「a lone empty column」）
const EMPTY_COL_NUM_ON_RIGHT := 1

## 按连线长度取阳光奖励（一次交换造成多组连线时各组奖励累加，见 wiki「Multiple matches ... more sun」）
static func get_sun_by_chain_len(chain_len: int) -> int:
	if chain_len >= 5:
		return SUN_CHAIN_MAX
	return int(SUN_BY_CHAIN_LEN.get(chain_len, 0))


## 把自定义种子包的卡面**整张**换成给定贴图（seeds.png 裁出的 50×70 整卡图，
## 图案已画好，卡面直接用它 —— 不在上面叠加任何东西）：
## 换掉卡片背景贴图，并清掉模板带来的角色静态形象（模仿者 / 毁灭菇那张残留的形象）
## 身份引用（模仿者 / 毁灭菇）只是取模板用的壳，换完卡面就与它无关了
static func set_packet_face(card: Card, texture: Texture2D) -> void:
	if card == null:
		return
	card.card_bg.texture = texture
	for child in card.character_static.get_children():
		child.queue_free()
