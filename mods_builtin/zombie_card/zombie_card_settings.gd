extends RefCounted
## 僵尸卡模组的共享常量
##
## ⚠️ 单独一份是为了让入口脚本与接线脚本都能读它，又不会互相 preload 成环
## （照 `glove_settings.gd` / `hammer_settings.gd` 的拆法，见 docs/参考存档/模组机制.md §四）。

## 「我是僵尸」关卡没写僵尸预选卡时，发哪几张僵尸卡
##
## 选的是原版最基础的四只：普通僵尸 / 路障僵尸 / 撑杆跳僵尸 / 铁桶僵尸
## —— 它们的卡在原版 `all_cards.tscn` 里都有登记，造得出来。
const DEFAULT_ZOMBIE_CARDS: Array[StringName] = [
	ZombieIds.NORM,
	ZombieIds.CONE,
	ZombieIds.POLE_VAULTER,
	ZombieIds.BUCKET,
]
