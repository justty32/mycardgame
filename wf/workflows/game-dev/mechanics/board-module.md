# board-module — 棋盤掛載、關閉與普通戰鬥

[機制入口](../mechanics.md)｜[架構分析](../../../specs/board-module/README.md)｜[場域與控制區](../fields-zoc.md)｜[資源生命週期](../resource-lifecycle.md)

**何時用**：改棋盤可選裝配、模組生命週期、無棋盤戰鬥、棋盤出牌接點，或把新增空間機制掛回 Combat。只新增既有原語可表達的卡牌／場域內容，先走 [content](../content.md)。

## Done when

掛載與 NONE 都經正常戰鬥入口驗證；普通出牌費用、敵人意圖、波次與勝敗沒有因關閉棋盤而失效；盤面專用內容有明確拒絕。新接點具有失敗回歸、清理與重開證據，分析與操作流程同步。若只有靜態核對，必須明列尚未驗證項目，不填 PASS。

## 先確定裝配與範圍

每場 0~N 盤先讀 [資料格式 v1](../../../specs/board-module/encounter-format.md)；[調查 H0](../../../notes/investigations/2026-10-21-multi-board-feasibility.md) 的先裝配後解析是 `7eba093` 舊基準。PreparedEncounter 區分 legacy、合法 0、明確正盤與錯誤；0 不掛模組，明確正盤缺能力拒絕，舊格式保留 fallback。改開戰入口時沿同份 prepared，不自行再查 Global 遭遇；本場規則讀 `get_combat_rules`，下一場準備讀 `get_configured_combat_rules`。正式入口、失敗與專項見 [C 分析](../../../../analysis/slay-the-robot/architecture/10_multi_board_encounters.md)。不得以空 Battlefield 或舊空覆寫字典冒充 0，也不從 faction／首末盤猜新格式位置。

