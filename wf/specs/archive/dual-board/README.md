> 封存 2026-10-20，由 analysis/slay-the-robot/design/dual-board/README.md 取代

# 雙棋盤 A：契約與 C 演進邊界

[INDEX](../../INDEX.md)｜[既有戰鬥框架](../combat-framework/README.md)｜[Phase 2b 暫停交接](../../plans/combat-framework/phase-2b.md#暫停交接)

**方向已決／已授權實作。** 使用者於 2026-10-20 要求敵人與玩家各一棋盤，先規劃與估成本，確認「一般各守自己的盤，但特殊卡可跨盤移動或交換位置」，並選擇「先 A，但保留 C 的可能性」。使用者隨後已授權依此實作、headless 回歸與同步分析／工作流；既有單棋盤歷史 spec 不改成新決議。

## 已確認與待定

兩盤各有格子、佔格與局部移動；特殊卡可以跨盤移動或交換。單位進入另一盤仍保留原陣營，`board_id` 不能由 `faction` 推導。盤的名稱表示初始配置，不代表只准該陣營佔格。沿用同一場戰鬥與 CTB 時間軸，無需拆成兩場戰鬥。

已選 A：跨盤直接選格、不計盤間距離，局部範圍在目標盤展開。這不等於忽略目標陣營、可選盤、遮擋或格子合法性，也不等於自動允許普通步行跨盤。同盤攻擊仍保留既有距離契約。

使用者同日已決：**第一版不支援方向型跨盤效果**。按現有 `TARGET_SHAPES`，跨盤拒絕 LINE／LINE_PIERCE；需要從另一盤來源推導方向的 PUSH／PULL／PULL_ADJACENT 同樣拒絕。CONE 目前不是框架 enum，本輪不新增它。拒絕須在費用／移動等副作用前發生，預覽、validator、實際出牌與敵方意圖一致，不能默默改成單點或任意局部方向。

跨盤可按 A 展開的現有形狀為 SINGLE、ROW、COLUMN、CROSS、SQUARE_3；裁切到目標盤邊界。SELF_AREA 保持施法者實際盤為中心；ALL 形狀明確限定選定盤，與全戰場 ALL_OPPONENTS 的 target override 分開，不借 A 偷改全域目標集合。NONE 不產生格子。沒有現成 CIRCLE／CONE 不代表第一版承諾新增。

同盤與跨盤依當下來源／目標的 board_id，**不依陣營**：特殊卡入侵後與敵人同盤時，既有 range、LINE／LINE_PIERCE、PUSH／PULL 仍合法。先前允許的顯式跨盤 transfer／swap 指定目的位置或兩單位，不受方向型禁用一刀排除；各卡費用等仍屬內容設定。
## 工程架構

已加入 `BoardPosition(board_id, cell)` 與 `CombatBattlefield`；後者持有兩個 `BoardData`，單位保留實際盤身分。單盤繼續管格子、佔格、尋路、場域、同盤相鄰；Battlefield 管查盤、跨盤目標與原子移動／交換。Director 仍負責唯一 CTB 與勝敗，將 tick 分派到兩盤，而行動開始／生成分派到單位實際所在盤。

跨盤 move／swap 先驗兩端盤身分、邊界、footprint、障礙、傳送限制及佔格，再一次提交；預檢或佔格提交失敗時兩端位置完全不變。工程事件序為兩端提交成功、帶盤移動訊號、原盤借機攻擊、原盤 leave、新盤 enter，逐步重驗位置與生命週期；這不表示已發生的傷害或觸發副作用可以回滾。場域、借機攻擊或其子行動可殺死單位或結束戰鬥，後續事件需重新查生命週期，不能在 signal 中途留下半個交換。普通 transfer 計一次移動，強制 swap 計一次位移；不捏造盤間距離。不可位移／禁傳送仍檢查，強制 ZOC 預設豁免、可由規則開啟。

普通步行不得越盤，跨盤只由顯式 Action 授權。同盤 ZOC 仍按實際敵對陣營判斷；入侵者在對方盤會產生正常相鄰控制區。跨盤邊界投射 ZOC 屬額外玩法，本方案沒有假定要做。

## 單一規則入口與未來 C

`CrossBoardPolicy.resolve` 是跨盤規則唯一解析入口，接收 battlefield、source／target 位置、shape、max_range、footprint 與 movement；卡牌／意圖先由 caller 正規化，再取得合法性和解析結果。Action、validator、UI、意圖與 preview 都消費同一結果；不在各處硬寫「跨盤不驗射程」。同盤與跨盤的判斷也在此入口，避免入侵單位被錯當還在原盤。

第一版僅 A；版本化契約為 `cross_board_policy_version = 1`、`cross_board_policy = SELECT_TARGET_CELL`。雙棋盤設定缺 policy 時明確採 v1/A；未知值或不支援版本拒絕並提供診斷，不默默降回 A。正常新局預設 DUAL；舊單盤回歸明確指定 SINGLE，不能因缺欄位就忽略既有射程。shape 的半徑／長度與跨盤射程分開，不能把 `card_range` 任意同時當兩者。

保留 C 的意思是未來可在該入口新增經批准的規則與卡牌覆寫，不是現在實作多 policy、動態 plugin 或通用 DSL。未來每加一個 policy，須同步 schema 的值／版本／預設與舊資料相容、validator 拒絕情境、形狀與 preview／實際執行一致、敵方 intent 解析；Phase 4 AI 存在後還需候選格與估值測試。A 的契約與回歸保持不變，不能因新增 C 讓舊卡默默改義。

未選 B 的共同虛擬座標幾何，也未選現在一次實作 C 的多種跨盤規則；理由是使用者選擇先做 A、保留後續選擇，未另外宣稱其玩法優劣。僅將單盤畫成兩區仍不符合兩張獨立棋盤需求。

## 呈現

使用者已確認角色與敵人本體直接站盤並隨位置移動，呈現雙方對峙的日式 RPG 回合戰鬥感；工程接線、未定視角與驗收見 [呈現子頁](presentation.md)。

## 可沿用與必改

可沿用單一 CTB／WaveController、單位 uid／陣營、卡牌抽棄牌與基本傷害。BoardData 的局部尋路、地形、footprint、FieldData／Instance、場域 stack／tick 大多可保留，但呼叫端須傳入正確盤。

必改是單一 `BoardData.get_active()`、`board_anchor` 與 CardPlayRequest.selected_cell 的定位契約；BoardTargeting、IntentResolver、ThreatPreview、BoardView、Hand 選格、cell／movement signals、Encounter 部署／波次／召喚都需帶盤身分。敵方盤與玩家盤的同座標不能互相覆蓋；不能以「找不到敵人」誤判勝利，勝敗須跨盤查單位。跨盤後陣營、owner、AI 控制者不隨盤轉換。

存檔不保存戰鬥中棋盤；需驗跨程序讀檔後重建兩盤，並明定 Encounter 舊內容相容預設，不抹去舊回歸。

Phase 2b 已恢復接線與專項 headless，完整整合驗收仍以矩陣最新證據為準；開工前暫停快照保留歷史。ignored `artifacts/phase2b-paused/manifest.json` 保存逐檔 hash，同目錄保留 diff 與未追蹤原件，並非發布證據。

## 建議實作順序與成本

跨盤射程已選 A；分段提案見 [執行計畫](../../plans/dual-board/README.md)。先建立版本化單入口與位置，再做原子轉移、選格／攻擊／意圖及 Phase 2b 整合。每段有可執行測試再往下一段，不先完成舊單盤所有功能後整批重寫。

A 基礎原估 6–8 批；納入 [角色本體站盤](presentation.md) 後約 **7–10 個可獨立驗收批次**，包含真正雙盤、特殊跨盤移動／交換、回歸與文件，不含本輪未完成的完整 Phase 2b；完整 Phase 2b 整合另約 **3–5 批**。預留 C 的單入口、版本與未知值拒絕併入契約及回歸批次，增加少量設計／測試，不另建通用系統。這不等於 C 已免費完成；未來按實際新增 policy 重估增量，沿用位置／轉移／A 基礎，不重算整個雙棋盤工程。

此為原規劃估算，不承諾工時；整合回歸串行。

估算不含原創素材／題材內容、Phase 4 AI、GUI 人工驗收或發行匯出。agent 只跑 headless，GUI 仍由使用者操作。

## 驗證矩陣與完成條件

可重用測試、必改案例、新增負例與驗收分層記於 [verification.json](verification.json)；逐次結果與最終整合結果分開記錄。完成需要：兩盤定位與原子性、同盤移動／場域、跨盤目標與預覽一致性、CTB／勝敗／存讀、隔離 runner All 及文件 strict lint／boundary 均有實際證據；GUI 觀感與鍵鼠操作另列未驗，不以 headless 推論。

依分階段計畫實作；A 與首版跨盤方向型拒絕已決，不再重問。C 保留演進可能，不是本輪承諾。
