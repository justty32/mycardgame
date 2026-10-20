# enemy-design — 敵人角色、意圖與遭遇驗收

[遊戲開發](README.md)｜[內容接線](content.md)｜[關卡設計](level-design.md)｜[核實來源](../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：設計／調整普通敵人、精英、boss、召喚物，以及它們的回合節奏、意圖與隊伍組合。

**何時不用**：只換敵人圖像／音效接 [UI](ui.md)；現有 Action 無法表達行為接 [mechanics](mechanics.md)；整個 act 的節奏接 level-design。沒有玩法需求時只建立設計候選，不加入遊戲。

## Done when

任務 spec（`games/<game>/design/specs/`）存在，寫明敵人 ID、角色、出現階段、目標牌組假設、各意圖／轉移／反制、難度差異與通過門檻。實作任務另有載入與遭遇接線檔；專項測試輸出包含初始意圖、轉移、預告與效果、死亡／召喚及難度邊界斷言，命令回傳預期結果。設計評量記錄填妥版本、seed、牌組、操作策略、結果與未驗項目；文件 strict lint 回傳 0。純設計交付不得標成玩法已驗收。

## 流程

### 先建立可檢驗的敵人角色

讀 [EnemyData](../../../game/data/prototype/EnemyData.gd)、[EnemyIntentData](../../../game/data/readonly/embedded/EnemyIntentData.gd)，沿核實來源追到執行者，不從教學註解推定能力。基準為 2026-10-19 核對的上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復；版本改變先重查。

以下是設計建議，並非框架自動規則：用一句話說玩家應學會什麼決策，例如「在蓄力回合留資源防守」，再指定可反制的方法與錯誤決策的代價。記下預期可用的牌組、費用、抽牌、生命與前置遭遇；普通／精英／boss 的定位不能只靠血量區分。boss 階段、血量觸發或反覆使用限制不是現成狀態機欄位，需求出現時先確認需要哪個自訂 action／validator。

先以單體最小循環表達角色，另列容易混淆的意圖及最壞連續壓力。定義可觀察門檻，例如在指定起始牌組與策略下的存活回合、生命損失範圍、是否存在回應窗口；數值由本遊戲目標決定，不抄參考作品當公認平衡常數。

### 將意圖寫成完整狀態圖

從 `intent_initial` 指向第一輪可用意圖，每個可到達狀態寫出傷害×次數、格擋、custom actions、下一狀態權重與預告內容。權重須非負、總和大於零，目標 ID 全部存在；需要停留時明確自迴圈，不用空權重代表「維持原狀」。目前空權重實際回傳 null，不能相信旁邊的停留註解。

敵人在進入時間軸等待時（開戰、生成、自身行動後）由 [CombatDirector](../../../game/scripts/combat/CombatDirector.gd) 呼叫 `Enemy.decide_next_intent()` 切換意圖。EnemyIntentController 依是否掛載 board_module 分派：有模組由 BoardEnemyIntent 處理移動、射程與命中；NONE 走普通 hero／SELF 目標，不查距離或移動。兩路均以 `Enemy.build_intent_actions_data` 組出 stack：重設格擋（依 rules）、加格擋、攻擊、custom actions；custom actions 也受逆序影響。每次行動依序處理 PRE_ENEMY_TURN → PRE_ENEMY_INTENT → 意圖 → POST_ENEMY_INTENT → POST_ENEMY_TURN；「先上易傷再攻擊」須測實際次序。

預告用 attack／attack-generator 的 preview interception 算數字，圖示來自 `enemy_intent_display_types`。custom action 的視覺推導只有部分已知腳本；新腳本須同步描述／圖示契約。純防禦或召喚意圖明確將傷害與攻擊次數設 0。重複預覽前後比較狀態、RNG 與資源，證明預覽不改遊戲；數字斷言不等於玩家已看得懂。

### 難度與遭遇接線

雙盤／移動意圖另讀 [棋盤意圖核實](../../../analysis/slay-the-robot/design/board-intents.md)。先指定來源與目標的實際 `board_id`，經 BoardTargeting.geometry → CrossBoardPolicy 查詢，不用 faction 推盤，也不把跨盤 A 當零距離。方向型跨盤效果在費用前拒絕，測例須包含 SINGLE 卡內巢狀推拉、request 值覆寫、全域／隨機目標、拒絕時費用與位置不變；只有 UI 拒絕不涵蓋自動／複製出牌。

先驗模組 on/off 邊界：NONE 的普通攻擊、格擋、custom 與音效須保留；NEAREST／FARTHEST 沿 hero，SELF 不計入 hero 來傷。明確棋盤 payload 用 BoardContentPolicy 在排隊前整體拒絕，純 helper 與來傷預覽共用，不能部分執行。有模組但單位缺盤身分必須拒絕，不得退回 NONE。本輪拆分先有靜態契約；新增回歸結果另依整合報告。

移動意圖至少對照預覽與真正 controller 的落點、命中與次序，覆蓋 move_after、rooted、禁閃現格、CHARGE 穿越去重及中途死亡／退出。NEAREST／FARTHEST 只比較同盤距離，無同盤候選按 uid；跨盤 ComputeBoardValue 卡整體拒絕。新自訂 payload 的估值未被標準預覽涵蓋時，另補實作與回歸，不能用數值 0 表示已模擬。此流程來自 2026-10-20 靜態接線核對；實測結果依該輪整合報告。

血量用上下界與 `add_health_bounds()`；一般屬性難度表的實際拼字為 `enemy_difficulty_to_enemy_modfiers`。`add_intent_state()` 可保存同原始 ID 的難度版本，但目前 override cache 未依玩家難度篩選，會挑最高版本。設計依賴此能力時先建立最低、門檻前、門檻及最高難度的失敗測例並接 mechanics 修正，不宣稱現成難度切換可用。

依 content 註冊 mod 資料，沿 `EnemyData → EventData.event_weighted_enemy_object_ids → EventPoolData → ActData／LocationData` 接入可到達遭遇。每個敵群欄位是一個生成槽的加權候選，不是「整隊二選一」；各槽組合可能產生單體設計未遇到的連鎖壓力。指定位置需覆蓋初始與召喚槽；確認敵人種類、minion、初始狀態、動畫與死亡 action。

### 建立專項回歸與評量

先用固定 seed、明確 HP 與最小牌組，通過真實生成、意圖更新、回合及死亡入口。覆蓋首輪與至少一輪完整循環、每條分支、狀態加成下的預告／實傷、提前擊殺、戰鬥結束時仍排隊的效果；召喚物另驗空槽／佔用槽、召喚上限假設及只剩 minion 的結束條件。只直接呼叫 action 無法驗證意圖週期。

評量建議分單體與整個敵群：固定牌組／策略比較改前改後，記錄回合數、生命損失、攻防資源、被迫行動及失敗原因；再換起手、seed、低生命、不同構築及最壞組合。平均值之外保留極端樣本與樣本數，避免把一場可贏當成平衡證明。沒有現成自動平衡器；策略模擬的結果只適用該策略。

依 [validation](validation.md) 選 Smoke、Combat 與本次專項；既有 Combat fixture 不包含所有自訂敵人、召喚或難度。只由當前 runtime owner 執行不開視窗的隔離測試，遵守 [操作邊界](../common/user.md)。預告辨識度、動畫時點與音效感知留為尚未人工驗證，禁止為此開視窗或截圖。

## 交接

交付設計檔、來源與接線 ID、測例／命令／日誌、評量結論及未驗部分。敵群配置接 level-design；原語缺口接 mechanics；呈現接 ui。多筆同質狀態／測例／評量超過 1 KB 時依 [資料契約](../common/data-files.md) 落 `wf-table/1`，不把大量表格塞回入口。可重用且已證實的限制回寫本流程與核實來源；未修缺口保持明示。
