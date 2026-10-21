# 方案／取捨

[README](README.md)

## 4. 方案／取捨

### 4.1 時間軸：每單位獨立時鐘 CTB vs 降級固定序列制

| | (A) 每單位獨立時鐘 CTB（選） | (B) 固定序列制（每輪每單位一次，速度只決定序內順序） |
|---|---|---|
| 符合需求 | 完全（G3） | 部分：速度無法改變頻率 |
| 實作 | 一個優先佇列 + 延遲公式；行動迴圈與 (B) 幾乎相同 | 同樣要拆回合交替；少一個時鐘 |
| 「每回合」語意 | 要改成「每次行動」／「每 N 刻」（§3.2） | 仍可保留「輪」 |
| 可讀性風險 | 高速單位連動、時間軸投影要 UI 支撐 | 低 |
| 降級成本 | **(A) 以資料降級為 (B)**：所有單位速度相同 + `tie_break=SPAWN_ORDER` → 每輪固定順序；延遲操作牌仍可用 | (B) 升級為 (A) 要重寫 |
| 決定 | 採 (A)；(B) 不另寫，當成 (A) 的資料特例，由題材包決定 |

### 4.2 棋盤：TileMapLayer vs 自繪 Control 網格

| | TileMapLayer | 自繪 Control 網格（選） |
|---|---|---|
| 輸入 | 需自行把滑鼠座標換算成格、無 per-cell 事件 | 每格一個 `BoardCell`（Button）→ `cell_clicked/hovered` 訊號；與現有 `Hand`／`Enemy.selection_button`（`Hand._on_enemy_clicked`）同模式，headless 測試可直接 `emit` |
| 單位節點 | `BaseCombatant` 是 Control（`extends Control`），放進 TileMap 要混用 Node2D 座標 | 直接 `add_child` 到格或 UnitLayer，用格的 `global_position` 定位 |
| 高亮／預覽層 | 要多層 TileMap 或自繪 | Control 疊 ColorRect／TextureRect，簡單 |
| 美術 | 自動拼接、大地圖強 | 小棋盤（≤ 9×9）用單一格貼圖即可；內容包給 `encounter_cell_texture_path` |
| 決定 | 不用 | 採用；日後若要大地圖或地形拼接再換 |

### 4.3 AI 規劃器深度

| | 貪婪一步（選） | 兩層前瞻／beam | MCTS |
|---|---|---|---|
| 需要狀態複製 | 否（用 preview 攔截估值） | 是：框架的 Action 直接改活節點，沒有可複製的戰鬥狀態 | 是 |
| 成本 | 可達格×手牌×目標 ≈ 25×10×25，每項一次 preview 攔截 | 乘以出牌序列數，需自建模擬器 | 同左且更重 |
| 品質 | 配合傾向權重與目標偏好，隊員行為可讀、可預測 | 更強但更難解釋 | 同 |
| 決定 | 先做；`BaseUnitController` 介面讓日後換；若要前瞻，先得在 Phase 6 之後做「可序列化戰鬥狀態」 | 延後 | 不做 |

### 4.4 多角色資料：拆出 `PartyMemberData` + proxy vs 直接擴充 `PlayerData`

直接在 `PlayerData` 加陣列但保留主角欄位會造成雙真相（主角 HP 存兩處）。選擇把角色層全部搬進 `PartyMemberData`，`PlayerData` 保留**非 @export 的 proxy 屬性**指向主角（或行動單位，依欄位）讓 60 處舊引用先編譯，Phase 6 再逐一改掉並刪 proxy。代價：過渡期 proxy 隱藏「到底在改誰」的錯誤——以單元測試 `party_data_regression.gd` 鎖定「主角 proxy 寫入 == party[0]」。

### 4.5 HandManager：多實例 vs 單例多牌堆

HandManager 是 autoload，且 `Hand` UI、14 個外部讀者都綁單例；改成每單位一個 HandManager 實例會波及 ActionGenerator/Card/CardData 全部呼叫點。選單例 + `unit_piles` 字典 + active proxy（§3.3）。

### 4.6 舊訊號：刪除 vs 保留重釋

保留 `player_turn_*`／`enemy_turn_*` 重釋語意（主角行動／單一敵人行動）：mods 與 `example_mod` 不會壞；代價是命名誤導，用文件與 `DebugLogger.log_warning`（首次連接時提示一次，可選）緩解。

### 4.7 存檔：拒絕舊檔 vs 遷移

**已決（decisions.json 第 14 列）：拒絕舊檔並提示，不做 v1→v2 遷移。** 遷移（單角色 → 一人隊伍的鍵名對映）技術上成本低，但要長期維護 `SaveMigration` 與真實 v1 fixture；存檔格式仍在開發期，故不採用。`save_load_flow.gd` 的跨程序讀寫骨架改加「拒絕舊格式」階段。
