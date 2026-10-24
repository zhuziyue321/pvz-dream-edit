extends Resource
## 僵尸出怪规则资源（对标植物侧的 `ResourcePlantCondition`）
##
## 背景：植物早就有「可多态的规则资源」（`plant_condition/condition_plant_base.gd` 的
## `judge_is_can_plant()`，`.tres` 里配 22 位地形掩码），而僵尸侧一直只有 4 值枚举
## `CharacterRegistry.ZombieRowType`，遇到「这只僵尸还要额外条件」时只能在出怪系统里
## 按类型硬判断（雪橇僵尸要不要冰道就是这么写进 `zm_zombie_wave_create_manager.gd` 的）。
##
## 本资源把这些附加条件收成数据：新增同类僵尸只加一行 `.tres` + 一条注册表字段，
## **不用再改选行系统**。
##
## 用法（`zombie_info_data.gd` 的对应条目里加一行）：
##     CharacterRegistry.ZombieInfoAttribute.ZombieCondition: preload("res://data/.../xxx.tres"),
##
## ⚠️ 这份资源是**可选**的：没登记的僵尸 `get_zombie_condition()` 返回 null，
## 所有字段按默认值理解（陆地行、不需要冰道）。
class_name ResourceZombieCondition

## 可出战的行走类型，取值对齐 `CharacterRegistry.ZombieRowType`
## （0 = Land / 1 = Pool / 2 = Both / 3 = None）。
##
## 为什么是 int 而不是直接标枚举类型：`CharacterRegistry` 是 autoload 节点，
## 它的枚举在编译期不是常量，写进 `@export` 默认值会报「非恒定表达式」
## （同 U-28 踩过的坑）。这里用 int，取值口径写在这条注释里。
@export var row_type: int = 0
## 必须先有冰道才能出（雪橇僵尸：没有冰的小队一落地就掉血，等于白出）
@export var require_ice_road := false
## 水陆两栖僵尸在水路时的本体变化（等价于 `Zombie000Base.body_change_on_pool` 的数据化入口）
@export var body_change_on_pool: ResourceBodyChange
