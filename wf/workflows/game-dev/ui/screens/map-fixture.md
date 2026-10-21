# 地圖畫面的最小 fixture 與具體接入

[地圖畫面](map.md)｜[驗證接線](../verification.md)｜[場景目錄](README.md)

**何時用**：為 [地圖畫面](map.md) 的節點、可達、拒絕、返回與重建寫背景專項。

**何時不用**：地圖生成或跨幕規則的測試走 [地圖內容規則](../../level-design/map-act.md)；一般 helper 接線原則見 [驗證接線](../verification.md)。

## Done when

- helper 已實際接到 Smoke 或 Combat 的 caller，斷言交給既有 `_check()` 並有結果。
- visited 副作用以預期失敗明列；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

### 靜態檢查的接點

依 verification，建議新增 tests/ui_map_probe.gd（尚未建立），由 Smoke `_run()` 在 Root ready 後 runtime load，做節點路徑、scene、animation、素材與尺寸檢查。若需要 populate／show_map，先提供 [地圖畫面](map.md#演出焦點與離場) 所述的無焦點 adapter。純讀靜態 scene 可以先做，但不能拿它替代導航結果。

### 旅程情境

旅程情境沿 tests/combat_flow.gd 的 `_scenario()` 起局與 run-start option，在首次 map ready、戰鬥選取之前插入獨立 probe，或交 runner owner 建專項。固定 seed，配置 STARTING、兩個可達分支、不可達／隱藏節點及終點，並驗證 ID／邊／event 有效。資料設定與玩家操作分開；不要直接 emit map_location_selected 假造走訪。

### 要斷言的項目

檢查每個節點的 position／label／flash animation、STARTING 不顯示、container 高度與空圖出口。在讀取與重建前後記錄 RNG／事件池，證明預覽沒有抽事件。查看模式與不可達點擊要經真實的 MapLocation.button_up，應不改 player_location_id、shop、存檔與 visited；目前的 visited 問題明列為預期失敗，不能默默放寬斷言。

合法點擊後有界等待 action idle，驗 location_id、visited、shop 清除、訊號恰好一次及 Map 關閉；連點、Back／重開與幕尾另列。測 populate 後同 frame 重建／釋放，確認舊節點已 queue_free、pending callback 已取消且不指向新 scene。若改 travel 時序，補上 combat／dialogue／shop／rest 的返回情境。

新增 suite 要同步 runner 的 SUITE_CHOICES、分支、mapping、PASS marker／manifest；現有 Combat 的單條路徑不是全圖驗收。

## 交接

交付 helper 路徑、caller 插入點、fixture 配置與預期失敗清單；視覺、命中與實際導航另列未驗。
