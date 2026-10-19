# Slay-The-Robot：行動、攔截與模組擴充

[分析入口](../README.md)｜[入門指南](beginner_guide_zh.md)｜[核實紀錄](verification.md)

依上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復核實（2026-10-19）。前置知識為 mod 登記、資料補丁、GDScript 繼承與 signal。以下契約不代表所有自訂機制已通過實測。

## 行動工廠與執行順序

[ActionGenerator.gd](../../../game/autoload/ActionGenerator.gd) `create_actions(parent_combatant, card_play_request, targets, actions_data, parent_action)` 依腳本路徑建立並 `init()` 行動，回傳 `Array[BaseAction]`，不自行執行。

[ActionHandler.gd](../../../game/autoload/ActionHandler.gd) 的 `add_actions()` 預設每個行動各自推入 stack，以 `pop_back()` 反序執行；`enqueue = true` 的 queue 以 `pop_front()` 正序執行。已有 queue／stack 會影響插入位置；`HandManager` 使用預設 stack，編排多段效果須驗順序。

新增同步 action 時繼承 [BaseAction.gd](../../../game/scripts/actions/BaseAction.gd)，覆寫 `perform_action()`，一般流程是 `_intercept_action()` → 逐一處理回傳 processor → 讀取 shadowed values → 套用效果。`get_action_value()` 的優先序為 action values、CardPlayRequest、CardData、玩家 values、預設值；`custom_key_names` 可映射參數名稱。

固定延遲使用 `time_delay`，由 handler 等待；普通 `perform_action()` 自行 await 不會讓 handler 等完。本地 [BaseAsyncAction.gd](../../../game/scripts/actions/BaseAsyncAction.gd) 以 `begin_async_action()` 開始、`finish_async_action()` 完成並清快取。取消先設定 `async_cancelled` 再解除等待，await 恢復後不得執行效果或 child；同步 callback 也可能立即取消，發出請求後須先檢查狀態再 await。直接呼叫會繞過 handler 的等待管理。

processor 現為 RefCounted，回指 action 使用 WeakRef；使用期間必須由呼叫端持有 action，不能保存 processor 後假設 parent 永遠存在。非同步快取、正常完成與取消的實作／驗收見 [資源生命週期](../architecture/05_resource_lifecycle.md)。

## 隨機棄牌：組合既有行動

不存在 `player.hand.discard_random_card()` API。可用 [ActionPickCards.gd](../../../game/scripts/actions/card_actions/pick_card_actions/ActionPickCards.gd) 選牌，再讓 [ActionDiscardCards.gd](../../../game/scripts/actions/card_actions/cardset_actions/ActionDiscardCards.gd) 呼叫 `HandManager.discard_cards()`。將下方物件放入 `card_play_actions`：

```json
{
  "res://scripts/actions/card_actions/pick_card_actions/ActionPickCards.gd": {
    "card_pick_type": "HAND",
    "random_selection": true,
    "min_card_amount": 1,
    "max_card_amount": 1,
    "action_data": [{
      "res://scripts/actions/card_actions/cardset_actions/ActionDiscardCards.gd": {
        "is_manual_discard": true
      }
    }]
  }
}
```

