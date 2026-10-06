extends RefCounted
class_name ConstFeatureSwitch
## 玩法功能总开关：临时下线某个已实现的玩法时，只改这里的常量（false = 隐藏，true = 恢复）。
##
## ★ 约定：开关关闭时**只让入口不可用**，代码与场景节点全部保留 —— 不要为了隐藏而删代码 / 删节点，
##   改回 true 就必须能完整恢复。想彻底删除请另开工单，不要借"隐藏"顺手删。
##
## 影响面（每个开关都写清楚，改完按它自查；漏一处就会"说是关了却还能用"）：
##
## GLOVE_ENABLED —— 关卡内手套（HandComponentGlove）
##   卡槽手套按钮 / G 快捷键 / 搬运交互 / 通关 4-5 解锁判定（ConstUnlockLevel.is_glove_unlocked）
##   / 冒险 4-6 戴夫赠礼对话（adventure_04_06）
##
## ZOMBIE_CARD_ENABLED —— 选卡界面的僵尸卡片
##   待选卡槽的僵尸候选卡页（CardSlotCandidate）/ 关卡预选僵尸卡（LevelData.prechosen_cards 里的
##   Zombie 条目，含 card_slot_norm 这条预选通道）/「重选上次卡片」里的僵尸卡
##   注意：解谜模式「我是僵尸」关卡靠预选僵尸卡开局，关掉后这些关卡没有可用卡片。
##
## 关联：ConstUnlockLevel ｜ HandComponentGlove ｜ CardSlotCandidate ｜ CardSlotNorm
## 记录：[工作记录 2026-10-04_隐藏关卡内手套功能](../../docs/工作记录/2026-10-04_隐藏关卡内手套功能.md)

## 关卡内手套：当前隐藏（改回 true 即恢复整套手套玩法）
const GLOVE_ENABLED := false

## 选卡界面的僵尸卡片：当前隐藏（改回 true 即恢复僵尸候选卡页与预选僵尸卡）
const ZOMBIE_CARD_ENABLED := false
