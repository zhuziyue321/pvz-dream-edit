extends BombComponentBase
class_name BombComponentNorm
## 普通炸弹使用爆炸组件

@onready var bomb_effect: BombEffectBase = $BombEffect

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 炸死所有敌人[僵尸有两个受击组件检测框,会被检测两次]
func _bomb_all_enemy():
	## 被爆炸炸到的敌人
	var character_be_bomb :Array[Character000Base] = []
	var areas = area_2d_bomb.get_overlapping_areas()
	for area in areas:
		var area_owner = area.owner
		if area_owner is Plant000Base:
			var plant:Plant000Base = area_owner as Plant000Base
			if not _is_bomb_enemy(plant):
				continue
			if can_attack_status_component.can_attack(plant):
				if not character_be_bomb.has(plant):
					if judge_lane(plant):
						character_be_bomb.append(plant)
		if area_owner is Zombie000Base:
			var zombie:Zombie000Base = area_owner as Zombie000Base
			## 敌我不再由碰撞层区分：魅惑僵尸归属植物方，己方（植物方）炸弹炸不到它
			if not _is_bomb_enemy(zombie):
				continue
			if can_attack_status_component.can_attack(zombie):
				if not character_be_bomb.has(zombie):
					if judge_lane(zombie):
						character_be_bomb.append(zombie)
		## 如果是梯子
		if area_owner is Ladder:
			if bomb_lane == -1 or (owner.lane + bomb_lane >= area_owner.lane and owner.lane - bomb_lane <= area_owner.lane ):
				area_owner.ladder_death()
	for c:Character000Base in character_be_bomb:
		if c is Zombie000Base:
			c.be_bomb(bomb_value, is_cherry_bomb)


## 爆炸范围内的角色是不是本方要炸的敌人
## 魅惑僵尸与普通僵尸同层（魅惑变体层已废弃），所以这里必须按归属阵营再判一次
## owner 不是角色时（编辑器预览 / 异常挂载）按「都是敌人」处理，保持原行为
func _is_bomb_enemy(character:Character000Base) -> bool:
	var bomb_camp := BulletCampConfig.get_owner_camp(owner)
	if bomb_camp == CharacterRegistry.CharacterType.Null:
		return true
	return BulletCampConfig.is_enemy(bomb_camp, character)


func judge_lane(enemy:Character000Base) -> bool:
	return bomb_lane == -1 or (owner.lane + bomb_lane >= enemy.lane and owner.lane - bomb_lane <= enemy.lane )
