extends RefCounted
class_name ConsoleBuiltinEntries
## 控制台的内置条目：本体自带的开关全都搬到这里，一条一行
##
## 为什么单独一个文件：注册表（`ConsoleRegistry`）与面板都不该认识「自动收集阳光」这种
## 具体选项，加 / 删一个内置开关只改这里。由 `ConsoleRegistry._ready()` 调 `register_all()`。
##
## ⚠️ 本文件在 `Global` 的 @onready 之前就跑完了，所以**不要在登记时读 `Global.config_service`** ——
##    一律写进 lambda 里，等面板真的取值时才去读。
##
## 关联：[控制台](../../../docs/参考存档/控制台.md) ｜ ConsoleEntry ｜ ConsoleRegistry


## 自动类
const CATEGORY_AUTO := "自动"
## 显示 / 界面类
const CATEGORY_DISPLAY := "显示"
## 调试类
const CATEGORY_DEBUG := "调试"


## 登记全部内置条目（[param registry] 是 `ConsoleRegistry`，这里刻意不写类型避免循环引用）
static func register_all(registry) -> void:
	if registry == null:
		return
	_register_auto_entries(registry)
	_register_display_entries(registry)
	_register_debug_entries(registry)


#region 三组内置条目
static func _register_auto_entries(registry) -> void:
	_add(registry, ConsoleEntry.create_toggle(&"auto_collect_sun", "自动收集阳光")
		.set_tooltip("掉落的阳光不用手动点，自动收取")
		.set_category(CATEGORY_AUTO)
		.set_order(10)
		.bind(func() -> bool: return Global.config_service.auto_collect_sun,
			func(value: bool) -> void: Global.config_service.auto_collect_sun = value))

	_add(registry, ConsoleEntry.create_toggle(&"auto_collect_coin", "自动收集金币")
		.set_tooltip("掉落的金币不用手动点，自动收取（功能未实现，仅占位）")
		.set_category(CATEGORY_AUTO)
		.set_order(20)
		.bind(func() -> bool: return Global.config_service.auto_collect_coin,
			func(value: bool) -> void: Global.config_service.auto_collect_coin = value))

	_add(registry, ConsoleEntry.create_toggle(&"track_bullet_mouse", "追踪子弹跟随鼠标")
		.set_tooltip("追踪类子弹没有目标时，改为追着鼠标飞")
		.set_category(CATEGORY_AUTO)
		.set_order(30)
		.bind(func() -> bool: return Global.config_service.track_bullet_mouse,
			func(value: bool) -> void: Global.config_service.track_bullet_mouse = value))


static func _register_display_entries(registry) -> void:
	_add(registry, ConsoleEntry.create_toggle(&"fullscreen", "游戏全屏")
		.set_tooltip("在全屏与窗口之间切换")
		.set_category(CATEGORY_DISPLAY)
		.set_order(10)
		.bind(func() -> bool:
			return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
			func(value: bool) -> void: DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if value
				else DisplayServer.WINDOW_MODE_WINDOWED)))

	_add(registry, ConsoleEntry.create_toggle(&"display_plant_HP_label", "显示植物血量")
		.set_tooltip("在每个植物头顶显示当前血量")
		.set_category(CATEGORY_DISPLAY)
		.set_order(20)
		.bind(func() -> bool: return Global.config_service.display_plant_HP_label,
			func(value: bool) -> void: Global.config_service.display_plant_HP_label = value))

	_add(registry, ConsoleEntry.create_toggle(&"display_zombie_HP_label", "显示僵尸血量")
		.set_tooltip("在每个僵尸头顶显示当前血量")
		.set_category(CATEGORY_DISPLAY)
		.set_order(30)
		.bind(func() -> bool: return Global.config_service.display_zombie_HP_label,
			func(value: bool) -> void: Global.config_service.display_zombie_HP_label = value))

	_add(registry, ConsoleEntry.create_toggle(&"fog_is_static", "静态浓雾")
		.set_tooltip("关卡有浓雾时，改用静态浓雾（关掉 = 动态浓雾）")
		.set_category(CATEGORY_DISPLAY)
		.set_order(40)
		.bind(func() -> bool: return Global.config_service.fog_is_static,
			func(value: bool) -> void: Global.config_service.fog_is_static = value))

	_add(registry, ConsoleEntry.create_toggle(&"disappear_spare_card_placeholder", "隐藏未选择植物卡槽")
		.set_tooltip("选的植物卡片没填满卡槽时，把多出来的空卡槽隐藏")
		.set_category(CATEGORY_DISPLAY)
		.set_order(50)
		.bind(func() -> bool: return Global.config_service.disappear_spare_card_Placeholder,
			func(value: bool) -> void:
				Global.config_service.disappear_spare_card_Placeholder = value))

	_add(registry, ConsoleEntry.create_toggle(&"card_slot_top_mouse_focus", "焦点卡槽自动置顶")
		.set_tooltip("鼠标移到卡槽上时把该卡槽置顶，避免被其它 UI 挡住")
		.set_category(CATEGORY_DISPLAY)
		.set_order(60)
		.bind(func() -> bool: return Global.config_service.card_slot_top_mouse_focus,
			func(value: bool) -> void: Global.config_service.card_slot_top_mouse_focus = value))

	_add(registry, ConsoleEntry.create_toggle(&"plant_be_shovel_front", "预铲除植物置顶")
		.set_tooltip("铲子指向某株植物时把它高亮并置顶，方便看清要铲的是哪一株")
		.set_category(CATEGORY_DISPLAY)
		.set_order(70)
		.bind(func() -> bool: return Global.config_service.plant_be_shovel_front,
			func(value: bool) -> void: Global.config_service.plant_be_shovel_front = value))


static func _register_debug_entries(registry) -> void:
	_add(registry, ConsoleEntry.create_toggle(&"open_all_level", "开放所有关卡")
		.set_tooltip("解锁全部分支模式（迷你 / 解谜 / 生存）关卡，以及主菜单的花园 / 图鉴 / 商店入口；" +
			"冒险模式没有选关界面、按进度只能打下一关，不受本开关影响（要跳关用「通关所有冒险关卡」）")
		.set_category(CATEGORY_DEBUG)
		.set_order(10)
		.bind(func() -> bool: return Global.config_service.open_all_level,
			func(value: bool) -> void: Global.config_service.open_all_level = value))
#endregion


## 统一走这里登记：内置条目的登记方一律标记成 `builtin`
## （这里写字面量而不是 `ConsoleRegistry.SOURCE_BUILTIN`，是为了不让「注册表 → 内置条目 → 注册表」
##  形成全局类的循环引用；两处值一致，改的时候一起改）
static func _add(registry, entry: ConsoleEntry) -> void:
	registry.register_entry(entry, &"builtin")
