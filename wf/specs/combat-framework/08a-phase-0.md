# 分階段計畫（§5）：Phase 0 基礎重構

[README](README.md)｜[分階段索引](08-phases.md)

## Phase 0：基礎重構——combatant 抽象化、單位註冊表、規則物件

可玩：與現在完全相同。

### 改動

`BaseCombatant.gd`（+unit_uid/faction/footprint/speed/move_range/anchor/controller 欄位與 `_on_own_action_*` hook）；新 `game/scripts/combat/UnitRegistry.gd`（autoload 或 CombatDirector 子物件：uid→節點、依陣營查詢、`get_hero()`）；`Global.get_player()` 改委派 Registry（= hero）；新 `CombatRulesData.gd` + SCHEMA 列 + `GlobalTestDataGenerator` 註冊 `combat_rules_default`（預設＝現行值）；`ActionGenerator.generate_start_of_turn_draw_actions`／`generate_start_of_turn_energy_actions` 的抽牌數／能量改讀 rules；`Signals.gd` 新增 §3.4 訊號（先只宣告 + 在舊流程中於對應時點**同時**發出 `unit_action_started/ended(hero)`）；`FileLoader._generate_base_mod_data()` 重跑更新 `external/data/mod_info.json`。

**修訂（實作 Phase 0）**：UnitRegistry 落在 `game/scripts/combat/UnitRegistry.gd` 並登記為 autoload；`Global.get_alive_enemies()` 也改委派 Registry（依場景樹順序，結果同原群組查詢）；`controller` 暫型別為 RefCounted（BaseUnitController 在 Phase 4 才有）；speed 拆為 `base_speed` + 唯讀 `speed`／`get_speed()`；訊號參數涉及尚未存在的類別（PartyMemberData、AiPlan）先不標型別；`Global.get_combat_rules()` 在 pack 側寫（不跑 GlobalTestDataGenerator）退回內建預設物件；`mod_info.json` 以手動加入 `combat_rules/` 列（與 `_generate_base_mod_data()` 輸出同格式）代替重跑；舊流程只對主角發 `unit_action_*`，敵人版留 Phase 1。

### 規模與風險

規模：~500 行；10 檔。

風險：低；SCHEMA 新類別要確認 `SerializableData.build_serializable_script_cache()` 掃得到（`Global._ready` 呼叫它）。

### Done when

V1–V3 全綠、`--suite All` 綠；新 `tests/unit_registry_probe.gd` 由 Smoke 呼叫：hero 註冊、faction 正確、`combat_rules_default` 可讀、`unit_action_started` 在舊回合開始時發出一次

**修訂**：Smoke 不開局，故「`unit_action_started` 在舊回合開始時發出一次」改由 `combat_flow.gd`（CombatVictory／Defeat）斷言，probe 只驗註冊、陣營、規則與訊號宣告；實際驗收見 [phase-0 plan](../../plans/combat-framework/phase-0.md)。

### agent

普通（opus）
