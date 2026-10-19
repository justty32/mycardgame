# 戰鬥遭遇 — 普通、精英與 Boss

[關卡入口](../level-design.md)｜[敵人設計](../enemy-design.md)｜[來源核實](../../../../analysis/slay-the-robot/design/encounters.md)

**何時用**：把敵人組成一場可到達戰鬥，指定難度定位與獎勵。**何時不用**：單體意圖與動畫走 enemy-design，整幕拓撲走 [map-act](map-act.md)。

## Done when

設計檔列出敵群槽位、普通／精英／Boss 定位、威脅與反制、池／位置 ID 及預期獎勵；真實載入與到達入口的斷言存在。測試日誌包含首輪、完整意圖循環、勝敗及退出，必要召喚／難度／跨幕分支有結果；未跑或未覆蓋部分明列。

## 流程

### 先找到可用的最小範例

從 [GlobalTestDataGenerator](../../../../game/autoload/GlobalTestDataGenerator.gd) 的 `add_test_events()`、`add_test_enemies()`、`add_test_acts()` 找相近內容：`event_act_1_easy_combat_1` 是多槽普通戰鬥，`event_act_1_miniboss_1` 是精英，`event_act_1_boss_1` 使用指定位置並預留召喚槽。這些是框架範例，不是本遊戲平衡標準。沿 [content](../content.md) 將新內容放獨立 mod；不要假設 external/data/enemies 已有 JSON 範本。

先按 enemy-design 定義每名敵人的角色與完整意圖圖，再按整隊檢查同步爆發、狀態互補、擊殺順序與最壞組合。指定起始牌組、前置生命／資源及評量策略；普通、精英、Boss 的差異不能只靠 HP。敵群 budget 是任務約束，沒有自動限制生成的欄位。

### 完成 ID 鏈

[EnemyData](../../../../game/data/prototype/EnemyData.gd) → [EventData](../../../../game/data/readonly/EventData.gd) → [EventPoolData](../../../../game/data/readonly/EventPoolData.gd) → [ActData](../../../../game/data/readonly/ActData.gd) → [LocationData](../../../../game/data/mutable/LocationData.gd)。

Event 的 `event_weighted_enemy_object_ids` 每個字典是一個槽的候選與權重，並非整隊二選一。檢查 ID 存在、權重非負且總和正、每槽組合可接受；指定配置時設 `event_enemy_placement_is_automatic=false` 並提供足夠 positions，召喚也使用同一槽索引。執行者在 [EnemyContainer](../../../../game/scripts/ui/EnemyContainer.gd)。初始與戰後 actions 分別放 `event_initial_combat_actions`、`event_post_combat_actions`。

普通池接 Act 的 easy/hard，精英接 miniboss，Boss 接 boss；地圖節點仍須是 COMBAT/MINIBOSS/BOSS，才由 [Combat 的訪問 handler](../../../../game/scripts/ui/Combat.gd) 啟動。敵人的 `enemy_type` 與節點 `location_type` 分別負責敵人分類和場景路由；只改前者不會生成精英節點或改節點獎勵。

池補充時去重洗牌，不是加權表；重複 event ID 不會提高機率。固定 `location_event_object_id` 優先於 pool，首次求 event 會消耗池並寫回位置。需要必定出現時使用固定位置／自訂生成，而非聲稱「加入池即保證每局出現」。fallback 與失敗策略限制、路線可達性見 map-act。

### 核對收益與終局

`event_has_combat_rewards` 是總開關。獎勵由 [RewardOverlay](../../../../game/scripts/ui/RewardOverlay.gd) 在 combat_started 時生成，稀有度依 [Random](../../../../game/autoload/Random.gd) 與節點種類，金錢預設 25–49；EventData 沒有金錢 budget 欄。自訂收益沿實際 action／interceptor 管線，不新增無消費端欄位。

非終局幕 Boss 戰後經獎勵 Continue 生成下一幕；最終戰的 combat_ended 由 [RunSummaryOverlay](../../../../game/scripts/ui/RunSummaryOverlay.gd) 直接發 run_victory，RewardOverlay 不顯示一般戰後獎勵。設計最終 Boss 收益時須先釐清是否需要改終局機制，完整流程見 [game-flow](../game-flow.md)。

### 分開驗接線、行為與平衡

[combat_fixture](../../../../tests/combat_fixture.gd) 示範用固定 HP／牌組註冊敵人及 event；[combat_flow](../../../../tests/combat_flow.gd) 用 `Global.get_next_locations()` 找相鄰戰鬥、綁 fixture event，再觸發真正地圖按鈕 signal。可重用此模式建立專項，但它會覆蓋 event ID，所以不能用來證明新事件已自然進池。

接線測例先檢查載入 ID／pool／fallback／Act 引用，再以固定 seed 及玩家可走的邊進入新遭遇。行為測首輪、完整循環、分支、死亡、勝敗與獎勵；有召喚時驗空槽／滿槽及只剩 minion。改難度意圖前先處理已知 override cache 未篩玩家難度的缺口。

現有命令為 `python3 tools/test_game.py --suite Smoke` 與 `--suite Combat`；新增遭遇測試須由 runner owner 接入 [隔離 runner](../../../../tools/test_game.py) 才有可執行命令，現在沒有 Encounter suite。依 [validation](../validation.md) 回報專項命令／完成標記；不得只以舊 fixture 綠燈交付。

平衡比較固定牌組／策略的改前改後，再換 seed、起手與低生命條件；記錄回合、生命損失、被迫行動、極端樣本及樣本數。沒有現成自動平衡器，一場可贏不證明平衡。

## 交接

交付敵人／事件／池／Act IDs、各槽及最壞組合、測例結果、版本／seed 與未驗內容。改路線交 map-act，新增原語交 mechanics；實際視覺預告與操作命中不可用 headless 數字斷言代替。
