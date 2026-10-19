# 概念原型總覽：世界觀 × 卡牌 × CTB 時間軸 × 戰棋站位

[design](../README.md)

**狀態**：概念草案，數值皆為佔位，未經使用者確認；未標「使用者」的決定皆為「預設，可改」。出處標記沿用原目錄（`[powers Pxx]` 等，見總覽）。

分檔導航：[戰鬥](concept-battle.md)｜[隊伍](concept-party.md)｜[核心系統](concept-systems.md)｜[遺物藥物與切片](concept-items-slice.md)｜[原型角色](concept-characters.md)｜[原型敵人](concept-enemies.md)

**使用者已定（2026-10-19，依先後）**
1. 免費同人；玩家為原創角色；只走昇華（正）側；大群與凝固者為反派；舞台與主角暫不決定（design/core-loop.md）。
2. 多角色採模型 (a)：各角色獨立牌組／手牌／能量；遺物／金錢／地圖全隊共用。
3. 關卡途中可**招募**隊友並**培養**（各自成長）。
4. 多組敵人先只做**波次**（一組全滅下一組上）；前後排／小隊之後再說。
5. 隊員預設 **AI 控制**（自己選牌獎、購物、戰鬥出牌）；主角由玩家操作；之後可能可切換手動。
6. 戰鬥採 **回合制＋速度（CTB 時間軸）**：每個單位依速度排隊，輪到才行動；這**取代**「全隊輪完才敵方回合」。
7. **站位系統**：只做**雙方共用一張棋盤**（戰棋式：移動、射程、距離、範圍）；最小 **5×5**，更大或長方形由遭遇資料指定。

從 (a) 保留下來的：獨立牌組／手牌／源質、全隊共用遺物金錢地圖；被 CTB 取代的：「回合」結構（本檔一律改成「行動」與「刻」）。

**資料來源**：`/home/lorkhan/repo/narratives/apocalypse/analysis/`。出處記法：`[powers Pxx]`＝powers.md／evidence/powers.json；`[lineages lixxx]`＝powers-catalog.md／evidence/lineages.json；`[item pixxx]`＝evidence/power-items.json；`[adv adxxx]`＝stage5/powers-catalog.md／evidence/advancement.json；`[creature crxxx]`＝bestiary.md／evidence/creature-catalog.json；`[bestiary Bxxx]`、`[factions Fxx]`、`[world Wxx]`＝各 md 證據編號。標「同人新增」者為原作沒有的規則或名稱。依 design/core-loop.md，本檔不收原文段落，只做規則轉譯。

**框架假設（基線）**：Slay-The-Robot 有 HP／格擋／能量／抽棄牌／狀態／敵人意圖權重圖（`enemy_intents`、`intent_initial`）／遺物／藥物／單一玩家實體／回合制。本檔的 CTB、棋盤、多單位、AI 隊員皆為新增層。

---

## 詞彙速查

（表已抽到 [table-vocab.json](table-vocab.json)，18 列；欄位：用語、遊戲定義、原作對應）

---