讀 [Combat.gd](../../../../game/scripts/ui/Combat.gd)、[CombatDirector.gd](../../../../game/scripts/combat/CombatDirector.gd)、[BoardCombatModule.gd](../../../../game/scripts/combat/board/BoardCombatModule.gd)，確認場景 `board_module_enabled` 與 rules `board_enabled` 的實際值（兩者都開才掛載，見 [架構分析的裝配與責任](../../../specs/board-module/README.md#裝配與責任)）。不要把 SINGLE、隱藏 BoardView、空棋盤或零移動點當作關閉功能。

盤定義、部署與呈現的接點見 [遷移 B 分析](../../../../analysis/slay-the-robot/architecture/09_board_setup_layout.md)：幾何消費 BoardSetup 集合，舊 mode 只在相容轉譯解讀；部署政策只產位置，BoardLayout 只產畫面矩形。不能把 party／enemy 或畫面槽數重新塞回通用盤定義。首波 `use_event_slots` 由 prepared 的格式選擇，新正盤不受畫面槽限制，舊內容預設不變；改呼叫時同時核對顯式 Encounter 的 positional 相容測例。

先定義改動是在開局前切換內容設定，還是要支援戰鬥中真正卸載 Node。後者必須涵蓋排隊請求、await 恢復、舊實例延遲 exit 與新實例身份；不要在未完成相關驗收前把「可選掛載」擴稱成任意時刻熱切換。

場景負責組裝元件：Combat 只在兩個旗標都開且 `BOARD_MODULE_SCRIPT` 檔案存在時以路徑 load BoardCombatModule。Director 保留普通 CTB、Encounter、waves 與行動流程，只經核心 [CombatModule](../../../../game/scripts/combat/CombatModule.gd) 介面的 hooks（setup／clear、單位進出、行動開始、時鐘、出牌、目標解析、敵人意圖、威脅、放置）呼叫模組，不引用任何棋盤類別；缺模組內容由 [CombatContentRequirements](../../../../game/scripts/combat/CombatContentRequirements.gd) 以資料標記判定。棋盤幾何、場域、移動、undo、盤面威脅與呈現歸模組。核心的 `board_*` 查詢只是無型別相容轉送，未掛載回 null；不能讓核心在缺模組時偷偷 new 棋盤來補洞，也不能在核心新增棋盤類別引用（會讓 BoardRemoved 失敗）。新需求先加在 CombatModule hooks，不為單一棋盤元件建立通用 plugin 系統。完整介面與刻意保留的殘留耦合見 [架構分析](../../../specs/board-module/README.md)。

搬動呈現節點時，先搜尋程式與全部測試裡的硬路徑：呈現搬進模組後，直取 `Combat/BoardView` 的舊 Board 回歸就曾因此失敗。擴充改走 Combat 相容 getter 或模組 owner，並保留節點有效、在樹內與可見性的斷言；不能只刪掉失效的檢查。

## 實作時保留普通流程

先追一場 NONE 的新局到結束，確認 [普通戰鬥與棋盤戰鬥](../../../specs/board-module/README.md#普通戰鬥與棋盤戰鬥) 所列的生成、波次、普通意圖、狀態、能量、抽棄牌與行動時鐘照常。Encounter 不能由 board getter 間接取得；掛載模式落格失敗不能退回無盤出生繞過碰撞檢查。

改卡牌接線時先讀 [CardPlayAdapter](../../../../game/scripts/combat/CardPlayAdapter.gd)、[BoardCardAdapter](../../../../game/scripts/combat/board/BoardCardAdapter.gd) 及 [HandManager](../../../../game/autoload/HandManager.gd)。adapter hooks 只選擇、驗證及提供執行資料，扣費、保留能量、退款與牌堆去向仍歸原流程（見 [出牌接點與費用原義](../../../specs/board-module/README.md#出牌接點與費用原義)）；入隊前拒絕不扣費，出隊拒絕沿既有退款，不再退第二次。

對盤面專用 actions、validators、目標 override 與巢狀 payload 做能力檢查；普通牌不能被一律拒絕。自動出牌與複製出牌也必須經過同一檢查。敵人意圖若含盤面專用效果，整份意圖的接受／拒絕要明確，避免普通傷害先發生再跳過位移。來源、別名與巢狀 payload 的解析以實際 BoardContentPolicy 為準。

## 停止、死亡與再次開始

維護 setup／clear 的成對責任；清理次序、死亡時保留呈現目的位置與實例身份的解除，見 [停止與重建](../../../specs/board-module/README.md#停止與重建)。不要清掉別的場景 registry，也不要讓下一場 NONE 的主角保留上一場有效格位。

若新增 await、回指或延遲 callback，依 [資源生命週期](../resource-lifecycle.md) 檢查停止後復原、同步停止與重複 clear。直接卸載實例時也要清核心引用，且舊實例的 exit 不能把新實例清掉。

## 驗證與交付

依 [testing](../../testing.md) 與 [validation 的棋盤開關](../validation.md#棋盤開關兩種模式都要驗) 交由單一 runtime owner 串行執行隔離 headless（至少 `--suite Boardless` 與 `--suite DualBoard`）。先用普通攻擊／防禦卡證明 NONE 可玩，再驗關閉狀態下的移動、場域、範圍選格牌明確拒絕；檢查能量、保留總額、牌堆及 action 數，不能只看錯誤字串。

覆蓋掛載到下一場 NONE、NONE 到掛載、死亡後重開、後續 wave、存讀續玩。若宣稱支援真正卸載，增加「排隊後卸載 → 出隊拒絕且只退一次 → 普通牌仍可打 → 重掛後舊請求仍拒絕」；模組 instance、模組 generation 與 Director generation 都要在證據中可辨識，並驗同一個 Node 重新使用時舊請求仍失效。既有 Board／DualBoard／Field／Wave 回歸用來排除拆分造成的語義改變，不能取代 NONE 專項。

交付記錄實際引擎、來源與測試 hash、日誌、失敗及重跑結果；原始碼凍結後發現問題先通知整合 owner，再修指定範圍並更新證據。文件 lint 與框架／題材邊界檢查由整合 owner 收尾（見 [testing](../../testing.md#文件檢查修改後必跑)）。headless 測試不能寫成視覺驗收。
