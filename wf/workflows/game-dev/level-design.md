# level-design — 遭遇、分支地圖與 act 節奏

[遊戲開發](README.md)｜[內容接線](content.md)｜[敵人設計](enemy-design.md)｜[核實來源](../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：建立／評量遭遇、事件池、地圖節點、act、商店／休息／獎勵配置與跨 act 流程。

**何時不用**：單體敵人行為走 enemy-design；新規則走 [mechanics](mechanics.md)；純地圖外觀走 [UI](ui.md)。只是討論題材時先保留方案，不新增內容或替使用者決定核心玩法。

## Done when

任務設計檔存在，包含 act 目的、路線取捨、遭遇／資源預算、節點與池 ID、生成約束、終局及存讀策略。實作任務另有對應資料／生成程式與專項測試：輸出列出可達性、固定 seed、事件選擇、獎勵與繼續流程斷言，命令回傳預期結果。設計評量記錄填滿改前改後、樣本與限制；受影響分析更新，strict lint 回傳 0。只交設計時標明未實作／未執行。

## 流程

### 從玩家旅程定義約束

以 [ActData](../../../game/data/readonly/ActData.gd)、[LocationData](../../../game/data/mutable/LocationData.gd) 與 [ActionGenerateAct](../../../game/scripts/actions/world_generation_actions/ActionGenerateAct.gd) 為真相。來源基準是 2026-10-19 核對的上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復；這是程式生成地圖，沒有核實過的關卡編輯器或自動難度求解器。

設計建議：先寫本 act 教會／考驗的決策、起始牌組與生命／金錢範圍，再畫出「學習—壓力—恢復—考驗」的節奏。分支應有可解釋的風險／收益差別，而非只是橫向座標不同。區分玩家可見資訊與隱藏節點；未知節點的波動也計入風險。門檻由任務定義，例如最少一次恢復機會、精英前可用的資源與 boss 前可選路線數，不把這些建議冒充固定引擎規則。

### 選擇現有生成器或明確擴充

現有 generator 預設十層、每層五點；程式固定前三層 easy、第四層 shop、第五層 miniboss、第六層 treasure、第七層 rest，後面 hard，再加 boss。相鄰層連同欄及左右欄，第一層全接起點，最後一層全接 boss；部分 combat 可轉 dialogue event 或隱藏類型。

`floors_per_act`、`locations_per_floor` 等是 action 參數，並非 ActData 匯出欄位。`ActionGenerator.generate_act()` 只傳 act_id／act_number；要調整生成參數先定義真正的供值路徑，或用 `act_action_script_path` 接自訂生成 action。只把未知欄位加進 act JSON 不會改變樓層。改短 act 必須重審固定層索引，不會自動按比例安排商店與休息。

先寫圖不變條件：ID 唯一、每條邊存在、從起點可到預定終點、無意外死路／回圈、每條允許路線符合必要資源約束。再定義分支合流、節點數與跨 act 邊界。舊 act 會被清除，只保留前 act 當前終點作新起點；不能把已清除節點當作仍可回訪的世界。

### 組合遭遇與資源經濟

戰鬥用 [EventData](../../../game/data/readonly/EventData.gd) 指定各槽的敵人候選及權重；先按 enemy-design 做單體，再檢驗整隊總壓力、狀態互補、同步爆發、擊殺優先序與最壞抽樣。框架沒有敵群 budget 欄位；任務中的 budget 是設計約束與評量結果，不是會自動限制生成的程式。

事件接 `event_dialogue_object_id`，測每個選項的條件、成本、效果、結束及死亡路徑。shop／rest／treasure 是 LocationData 的種類，各自由 overlay／action 處理，不是任意 EventData 加同名屬性。休息行為、商店商品／價格、卡牌／遺物獎勵需沿實際來源驗證；`event_has_combat_rewards` 是總開關，預設金錢由 Random 固定產生 25–49，不是 event 的金錢欄位。

比較每條路線的生命代價、可得金錢與牌組成長，記錄恢復、移除／升級機會是否抵消挑戰。將「較難遭遇應有較高收益」當設計假說，以同牌組／同策略測試，不直接將敵人 HP 換算成固定獎勵。

### 核對池、終點與存讀

[EventPoolData](../../../game/data/readonly/EventPoolData.gd) 是 ID 陣列：補池去重後洗牌、抽出有效事件並移除，並非加權事件表；重複 ID 不會增加權重。LocationData 首次求 event 時會寫入已選 ID，固定 event ID 優先於 pool。fallback 要存在且適合所有退路；目前 fallback 不再次經 event validator。

不要依賴目前未完成的失敗策略：PlayerData 沒有把拒絕的 ID 放入 failed 清單，BLACKLIST 也未參與補池過濾。需要 KEEP／REMOVE／APPEND／REINSERT／BLACKLIST 的需求先交 mechanics，以失敗測例修好再採用。缺口來源見核實筆記，不能拿 enum 存在當實作證據。

`act_next_act_ids` 非空仍不保證進下一幕；`Global.is_end_of_run()` 另看 `player_act_max`，無後繼位置會被判定 act 結束。需要正常勝利、無窮循環或分支 act 時，將 next IDs、最大 act 與 reward Continue 的行為一起驗。空 next-act 清單與尚未到 act_max 的組合也要測，不能只依 ActData 註解推定會勝利。

訪問 action 先更新 player_location_id、清空 shop、autosave，再發送訪問訊號；讀檔會重新進入目前位置。保存的是 PlayerData 的地圖、池與 RNG 等資料，沒有完整戰鬥中途快照。存讀測例要對齊這個邊界，比較載入後的下一事件／敵群／獎勵和不中斷路徑；有意變更 ID／生成規則時另寫舊存檔策略。

### 分層驗收與評量

先靜態驗 ID、邊、權重、pool/fallback 與 act 連接，再在隔離 fixture 用固定 seed 生成／走訪；同 seed 加相同選擇序列應可重現，改 RNG 呼叫數會改後續結果。跨多 seed 統計節點／路線／事件分布與極端值；有限樣本不能證明所有 seed 安全，結構不變條件應直接斷言。

至少走新局起點、正常戰鬥勝敗、event 返回、shop、rest、treasure、boss 後 Continue 及跨 act／終局，並針對本次變更的分岔做保存→另一程序讀取→下一步比較。現有 Combat／SaveLoad 只提供基準，不覆蓋全 act 或所有 overlay。未新增專項測例前標未驗，不能因既有 suite 綠燈宣稱整章完成。

測試由 runtime owner 依 [validation](validation.md) 安排，遵守 [只做背景檢查](../common/user.md)。地圖可讀性、點擊命中與視聽節奏仍需後續有效授權的人工評量，本次不開視窗或截圖。保留 sample size、策略、seed 與候選版本，區分可達性通過與平衡假說。

## 交接

交付任務設計、接線／生成差異、可重現樣本、測試日誌、未驗項目與存檔政策。敵人調整回 enemy-design，原語修復回 mechanics。大量節點／遭遇／seed 評量依 [資料契約](../common/data-files.md) 存 `wf-table/1`，入口只留摘要與導航；重用的已驗限制同步本流程與核實筆記。
