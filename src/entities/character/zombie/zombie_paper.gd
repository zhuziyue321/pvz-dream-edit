extends Zombie000Base
class_name Zombie006Paper
## 读报僵尸
##
## 报纸是一件 `ArmorComponentNewspaper`（二类防具），破防后的暴走表现**写在那个防具组件里**，
## 本文件不再连"防具掉了"的信号 —— 见 `component_armor_newspaper.gd`。

@export_group("动画状态")
@export var is_gasp:bool = false
