# 資源生命週期修復與驗證

[分析入口](../README.md)｜[前次功能驗證](04_regression_validation.md)｜[testing](../../../wf/workflows/testing.md)

2026-10-19，已修復本輪定位的資源保留與非同步取消問題；隔離 headless All 共 498 項通過，未出現退出資源保留。版本基於 Slay-The-Robot `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d`、Godot 4.6 及既有 Dictionary／存讀修復。此結論限定下述測試，不涵蓋原生 GUI crash。

## 修復前證據

[04 報告](04_regression_validation.md) 保留前次 All 的 371 項功能 assertions 與退出資源限制。當時啟動／Smoke 保留 1 resource，戰鬥勝利 27、敗北 23、存檔 write 6、read 21；功能通過與資源清理是兩項不同結果，不能事後改寫為當時已無洩漏。

已定位的 ownership 問題是 [ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd) 原先繼承 Node，[BaseAction.gd](../../../game/scripts/actions/BaseAction.gd) 建立 processor 後既未掛樹也未釋放；processor 又持有 parent action，連帶保留相關行動與資料。前次 verbose 與正常 QUIT 後仍有資源的證據詳見 04。

## 本地實作契約

processor 改為 RefCounted，`parent_action` 改弱回指；返回的陣列或 async cache 擁有 processor，呼叫端／handler 擁有 action。這避免未掛樹 Node 保留，也避免 action → cache → processor → action 循環。getter 在 owner 消失後可回傳 null，但 processor 的攔截與取值方法仍要求有效 action；不保證保存 processor 後能繼續使用已消失的 parent。

[BaseAsyncAction.gd](../../../game/scripts/actions/BaseAsyncAction.gd) 新增 `begin_async_action()`／`finish_async_action()`，完成訊號清 cache；實際攔截快取只建立一次，預覽獨立走 `preview_mode`，不寫入實際執行 cache。這同時修正原本未設定 cache 旗標、可能重複觸發攔截副作用的問題。

