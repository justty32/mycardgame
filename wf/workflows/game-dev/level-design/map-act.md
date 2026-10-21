# 地圖與幕 — 路線、資源節奏及終點

[關卡入口](../level-design.md)｜[全局流程](../game-flow.md)｜[來源核實](../../../../analysis/slay-the-robot/design/encounters.md#地圖生成路線與終局)

**何時用**：改生成規則、分支、節點配置、跨幕或終局。**何時不用**：單場接線走 [combat](combat.md)／[noncombat](noncombat.md)，純視覺走 UI。

## Done when

設計檔列 act 目的、路線取捨、資源預算、ID／池、生成不變條件、終局及存讀策略。對應生成程式／資料存在；專項日誌列固定 seed、結構、可達性、跨幕／終局與續玩斷言及命令結果。有限 seed 的分布評量明列樣本與限制，受影響分析同步。

## 流程

### 定義旅程，再選生成方式

地圖是程式生成，沒有已核實的關卡編輯器或難度求解器。寫下 act 要教會／考驗的決策、起始牌組與生命／金錢範圍，再安排學習、壓力、恢復與考驗；分支須有風險／收益差異，隱藏節點的波動也計入。

預設網格、固定設施樓層與連邊方式見[核實的地圖生成](../../../../analysis/slay-the-robot/design/encounters.md#地圖生成路線與終局)。縮短樓層不會重排固定設施索引，不能只改層數便聲稱節奏保持。樓層數、每層點數與隱藏／事件比率是 action 參數而非 ActData 欄位；要改就建立實際供值路徑或用 `act_action_script_path` 接自訂 action，只加 JSON 未知欄位不會改地圖。新局 act 的選擇與 player_act_max 接點沿 game-flow 查核。

### 寫圖不變條件與池契約

先斷言 ID 唯一、每條邊存在、起點可達指定終點、沒有意外死路／回圈，每條允許路線符合任務中的資源約束。最低恢復機會、精英前資源與 Boss 前分支數是設計門檻，不是引擎保證。比較每路生命代價、金錢、卡牌與遺物成長；恢復、移除與升級要沿 noncombat 的實際能力計算。

池的抽取規則（無權重、去重洗牌、固定位置優先、fallback 不經 validator、失敗策略與黑名單未接線、列舉須用 Global getters）見[核實的池段](../../../../analysis/slay-the-robot/design/encounters.md#遭遇池與資料接線)；設計上需要必定出現時用固定位置／自訂生成，依賴失敗策略時先交 mechanics 加失敗測例修復。

### 指定跨幕、終局與保存邊界

終點判斷（`is_end_of_act`／`is_end_of_run`、act_max 與 next IDs）與換幕清圖見[核實的終局段](../../../../analysis/slay-the-robot/design/encounters.md#地圖生成路線與終局)，各節點的離開／轉幕出口（Reward／Shop Continue 會轉幕、REST／EVENT 不會、最終戰直接結算不給一般獎勵）見[獎勵與 overlay 段](../../../../analysis/slay-the-robot/design/encounters.md#獎勵overlay-與存檔邊界)。設計時正常勝利、無窮與分支 act 都要一起驗 max、next IDs 及出口；EVENT／REST 放幕尾或最終 Boss 先領獎都是機制修改，需要專項測例；清掉的前幕節點不可設計成仍可回訪。

存檔時點與保存範圍見 [存讀與局外進度](../game-flow/persistence.md#先選保存承諾)。ID 或生成改動要明列舊存檔保持相容、轉換或拒絕策略，測試不得碰玩家唯一存檔。

### 分層驗收

先靜態驗 ID／邊／權重／fallback／act 鏈，再在隔離 fixture 用固定 seed 生成並按真實可達邊走訪；改 RNG 呼叫次數會影響後續抽樣。跨多 seed 統計節點、路線、事件分布與極端值；有限樣本不能證明所有 seed，結構不變條件應直接斷言。

至少覆蓋新局起點、戰鬥勝敗、EVENT 返回、SHOP、REST、TREASURE、非終局 Boss 轉幕與最終戰結算。針對變更的分岔做保存→另一程序讀取→下一步，與不中斷路徑比較。runner、證據記錄與 GUI 未驗的共同規則見[共同驗收](../level-design.md#共同驗收)。

## 交接

交付設計、生成差異、ID 鏈、圖不變條件、樣本／日誌、未驗項目與存檔政策。敵群交 combat，事件／設施交 noncombat，流程出口與續玩交 game-flow。大量節點或 seed 記錄依資料契約落資料檔，入口只保留摘要與導航。
