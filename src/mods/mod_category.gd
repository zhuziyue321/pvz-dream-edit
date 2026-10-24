extends RefCounted
class_name ModCategory
## 模组分类（维度 C：内容性质）。与 `ModIds` / `ModConfig` 同为本体与模组共享的契约
## （保留 `class_name`，模组脚本可直接引用 `ModCategory.XXX`）。
##
## ★ 多标签：一个模组可同时归属多个分类（返回 `Array[StringName]`），
##   界面里的过滤按 **OR** 语义 —— 选中若干分类时，命中任意一个就显示。
##
## ★ 这套分类与具体玩法解耦（见 `mods_builtin/README.md` 的「三维分类法」），
##   新增模组只需在 `get_mod_categories()` 里返回对应常量，不必为每个模组单独写说明。
##
## 维度 C 的四类：
##   · 新增单位  —— 原版没有的植物 / 僵尸变体（含防具这类挂在单位上的新资源）
##   · 新增工具  —— 场上交互用的手持物 / 道具
##   · 改写规则  —— 改原版已有的数值 / 行为，不新增单位
##   · 新增结构  —— 关卡 / 系统等框架级扩展（跨局、常改菜单）

## 新增战斗单位：原版没有的植物 / 僵尸变体
const ADD_UNIT := &"add_unit"
## 新增工具 / 手持物：场上交互道具
const ADD_TOOL := &"add_tool"
## 改写规则：改原版已有的数值 / 行为（不加新单位）
const OVERRIDE_RULE := &"override_rule"
## 新增结构：关卡 / 系统等框架级扩展
const ADD_STRUCTURE := &"add_structure"

## 全部分类（界面生成过滤器用）
const ALL := [&"add_unit", &"add_tool", &"override_rule", &"add_structure"]

## 分类显示名（界面用）
const NAMES := {
	&"add_unit": "新增单位",
	&"add_tool": "新增工具",
	&"override_rule": "改写规则",
	&"add_structure": "新增结构",
}

## 取分类显示名（未知回退到原始值）
static func name_of(category: StringName) -> String:
	return NAMES.get(category, str(category))
