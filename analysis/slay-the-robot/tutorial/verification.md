# 教學核實紀錄

[分析入口](../README.md)｜[入門指南](beginner_guide_zh.md)｜[進階指南](senior_guide.md)

2026-10-19，依本機 `game/` 的 Slay-The-Robot commit `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`，逐項對照從 PAS 移入的兩篇教學。本文保留最初靜態核實及後續更正；遊戲啟動與互動驗收以專案測試紀錄為準。沒有將教學示範 mod 安裝進原始框架。

## 已保留且補足的觀念

Action／Validator／Interceptor 分工、`card_values`、卡牌類型 enum、起始牌組 `append` 補丁均有對應實作。JSON 外部資料確實能新增或補丁既有物件；但框架也在 GDScript 產生測試內容。將「所有內容都在 JSON」改為兩條內容來源，並補齊模組資料夾登記、載入順序及重新開局條件。

依據：[Global.gd](../../../game/autoload/Global.gd) `_ready()`、[FileLoader.gd](../../../game/autoload/FileLoader.gd) `load_read_only_data()`、[CardData.gd](../../../game/data/prototype/CardData.gd) 的 exported properties。

## 入門指南的實質更正

攻擊產生器不在 `meta_actions/`，實際為 `combatant_actions/ActionAttackGenerator.gd`。抽牌產生器位於 `combatant_actions/player_actions/ActionDrawGenerator.gd`，參數是 `draw_count`，不是 `draw_amount`。重擊範例改用真實路徑、明確目標選取及獨立 mod；保留原有紅色卡圖的有效路徑。

依據：[Scripts.gd](../../../game/autoload/Scripts.gd) `ACTION_ATTACK_GENERATOR`／`ACTION_DRAW_GENERATOR`；兩個 action 的 `perform_action()`。

移除無效的簡化敵人 JSON：`enemy_attack_states` 不是 `EnemyData` 欄位，敵人使用 `enemy_intents` 與 `EnemyIntentData` 的權重圖。生成血量受上下界與難度修正影響。新增敵人資料夾也必須登記，且敵人需由戰鬥事件引用才會出現。

依據：[EnemyData.gd](../../../game/data/prototype/EnemyData.gd) `add_intent_state()`／`apply_enemy_difficulty_modifiers()`；[GlobalTestDataGenerator.gd](../../../game/autoload/GlobalTestDataGenerator.gd) `add_test_enemies()`。

## 進階指南的實質更正

刪除虛構的 `player.hand.discard_random_card()`，改為既有選牌行動搭配棄牌子行動。固定延遲由 `ActionHandler` 管理，非同步 action 必須遵守完成訊號契約。補充預設 action stack 反序與 enqueue queue 的差別，避免將動作陣列當成一般正序清單。

依據：[ActionBasePickCards.gd](../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) `perform_action()`；[ActionDiscardCards.gd](../../../game/scripts/actions/card_actions/cardset_actions/ActionDiscardCards.gd) `perform_action()`；[ActionHandler.gd](../../../game/autoload/ActionHandler.gd) `add_actions()`／`_perform_actions()`。

移除不完整的雙倍傷害模板，改沿易傷實例說明攔截器腳本、資料與狀態的完整接線。以 setter 更新 shadowed values，避免漏掉自訂參數映射；狀態欄位是 `status_effect_interceptor_ids`。

依據：[ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd) `set_shadowed_action_values()`；[StatusEffectData.gd](../../../game/data/readonly/StatusEffectData.gd)。

擊殺遺物的正確方法為 `connect_signals()`，信號是 `enemy_killed`，抽牌參數為 `draw_count`。上游已存在完整 [ArtifactDrawOnKill.gd](../../../game/scripts/artifacts/ArtifactDrawOnKill.gd)，並檢查仍有敵人；原稿的 `_connect_signals()` 與 `enemy_died` 均無對應 API。

`patch_data` 的 `merge` 不被支援，會落入 overwrite；原始碼雖定義 `merge_overwrite`／`merge_keep`，但後續 runtime 已重現載入時丟掉原有 key 的缺陷，因此移除局部 Dictionary 合併的操作範例，改為完整 overwrite 或新卡，並以真實 ID `card_attack_basic` 取代 `card_strike`。logger 改為 `log_line()`，刪除不存在的 `LOG_CHANNELS` 和分頻日誌面板說法。

依據：[SerializableData.gd](../../../game/data/SerializableData.gd) `patch_dictionary()`／`patch_array()`；[DebugLogger.gd](../../../game/autoload/DebugLogger.gd)。

## 後續更正：本地 Dictionary 修復（2026-10-19）

前述移除局部合併範例，是當時原版缺陷下的處理。其後本專案將 [SerializableData.gd](../../../game/data/SerializableData.gd) `set_serializable_properties()` 普通 JSON Dictionary 分支的寫回值由 `temp_value` 改為 `patched_dictionary`，進階指南已同步目前可用的合併契約。上游 commit 未改變；本地 checkout 包含這一行修復。

已核對 [dictionary_regression.gd](../../../tests/dictionary_regression.gd) 與 `artifacts/dictionary-regression/red.log`、`green.log`：同一公開 JSON patch 回歸在未修版本為 47 checks／8 failures／exit 1，修復後為 47／0／exit 0；隔離 Smoke 為 43／0。完整證據與執行方式見 [回歸驗證](../architecture/04_regression_validation.md)。

回歸涵蓋 merge_keep、merge_overwrite、erase、overwrite、預設／未知策略 fallback、空字典與 null、淺層子字典取代、舊字典及輸入不變、typed Dictionary 型別與 JSON 往返，並確認 Array 策略維持原行為。`merge` 仍非有效策略；此修復不增加遞迴深合併，也未驗證所有 embedded／原生型別分支或教學自訂卡牌實戰。

## 後續更正：行動生命週期（2026-10-19）

進階指南同步本地 `begin_async_action()`／`finish_async_action()`、取消旗標與同步 callback 的檢查順序。processor 改 RefCounted 與弱回指，使用期間仍須有 action owner；不能把弱參照當成安全保留已銷毀來源的方式。正常／拒絕／預覽、非同步與取消的修前修後證據見 [05 資源生命週期](../architecture/05_resource_lifecycle.md)，完整自訂機制仍需針對性驗收。

## 驗證邊界

兩篇文件的 JSON 程式區塊可作語法檢查；原始碼連結、action 路徑與引用的函式／欄位已對照本機版本。示範行為仍須依各篇「驗證」段實際操作，尤其空手牌、最後一名敵人、多 action 順序及攔截器預覽。不得把文件連結檢查或原版能啟動，當作自訂內容已通過遊戲測試。

主選單、角色資料、Array append 與官方 example_mod 已有 [執行證據](../architecture/03_startup_validation.md)；上述更正後自訂卡牌範例仍未逐一實玩。
