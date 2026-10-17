<!-- AGENT-DOC: record -->

# 2026-10-16_防具吸收并入process_damage

> **本次任务**：把防具的伤害吸收从 ③ 结算层（`HpComponentZombie.hp_loss()` 遍历 `armor_list` 调 `absorb_damage()`）搬进防具自己的 ② `ArmorComponent.process_damage()`。
> **耗时 / 轮次**：1 轮；编译门禁 ×2、探针 ×2（`probe_armor_component` / `probe_more_armor_mod`，均 PASS）
> **推荐度**：推荐（但**先读下面的「三条语义变化」**再决定要不要照做）

## 目标

原来一次伤害要遍历 `armor_list` **两趟**：②-a 加工包（`process_damage_armors()`）、③ 分血（`hp_loss()` 再遍历一次调 `absorb_damage()`）。
把 ③ 那趟并进 ②：每层防具在自己的 `process_damage()` 里就地扣血，并把 `info.amount` 改写成"走完本层还剩多少"。
`hp_loss()` 只拿剩下的打本体。

## 最简路径（步骤）

1. `src/entities/character/components/armor_component/component_armor.gd` → `process_damage(info)`：
   非秒杀时 `info.amount = absorb_damage(info.mode, info.amount)`；**扣血前后比一次 `curr_hp`**，掉了就 `info.is_armor_absorbed = true`（见第 4 步，必须）。
   `absorb_damage()` / `get_absorb_rule()` **原样保留**（模组靠重写它们做易伤 / 减伤）。
2. `component_hp_zombie.gd` → `process_damage_armors(info)`：进循环前先 `armor.begin_damage_settlement()` 清「挨打」标记，再逐层 `process_damage()`。
   （**顺序反了会在 ③ 把 ② 刚置上的标记清掉** —— 标记是给 `hp_loss()` 末尾补发掉血信号 / 音效用的。）
3. `component_hp_zombie.gd` → `hp_loss(info)`：删掉防具遍历与 `remain`，直接 `if curr_hp > 0 and info.amount > 0: curr_hp -= get_body_damage(mode, info.amount)`。
   `get_body_damage()` 不动（保龄球 / 锤子的固定本体伤害仍靠它）。
4. `src/core/consts/const_damage.gd` + `src/core/damage/damage_info.gd`：新增元信息 `KEY_ARMOR_ABSORBED` / 代理字段 `is_armor_absorbed`；
   `damage_system.gd` 的 `_apply_effect_damage()` 判定改成 `amount <= 0 and not is_instant_kill and not is_armor_absorbed → return false`。
5. `test/scenarios/probe_armor_component.gd`：探针自用的 `_ArmorImmuneBomb.process_damage()` 放行分支改成 `return super(info)`（吸收在父类里，只 `return true` 就永远不掉血）。
6. 模组 `mods_builtin/more_armor/`：三个 `absorb_damage()` 重写**一行逻辑都不用改**（调用点换了，重写点没换），只把注释里的「血量组件正遍历防具链」改成「伤害系统正在 ② 加工阶段遍历防具链」。
7. 文档：`docs/参考存档/防具.md` §3 从「两站」改写为「一站两件事」；`伤害系统.md` 的 §0/§2/§4.2/§4.3/§5/§9.1/§10/§12/§13 同步。
8. 收尾：`powershell -File test/check_scripts.ps1` + 两个探针（**必须 `-Windowed -KillStale`**，见踩坑 3）。

## 弯路 / 踩坑（三段式）

- **试过**：只把吸收搬进 `process_damage()`，没动 `DamageSystem._apply_effect_damage()` 的 `amount <= 0` 早退。
- **因为**：防具吃光一整发（路障 370 挨一发 20 的豌豆）后 `info.amount` 被削成 0 ⇒ `_apply_effect_damage()` 返回 false ⇒ `_apply_effects()` 空 ⇒ `apply()` 提前返回 `canceled(ZeroAmount)`，**`hp_loss()` 根本不会被调**，于是防具的 `signal_armor_hp_loss` / 受击音效 / 血条刷新、以及 `signal_zombie_hp_loss`（波次残半刷新要用）**全都不发**。
- **结论**：给包里加 `is_armor_absorbed`（②-a 由防具置位），③ 靠它把「被防具吃光」和「压根没伤害」分开；两种 `amount == 0` 的放行理由（秒杀 / 被防具吃光）都写进了 `_apply_effect_damage()` 的注释。

- **试过**：`run_autopilot.ps1 -Scenario probe_armor_component` 不带开关直接跑（先 headless 试了一次）。
- **因为**：headless 那趟没产出报告且**留了个不退出的 godot 进程**；紧接着无头/窗口跑都被脚本的 stale 守卫判 `STALE_PROCESS`（`check_scripts.ps1` 跑完也会短暂留一下 godot）。
- **结论**：跑探针一律 `-Windowed -KillStale`；被拦时先确认进程是不是自己的（`Get-Process | Where-Object -Property ProcessName -Match godot`）再决定杀不杀。

## 推荐度与理由

**推荐**：一次遍历把防具链结算完，少了「② 加工 / ③ 分血」两套顺序各自维护、以及"血量组件得认识 `absorb_damage`"这条耦合。

**照做前必须先接受这三条语义变化**（已写进 `防具.md` §3.2 与 `伤害系统.md` §4.2/§10）：

1. **吸收排在修饰器之前**：②-c 的修饰器读到的 `info.amount` 已经是"走完防具剩下的"——「按比例减伤」只作用到打本体那部分，不再影响防具层。要连防具一起吃比例，得写 `absorb_damage()`。
2. **靠里的取消不再退还外层防具血**：本体 / 内层防具 / 修饰器 `return false` 只挡掉更内层与本体；要"整包取消连防具也不掉血"，必须让**最外层**的防具取消。
3. **重写 `process_damage()` 的防具必须 `return super(info)`**：吸收在父类那一步，漏了就是那层永久不掉血且**没有任何报错**。

---

## 补充 / 评价（同日 · 记账与静默面整改）

> **后续记录**：[2026-10-16_伤害管线记账与静默面整改.md](2026-10-16_伤害管线记账与静默面整改.md) ←→ 被补充：本文件

- **补正**：上面那三条语义变化仍然成立，但其中**第 3 条已加护栏** —— 漏 `return super()` 现在会在 debug 构建下被 `_verify_armor_absorbed()`（`HpComponentZombie`）点名，只报不改。另有两处随后被发现并修掉：**取消整包时 `DamageResult` 丢血量快照**（新增 `canceled_with_hp()`）、**保龄球 / 锤子的固定数值散在两处 `match`**（已集中到 `ConstDamage.BOWLING_*` / `HAMMER_ARMOR1`）。
- **评价**：本文件的实现方向不用改。补一条经验：**护栏要加在引擎侧** —— `probe_armor_component` 只能证明「那一层写对了」，证明不了「别人漏了 `super()` 会被发现」。
