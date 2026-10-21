# code-map／每場戰鬥準備

[戰鬥框架](combat-framework.md)｜[每場準備分析](../../../../analysis/slay-the-robot/architecture/08_combat_preparation.md)

每場準備入口為 [PreparedEncounter.gd](../../../../game/scripts/combat/PreparedEncounter.gd)：單次取得遭遇、深複製 Event／Rules／Encounter 作者資料，供 Combat 裝配與 Director 共用；Director 是 active prepared 唯一 owner。Global 區分當場規則 `get_combat_rules` 與下場配置 `get_configured_combat_rules`；停止後回配置。核實與邊界見 [每場準備](../../../../analysis/slay-the-robot/architecture/08_combat_preparation.md)，Smoke 專項在 [prepared_encounter_probe.gd](../../../../tests/prepared_encounter_probe.gd)，直接開戰與停止後重掛在 [prepared_start_cases.gd](../../../../tests/prepared_start_cases.gd)（DualBoard）。

## 裝配與執行接點

[Combat.gd](../../../../game/scripts/ui/Combat.gd) 在開戰時準備資料並組裝可選模組，未開場的 `_ready` 不猜測本場能力；`compose_combat_module` 是通用場景接點，舊 `_compose_board_module` 保留相容轉送。

[CombatDirector.gd](../../../../game/scripts/combat/CombatDirector.gd) 的 `begin_prepared_combat` 消費準備結果，`begin_combat(event)` 是相容入口；`_stop` 同時失效 active prepared 與 generation。場景只查詢 Director 的當前準備結果，避免停止後殘留另一份狀態。

[CombatStartActions.gd](../../../../game/scripts/combat/CombatStartActions.gd) 使用 Director 的 Event 快照建立初始 actions；[Global.gd](../../../../game/autoload/Global.gd) 的遭遇查找／合成可接明確規則，配置與當場規則讀取分開。費用、抽牌與結算仍由原有核心 owner 執行；詳細邊界與實際測試結果沿上方分析，不由本導航另定規格。
