# 擴充方式與已核實限制

[分析入口](../README.md)｜[架構總覽](01_overview.md)

核實日期：2026-10-19；上游基準 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復。以下區分程式契約與實測；教學自訂內容不視為已通過測試。

## 先從資料組合既有能力

[CardData.gd](../../../game/data/prototype/CardData.gd) 提供 `card_values`、`card_play_actions`、抽牌／棄牌／回合等 actions、出牌與發光 validators、升級及 decorator 欄位。新增卡牌可由 GDScript 建物件後 `Global.register_rod()`，或透過已啟用 mod 的 cards 資料夾載入 JSON。JSON 格式必須看 [example_mod 的卡牌](../../../game/external/mods/example_mod/cards/card_modded_card.json)：最外層為 `properties`／`patch_data`，action 字典以完整腳本路徑為 key。

加入資料表不等於一定能抽到卡。[CharacterData.gd](../../../game/data/readonly/CharacterData.gd) 的 `character_starting_card_object_ids` 決定起始牌組，`character_starting_card_draft_card_pack_ids` 決定可用 card packs；pack 的 filters 與卡牌 `card_appears_in_card_packs` 也會影響篩選。[Global.gd](../../../game/autoload/Global.gd) `_generate_card_pack_cache()` 在載入資料後執行，開發時改資料以重新啟動驗證最直接。

新增敵人要同時處理 [EnemyData.gd](../../../game/data/prototype/EnemyData.gd)、內嵌 [EnemyIntentData.gd](../../../game/data/readonly/embedded/EnemyIntentData.gd) 及將其納入遭遇的 [EventData.gd](../../../game/data/readonly/EventData.gd)；事件池／章節再控制可出現位置。只放一份敵人 JSON 不會自動生成遭遇。可對照生成器的 `add_test_enemies()`、`add_test_events()`、`add_test_acts()`。

## 需要新規則時擴充 action

新 action 繼承 [BaseAction.gd](../../../game/scripts/actions/BaseAction.gd)，覆寫 `perform_action()`，由 ActionGenerator 的 `create_actions()` 動態載入。`Scripts.gd` 是腳本路徑常數的便利入口，不是固定的 action 類別註冊表。新增路徑常數有助維護，但 JSON 直接使用完整路徑亦可。

