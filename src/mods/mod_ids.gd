extends RefCounted
class_name ModIds
## 模组 id 常量表
##
## 本体与模组一律引用这里的常量，不写字面量字符串（写歪了不会报错，只会静默装不上）。
## 硬约束 §1-4：id → 脚本的映射只准出现在注册表里，这里的 id 与
## `ModManager.MOD_SCRIPT_PATHS` 一一对应。
##
## 新增一个模组的三步：
##   1. 本文件加一个常量
##   2. `ModManager.MOD_SCRIPT_PATHS` 加一行（id → 入口脚本路径）
##   3. `src/mods/<id>/` 下写入口脚本（继承 `ModBase`）与该模组自己的脚本 / 场景
## 开关：模组页面里开 / 关，存进 `user://<用户名>/mod_config.ini`（`ModManager` 统一管）；
## `data/mods/mod_config.tres` 只是**没有存档文件时播种用的工程默认**。

## 手套：把场上已种下的植物搬到另一个格子（不铲除、不重种，实例与状态全保留）
## 原版没有这个玩法（原版手套是禅境花园工具），所以整条链路都在模组里
const GLOVE := &"glove"

## 自制关卡：把 `user://custom_level` 下的玩家自制关卡脚本加载成可选关卡，
## 并在主菜单加一个入口按钮。原版没有这个功能，所以整条链路都在模组里
const CUSTOM_LEVEL := &"custom_level"

## 联机：多人（先做两人）合作共守一块草坪。原版没有任何联机功能，所以整条链路都在模组里。
## 当前是**骨架**：ENet 连线 + 玩家操作命令上行，还没做状态同步（见
## [联机模组](../../docs/参考存档/联机模组.md) §5 的阶段划分）
const NETPLAY := &"netplay"
