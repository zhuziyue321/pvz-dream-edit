<!-- AGENT-DOC -->
# `src/core/consts/`

> **[面向 AI Agent]** ｜ **触发条件**：需要新增或查找全局枚举 / 关卡常量时
> **读完你能**：知道该把新枚举放进哪个文件、如何通过 `class_name` 直接引用（无需 `preload`）
> **强制级别**：应该 ｜ **不读的风险**：枚举散落各处或重复定义，与 `ResourceLevelData` 脱节
> **关联**：仓库入口 [../../AGENTS.md](../../../AGENTS.md) ｜ 文档地图 [../../docs/README.md](../../../docs/README.md)

本目录存放**全局可引用的枚举与关卡相关常量**，通过 `class_name` 在任意脚本中直接使用类型名，无需 `preload` 路径。

## 文件说明

| 文件 | `class_name` | 内容概要 |
|------|----------------|----------|
| `const_level_data.gd` | `ConstLevelData` | 关卡数据配套：背景 `GameBg`、BGM `GameBGM` 与路径表、出怪/卡槽/罐子模式枚举及纹理、音频等常量映射。被 `ResourceLevelData`（`level_data.gd`）等引用。 |
| `const_plant_unlock.gd` | `ConstPlantUnlock` | 植物解锁进度：初始植物、紫卡与模仿者的开放购买关卡与售价。被 `GlobalGameState`、`SaveService`、`StoreManager` 引用。**不含**「冒险第 N 关给哪株植物」 —— 那句话写在那一关的关卡脚本上（`LevelRegistry.get_adventure_level_reward_plant()`）。 |
| `const_shop.gd` | `ConstShop` | 疯狂戴夫商店的卡槽扩充商品常量：出战卡槽基准数 / 上限、单价、可购买次数。被 `GlobalGameState`、`ResourceLevelData`、`GoodsCardSlot` 引用。 |
| `const_unlock_level.gd` | `ConstUnlockLevel` | 冒险模式进度解锁：模式 / 铲子 / 图鉴 / 手套 / 花园 / 金钱 / 商店的解锁关卡序号与判定函数。 |
| `const_feature_switch.gd` | `ConstFeatureSwitch` | **玩法功能总开关**：临时下线已实现的玩法时改这里（`false` = 隐藏，`true` = 恢复）。当前含 `ZOMBIE_CARD_ENABLED`（选卡界面的僵尸卡片）。**原 `GLOVE_ENABLED`（关卡内手套）已删除** —— 手套改成了模组，开关与设置都在 `user://<用户名>/mod_config.ini`（见 [参考存档/模组机制.md](../../../docs/参考存档/模组机制.md)）；**原版没有的玩法一律做成模组，不要在这里加开关**（见该脚本文件头）。新增本体开关**只放这里**，不要散到别的常量文件。 |


## 使用方式

在脚本中直接写类型或枚举成员，例如：

```gdscript
var bg: ConstLevelData.GameBg = ConstLevelData.GameBg.Pool
var scene: EnumsMainScene.MainScenes = EnumsMainScene.MainScenes.ChooseLevelAdventure
```

新增枚举或常量时，优先放在语义对应的文件中；若属于「整局关卡规则」且与 `ResourceLevelData` 强相关，放在 `ConstLevelData` 中。
