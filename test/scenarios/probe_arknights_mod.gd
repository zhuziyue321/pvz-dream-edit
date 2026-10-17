extends RefCounted
## 探针：模组「明日方舟」（防御力 / 法术抗性 + 物理 / 法术伤害分类 + 减免修饰器）
##
## 验四块：
##   ① 减免公式：物理 `max(0, 伤害-防御)`、法术 `round(伤害 × (100-法抗%) / 100)`（含夹取与四舍五入）
##   ② 伤害类型便签：未标记 = 物理；mark_attack() 标什么就是什么
##   ③ 模组登记：MOD_SCRIPT_PATHS / 实例 / id / 名称 / 分类 / 模组页面详情
##   ④ 修饰器端到端：秒杀原样放行；真僵尸实例上单实例覆盖防御力 / 法抗后，
##      物理 100→50、法抗 20% 时法术 100→80，清掉覆盖回默认 0
##
## 机器可读汇总：最后一行 [ARKNIGHTS] result=PASS|FAIL failed=<n>

const STATS_PATH := "res://mods_builtin/arknights/arknights_stats.gd"
const MOD_PATH := "res://mods_builtin/arknights/arknights_mod.gd"

var _failed := 0


func run(a) -> void:
	var Stats = load(STATS_PATH)
	var ModScript = load(MOD_PATH)
	_check(a, "共享契约脚本可加载", Stats != null, STATS_PATH)
	_check(a, "入口脚本可加载", ModScript != null, MOD_PATH)
	if Stats == null or ModScript == null:
		_finish(a)
		return

	# ------------------------------------------------ ① 减免公式
	_check(a, "物理 100-30=70", Stats.reduce_physical(100, 30) == 70, str(Stats.reduce_physical(100, 30)))
	_check(a, "物理 10-30=0（不会倒扣）", Stats.reduce_physical(10, 30) == 0, str(Stats.reduce_physical(10, 30)))
	_check(a, "物理负防御按 0", Stats.reduce_physical(100, -5) == 100, str(Stats.reduce_physical(100, -5)))
	_check(a, "法术 100×80%=80", Stats.reduce_spell(100, 20.0) == 80, str(Stats.reduce_spell(100, 20.0)))
	_check(a, "法术 101×80% 四舍五入=81", Stats.reduce_spell(101, 20.0) == 81, str(Stats.reduce_spell(101, 20.0)))
	_check(a, "法抗 100 = 免疫", Stats.reduce_spell(100, 100.0) == 0, str(Stats.reduce_spell(100, 100.0)))
	_check(a, "法抗超出夹 100", Stats.reduce_spell(100, 150.0) == 0, str(Stats.reduce_spell(100, 150.0)))
	_check(a, "负法抗夹 0", Stats.reduce_spell(100, -20.0) == 100, str(Stats.reduce_spell(100, -20.0)))

	# ------------------------------------------------ ② 伤害类型便签
	var info := DamageInfo.create(null, 10)
	_check(a, "未标记 = 物理", not Stats.is_spell_attack(info))
	Stats.mark_attack(info, Stats.TYPE_SPELL)
	_check(a, "标了 TYPE_SPELL 就是法术", Stats.is_spell_attack(info))
	Stats.mark_attack(info, Stats.TYPE_PHYSICAL)
	_check(a, "标了 TYPE_PHYSICAL 就是物理", not Stats.is_spell_attack(info))

	# ------------------------------------------------ ③ 模组登记与入口
	_check(a, "ModManager 登记了 arknights", ModManager.MOD_SCRIPT_PATHS.has(ModIds.ARKNIGHTS))
	var mod = ModManager.all_mods.get(ModIds.ARKNIGHTS)
	_check(a, "ModManager 创建了模组实例", mod != null)
	if mod == null:
		_finish(a)
		return
	_check(a, "get_mod_id", mod.get_mod_id() == ModIds.ARKNIGHTS, str(mod.get_mod_id()))
	_check(a, "get_mod_name", mod.get_mod_name() == "明日方舟", mod.get_mod_name())
	var cats: Array = mod.get_mod_categories()
	_check(a, "分类 = [OVERRIDE_RULE]",
		cats.size() == 1 and cats[0] == ModCategory.OVERRIDE_RULE, str(cats))
	var detail = mod.create_detail_control()
	_check(a, "模组页面详情可建造", detail != null and detail.get_child_count() > 0)

	# ------------------------------------------------ ④ 修饰器端到端
	var kill := DamageInfo.create(null, 10)
	kill.is_instant_kill = true
	_check(a, "秒杀原样放行", mod.modify_damage(kill) and kill.amount == 10, str(kill.amount))

	var zombie = Global.character_registry.instantiate_zombie(ZombieIds.NORM)
	_check(a, "造得出普通僵尸实例", zombie != null)
	if zombie != null:
		Stats.set_instance_defense(zombie, 50)
		_check(a, "单实例覆盖防御力读得回来", Stats.get_defense(zombie) == 50, str(Stats.get_defense(zombie)))
		var physical := DamageInfo.create(zombie, 100)
		mod.modify_damage(physical)
		_check(a, "物理 100 挨 50 防御 = 50", physical.amount == 50, str(physical.amount))
		var spell := DamageInfo.create(zombie, 100)
		Stats.mark_attack(spell, Stats.TYPE_SPELL)
		mod.modify_damage(spell)
		_check(a, "法抗 0 时法术 100 不减", spell.amount == 100, str(spell.amount))
		Stats.set_instance_spell_resist(zombie, 20.0)
		_check(a, "单实例覆盖法抗读得回来", Stats.get_spell_resist(zombie) == 20.0, str(Stats.get_spell_resist(zombie)))
		var spell2 := DamageInfo.create(zombie, 100)
		Stats.mark_attack(spell2, Stats.TYPE_SPELL)
		mod.modify_damage(spell2)
		_check(a, "法抗 20% 时法术 100 → 80", spell2.amount == 80, str(spell2.amount))
		Stats.clear_instance_stats(zombie)
		_check(a, "清掉覆盖后防御回 0", Stats.get_defense(zombie) == 0, str(Stats.get_defense(zombie)))
		zombie.free()

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[ARKNIGHTS] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
