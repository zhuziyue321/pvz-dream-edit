extends Resource
class_name ModConfig
## 模组开关清单（数据层唯一事实来源）
##
## 开 / 关模组 = 改 `data/mods/mod_config.tres` 里这一行，不碰代码。
## 关掉的模组**完全不安装**（不是"装了再隐藏"）：主游戏里不会多出任何节点。
##
## 默认全部关闭 —— 本体 = 原版体验，原版之外的玩法要靠模组显式打开。

## 启用的模组 id（值取自 `ModIds`；不在表里 = 关闭）
@export var enabled_mods: Array[StringName] = []
