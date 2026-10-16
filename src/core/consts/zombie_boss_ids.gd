extends RefCounted
class_name ZombieBossIds
## 僵王类型 id 表：**用 StringName 当 id，不再用 ZB001 这种数字编号**（2026-10-13 迁移）。
##
## 与 `PlantIds` / `ZombieIds` 同一轮迁移。目前只有一位僵王博士，但 id 化之后
## 加第二位僵王只需在这里加一个常量 —— 不用再想"下一个编号取几"。
##
## 与旧枚举的**值对应关系**（旧 `CharacterRegistry.ZombieBossType` 已删除）：`ZB001Doctor = 1`。
##
## ⚠️ 僵王**两张表各有一个 id**：生成侧（关卡 `boss_type` / `ZmBossRegistry` / 僵王卡）用这里的
## `DOCTOR`；通用僵尸系统（遍历 / 敌方计数 / 图鉴）用 `ZombieIds.ZOMBOSS_DOCTOR`。
## 这不是重复登记，是两个不同的身份视角（详见 `ZombieIds` 文件头的说明）。


## 空 id：没指定僵王。
const NULL := &""


const DOCTOR := &"doctor"	## 僵王博士 Dr. Zomboss（ZB001）


## 全部僵王 id
const ALL: Array[StringName] = [DOCTOR]


## 老存档里的数字编号 → id（**只给读老存档用**）
const LEGACY_INT_TO_ID: Dictionary[int, StringName] = {1: DOCTOR}


## 是不是一个已知的僵王 id（空 id 不算）
static func is_valid(boss_id: StringName) -> bool:
	return boss_id != &"" and boss_id in ALL


## 老存档迁移：把一个可能是 int 也可能是 id 的值统一成 id（转不出来返回 `NULL`）
static func from_legacy(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING:
		## 同 `PlantIds.from_legacy()`：`StringName(value)` 是构造不出来 id 的，交 String 回去即可
		return str(value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return LEGACY_INT_TO_ID.get(int(value), NULL)
	return NULL
