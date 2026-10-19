# 目標、非目標與現況分析

[README](README.md)

## 1. 目標與非目標

### 目標（使用者 2026-10-19 決定，框架通用）

（表）已抽到 [goals.json](goals.json)（6 列）。欄位：#、能力、一句話。

框架預設值（`CombatRulesData`，見 §3.1）維持「單一主角、速度全同、每次行動補滿能量、抽 5、行動末棄手牌」，讓現有框架測試資料與回歸在語意上仍成立；題材包以 patch 改成自己的節奏。

### 非目標（本 spec 不做）

- 戰鬥中存檔／讀檔（現行只在到達地點與開局 autosave，`FileLoader.gd:462-470`；棋盤與時間軸不序列化）。
- 地形格、視線、障礙物、單位朝向與旋轉（資料欄位預留，不實作判定）。
- 深度搜尋型 AI（MCTS／多層前瞻）；本 spec 只做貪婪一步評分，但介面可插拔。
- 手動切換隊員的 UI（只做 `member_control_mode` 旗標與控制器分派）。
- 前後排／多小隊、士氣、首領光環等題材規則（由內容包用狀態效果／攔截器自行組合）。
- 任何題材名詞或數值。

---

## 2. 現況分析：要拆掉的單玩家／回合交替假設

### 2.1 單玩家實體（一個 `Player` 節點 + `Global.player_data` 即角色）

（表）已抽到 [current-single-player.json](current-single-player.json)（9 列）。欄位：假設、出處、影響。

### 2.2 回合交替（玩家回合 → 敵方回合 → …）

（表）已抽到 [current-turn-based.json](current-turn-based.json)（18 列）。欄位：假設、出處、影響。

### 2.3 可以不動的部分（沿用）

Action／Interceptor 管線（`ActionHandler`、`BaseAction._intercept_action` 的 preview 模式可拿來做 AI 估值與意圖預覽）、狀態效果容器（`BaseCombatant.gd:204-396`）、SerializableData／mod 載入（`FileLoader.gd:207-283`）、RNG 軌道（`PlayerData.get_player_rng`）、獎勵與商店資料（`ShopData`、`ActionGrantRewards`）、`CustomUI`／`CustomSignal` 擴充點。
