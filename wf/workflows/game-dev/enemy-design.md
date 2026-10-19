# enemy-design — 敵人角色、意圖與遭遇驗收

[遊戲開發](README.md)｜[內容接線](content.md)｜[關卡設計](level-design.md)｜[核實來源](../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：設計／調整普通敵人、精英、boss、召喚物，以及它們的回合節奏、意圖與隊伍組合。

**何時不用**：只換敵人圖像／音效接 [UI](ui.md)；現有 Action 無法表達行為接 [mechanics](mechanics.md)；整個 act 的節奏接 level-design。沒有玩法需求時只建立設計候選，不加入遊戲。

## Done when

任務設計檔存在，寫明敵人 ID、角色、出現階段、目標牌組假設、各意圖／轉移／反制、難度差異與通過門檻。實作任務另有載入與遭遇接線檔；專項測試輸出包含初始意圖、轉移、預告與效果、死亡／召喚及難度邊界斷言，命令回傳預期結果。設計評量記錄填妥版本、seed、牌組、操作策略、結果與未驗項目；文件 strict lint 回傳 0。純設計交付不得標成玩法已驗收。

## 流程

### 先建立可檢驗的敵人角色

讀 [EnemyData](../../../game/data/prototype/EnemyData.gd)、[EnemyIntentData](../../../game/data/readonly/embedded/EnemyIntentData.gd)，沿核實來源追到執行者，不從教學註解推定能力。基準為 2026-10-19 核對的上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復；版本改變先重查。

以下是設計建議，並非框架自動規則：用一句話說玩家應學會什麼決策，例如「在蓄力回合留資源防守」，再指定可反制的方法與錯誤決策的代價。記下預期可用的牌組、費用、抽牌、生命與前置遭遇；普通／精英／boss 的定位不能只靠血量區分。boss 階段、血量觸發或反覆使用限制不是現成狀態機欄位，需求出現時先確認需要哪個自訂 action／validator。

先以單體最小循環表達角色，另列容易混淆的意圖及最壞連續壓力。定義可觀察門檻，例如在指定起始牌組與策略下的存活回合、生命損失範圍、是否存在回應窗口；數值由本遊戲目標決定，不抄參考作品當公認平衡常數。

### 將意圖寫成完整狀態圖

從 `intent_initial` 指向第一輪可用意圖，每個可到達狀態寫出傷害×次數、格擋、custom actions、下一狀態權重與預告內容。權重須非負、總和大於零，目標 ID 全部存在；需要停留時明確自迴圈，不用空權重代表「維持原狀」。目前空權重實際回傳 null，不能相信旁邊的停留註解。

`Enemy._on_player_turn_started()` 切換意圖，敵方回合執行目前意圖。核對 [Combat.perform_enemy_turn](../../../game/scripts/ui/Combat.gd) 的 stack 順序：重設格擋、加格擋、攻擊、custom actions；custom actions 陣列也受逆序影響。狀態處理另分 PRE／POST_ENEMY_TURN 與 PRE／POST_ENEMY_INTENT；「先上易傷再攻擊」必須測實際次序，不能只看 JSON 排列。

預告用 attack／attack-generator 的 preview interception 算數字，圖示來自 `enemy_intent_display_types`。custom action 的視覺推導只有部分已知腳本；新腳本須同步描述／圖示契約。純防禦或召喚意圖明確將傷害與攻擊次數設 0。重複預覽前後比較狀態、RNG 與資源，證明預覽不改遊戲；數字斷言不等於玩家已看得懂。

### 難度與遭遇接線

血量用上下界與 `add_health_bounds()`；一般屬性難度表的實際拼字為 `enemy_difficulty_to_enemy_modfiers`。`add_intent_state()` 可保存同原始 ID 的難度版本，但目前 override cache 未依玩家難度篩選，會挑最高版本。設計依賴此能力時先建立最低、門檻前、門檻及最高難度的失敗測例並接 mechanics 修正，不宣稱現成難度切換可用。

依 content 註冊 mod 資料，沿 `EnemyData → EventData.event_weighted_enemy_object_ids → EventPoolData → ActData／LocationData` 接入可到達遭遇。每個敵群欄位是一個生成槽的加權候選，不是「整隊二選一」；各槽組合可能產生單體設計未遇到的連鎖壓力。指定位置需覆蓋初始與召喚槽；確認敵人種類、minion、初始狀態、動畫與死亡 action。

### 建立專項回歸與評量

先用固定 seed、明確 HP 與最小牌組，通過真實生成、意圖更新、回合及死亡入口。覆蓋首輪與至少一輪完整循環、每條分支、狀態加成下的預告／實傷、提前擊殺、戰鬥結束時仍排隊的效果；召喚物另驗空槽／佔用槽、召喚上限假設及只剩 minion 的結束條件。只直接呼叫 action 無法驗證意圖週期。

評量建議分單體與整個敵群：固定牌組／策略比較改前改後，記錄回合數、生命損失、攻防資源、被迫行動及失敗原因；再換起手、seed、低生命、不同構築及最壞組合。平均值之外保留極端樣本與樣本數，避免把一場可贏當成平衡證明。沒有現成自動平衡器；策略模擬的結果只適用該策略。

依 [validation](validation.md) 選 Smoke、Combat 與本次專項；既有 Combat fixture 不包含所有自訂敵人、召喚或難度。只由當前 runtime owner 執行不開視窗的隔離測試，遵守 [操作邊界](../common/user.md)。預告辨識度、動畫時點與音效感知留為尚未人工驗證，禁止為此開視窗或截圖。

## 交接

交付設計檔、來源與接線 ID、測例／命令／日誌、評量結論及未驗部分。敵群配置接 level-design；原語缺口接 mechanics；呈現接 ui。多筆同質狀態／測例／評量超過 1 KB 時依 [資料契約](../common/data-files.md) 落 `wf-table/1`，不把大量表格塞回入口。可重用且已證實的限制回寫本流程與核實來源；未修缺口保持明示。
