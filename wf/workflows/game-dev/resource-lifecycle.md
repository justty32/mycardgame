# resource-lifecycle — 所有權與資源清理

[機制修改](mechanics.md)｜[驗收分流](validation.md)｜[資源調查紀錄](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md)

**何時用**：新增暫存 processor、跨 frame 持有行動、非同步快取、signal callback 或回指參照，或退出時出現 ObjectDB／resource 保留。**何時不用**：單純數值調整不改所有權；未定位的原生 crash 另依 [原生崩潰調查筆記](../../notes/investigations/godot-native-crash.md)，不能先假定是 leak 造成。

## Done when

回歸與受影響 suite 指令回傳 0，完整退出日誌沒有目標物件保留；修前同測失敗的證據已保存。分析檔記錄持有者、釋放時點、正常／拒絕／取消結果及未覆蓋範圍。不能只把舊 warning 加入白名單。

## 找出真正的持有鏈

從 [BaseAction.gd](../../../game/scripts/actions/BaseAction.gd)、[ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd)、[BaseAsyncAction.gd](../../../game/scripts/actions/BaseAsyncAction.gd) 與 [ActionHandler.gd](../../../game/autoload/ActionHandler.gd) 沿建立、儲存、完成及取消路徑追蹤。先分清 Node、RefCounted／Resource、SceneTree 節點與普通資料容器，不以變數離開函式就推定物件已釋放。

記下強參照方向：誰建立並使用誰、誰只是回看來源。Node 不因局部變數消失而自動銷毀；未掛樹的 Node 必須有明確生命週期。RefCounted 可以隨引用計數釋放，但雙向強參照或容器／快取形成的循環仍會保留。只有前向所有權確實存在、反向只是查詢時，才把回指改成 WeakRef；不能讓必須跨等待存活的真正擁有者一併變弱。

本地 processor 的 `parent_action` getter 在 owner 消失後回傳 null，但取值／攔截方法仍要求有效 action；呼叫端必須在使用期間持有它。不要把「可讀弱參照」誤解成「可在 owner 消失後執行」。新增 fallback 的值與 target 行為屬公開契約，須另驗，不能悄悄改效果。

## 非同步與快取

等待中的 action 由執行者持有；若它快取 processor，而 processor 回指 action，需明確打斷循環。列出完成、拒絕、強制取消、run 結束各出口，確認快取／signal／callback 不在出口後仍延長行動生命。

本地 BaseAsyncAction 以 `begin_async_action()` 重設狀態、`finish_async_action()` 保證完成一次；完成訊號清 cache。預覽不得寫入實際執行 cache，也不得因此略過真正執行的攔截。呼叫端／handler 跨 await 持有 action；清理 processor 不等於刪掉 child 尚需的選牌資料。

取消先設 `async_cancelled`，再解除 confirmed／timer 等等待；恢復後先檢查取消或 generation，再執行效果／派發 child。訊號 callback 可能同步呼叫 clear，需在送出請求後、安裝 await 前再次檢查。測 handler 等待與取消，不能只直接呼叫 action；完成後仍收到 callback 也不得重複效果。

也查所有覆寫：基底 picker 修過，不代表自行覆寫 `perform_action()` 的 CreateCards 已有 guard。frame await 會保留參數／局部陣列；Map 只需延後捲動時，以 owner 可取消的一次性 callback 取代整段懸停，弱參照目標節點，clear／離樹時斷開。回歸包含「建立與離樹同 frame」，不要先多等幾 frame 排空問題再驗退出。

## 寫能辨認問題的驗證

使用弱參照或 instance ID 觀察測試物件在移除最後一個預期持有者後是否仍存在；不要由測試偷偷保留強參照而誤判 leak，也不要由測試手動 free 原應由產品管理的物件來掩蓋問題。先在未修版本執行同一情境確認失敗，再以修正版轉綠。

預覽需比較前後遊戲狀態，非同步需等待明確完成訊號並有 timeout。測試結束後可清理測試自己建立的 SceneTree／fixture，但應在 assertions 完成後執行，且留下正常結束流程與最終退出日誌；不能清空所有全域資料後只宣稱產品有正確 ownership。

現有命令為 `python3 tools/test_game.py --suite ResourceLifecycle`；[測試案例](../../../tests/resource_lifecycle_cases.gd) 用觀測用 interceptor／child fixture，搭配真實 processor、handler 與選牌動作。新增所有權型態須補對應路徑，不能由既有案例推定全部涵蓋。

再依 [testing](../testing.md) 執行受影響 suite。診斷 verbose 中保留資源的路徑與類型；exit 0 或資源數變少不足以通過清理驗收。若局部已綠但完整戰鬥仍保留資源，記錄剩餘持有鏈，不放寬測試。2026-10-19 的實作及實測狀態統一見 05 報告（現況基準 Godot 4.7.2；初測於 4.6，4.7.2 Linux 重跑一致），見 [upstream.json](../../../tools/upstream.json) `engine_policy.migration_from_4_6`。

## 同步與適用邊界

修復確認後同步分析、擴充教學及 runner 的現行判讀規則。歷史報告保留當時數據，另連到新證據；通用規則記錄必要條件，測試結果則記版本與實際命令。本流程不保證所有新內容永遠無 leak，也不證明 GPU／視窗或原生 crash 問題已修復。
