extends Node
class_name ItemRegistry
## ⚠️ **本类是空壳占位**，当前没有任何登记内容（U-08 已核实）。
##
## 为什么还没删：`global.gd` 用 `@onready var item_registry: ItemRegistry = %ItemRegistry`
## 引用它，`global.tscn` 里也有对应节点 —— 删脚本要连场景一起改，收益 < 风险。
## 2026-10-07 的架构清理已判定**保留**（见那次的工作记录）。
##
## 真要往里放东西时：本类的定位是「场上物件（小推车 / 掉落物 / 罐子…）的类型 → 场景」映射，
## 与 `CharacterRegistry` / `BulletRegistry` 同一层；在那之前不要凭空加字段。
