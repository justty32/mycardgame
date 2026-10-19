# 地圖與幕 — 路線、資源節奏及終點

[關卡入口](../level-design.md)｜[全局流程](../game-flow.md)｜[來源核實](../../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：改生成規則、分支、節點配置、跨幕或終局。**何時不用**：單場接線走 [combat](combat.md)／[noncombat](noncombat.md)，純視覺走 UI。

## Done when

設計檔列 act 目的、路線取捨、資源預算、ID／池、生成不變條件、終局及存讀策略。對應生成程式／資料存在；專項日誌列固定 seed、結構、可達性、跨幕／終局與續玩斷言及命令結果。有限 seed 的分布評量明列樣本與限制，受影響分析同步。

## 流程

### 定義旅程，再選生成方式

以 [ActData](../../../../game/data/readonly/ActData.gd)、[LocationData](../../../../game/data/mutable/LocationData.gd)、[ActionGenerateAct](../../../../game/scripts/actions/world_generation_actions/ActionGenerateAct.gd) 為真相。這是程式生成地圖，沒有已核實的關卡編輯器或難度求解器。寫下 act 要教會／考驗的決策、起始牌組與生命／金錢範圍，再安排學習、壓力、恢復與考驗；分支須有風險／收益差異，隱藏節點的波動也計入。

預設十層、每層五點；前三層 easy，第四 shop、第五 miniboss、第六 treasure、第七 rest，後面 hard，另加 boss。相鄰層接同欄與左右欄，起點全接首層，末層全接 boss；部分 combat 轉 EVENT 或隱藏種類。縮短樓層不會按比例重排固定設施索引，不能只改十成五便聲稱節奏保持。

`floors_per_act`、`locations_per_floor`、隱藏／事件比率是 action 參數，不是 ActData 匯出欄。[ActionGenerator.generate_act()](../../../../game/autoload/ActionGenerator.gd) 只傳 act_id／act_number；要改參數須建立實際供值路徑或用 `act_action_script_path` 接自訂 action。只加 JSON 未知欄位不會改地圖。新局 act 的選擇與 player_act_max 接點沿 game-flow 查核。

### 寫圖不變條件與池契約

先斷言 ID 唯一、每條邊存在、起點可達指定終點、沒有意外死路／回圈，每條允許路線符合任務中的資源約束。最低恢復機會、精英前資源與 Boss 前分支數是設計門檻，不是引擎保證。比較每路生命代價、金錢、卡牌與遺物成長；恢復、移除與升級要沿 noncombat 的實際能力計算。

池是 ID 陣列，補池去重後用 rng_event_pool 洗牌，抽出有效 event 並移除；固定 location event 優先。fallback 必須存在且適合所有退路，它不再經 validator。PlayerData 沒有把拒絕 ID 填入 failed 清單，BLACKLIST 也未參與補池過濾；設計若依賴 KEEP／REMOVE／APPEND／REINSERT／BLACKLIST，先交 mechanics 加失敗測例修復。不要依 enum 存在假定有功能。

資料列舉使用 Global getters，別為了讀取而呼叫 `get_location_event_object_id()` 消耗池／RNG。[Map](../../../../game/scripts/ui/Map.gd) handler 檢查 can_travel 與下一位置；[ActionVisitLocation](../../../../game/scripts/actions/world_interaction_actions/ActionVisitLocation.gd) 是強制訪問，不驗鄰接。測試直接傳遠處 ID 不能證明玩家路線可達。

### 指定跨幕、終局與保存邊界

`Global.is_end_of_act()` 看後繼位置為空，`is_end_of_run()` 再看 player_act_max（<=0 是 endless）與目前 act。`act_next_act_ids` 非空不保證轉幕；未達 act_max 而 next IDs 空時，generate_next_act 只記錯誤。正常勝利、無窮與分支 act 都要一起驗 max、next IDs 及出口。

非終局戰鬥／寶箱由 Reward Continue、商店由 Shop Continue 處理生成下一幕。最終戰 combat_ended 由 RunSummary 直接勝利。EVENT 結束只回 Map；REST Continue 沒有 generate_next_act。因此將 EVENT／REST 放幕尾，需要額外轉幕機制和測例，不能沿用一般 Boss 假設。

新 act 清除舊地圖，只保留前幕目前終點接首層，不可把清掉的節點設計成仍可回訪。訪問先更新位置、清 shop、autosave，再發訪問訊號；讀檔會重新進入當前位置。保存 PlayerData 地圖、池、RNG 等，不保存完整戰鬥／事件互動快照。ID 或生成改動要明列舊存檔保持相容、轉換或拒絕策略，測試不得碰玩家唯一存檔。

### 分層驗收

先靜態驗 ID／邊／權重／fallback／act 鏈，再在隔離 fixture 用固定 seed 生成並按真實可達邊走訪。同 seed 加相同操作才可比較；改 RNG 呼叫次數會影響後續抽樣。跨多 seed 統計節點、路線、事件分布與極端值；有限樣本不能證明所有 seed，結構不變條件應直接斷言。

至少覆蓋新局起點、戰鬥勝敗、EVENT 返回、SHOP、REST、TREASURE、非終局 Boss 轉幕與最終戰結算。針對變更的分岔做保存→另一程序讀取→下一步，與不中斷路徑比較。現有 `python3 tools/test_game.py --suite Combat`／`--suite SaveLoad` 只提供基準，沒有全幕 suite；新增專項與 runner 接線後才有本次命令，不把舊 suite 當整章完成。

背景測試由 runtime owner 依 [validation](../validation.md) 串行安排。地圖可讀性、點擊命中與視聽節奏在目前禁止視窗操作下保留未驗；記錄版本、seed、樣本與策略，區分可達性及平衡假說。

## 交接

交付設計、生成差異、ID 鏈、圖不變條件、樣本／日誌、未驗項目與存檔政策。敵群交 combat，事件／設施交 noncombat，流程出口與續玩交 game-flow。大量節點或 seed 記錄依資料契約落資料檔，入口只保留摘要與導航。