[ActionBasePickCards.gd](../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 的 `perform_action()` 使用玩家的 `rng_card_picking` 隨機選出 `min_card_amount` 張牌；不能將最小值設 0，否則隨機分支會選零張。`ActionPickCards._generate_child_actions()` 傳入父行動，`BaseCardsetAction._get_picked_cards()` 取得所選卡牌。`is_manual_discard` 控制棄牌副作用，不表示一定由玩家選牌。驗證須涵蓋空手牌、最後一張牌及帶棄牌效果的卡。

## 攔截器與狀態效果

完整接線包含腳本、`ActionInterceptorData` 及 `StatusEffectData.status_effect_interceptor_ids`。資料中的 `action_interceptor_script_path` 指定腳本，`action_intercepted_action_paths` 選擇要攔截的行動，`action_interceptor_modifies_parent` 區分來源／目標，priority 決定處理次序。

實例可沿 [測試資料產生器](../../../game/autoload/GlobalTestDataGenerator.gd) 的 `interceptor_vulnerable` 與 `status_effect_vulnerable` 查到 [InterceptorVulnerable.gd](../../../game/scripts/action_interceptors/InterceptorVulnerable.gd)：它攔截 `Scripts.ACTION_ATTACK`、屬於目標端，將傷害乘 1.5 後取整數。

要改成自己的倍率，複製這組實例並使用新 ID，再改倍率與描述；勿只新增腳本或虛構 `action_interceptor_id` 欄位。在 processor 中使用 `get_shadowed_action_values()` 與 `set_shadowed_action_values()`，讓 `custom_key_names` 映射保持一致。若攔截器會產生副作用，必須檢查 `preview_mode`，避免滑鼠預覽卡牌就改變遊戲狀態。

驗證時比較卡牌預覽、敵人意圖及實際傷害，並加入多個攔截器檢查優先序；單看乘法正確不代表接線完成。

## 遺物與 signal

實際範例已存在於 [ArtifactDrawOnKill.gd](../../../game/scripts/artifacts/ArtifactDrawOnKill.gd)，不需要重新發明擊殺抽牌遺物。它覆寫 `connect_signals()`（沒有開頭底線）、監聽 `Signals.enemy_killed(enemy: Enemy)`，確認仍有敵人後產生 `Scripts.ACTION_DRAW_GENERATOR` 與 `{"draw_count": 1}`，並發送 `artifact_proc`。

[BaseArtifact.gd](../../../game/scripts/artifacts/BaseArtifact.gd) 在 `_init(artifact_data)` 呼叫 `connect_signals()`。若自訂遺物要保留基底的回合／戰鬥結束處理，覆寫時呼叫 `super.connect_signals()`；上游擊殺抽牌範例沒有這個呼叫，不能假設它保留全部基底連線。資料透過 `ArtifactData.artifact_script_path` 指向腳本，再經角色起始遺物或取得遺物流程建立實例。

信號名稱以 [Signals.gd](../../../game/autoload/Signals.gd) 為準；沒有 `enemy_died`。驗證至少包含殺死非最後一名敵人、殺死最後一名敵人、移除遺物與重新開局，檢查重複連線或殘留效果。

## 資料補丁與腳本擴充

上游固定 commit 的普通 JSON Dictionary 合併會丟掉原有欄位，原始缺陷見 [啟動驗證](../architecture/03_startup_validation.md)。本專案已修正 [SerializableData.gd](../../../game/data/SerializableData.gd) `set_serializable_properties()`，寫回 `patch_dictionary()` 的計算結果。若只修改 `card_values` 中的 `damage`，目前可使用 `merge_overwrite` 保留其他頂層 key；`merge_keep` 則保留既有同名 key，只補入新 key。這是本地修復，重新取得原版 checkout 不會自動包含它。

`patch_dictionary()` 支援 `merge_overwrite`、`merge_keep`、`erase`、`overwrite`。`merge` 不是支援值，未知策略仍走 overwrite；Dictionary 也沒有 append。合併只處理頂層 key，子字典不遞迴合併。Array 的 `append`／`append_uniques`／`erase`／`overwrite` 是另一分支。

[dictionary_regression.gd](../../../tests/dictionary_regression.gd) 經公開 JSON patch API 驗字典策略、typed Dictionary 與 Array；修前 47 項中 8 項失敗、修後全過，見 [回歸驗證](../architecture/04_regression_validation.md)。不涵蓋所有巢狀型別或自訂卡牌實戰，新內容仍需驗載入與效果。

基本攻擊 ID 是 `card_attack_basic`，不是舊教學的 `card_strike`；由 [GlobalTestDataGenerator.gd](../../../game/autoload/GlobalTestDataGenerator.gd) `add_test_cards()` 核對，再驗載入結果。

新增腳本可採專案內 `res://` 路徑，或使用模組的 `mod_script_file_paths` 登記外部腳本。[FileLoader.gd](../../../game/autoload/FileLoader.gd) `load_read_only_data()` 先載入腳本，非空的目標路徑會呼叫 `take_over_path()`；這會影響後續相同路徑的 `load()`。獨立內容優先使用新路徑，真正要替換框架行為才配置既有路徑。

## 除錯與驗收

實際記錄 API 是 [DebugLogger.gd](../../../game/autoload/DebugLogger.gd) 的 `log_line(message, color, severity)`、`log_warning()`、`log_error()`。可呼叫 `DebugLogger.log_line("自訂行動執行", Color.CYAN)`；沒有 `log_message()` 或 `LOG_CHANNELS.ACTIONS`，也不能據此宣稱存在內建分頻日誌面板。

擴充後以固定牌組或遺物驗載入與目標行為；記錄順序、攔截及非同步結果。依 [testing](../../../wf/workflows/testing.md) 執行必要檢查，區分已驗與待測。