[ActionBasePickCards.gd](../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 及其選牌／升級／複製子類統一完成出口。取消先設旗標，再解除 confirmed 等待；自動選牌的 frame 等待恢復後也先檢查取消。發出選牌請求時 callback 可能同步取消，因此請求後、安裝 await 前也檢查狀態。取消不得產生 child 或留下 pending selection；正常 child 仍能取得父行動的選牌資料。

[ActionHandler.gd](../../../game/autoload/ActionHandler.gd) 在執行／await 期間用局部強參照持有 action，以 generation 辨識被 clear 的舊 continuation，清除時解除 timer 等待；重入取消不能復活已清除 run 的行動。[Root.gd](../../../game/scripts/Root.gd) 離樹時清 pending actions 與攔截器。[BaseMenu.gd](../../../game/scripts/ui/menus/BaseMenu.gd) 將兩個導覽 Dictionary 的 value 型別由自身腳本改為 Control，解除腳本型別 metadata 的自我保留，場景檔不變。

整合驗證另定位 [Map.gd](../../../game/scripts/ui/Map.gd) 的 `populate_locations()`：await frame 會連同參數保留整組 LocationData，同 frame 離樹時留下資源。改由 Map 擁有可取消的一次性 frame callback，只弱參照目標節點，`clear_locations()`／離樹時斷開。[ActionCreateCards.gd](../../../game/scripts/actions/card_actions/pick_card_actions/ActionCreateCards.gd) 自行覆寫 perform_action，另補 begin 與 frame 等待後的取消檢查，避免取消後仍生成 child。

## 同一測試的紅綠證據

[resource_lifecycle.gd](../../../tests/resource_lifecycle.gd) 搭配 [案例](../../../tests/resource_lifecycle_cases.gd) 使用觀測用 interceptor／child fixture，實際執行產品 processor、handler、picker 與 Root 離樹。以 WeakRef 與 orphan Node 計數檢查釋放，不由測試手動 free processor。涵蓋正常／拒絕／預覽、同一 async 重用、取消 cache、選牌普通／同步／run 結束取消、自動選牌、timer、重入 callback 與 Root teardown；同時驗數值、副作用及完成次數。

同一 112 項測試：修前 [紅測試日誌](../evidence/2026-10-19/resource-lifecycle-red.log) 為 29 failures／exit 1，另有上游 handler 在取消後讀取 null `current_action` 的 SCRIPT ERROR、ObjectDB leak 與 11 resources；修後 [綠測試日誌](../evidence/2026-10-19/resource-lifecycle-green.log) 為 0 failures／exit 0，沒有 ObjectDB／退出 resource 訊息。[綠測試 manifest](../evidence/2026-10-19/resource-lifecycle-green-results.json) 保留來源／測試 hashes、命令與各程序結果。

首次冷匯入仍遇指定 SoundManager UID，runner 建好快取後重驗 Import 通過；不能將此結果寫成首次匯入沒有 ERROR。後續另補同步完成後 handler 不等待過去訊號，以及 CreateCards／Map 的新回歸，不能把增加的案例冒稱為原本 112 項同測。

## 整合發現與第二段回歸

首次 All 在戰鬥勝利階段被 runner 攔下；後續 verbose 戰鬥日誌雖有 82 checks／0 failures，仍列 ObjectDB leak、2 resources（SerializableData／LocationData）。原始證據為 `artifacts/verification/20261019-140201-6375024b/CombatVictory/combatvictory.log`。這證明局部生命週期綠燈不能取代完整流程退出驗證。

針對 Map 與 CreateCards 擴充至 127 項後，在前九檔修復 snapshot 執行 [第二段紅測試](../evidence/2026-10-19/resource-lifecycle-127-red.log)：2 failures／exit 1，正是取消後 child 效果及同 frame Root 離樹仍保留 LocationData；無 SCRIPT ERROR，但仍有 2 resources。同組 lifecycle 測試檔 hash 在最終 All 相同，新增兩檔修復後 [127／0／exit 0](../evidence/2026-10-19/final-all/ResourceLifecycle/resourcelifecycle.log)，且無退出資源訊息。

## 最終整合結果

由專責 runtime agent 以 `./tools/test-game.ps1 -Suite All` 執行，[最終 manifest](../evidence/2026-10-19/final-all-results.json) 對應原始 `artifacts/verification/20261019-141014-31bb0cb1/results.json`。文件與實作線另讀 manifest／原始日誌核對：completed=true、verdict=PASS，21 個程序階段全 exit 0；shutdown_resources 與 native_crash_signatures 全空，日誌沒有 ObjectDB leak。六個 suite 的 13 份產品來源 hash 與當前 game 相符，測試也保存獨立快照。

總計 498 checks／0 failures：ResourceLifecycle 127、Dictionary 47、Smoke 43、Combat 勝利 82／敗北 42、SaveLoad write 28／read 56／rejected 73。存讀三程序仍驗保存後語意還原與後續遭遇，並非戰鬥中快照；受控 fixture 的勝敗不代表全部敵人或卡牌平衡。

runner 現行預設將 ObjectDB／退出 resource 訊息判為失敗，即使 exit 0 且有 PASS；歷史容許計數不再是正常驗收基準。[背景合成診斷](../evidence/2026-10-19/runner-diagnostics-44-results.json) 另有 44 checks 通過，包含此拒絕能力。仍有 icon UID fallback、外部 image 警告；冷匯入的指定 SoundManager UID 必須重驗，壞檔 phase 僅放行十個已核對的預期拒絕。

## 邊界

本輪只做檔案修改與不開視窗的背景檢查；文件工作未啟動 Godot。沒有桌面、視窗、截圖、焦點操作或干預既有程序。headless／handler 斷言不驗 GPU、實際滑鼠命中、視覺呈現、成品 export 或全幕通關。原生記憶體錯誤調查由使用者要求擱置；本輪無 crash 標記只描述本輪程序，不能當成該事故已重現、已解釋或已修復。
