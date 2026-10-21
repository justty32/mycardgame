# 冷接手演練與修補證據

[分析入口](../README.md)｜[可重複方法](../../../wf/workflows/agent-session/cold-start.md)

2026-10-19 從專案提交 `fe34b532b783957a70d801d56be190e98e7651c8` 開始，讓沒有本輪對話歷史的 agent 從 wf/ 接不同任務。原始碼基準是 Slay-The-Robot `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加 [來源鎖](../../../tools/upstream.json) 的既有修復。領域受測者只讀檔與做背景靜態檢查，修補只改文件，沒有操作桌面／視窗。另派專責 agent 的隔離候選 mod 驗證已完成 52 checks／0 failures，含八項新載入斷言；與獨立導航復走分開，詳見 [可攜證據](evidence/README.md)。歷史 498 項未在本次重跑。

## 情境與判定

初讀／修補／復走記錄已抽到 [scenarios.json](scenarios.json)（9 列）。初讀來自 5 位受測 agent 的本機報告；其中卡牌分為實作、評量與新機制，關卡分為戰鬥與非戰鬥，呈現分為新卡素材與結算／繁中 UI。共同問題是新內容專項驗證缺少固定 suite 的接線說明；各領域另有導航或描述缺口。這些發現不等於框架功能已修復。

每列的 `id`／`task` 識別任務；`initial_route` 記實際導航；`initial_gap` 記首次阻礙；`initial_report` 與 `initial_sha256` 保存未追蹤原始報告的位置和雜湊；`repair_entry` 指向維護中的修補入口；`repair_summary` 說明改了什麼；`retest_status`／`retest_reviewer`／`retest_evidence` 記獨立復走；`limits` 定義仍不能證明的範圍。原始報告路徑只作本機來源標識，不是 fresh clone 的必要依賴；本表保存其必要發現。

最終 9/9 情境的靜態路由皆 pass，無 pending／blocked。戰鬥／非戰鬥首次因 owner 尚未 freeze 遇到缺檔，完成後重走通過，記在 [世界復走報告](evidence/world-review.md)。新機制首次缺攔截預覽橋接，補充 Card 的消費契約後由原獨立 reviewer 復核通過，記在 [內容復走報告](evidence/content-review.md)。兩次文件中斷與候選 runtime 首次 certificate store 失敗均保留，沒有改寫成首次順利。

`pass` 只表示獨立 agent 已能從 wf 找到來源鏈，提出檔案／ID／步驟／真實測試入口及未驗範圍的可執行計畫；不代表遊戲已實作、已玩過、平衡良好或呈現可用。資料接線、戰鬥效果、音訊輸出、視覺與輸入、完整多幕／存讀仍依實際任務各自驗收。

## 後續維護

2026-10-21 另以 `7eba093` 核對「每場 0~N 盤」接手路由，情境表追加 `per-encounter-board-count`，總計 10 列（不改上述首輪 9/9 歷史結果）。初讀發現決策已含 0 盤，但調查仍只推薦 2..上限且沒有每場裝配橋接；補入 H0 與現況／決策界線後，另一位無歷史 agent 靜態復走通過。後續使用者要求先規劃乾淨解耦結構，實際方案見 [架構草案](../../../wf/specs/multi-board/README.md)。本次沒有改遊戲或執行 Godot。

後續呈現領域輪次另見 [美術、動畫、VFX、音訊與 UI 演練](media.md)；獨立保存初讀缺口與復走狀態，不改寫本輪 9 情境或 52 checks 證據。

再追加的 [完整用途呈現演練](media-purpose.md) 覆蓋卡牌／戰鬥、敵人、對話、商店／休息、獎勵選牌與選角至結算旅程，與技術領域情境分開判定。

初始路由與缺口不隨修補覆寫。修補入口及獨立結果在實際檔案和 reviewer 報告可核對後更新；出現新缺口則保留該次結果，下一次復走另註。更換來源版本或測試 runner 後，重新查核受影響的情境，避免把本次文件可用性沿用成新版程式保證。
