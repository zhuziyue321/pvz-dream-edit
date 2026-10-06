class_name ZombieBossInfoData
extends RefCounted

## 僵王注册表数据表。
## 只放常量数据，查询入口见 CharacterRegistry.get_zombie_boss_info()。

const ZOMBIE_BOSS_INFO = {
	CharacterRegistry.ZombieBossType.ZB001Doctor: {
		CharacterRegistry.ZombieBossInfoAttribute.BossName: "ZB001Doctor",
		CharacterRegistry.ZombieBossInfoAttribute.BossScenes: preload("res://src/entities/character/zombie_boss/zombie_boss_001_doctor.tscn"),
		CharacterRegistry.ZombieBossInfoAttribute.SunCost: 10000,
		CharacterRegistry.ZombieBossInfoAttribute.CoolTime: 0,
	},
}
