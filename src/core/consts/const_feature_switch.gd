extends RefCounted
class_name ConstFeatureSwitch
## 玩法功能总开关：临时下线某个已实现的玩法时，只改这里的常量（false = 隐藏，true = 恢复）。
##
## ★ 约定：开关关闭时**只让入口不可用**，代码与场景节点全部保留 —— 不要为了隐藏而删代码 / 删节点，
##   改回 true 就必须能完整恢复。想彻底删除请另开工单，不要借"隐藏"顺手删。
##
## ★ 新玩法不进本体：原版没有的玩法请做成**模组**（`mods_builtin/<id>/`，由 `ModManager` 装载，
##   开关与设置都在 `user://<用户名>/mod_config.ini`），不要在这里加开关 —— 加了开关就等于把玩法本体化，
##   关掉它还要在本体各处堵分支（手套就是这样走过一遍的，见
##   [工作记录 2026-10-04_隐藏关卡内手套功能](../../docs/工作记录/2026-10-04_隐藏关卡内手套功能.md)，
##   现已改成手套模组）。本文件只留给"暂时不想启用的本体功能"。
##
## 影响面（每个开关都写清楚，改完按它自查；漏一处就会"说是关了却还能用"）：
##
## ZOMBIE_CARD_ENABLED —— 选卡界面的僵尸卡片
##   待选卡槽的僵尸候选卡页（CardSlotCandidate）/ 关卡预选僵尸卡（LevelData.prechosen_cards 里的
##   Zombie 条目，含 card_slot_norm 这条预选通道）/「重选上次卡片」里的僵尸卡
##   注意：解谜模式「我是僵尸」关卡靠预选僵尸卡开局，关掉后这些关卡没有可用卡片。
##
##   ★ 这条是「总开关」，为 false 时**仍有一条运行期通道**：控制台「调试模式」打开也能用僵尸卡
##     （唯一判据是 GlobalGameState.is_zombie_card_enabled()，改判据不要改这里的调用点）。
##
## 关联：ConstUnlockLevel ｜ CardSlotCandidate ｜ CardSlotNorm ｜ ModManager ｜ GlobalGameState

## 选卡界面的僵尸卡片：当前隐藏（改回 true 即恢复僵尸候选卡页与预选僵尸卡）
## 隐藏期间仍可在控制台打开「调试模式」临时使用（见 GlobalGameState.is_zombie_card_enabled）
const ZOMBIE_CARD_ENABLED := false
