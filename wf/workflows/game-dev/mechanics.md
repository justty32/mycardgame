# mechanics — 規則與執行機制

[遊戲開發入口](README.md)｜[驗收分流](validation.md)｜[資源生命週期](resource-lifecycle.md)｜[testing](../testing.md)

**何時用**：新增／修正 actions、validators、interceptors、狀態、回合、RNG、序列化或載入機制。

**何時不用**：現有原語能表達的內容走 [content](content.md)；只改展示或輸入接線走 [ui](ui.md)；行為不變的拆檔走 refactor。

## Done when

需求有可重現輸入與可觀察結果；順序、等待／取消、預覽與受影響資料契約有證據。修 bug 的 regression 在舊行為失敗、修正後通過，並同步必要基準、文件及 code map；文件 lint 通過（見 [testing](../testing.md#文件檢查修改後必跑)）。

## 先讀來源

讀 [ActionGenerator.gd](../../../game/autoload/ActionGenerator.gd) `create_actions()`、[ActionHandler.gd](../../../game/autoload/ActionHandler.gd) `add_actions()`／`_perform_actions()`，再按改動讀 [BaseAction.gd](../../../game/scripts/actions/BaseAction.gd)、[BaseAsyncAction.gd](../../../game/scripts/actions/BaseAsyncAction.gd)。參數名稱以實際 action 讀值處為準，常數位置見 [Scripts.gd](../../../game/autoload/Scripts.gd)。

攔截與條件走 [ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd)、[ActionInterceptorData.gd](../../../game/data/readonly/ActionInterceptorData.gd)、[BaseValidator.gd](../../../game/scripts/validators/BaseValidator.gd)。狀態接線看 [StatusEffectData.gd](../../../game/data/readonly/StatusEffectData.gd) 及實際狀態腳本。只有改到資料生命週期才讀 [SerializableData.gd](../../../game/data/SerializableData.gd)、[PlayerData.gd](../../../game/data/prototype/PlayerData.gd) 與 [Random.gd](../../../game/autoload/Random.gd)。

## 操作流程

先以 `rg` 查呼叫者、JSON／產生器引用及訊號訂閱者。用一個具體例子記錄期望：何時觸發、來源與目標、數值、執行先後、可取消條件、需要保存的狀態。若既有 action 組合已能表達，就沿用原語，不為一張卡增加通用框架。

新增原語時按同類實作接 `ActionGenerator` 的 `init()` 契約，處理可能為 null 的 parent／card／target。需要被加成或拒絕的效果經 `_intercept_action()`，從 processor 取值；不要先改動世界再驗證。參數層級及 `custom_key_names` 都由既有讀值 API 處理，避免另寫一套優先序。

最短接線是新腳本繼承 BaseAction、覆寫 `perform_action()`，內容以完整腳本路徑為 key。`create_actions(parent, request, targets, actions_data, parent_action)` 只建立並 init；回傳值交 `ActionHandler.add_actions()` 才執行。Scripts 常數是便利入口，不是必填註冊表。若新增 action 仍讀現有 CardData 欄位，不須改 schema。讀值的 CardData 分支會在缺 key 時直接回 default，細節見 [擴充契約](../../../analysis/slay-the-robot/architecture/02_extension_points.md)，不可假設必然回落 player_values。

### 順序與等待

預設 `add_actions([A, B])` 將每個 action 推成獨立 queue，stack 的 `pop_back()` 使 B 先於 A；`enqueue = true` 使用 queue，queue `pop_front()` 保持加入順序。已有 stack／current queue 時須追蹤實際插入位置，測試子行動與完成 sentinel；勿只換陣列順序就宣稱所有情境已正確。

固定延遲用 `time_delay`；普通 action 內的 `await` 不會自動讓 handler 等完。需要等待時沿用 BaseAsyncAction，其開始／完成／取消契約與驗法（含同步 callback 立即取消、不得繞過 handler）見 [資源生命週期的非同步與快取](resource-lifecycle.md#非同步與快取)；新增 processor、回指或 async cache 時，同檔追蹤強參照與釋放出口，驗正常、拒絕、取消及預覽路徑。

### 攔截與 validators

核對攔截腳本、被攔截 action 路徑、來源／目標端及 priority。以 `set_shadowed_action_values()` 寫入，保留自訂 key 映射。`preview_mode` 下不得消耗充能、抽 RNG、改牌組或送出有遊戲效果的訊號；重複預覽前後比較狀態，再比較一次真正執行的結果。

預覽也不能回 REJECTED（Card 描述直接取 processor `[0]`）。何時需要 `card_description_preview_overrides`、非空陣列取代預設表、空 payload／null 目標與未被消費的第三欄，見 [卡面預覽契約](../../../analysis/slay-the-robot/design/cards.md#卡面攔截預覽的消費端契約)；專項驗無缺鍵／空結果、基礎／升級／加成顯示及狀態不變。

只有 ActionInterceptorData 入表還不會生效。狀態用 `StatusEffectData.status_effect_interceptor_ids`，由 [BaseCombatant](../../../game/scripts/combatants/BaseCombatant.gd) 在首次建立／最後移除時註冊／撤銷；其他 owner 須追到 `ActionHandler.register_action_interceptor(combatant, id)` 與對應 unregister。同 ID 不重複註冊，不應由多個 owner 各自擁有。Interceptor 覆寫 `process_action_interception(processor, preview_mode)`，回傳碼（CONTINUE／STOPPED／REJECTED）與 priority 排序見 [擴充契約](../../../analysis/slay-the-robot/architecture/02_extension_points.md#攔截狀態與條件驗證)。上述接線為 2026-10-19 的靜態核實結果，新增機制仍需自己的執行證據。

Validator 覆寫 `_validation()`，呼叫者使用 `validate()` 以保留反轉等包裝契約；依呼叫情境處理 null card／action。新增條件至少檢查一個允許、一個拒絕及邊界值。若條件只是阻擋玩家出牌，核對是否也該限制自動出牌或 action；不要因掛在 `card_play_validators` 就假設涵蓋所有路徑。

### RNG 與資料契約

命名 RNG 流、固定 seed 重跑、序列化分支與 JSON patch 策略的修改與回歸，見 [RNG 與資料契約](mechanics/rng-data.md)。

## 驗收與同步

Smoke 不是完整戰鬥、取消或存讀驗收（涵蓋範圍見 [validation](validation.md#現有基準與命令)）；依 validation 選能辨識本次錯誤的專項檢查，以完成訊號與 timeout 判定，不用任意 sleep 當作完成。

機制／資料格式／載入流程變更依 [testing](../testing.md) 跑 Smoke；資源變更加 Import。regression 保留觸發條件與失敗訊息，區分既有及新增問題；公開契約變更同步 [code-map](../common/code-map.md)、分析／教學及驗證指令。

場域、ZOC、位移與有序反應改動先讀 [fields-zoc](fields-zoc.md)；雙盤定位與跨盤拒絕沿 [A 契約](../../../analysis/slay-the-robot/design/dual-board/README.md)。範圍含 UI/預覽、生命週期與動態時間等價，不能只驗數值 helper。

棋盤掛載、普通卡解耦與未掛模組戰鬥沿 [可選棋盤模組](mechanics/board-module.md)。不要把空間規則加回 Hand／HandManager；新卡只透過效果與 `card_values.board` 表達模組選項。
