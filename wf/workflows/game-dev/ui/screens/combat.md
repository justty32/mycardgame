# 戰鬥畫面 — HUD、卡牌、敵人與回合

[場景目錄](README.md)｜[戰鬥關卡規則](../../level-design/combat.md)｜[互動狀態](../interaction-states.md)｜[元件規格](../components-layout.md)

**何時用**：交付可判斷並操作一回合的完整戰鬥畫面，或新增敵人／頭目資訊與回合提示。**何時不用**：傷害／AI／遭遇規則交機制及戰鬥關卡；只做卡圖交素材。

## Done when

畫面包有玩家決策資訊、各狀態和 cue 的資料 owner／接點；戰鬥 fixture 驗 HUD、成功／拒絕／目標取消及結束轉場，未掛棋盤與已掛棋盤兩種模式都有結果；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

### 畫面目的與完整素材包

玩家須同時辨識手牌效果與費用、能量、敵人意圖／生命／格擋、自己的生存狀態，完成出牌和結束回合，再看懂結果。以 [Root](../../../../../game/scenes/Root.tscn) 的 `RunScreen/Combat` 組合 BackgroundButton、Player、EnemyContainer、Hand、Energy／牌堆、EndTurnButton、TurnOverlay、TimelineBar（行動順序條）、CardPicking、SelectTargetLabel；跨場景說明由根 Tooptips 提供。沒有獨立「頭目 HUD」場景可直接套用。

素材包包括背景及安全區、角色／敵人 SpriteFrames、卡圖與卡框／費用圖示、意圖／狀態／牌堆圖示、血條／格擋標記、回合提示、選取／不可用／focus 樣式；HUD 文字與數值保留可編輯。圖像交 [卡牌](../../art-assets/cards.md)、[戰鬥角色](../../art-assets/combatants.md) 與 [場景背景](../../art-assets/environments.md)；元件尺寸和 Hand 相依值見元件規格。

頭目新階段提示需先定義由哪個資料／signal 表達 phase；不能把 EnemyIntent 的 icon 或任意血量百分比當作既定階段規則。圖像、音效、動畫只能消費已確認的階段事件，規則未決保留候選設計。

### 資料與進場

Combat 收 map_location_selected，依 LocationData 類型決定戰鬥或隱藏 HUD；COMBAT／MINIBOSS／BOSS 經 ActionGenerator.generate_combat_start 的 ActionStartCombat 呼叫 Scene request。先由 PreparedEncounter 驗資料／能力、Director 暫存模組 setup，成功才發 `combat_started` 初始化原訂閱者並接同一個首波／CTB loop；不要直接 emit 該通知來要求開戰。失敗關閉戰鬥 HUD／輸入並允許重試，不能先清牌或排獎勵。**棋盤不一定存在**：合法 0 不掛模組，普通 EnemyContainer 與卡牌流程照常；正盤依明確設定組裝 BoardCombatPresentation／BoardView，UI 不得依賴格子必然存在（見 [board-module](../../mechanics/board-module.md)）。背景非空路徑依 Act→Location→Event 覆寫，Event 優先；空路徑不一定清前場景圖，需求若要空白須明定。

HUD 的資料來源與刷新訊號、Card／Hand 的出牌與拒絕檢查、背景取消與右鍵差異集中在 [互動狀態](../interaction-states.md#戰鬥-hud-與出牌)；UI 不因動畫顯示或每 frame 重算就重複扣費、傷害、抽牌。選目標有兩條入口：**未掛棋盤**時 Enemy 發 enemy_clicked，Hand._on_enemy_clicked 以 [CardPlayAdapter](../../../../../game/scripts/combat/CardPlayAdapter.gd).selection_for_target(enemy) 出牌，這是普通出牌路徑；**已掛棋盤**時格子點擊經 BoardCardAdapter。改出牌路徑兩種模式都要驗，見 [validation 的棋盤開關](../../validation.md#棋盤開關兩種模式都要驗)。

### 狀態、回合與結束

缺能量／validator 失敗／手牌禁用／同牌已排隊要有可辨識理由，禁止狀態不只靠紅色或透明；空手牌仍保留合法 End Turn，零敵人或死亡不是普通空態。選牌 Action 可能暫時接管 Hand／CardPicking 或整個 overlay；玩家應看出選幾張、已選數、能否確認，不能同時出牌。tooltip 和 modal 的層級及輸入擁有者按共同互動設定，裝飾不得遮住命中區。額外確認步驟必須由規格要求，不能悄悄改成拖放或雙擊。

Combat.gd 只做 HUD，行動流程在 CombatDirector：EndTurnButton 發 end_action_requested，經 CombatEndAction 等排隊卡與 actions 完成；TurnOverlay 由 update_turn_label 顯示「Tick T - Action N」（刻數與主角行動數）。CombatAnimation 的 start_turn／end_turn 由 Director 播放後 await animation_finished，改動畫時長會直接改變行動節奏（軌道內容見 [畫面轉場](../../art-assets/motion/menus.md#回合提示與規則回呼)）。敵人死亡動畫完成後由 Combat 判定結束並等待 actions；一般勝利進 [獎勵](rewards-selection.md)，玩家死亡進 [結算](menus-collection.md#圖鑑歷史與結算)，通關是另一條規則。離開時清選取／tooltip／待選 Action，晚到的視覺完成不能再出牌或再開獎勵。

### 聲音、動畫與結果回饋

成功出牌、無效拒絕、選目標／取消、命中傷害、格擋、狀態改變、敵人死亡、回合開始、勝敗各自指定 cue owner；事件鏈與「點擊不是命中」見 [出牌時序](../../presentation-delivery.md)。重播／刷新 UI 不發遊戲事件；先查卡 Action／AttackGenerator／EnemyIntent 既有音圖路徑，避免 UI 再播一次。聲音接 [戰鬥聲包](../../audio/combat-cues.md)，hover／出牌動態接 [卡牌動態](../../art-assets/motion/cards.md)，人物／命中接 [動畫](../../art-assets/animation.md) 與 [VFX](../../art-assets/vfx.md)。若要整段頭目進場，先寫入「鎖輸入→介紹→資料 ready→解鎖」及跳過／退出時恢復，不假設已有 orchestration manager。

### Fixture 與驗收

由既有 Combat fixture 建 run 和敵人，選正常出牌、費用不足、目標取消各一條；HUD 數值與資料一致，queue／能量／HP 變化恰一次。加空手牌、滿手重疊、長卡文、多狀態、複數敵人／大圖框、等待中離場；不要只以單敵原生五張牌證明所有新資訊可讀。helper 接入點與證據判讀見 [專項驗證](../verification.md)。

## 交接

交畫面節點／資料映射、整套素材與各 cue owner、正常／拒絕／取消／死亡狀態、專項 fixture 和實測限制；內容規則維持戰鬥關卡單一來源。
