# 呈現製作冷接手演練

[演練入口](README.md)｜[呈現交付流程](../../../wf/workflows/game-dev/presentation-delivery.md)｜[設計分析](../design/README.md)

2026-10-19 的後續輪次，針對美術風格／靜態素材、動畫、VFX、音效／音樂與 UI 子流程。來源仍是 Slay-The-Robot `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加來源鎖既有修復。五位領域 agent 先從 wf 冷讀並保存 initial 報告，再查實碼修補文件；整合者只核對交接鏈，不擔任這五份產物的獨立 reviewer。

本輪 8 個技術領域情境保存在 [media-scenarios.json](media-scenarios.json)：美術 1、動畫 1、VFX 1、音訊 2、UI 3。兩位未參與修補的 reviewer 首次復走分別確認 3 案及 5 案可提出開工計畫，合計 8/8 pass；完整報告保存於可攜證據。判定限於文件能支援開工（未驗範圍見下文本輪邊界）。跨域交付是共同修補入口，沒有虛增未經初讀的情境。

使用者後續要求按完整用途覆蓋卡框＋卡圖、敵人、對話、商店等畫面套件；本輪 8 案不能證明該擴充已涵蓋。[新用途輪次](media-purpose.md) 另立情境、初讀和獨立復走，不改寫本輪的任務或判定範圍。

音訊／UI 復走另提出兩項不阻礙開工的精度提醒：draft Skip 會保留原 CardRewardButton 供重開；Back 的零選取不執行效果需驗 pick action 的最少數量與 `min_cards_are_required_for_action`，不能泛稱取消效果零次。原報告保留首次判定，後續由 UI owner 對來源補精度。

## 如何讀證據

`id`／`domain`／`task` 識別具體情境。

`initial_route` 記第一次採用的入口鏈。

`initial_gap` 保存修補前阻礙，不被修補結果覆寫。

`initial_report`／`initial_sha256` 記本機原始報告與內容雜湊；`initial_evidence` 指向逐 byte 保存的[可攜副本](media-evidence/README.md)。原件位於未追蹤 artifacts，fresh clone 沿副本查核。

`repair_entry`／`repair_summary` 指向維護中的子流程及修補內容。

`retest_status`／`retest_reviewer`／`retest_evidence` 留給獨立 reviewer 寫實際結果；`limits` 標明不能推出的結論。

音訊初讀曾把 location music 呼叫定位為 `_start_combat`，追完整函式後更正為 `_on_map_location_selected`；原報告以追加修正保留過程。正確邊界是到訪節點已有接點，單純開地圖、獎勵與結算沒有各自獨立切曲入口。此差異保存在音樂情境修補摘要，不抹平首次誤判。

## 復走與驗收邊界

reviewer 應各自交出可開始工作的檔案／ID／資料欄位、事件與清理 owner、第一步、可用測試入口及未驗條件；發現斷鏈先記結果再交原 owner 修補，之後明記再次復走。只有實際報告存在時才填 reviewer 和 evidence。表中 `pending` 不應由 owner 自評改成 pass。

本輪只改文件及執行背景靜態檢查，沒有啟動 Godot、製作／匯入新素材、播放音訊、操作 UI／桌面／視窗／截圖／焦點或既有程序。動作順序、雙播、格擋分支等是查碼發現，沒有修遊戲。後續即使靜態復走 pass，也不證明素材品質、動畫同步、聽感、真實輸入、多尺寸或媒體生命週期已通過。

原 [9 情境演練](README.md) 與其 52 checks runtime 證據保持原紀錄；本輪不沿用該計數作為媒體專項驗證，也不重跑或重寫歷史結果。局部文件檢查交由各 owner 記錄，全倉 strict lint 與最終統計由主 agent 串行整合。
