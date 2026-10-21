# 目標、非目標與現況分析

[README](README.md)

## 1. 目標與非目標

### 目標（使用者決定，框架通用）

**G1 隊伍**：主角由玩家操作；隊員可局中招募、各自培養（牌組／HP／能量上限／升階各自獨立，「模型 a」）；遺物、金錢、藥物、地圖全隊共用

**G2 隊員 AI**：隊員預設 AI 控制：戰鬥自行移動／出牌，局外自行選牌獎、購卡；控制模式是資料旗標，之後可切手動

**G3 CTB 行動條**：所有單位（主角、隊員、敵人、召喚物）依速度排在同一條時間軸；速度快者行動頻繁；畫面顯示未來順序；**取代**我方／敵方回合交替

**G4 棋盤（可選模組）**：〔已修正：原寫「雙方同一張戰棋棋盤」，已由雙盤 A 與「棋盤為可選掛載模組」取代，見 [decisions.json](../../workflows/decisions.json) 第 18、21 列〕棋盤是戰鬥場景可選掛載的模組：未掛載時為普通卡牌戰鬥；掛載時採雙盤 A（雙方各一盤，特殊卡可跨盤移動／交換）。棋盤提供移動、射程、距離、範圍形狀、大型單位佔多格；尺寸由遭遇資料指定（最小 5×5，可 7×7 或長方形）

**G5 波次**：一場遭遇可含多組敵人，一組全滅下一組進場；由遭遇資料定義

**G6 內容包驅動**：角色、卡、敵、遭遇、AI 傾向參數、升階曲線全由 JSON 內容包提供；框架定義資料類別並登記到 `Global.SCHEMA`／`CLASS_NAME_TO_CLASS`

框架預設值（`CombatRulesData`，見 §3.1）維持「單一主角、速度全同、每次行動補滿能量、抽 5、行動末棄手牌」，讓現有框架測試資料與回歸在語意上仍成立；題材包以 patch 改成自己的節奏。

### 非目標（本 spec 不做）

- 戰鬥中存檔／讀檔（現行只在到達地點與開局 autosave，`FileLoader.autosave()`；棋盤與時間軸不序列化）。
- 地形格、視線、障礙物、單位朝向與旋轉（資料欄位預留，不實作判定）。
- 深度搜尋型 AI（MCTS／多層前瞻）；本 spec 只做貪婪一步評分，但介面可插拔。
- 手動切換隊員的 UI（只做 `member_control_mode` 旗標與控制器分派）。
- 前後排／多小隊、士氣、首領光環等題材規則（由內容包用狀態效果／攔截器自行組合）。
- 任何題材名詞或數值。

---

## 2. 現況分析：要拆掉的單玩家／回合交替假設

本節是開工前（2026-10-19）舊樹的盤點，「出處」行號指舊樹、僅供考古；多數假設已在 Phase 0–3 拆除，現況以 [code-map/combat-framework](../../workflows/common/code-map/combat-framework.md) 為準。

### 2.1 單玩家實體（一個 `Player` 節點 + `Global.player_data` 即角色）

（表）開工前現況快照已隨 Phase 0–3 完成而封存；現況見 [code map](../../workflows/common/code-map/combat-framework.md)。

### 2.2 回合交替（玩家回合 → 敵方回合 → …）

（表）開工前現況快照已隨 Phase 1 改為 CTB 而封存；現況見 [code map](../../workflows/common/code-map/combat-framework.md)。

### 2.3 可以不動的部分（沿用）

Action／Interceptor 管線（`ActionHandler`、`BaseAction._intercept_action` 的 preview 模式可拿來做 AI 估值與意圖預覽）、狀態效果容器（`BaseCombatant` 的 `add_new_status_effect`、`perform_status_effect_process_actions` 等）、SerializableData／mod 載入（`FileLoader.load_read_only_data`）、RNG 軌道（`PlayerData.get_player_rng`）、獎勵與商店資料（`ShopData`、`ActionGrantRewards`）、`CustomUI`／`CustomSignal` 擴充點。
