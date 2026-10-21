> 封存 2026-10-21，由 已完成（91f3655）；現況見 wf/specs/combat-framework/README.md 取代

# plan：戰鬥框架 Phase 0 基礎重構（已完成 2026-10-19）

[spec](../../specs/combat-framework/README.md)｜[分階段](../../specs/combat-framework/08-phases.md)｜[INDEX](../../INDEX.md)

範圍：spec [Phase 0](../../specs/combat-framework/08a-phase-0.md)。這是純重構，現有遊戲行為與回歸測試的數值契約都不變。程式 commit 為 `91f3655`，本地補丁為 `tools/patches/combat-framework-phase0.patch`（登記在 [upstream.json](../../../tools/upstream.json)）。

## 步驟

[BaseCombatant.gd](../../../game/scripts/combatants/BaseCombatant.gd) 新增 `FACTIONS`、`unit_uid`、`faction`、`board_anchor`、`footprint`、`base_speed`／唯讀 `speed`、`move_range`、`next/last_action_tick`、`action_count`、`controller`，以及 `_on_own_action_started/ended` hook。`_ready()` 會向 Registry 註冊，`tree_exiting` 時取消註冊。Player 屬 PARTY 且 `is_hero()`；Enemy 屬 ENEMY。

新增 [UnitRegistry.gd](../../../game/scripts/combat/UnitRegistry.gd) autoload：依 uid 查單位、依陣營查詢（依場景樹順序）、`get_hero()`。`Global.get_player()` 先取 hero，取不到才退回 players 群組；`get_alive_enemies()` 改走 Registry。

新增 [CombatRulesData.gd](../../../game/data/readonly/CombatRulesData.gd)，並加入 SCHEMA 列 `combat_rules/`。測試資料註冊 `combat_rules_default`；`Global.get_combat_rules()` 在 pack 側寫時退回內建預設。`mod_info.json` 已補上資料夾列。

ActionGenerator 開局抽牌數改讀 `draw_per_action`。能量改讀 `energy_per_action`／`energy_cap`：預設 -1 時，照舊歸零後補滿。

Signals 宣告 spec §3.4 的全部訊號。Combat.gd 在主角回合抽牌後、解鎖手牌前發 `unit_action_started(hero)`；在回合末 POST_DISCARD 後發 `unit_action_ended(hero)`。

## 驗證（2026-10-19 Manjaro，godot-mono 4.7.2）

- Smoke 由 [unit_registry_probe.gd](../../../tests/unit_registry_probe.gd) 驗證，共 36 項：主角註冊與 uid 查詢、PARTY 陣營、預設欄位、規則預設等於原行為、JSON 的 Vector2i 往返，以及 17 個訊號的宣告。test 與 pack 兩種側寫都通過。
- [combat_flow.gd](../../../tests/combat_flow.gd) 的新斷言：第一回合 `unit_action_started(hero)` 發 1 次、第二回合累計 2 次；ended 發 1 次；`action_count` 跟著一致；fixture 敵人是 ENEMY 且可依 uid 查到；敗北路徑的 started 與 ended 各 1 次。原有的 14 傷害、10 格擋、抽 5、能量 3 等斷言不變。
- `python3 tools/test_game.py --suite All` 通過，包含 ResourceLifecycle、Dictionary、Smoke、CombatVictory／Defeat、SaveLoad。pack 側寫的 Smoke 也通過，共 60 checks。
- runner 合成測試 134 項、boundary lint 測試 19 項、new_pack 測試 14 項全部通過。boundary lint 的 violations 為 0，strict 文件 lint 回傳 0。

## 未做／交給 Phase 1

- 敵人的 `unit_action_*`、`end_action_requested` 接線，以及其餘只宣告未發出的訊號。
- `hand_limit`、`discard_hand_on_action_end`、`reset_block_on_action_start` 等規則欄位還沒有消費端。
- `speed` 尚未讀資料欄位：`enemy_speed`／`character_speed` 在 Phase 1 才加入。
- 舊監聽者的遷移（listener-migration.json）尚未開始。
