# enemy-design — 敵人角色、意圖與遭遇驗收

[遊戲開發](README.md)｜[內容接線](content.md)｜[關卡設計](level-design.md)｜[核實來源](../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：設計／調整普通敵人、精英、boss、召喚物，以及它們的回合節奏、意圖與隊伍組合。

**何時不用**：只換敵人圖像／音效接 [UI](ui.md)；現有 Action 無法表達行為接 [mechanics](mechanics.md)；整個 act 的節奏接 level-design。沒有玩法需求時只建立設計候選，不加入遊戲。

## 最小可行範例

下例節錄自 [demo_enemy_anchor.json](../../../examples/board-lab/pack/enemies/demo_enemy_anchor.json)，只保留 `intent_initial` 加一個自迴圈攻擊意圖，刪去機會攻擊與防禦意圖；框架內建的更多寫法見 [GlobalTestDataGenerator](../../../game/autoload/GlobalTestDataGenerator.gd) 的 `add_test_enemies()`。`enemy_type=0` 為 STANDARD，`enemy_intent_target_rule=4` 為 HERO，`enemy_intent_move=0` 為 HOLD，`enemy_intent_display_types` 的 0 為 ATTACKING，須隨 enum 重新核對。

```json
{
  "patch_data": {},
  "properties": {
    "object_id": "demo_enemy_anchor",
    "enemy_name": "定點守衛",
    "enemy_health": 14,
    "enemy_health_max": 14,
    "enemy_health_max_random_lower": 14,
    "enemy_health_max_random_upper": 14,
    "enemy_type": 0,
    "enemy_intents": {
      "intent_initial": {
        "object_id": "intent_initial",
        "enemy_intent_overrides_id": "intent_initial",
        "enemy_intent_name": "進場",
        "enemy_intent_number_of_attacks": 0,
        "enemy_intent_next_intent_weights": {"demo_enemy_anchor_attack": 1},
        "enemy_intent_target_rule": 4,
        "enemy_intent_move": 0
      },
      "demo_enemy_anchor_attack": {
        "object_id": "demo_enemy_anchor_attack",
        "enemy_intent_overrides_id": "demo_enemy_anchor_attack",
        "enemy_intent_name": "定點短擊",
        "enemy_intent_attack_damage": 4,
        "enemy_intent_number_of_attacks": 1,
        "enemy_intent_display_types": [0],
        "enemy_intent_next_intent_weights": {"demo_enemy_anchor_attack": 1},
        "enemy_intent_target_rule": 4,
        "enemy_intent_move": 0
      }
    }
  }
}
```

原檔另有動畫、貼圖、速度、站格大小與 `enemy_intent_range` 等欄位；接入遊戲時以原檔與 [EnemyData](../../../game/data/prototype/EnemyData.gd) 為準，並依 content 登記 enemies 資料夾。新增敵人一律依 [validation 的棋盤開關](validation.md#棋盤開關兩種模式都要驗) 跑兩種模式。

## Done when

任務 spec（`games/<game>/design/specs/`）存在，寫明敵人 ID、角色、出現階段、目標牌組假設、各意圖／轉移／反制、難度差異與通過門檻。實作任務另有載入與遭遇接線檔；專項測試輸出包含初始意圖、轉移、預告與效果、死亡／召喚及難度邊界斷言，命令回傳預期結果。設計評量記錄填妥版本、seed、牌組、操作策略、結果與未驗項目；文件 lint 通過（見 [testing](../testing.md#文件檢查修改後必跑)）。純設計交付不得標成玩法已驗收。

## 流程

### 先建立可檢驗的敵人角色

讀 [EnemyData](../../../game/data/prototype/EnemyData.gd)、[EnemyIntentData](../../../game/data/readonly/embedded/EnemyIntentData.gd)，沿核實來源追到執行者，不從教學註解推定能力；核對基準與重查時機見 [validation](validation.md#現有基準與命令)。

以下是設計建議，並非框架自動規則：用一句話說玩家應學會什麼決策，例如「在蓄力回合留資源防守」，再指定可反制的方法與錯誤決策的代價。記下預期可用的牌組、費用、抽牌、生命與前置遭遇；普通／精英／boss 的定位不能只靠血量區分。boss 階段、血量觸發或反覆使用限制不是現成的狀態機欄位，需求出現時先確認需要哪個自訂 action／validator。

先以單體最小循環表達角色，另列容易混淆的意圖及最壞的連續壓力。定義可觀察門檻，例如在指定起始牌組與策略下的存活回合、生命損失範圍、是否存在回應窗口；數值由本遊戲目標決定，不抄參考作品當公認平衡常數。

### 將意圖寫成完整狀態圖

從 `intent_initial` 指向第一輪可用意圖，每個可到達狀態寫出傷害×次數、格擋、custom actions、下一狀態權重與預告內容。權重須非負、總和大於零，目標 ID 全部存在；需要停留時明確寫自迴圈，不用空權重代表「維持原狀」（空權重實際行為與程式旁註解不符，見 [核實來源](../../../analysis/slay-the-robot/design/encounters.md#敵人能力的現有缺口)）。

意圖切換時點（[CombatDirector](../../../game/scripts/combat/CombatDirector.gd) 在敵人進入時間軸等待時呼叫 `decide_next_intent()`）、`build_intent_actions_data` 的 stack 次序（reset → block → attack → 逆序 custom actions）與 PRE／POST 回合時點見 [核實來源](../../../analysis/slay-the-robot/design/encounters.md#敵人資料與意圖時序)；有無棋盤模組的分派見 [棋盤意圖核實](../../../analysis/slay-the-robot/design/board-intents.md#可選模組與普通戰鬥)。「先上易傷再攻擊」須測實際次序。

意圖在執行前被拒絕（例如未掛棋盤時的盤面專屬 payload）時不保留該意圖，下次行動照常輪替；`Enemy.decide_next_intent` 也會跳過需要未掛模組的意圖（嘗試次數以意圖數為上限）。回歸在 [boardless_intent_cases](../../../tests/boardless_intent_cases.gd)，核實見 [棋盤模組分析](../../../analysis/slay-the-robot/design/board-module.md)。設計敵人時，NONE 模式下至少要有一個不需模組的可到達意圖，否則該敵人在未掛棋盤時只會反覆跳過。

預告數字與圖示推導的限制見 [核實來源](../../../analysis/slay-the-robot/design/encounters.md#敵人資料與意圖時序)：新 custom action 腳本須同步描述／圖示契約，純防禦或召喚意圖要明確把傷害與攻擊次數設為 0。重複預覽前後比較狀態、RNG 與資源，證明預覽不改遊戲；數字斷言不等於玩家已看得懂。

### 棋盤意圖與模組開關

雙盤定位、移動意圖、模組 on/off 的拒絕規則與移動測例見 [棋盤意圖與模組開關](enemy-design/board-intents.md)。

### 難度與遭遇接線

血量用上下界與 `add_health_bounds()`。難度表欄位的實際拼字，以及 `add_intent_state()` 難度版本的 override cache 未依玩家難度篩選的缺口，見 [核實來源](../../../analysis/slay-the-robot/design/encounters.md#敵人能力的現有缺口)。設計依賴此能力時，先建立最低、門檻前、門檻及最高難度的失敗測例並接 mechanics 修正，不宣稱現成的難度切換可用。

依 content 註冊 mod 資料；接入可到達遭遇的 ID 鏈、生成槽語意與指定位置見 [戰鬥遭遇](level-design/combat.md#完成-id-鏈)。各槽組合可能產生單體設計未遇到的連鎖壓力；確認敵人種類、minion、初始狀態、動畫與死亡 action。

### 建立專項回歸與評量

固定 seed 的專項回歸、單體與敵群評量、應選的 suite 見 [專項回歸與評量](enemy-design/regression.md)。

## 交接

交付設計檔、來源與接線 ID、測例／命令／日誌、評量結論及未驗部分。敵群配置接 level-design；原語缺口接 mechanics；呈現接 ui。多筆同質狀態／測例／評量超過 1 KB 時依 [資料契約](../common/data-files.md) 落 `wf-table/1`，不把大量表格塞回入口。可重用且已證實的限制回寫本流程與核實來源；未修缺口保持明示。