一般可攔截 action 應以 `_intercept_action()` 取得各目標的 processor，再從 `get_shadowed_action_values()` 讀參數。參考 [ActionAttack.gd](../../../game/scripts/actions/combatant_actions/ActionAttack.gd)；正常攻擊常由 [ActionAttackGenerator.gd](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 生成逐擊 action，包含次數與動畫處理，不能把直接呼叫 `target.damage()` 當成完整攻擊管線。

`BaseAction.get_action_value()` 實際優先序是 action.values → CardPlayRequest.card_values → CardData.card_values → PlayerData.player_values → 呼叫端預設值；`custom_key_names` 可改用另一個 key。攔截器提供更高層的 shadow values。直接讀 `values["damage"]` 會繞過這些能力。

排程採 LIFO：假設同次 `add_actions([A, B])` 且未 enqueue，B 先於 A。卡牌的 action 陣列亦受此規則影響；見 [HandManager.gd](../../../game/autoload/HandManager.gd) `_play_card()` 將「完成 action」放在陣列前端，讓它最後執行。需要抽牌後才依手牌數計傷害時，務必先驗證實際執行序。

需等待選牌／輸入的動作繼承 [BaseAsyncAction.gd](../../../game/scripts/actions/BaseAsyncAction.gd)。本地版本以 `begin_async_action()` 重設狀態、`finish_async_action()` 完成並清除快取；覆寫取消時先設定 `async_cancelled` 再解除等待，await 恢復後禁止套用效果或新增 child。單靠 `time_delay` 不能取代等待輸入。所有權與回歸狀態見 [資源生命週期](05_resource_lifecycle.md)。

## 攔截、狀態與條件驗證

[ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd) 依父戰鬥者／目標已註冊 IDs、ActionInterceptorData 指定的 action 腳本路徑及 modifies_parent 選出攔截器，再按 priority 由大到小執行；同 priority 依 object_id 反向比較。`STOPPED` 停止後續攔截但保留本目標，`REJECTED` 則捨棄該目標的結果。只有 action 主動呼叫 `_intercept_action()` 才有此管線。

[BaseActionInterceptor.gd](../../../game/scripts/action_interceptors/BaseActionInterceptor.gd) 的介面是 `process_action_interception(processor, preview_mode)`。預覽也會走攔截鏈，凡扣層數、抽牌或新增 action 等副作用都必須區分 preview_mode；不能只驗證實戰傷害而忽略卡面／敵方意圖預覽。

一般狀態先用 [StatusEffectData.gd](../../../game/data/readonly/StatusEffectData.gd) 配置 process actions、interceptor IDs、衰減與層數；複雜行為才延伸 [BaseStatusEffect.gd](../../../game/scripts/status_effects/BaseStatusEffect.gd)。[BaseCombatant.gd](../../../game/scripts/combatants/BaseCombatant.gd) 的 `_create_status_effect()`／`_remove_status_effect()` 管理腳本與攔截器生命週期。遺物同理：ArtifactData 提供事件 actions，特殊監聽才延伸 [BaseArtifact.gd](../../../game/scripts/artifacts/BaseArtifact.gd) 的 `connect_signals()`。

[Global.gd](../../../game/autoload/Global.gd) 的 `validate()` 將 validator 字典轉成腳本，任一失敗即 false；[BaseValidator.gd](../../../game/scripts/validators/BaseValidator.gd) 子類覆寫 `_validation()`，wrapper 支援 `invert_validation`。卡的 `card_play_validators` 控制可否出牌；[ActionValidator.gd](../../../game/scripts/actions/meta_actions/ActionValidator.gd) 是已進入 action 後的 if/else，不會阻止使用者出牌。其 `_validate()` 直接讀 `card_play_request.card_data`，不能假設傳 null request 也安全。

## Mod 與 patch_data 的真實邊界

[mod_list.json](../../../game/external/mod_list.json) 預設只啟用 `external/`，example_mod 為 false。[ModListData.gd](../../../game/data/readonly/modding/ModListData.gd) 按 `load_priority` 升序載入，高值較晚套用；未定義同優先序的內容衝突規則。每個啟用項目的 `mod_info.json` 指定資料夾、class_name、table_name 與 script overrides。新資料夾要列入此映射，不能只在磁碟建立資料夾。

[FileLoader.gd](../../../game/autoload/FileLoader.gd) `load_read_only_data()` 找同 object_id 既有物件再 patch；沒找到則 new。`mod_script_file_paths` 可用 `take_over_path()` 替換腳本，屬可執行程式擴充。`validate_enabled_mod_dependencies()` 目前只是 TODO，不應宣稱已驗證 mod 相依性。

[SerializableData.gd](../../../game/data/SerializableData.gd) `patch_dictionary()` 支援 `merge_overwrite`、`merge_keep`、`erase`、`overwrite`；**沒有 `merge` 策略**，未知策略會走 overwrite。`patch_array()` 支援 `append`、`append_uniques`、`erase`、`overwrite`。數值沒有 add 策略；巢狀 SerializableData／原生型別的還原分支會直接重建，不代表所有欄位都支援合併。

原版的 [啟動驗證](03_startup_validation.md) 重現 Dictionary 缺陷：JSON 普通 Dictionary 分支算出 `patched_dictionary` 卻寫回 `temp_value`。本專案已在 `SerializableData.gd:320` 修正寫回值，上游 commit 仍保留原缺陷。

[dictionary_regression.gd](../../../tests/dictionary_regression.gd) 經公開 JSON patch API 的同測為修前 47 checks／8 failures、修後 47／0；策略、typed Dictionary、輸入不變與 Array 邊界見 [回歸驗證](04_regression_validation.md)。

合併是淺合併：`merge_keep` 保留衝突 key 舊值，`merge_overwrite` 以新值取代，子字典整個處理。這不保證 embedded／原生型別還原也支援合併。官方 [character_red.json](../../../game/external/mods/example_mod/characters/character_red.json) 的陣列 append 維持原行為。

## 本專案下一步建議

先建獨立 mod，以一張新卡及起始牌組 append 驗載入、出牌、預覽及存讀，再加敵人／事件。action 或序列化修改分開驗證並保留上游基準；畫面驗收依有效授權執行。
