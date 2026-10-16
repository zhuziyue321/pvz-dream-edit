extends RefCounted
class_name PlantConditionBits
## 植物种植条件的**地形位**：`ResourcePlantCondition.plant_condition` 是一个位掩码，
## 每一位 = 一种可以落地的地形（格的 `curr_condition` 与它按位与，非 0 即满足）。
##
## ★ 这些位原先散落在各处当裸数字写（`plant_condition = 22`、`own_condition_bit = 64`），
##   加一类地形要在几个文件里同步改，还得回头猜"22 是哪两个位" —— 现在一律按名字取：
##   `PlantConditionBits.GRASS | PlantConditionBits.ROOF`。
##
## ⚠️ 加一位要动两处（漏一处 = 代码认这个位、编辑器里却勾不出来）：
##   1. 本文件加一个常量；
##   2. `data/character/plant_condition/condition_plant_base.gd` 的 `@export_flags` 补一个选项
##      （那串字符串是编辑器里的勾选项，格式是「位值 名字」）。

const NONE := 1			## 无（空地）
const GRASS := 2		## 草地
const FLOWER_POT := 4		## 花盆（种下花盆 / 水盆之后格子带的位）
const WATER := 8		## 水（水池行）
const LILY_PAD := 16		## 睡莲
const ROOF := 32		## 屋顶 / 裸地
const WATER_BOWL := 64		## 水盆（原版没有这只底部植物，位由本体空出来，见 `Plant000DownBase.own_condition_bit`）

## 原版普通植物的默认地形：草地 + 花盆 + 睡莲
const DEFAULT_NORM := GRASS | FLOWER_POT | LILY_PAD

## 底层植物（花盆 / 水盆）自己的地形：草地 + 屋顶
const DEFAULT_DOWN := GRASS | ROOF
