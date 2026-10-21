# 戰鬥遭遇 — 普通、精英與 Boss

[關卡入口](../level-design.md)｜[敵人設計](../enemy-design.md)｜[來源核實](../../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：把敵人組成一場可到達戰鬥，指定難度定位與獎勵。**何時不用**：單體意圖與動畫走 enemy-design，整幕拓撲走 [map-act](map-act.md)。

## Done when

設計檔列出敵群槽位、普通／精英／Boss 定位、威脅與反制、池／位置 ID 及預期獎勵；真實載入與到達入口的斷言存在。測試日誌包含首輪、完整意圖循環、勝敗及退出，必要召喚／難度／跨幕分支有結果；未跑或未覆蓋部分明列。

## 流程

### 先找到可用的最小範例

從 [GlobalTestDataGenerator](../../../../game/autoload/GlobalTestDataGenerator.gd) 的 `add_test_events()`、`add_test_enemies()`、`add_test_acts()` 找相近內容：`event_act_1_easy_combat_1` 是多槽普通戰鬥，`event_act_1_miniboss_1` 是精英，`event_act_1_boss_1` 使用指定位置並預留召喚槽。這些是框架範例，不是本遊戲平衡標準；新內容沿 [content](../content.md) 放獨立 mod（external/data 只有映射、沒有可複製的敵人 JSON，見[核實](../../../../analysis/slay-the-robot/design/encounters.md#遭遇池與資料接線)）。

先按 enemy-design 定義每名敵人的角色與完整意圖圖，再按整隊檢查同步爆發、狀態互補、擊殺順序與最壞組合。指定起始牌組、前置生命／資源及評量策略；普通、精英、Boss 的差異不能只靠 HP。敵群 budget 是任務約束，沒有自動限制生成的欄位。

### 完成 ID 鏈

[EnemyData](../../../../game/data/prototype/EnemyData.gd) → [EventData](../../../../game/data/readonly/EventData.gd) → [EventPoolData](../../../../game/data/readonly/EventPoolData.gd) → [ActData](../../../../game/data/readonly/ActData.gd) → [LocationData](../../../../game/data/mutable/LocationData.gd)。

`event_weighted_enemy_object_ids` 是每槽一個加權字典（不是整隊二選一），生成與指定位置的規則見[核實的遭遇接線](../../../../analysis/slay-the-robot/design/encounters.md#遭遇池與資料接線)。接線時檢查 ID 存在、權重非負且總和正、每槽組合可接受；指定配置設 `event_enemy_placement_is_automatic=false` 並提供足夠 positions，召喚也使用同一槽索引。初始與戰後 actions 分別放 `event_initial_combat_actions`、`event_post_combat_actions`。

普通池接 Act 的 easy/hard，精英接 miniboss，Boss 接 boss；地圖節點仍須是 COMBAT/MINIBOSS/BOSS，才由 [Combat 的訪問 handler](../../../../game/scripts/ui/Combat.gd) 啟動。敵人的 `enemy_type` 與節點 `location_type` 分別負責敵人分類和場景路由；只改前者不會生成精英節點或改節點獎勵。池的抽取規則與路線可達性見 [map-act](map-act.md#寫圖不變條件與池契約)；加入池不保證每局出現。

### 指定棋盤大小（掛棋盤時）

每場戰鬥的棋盤大小寫在 EncounterData：`encounter_boards.party.size`／`encounter_boards.enemy.size` 分別指定雙盤寬高（如 `[3, 3]`、`[8, 6]`），或用 `encounter_board_size` 一次套所有盤；省略就沿用規則預設 5×5。預設允許 3×3 到 12×12，部署、生成、障礙、初始場域與波次格都要落在所屬盤內，否則該場以清楚的錯誤拒絕建立棋盤。JSON 範例、上下限理由與錯誤代碼見 [每場戰鬥的棋盤大小](../../../specs/board-module/board-size.md)；帶內容包跑 Smoke 可提早列出不合格的遭遇。換大小後重跑該遭遇的站位、射程與波次測例，實際觀感交人工試玩。

### 核對收益與終局

`event_has_combat_rewards` 是總開關；獎勵生成時點、稀有度與金錢範圍見[核實的獎勵段](../../../../analysis/slay-the-robot/design/encounters.md#獎勵overlay-與存檔邊界)，EventData 沒有金錢 budget 欄。自訂收益沿實際 action／interceptor 管線，不新增無消費端欄位。最終戰不顯示一般戰後獎勵，設計最終 Boss 收益前先看 [map-act 的終局出口](map-act.md#指定跨幕終局與保存邊界)，判斷是否要改終局機制。

### 分開驗接線、行為與平衡

[combat_fixture](../../../../tests/combat_fixture.gd) 示範用固定 HP／牌組註冊敵人及 event；[combat_flow](../../../../tests/combat_flow.gd) 綁 fixture event 時會覆蓋 event ID，不能用來證明新事件已自然進池。runner、路線與 GUI 的共同規則見[共同驗收](../level-design.md#共同驗收)。

接線測例先檢查載入 ID／pool／fallback／Act 引用，再以固定 seed 及玩家可走的邊進入新遭遇。行為測首輪、完整循環、分支、死亡、勝敗與獎勵；有召喚時驗空槽／滿槽及只剩 minion。改難度意圖前先處理 [override cache 未篩玩家難度的缺口](../../../../analysis/slay-the-robot/design/encounters.md#敵人能力的現有缺口)。平衡評量以整個敵群為單位，做法與限制見 [敵人的專項回歸與評量](../enemy-design/regression.md#回歸與評量)。

## 交接

交付敵人／事件／池／Act IDs、各槽及最壞組合、測例結果、版本／seed 與未驗內容。改路線交 map-act，新增原語交 mechanics。
