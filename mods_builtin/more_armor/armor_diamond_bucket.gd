extends ArmorComponent
## 「更多的防具」模组：钻石桶那一层防具 —— **受击 20 次触发变身信号**
##
## 铜桶（下界合金）的特殊点都在伤害结算上（易伤 / 减伤），可以直接在 `absorb_damage()`
## 里改；钻石桶的特殊点在「累计挨打次数」上 —— 这个数跟结算无关，所以另存一个计数、
## 满 `TRANSFORM_HIT_COUNT` 次就发个 `sig_need_transform` 信号给宿主。
## 宿主在**结算结束之后**（`call_deferred`）把整层防具换成下界合金桶那层、贴图也换、
## hp 接着用 —— 不能在 `absorb_damage()` 里直接换：此刻伤害系统正在 ② 加工阶段
## 遍历防具链（`HpComponentZombie.process_damage_armors()`）。
##
## ★ 计数只算「打到活着的本层防具的命中」：
##   · 桶已经破的命中不计（没东西可继承）；
##   · 本次没掉血（remain <= 0）不计；
##   · 已触发过变身的命中不计（旧层防具即将被摘掉）。
## 把「第 20 击是破桶那一下」也算上：触发后再让宿主判活不活，不活就跳过变身。
##
## 关联：[防具](../../../../docs/参考存档/防具.md) ｜ [模组机制 §6.3](../../../../docs/参考存档/模组机制.md) ｜ ArmorComponent

## 挨打多少次就该变下界合金桶
const TRANSFORM_HIT_COUNT := 20

## 告诉宿主「该换桶了」—— 宿主用 `call_deferred` 接收（不能在结算途中换）
signal sig_need_transform

## 累计挨打次数（打到本层防具的 hit）
var hit_count := 0
## 是否已触发过变身：防止同一层防具反复触发
var _transformed := false


func absorb_damage(mode: ConstDamage.E_DamageMode, remain: int) -> int:
	## `was_alive` 在父类**之前**拍一张：本层「命中时刻」是否还活着 —— 即便这一击把它打没了
	var was_alive := is_alive()
	var passed := super.absorb_damage(mode, remain)
	## 触发过 / 本层破的命中 / 本次没掉血：都不计
	if _transformed or not was_alive or remain <= 0:
		return passed
	hit_count += 1
	if hit_count >= TRANSFORM_HIT_COUNT:
		_transformed = true
		sig_need_transform.emit()
	return passed
