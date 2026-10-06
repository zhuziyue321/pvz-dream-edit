class_name BulletCampConfig
## 子弹阵营配置：把「阵营 → 碰撞层 / 敌人类型 / 索敌优先级」的映射收在一处
##
## 为什么需要这一份配置：
##   重构前「子弹属于植物方」是写死的 ——
##   · 碰撞层写死在每个 .tscn 的 Area2DAttack 上（植物方 layer4 / mask 只覆盖僵尸真实层，
##     僵尸方只有篮球一个场景手改 layer8 / mask 植物真实层）；
##   · `bullet_camp` 只是场景导出值，发射方无法指定，同一份子弹场景不能被双方复用；
##   · 追踪子弹索敌时植物候选被直接跳过（见 detect_target_strategy.gd）。
##   植物僵尸（僵尸头顶带植物、向玩家的植物开火）要求**同一份子弹场景能被双方复用**，
##   所以一切与阵营相关的常量必须集中、可查、可在 `init_bullet` 时切换。
##
## 约定：
##   · 全部 static，不持有状态 —— 只吃参数、吐结果（与 DetectTargetStrategy 同风格）
##   · 碰撞层编号见 docs/参考存档/子弹与碰撞.md 的「碰撞层说明」

#region 阵营与碰撞层
## 阵营自己的碰撞层（Area2DAttack.collision_layer）
const C_CampCollisionLayer: Dictionary[CharacterRegistry.CharacterType, int] = {
	CharacterRegistry.CharacterType.Plant: 8,		## layer 4 BulletFromPlant
	CharacterRegistry.CharacterType.Zombie: 128,	## layer 8 BulletFromZombie
}
## 阵营要检测的敌人受击层（Area2DAttack.collision_mask）
## 简化后的受击层只有 4 个：layer 2/3（植物/僵尸索敌框）、layer 9/10（植物/僵尸真实受击框），
## 原来表达「魅惑」的 layer 6 / 11 已废弃 —— 魅惑僵尸与普通僵尸同在 layer 3 / 10，
## 敌我改由归属阵营判断（见 get_owner_camp / is_enemy），所以僵尸方必须把 512 也放进 mask：
##   · 植物方子弹（mask 512）物理上会碰到魅惑僵尸，但被 is_enemy 拒绝 —— 与原版一致；
##   · 僵尸方子弹 / 啃食（mask 256+512）会打植物，也会打魅惑僵尸（魅惑僵尸归属植物方）。
const C_CampEnemyMask: Dictionary[CharacterRegistry.CharacterType, int] = {
	CharacterRegistry.CharacterType.Plant: 512,			## layer 10 ZombieHurtBoxReal
	CharacterRegistry.CharacterType.Zombie: 256 + 512,	## layer 9 PlantHurtBoxReal + layer 10 ZombieHurtBoxReal
}
## 所有「阵营自己的层」的位集合：用于从场景配置里剥离不属于阵营的额外层
## （直线子弹额外带 layer1 World 判斜坡、保龄球额外带 layer7 Bowling 供撑杆跳检测）
const C_AllCampLayerBits := 8 | 128
## 所有「阵营敌人层」的位集合：用途同上（魅惑变体层 1024 已废弃，不再列入）
const C_AllCampMaskBits := 512 | 256
#endregion

## 阵营自己的碰撞层
static func get_collision_layer(camp:CharacterRegistry.CharacterType) -> int:
	return C_CampCollisionLayer.get(camp, C_CampCollisionLayer[CharacterRegistry.CharacterType.Plant])


## 阵营要检测的敌人受击层
static func get_enemy_mask(camp:CharacterRegistry.CharacterType) -> int:
	return C_CampEnemyMask.get(camp, C_CampEnemyMask[CharacterRegistry.CharacterType.Plant])


## 阵营的敌对阵营
static func get_enemy_camp(camp:CharacterRegistry.CharacterType) -> CharacterRegistry.CharacterType:
	match camp:
		CharacterRegistry.CharacterType.Plant:
			return CharacterRegistry.CharacterType.Zombie
		CharacterRegistry.CharacterType.Zombie:
			return CharacterRegistry.CharacterType.Plant
	return CharacterRegistry.CharacterType.Null


## 角色的阵营（只看类型：魅惑僵尸仍算僵尸阵营 —— 阵营与敌我是两回事）
static func get_camp_of_character(character:Node) -> CharacterRegistry.CharacterType:
	if character is Plant000Base:
		return CharacterRegistry.CharacterType.Plant
	## 僵王在阵营侧按僵尸处理：植物方子弹能打它，僵尸方子弹不能
	## （卡牌类型才区分 ZombieBoss，阵营判定不引入新阵营）
	if character is Zombie000Base or character is ZB000Base:
		return CharacterRegistry.CharacterType.Zombie
	return CharacterRegistry.CharacterType.Null


## 角色的**归属阵营**：魅惑僵尸算植物方（它是玩家的人）
## 敌我一律用归属阵营判断，层只回答「我是植物还是僵尸、是索敌框还是伤害框」：
##   · 魅惑僵尸（归属植物方）成为僵尸方的敌人、植物方的自己人 —— 与原版一致
##   · 魅惑僵尸作为攻击方时会啃普通僵尸、不啃植物：is_enemy(植物方, 普通僵尸) 为真
static func get_owner_camp(character:Node) -> CharacterRegistry.CharacterType:
	if character is Zombie000Base:
		var zombie: Zombie000Base = character
		if zombie.is_hypno:
			return CharacterRegistry.CharacterType.Plant
	return get_camp_of_character(character)


## camp 方是否把 character 当作敌人（同阵营一律不是敌人；魅惑使归属阵营反转）
static func is_enemy(camp:CharacterRegistry.CharacterType, character:Node) -> bool:
	var enemy_camp := get_enemy_camp(camp)
	if enemy_camp == CharacterRegistry.CharacterType.Null:
		return false
	return get_owner_camp(character) == enemy_camp


## 索敌时 candidate 是否比 curr 更应该被选中
## · 植物方子弹（打僵尸）：越靠近房子（x 越小）越优先
## · 僵尸方子弹（打植物）：越靠近僵尸出生侧（x 越大）越优先
static func is_nearer(camp:CharacterRegistry.CharacterType, candidate_x:float, curr_x:float) -> bool:
	if camp == CharacterRegistry.CharacterType.Zombie:
		return candidate_x > curr_x
	return candidate_x < curr_x


## 把阵营对应的碰撞层写进一个 Area2D，同时保留场景里配置的「非阵营」额外层
## [area] 子弹的攻击框 / 溅射框
## [camp] 子弹阵营
static func apply_camp_collision(area:Area2D, camp:CharacterRegistry.CharacterType) -> void:
	if not is_instance_valid(area):
		return
	## 场景里配置的、不属于任何阵营基础层的位视为额外层（World / Bowling 等），原样保留
	var extra_layer := area.collision_layer & (~C_AllCampLayerBits)
	var extra_mask := area.collision_mask & (~C_AllCampMaskBits)
	area.collision_layer = get_collision_layer(camp) | extra_layer
	area.collision_mask = get_enemy_mask(camp) | extra_mask
