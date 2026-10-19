# 戰鬥畫面 — HUD、卡牌、敵人與回合

[場景目錄](README.md)｜[戰鬥關卡規則](../../level-design/combat.md)｜[互動狀態](../interaction-states.md)｜[元件規格](../components-layout.md)

**何時用**：交付可判斷並操作一回合的完整戰鬥畫面，或新增敵人／頭目資訊與回合提示。**何時不用**：傷害／AI／遭遇規則交機制及戰鬥關卡；只做卡圖交素材。

## Done when

畫面包有玩家決策資訊、各狀態和 cue 的資料 owner／接點；戰鬥 fixture 驗 HUD、成功／拒絕／目標取消及結束轉場，文件 lint 通過。視覺、真實輸入、聽感與同步未驗者分開記錄。

## 流程

### 畫面目的與完整素材包

玩家須同時辨識手牌效果與費用、能量、敵人意圖／生命／格擋、自己的生存狀態，完成出牌和結束回合，再看懂結果。以 [Root](../../../../../game/scenes/Root.tscn) 的 `RunScreen/Combat` 組合 BackgroundButton、Player、EnemyContainer、Hand、Energy／牌堆、EndTurnButton、TurnOverlay、TimelineBar（行動順序條）、CardPicking、SelectTargetLabel；跨場景說明由根 Tooptips 提供。沒有獨立「頭目 HUD」場景可直接套用。

素材包包括背景及安全區、角色／敵人 SpriteFrames、卡圖與卡框／費用圖示、意圖／狀態／牌堆圖示、血條／格擋標記、回合提示、選取／不可用／focus 樣式；HUD 文字與數值保留可編輯。圖像交 [卡牌](../../art-assets/cards.md)、[戰鬥角色](../../art-assets/combatants.md) 與 [場景背景](../../art-assets/environments.md)；實際元件尺寸和 Hand 相依值見元件規格，不各自發明第二套。

頭目新階段提示需先定義由哪個資料／signal 表達 phase；不能把 EnemyIntent 的 icon 或任意血量百分比當作既定階段規則。圖像、音效、動畫只能消費已確認的階段事件，規則未決保留候選設計。

### 資料與進場

Combat 收 map_location_selected，依 LocationData 類型決定戰鬥或隱藏戰鬥 HUD；COMBAT／MINIBOSS／BOSS 經 ActionGenerator.generate_combat_start 進既有流程。Combat._on_combat_started 把 EventData 交 CombatDirector.begin_combat(event)：建棋盤（EncounterData 或合成）、經 EnemyContainer 生第 0 波並放格、首次行動前處理、時間軸排序；BoardView（左上自繪格子）在 Director 執行中顯示，主角行動時才播動畫、補能量與抽牌。背景非空路徑依 Act→Location→Event 覆寫，Event 優先；空路徑不一定清前場景圖，需求若要空白須明定。

玩家與敵人數值來自 mutable data／combatant；HUD 讀 Global.player_data／HandManager，意圖在 Enemy.Visible/Intent，狀態在 BaseCombatant.Visible/StatusContainer。每次 action 刷新與訊號鏈見互動狀態；UI 不因動畫顯示或每 frame 重算就重複扣費、傷害、抽牌。

### 正常、不可用、目標與回合完成

閒置可出牌→選卡→選目標或直接入列→支付／效果→牌堆移動是成功鏈。缺能量／validator 失敗／手牌禁用／同牌已排隊要有可辨識理由；禁止狀態不只靠紅色或透明。選目標可點背景取消，右鍵可能另執行卡自訂 action，取消與右鍵玩法須分開呈現；空手牌仍保留合法 End Turn，零敵人或死亡不是普通空態。

選牌 Action 可能暫時接管 Hand／CardPicking 或整個 overlay；玩家應看出選幾張、已選數、能否確認，不能同時出牌。Energy／牌堆檢視、tooltip 和 modal 的層級及輸入擁有者按共同互動設定，裝飾不得遮住命中區。額外確認步驟必須由規格要求，不能悄悄改成拖放或雙擊。

Combat.gd 只做 HUD，行動流程在 CombatDirector：EndTurnButton 發 end_action_requested，經 CombatEndAction 等排隊卡與 actions 完成；TurnOverlay 由 update_turn_label 顯示「Tick T - Action N」（刻數與主角行動數）。CombatAnimation 的 start_turn／end_turn 已無流程 callback，由 Director 播放後 await animation_finished，改動畫時長會直接改變行動節奏。敵人死亡動畫完成後由 Combat 判定結束並等待 actions；一般勝利進獎勵，玩家死亡進結算，通關是另一條規則。離開時清選取／tooltip／待選 Action，晚到的視覺完成不能再出牌或再開獎勵。

### 聲音、動畫與結果回饋

成功出牌、無效拒絕、選目標／取消、命中傷害、格擋、狀態改變、敵人死亡、回合開始、勝敗各自指定 cue owner。出牌點擊不是命中，生命數值更新不是所有 VFX 的唯一事件；重播／刷新 UI 不發遊戲事件。查卡 Action／AttackGenerator／EnemyIntent 既有音圖路徑，避免 UI 再重播一次。

[戰鬥音訊](../../audio/combat-cues.md) 管聲音接受／成功時點與重疊；[UI 動態](../../art-assets/ui-motion.md) 管 hover／回合提示，[動畫](../../art-assets/animation.md) 和 [VFX](../../art-assets/vfx.md) 管人物／命中。若要整段頭目進場，先寫入「鎖輸入→介紹→資料 ready→解鎖」及跳過／退出時恢復，不假設已有 orchestration manager。

### Fixture 與驗收

由既有 Combat fixture 建 run 和敵人，選正常出牌、費用不足、目標取消各一條；HUD 數值與資料一致，queue／能量／HP 變化恰一次。加空手牌、滿手重疊、長卡文、多狀態、複數敵人／大圖框、等待中離場；不要只以單敵原生五張牌證明所有新資訊可讀。具體 helper 接入點見 [專項驗證](../verification.md)。

音效／動畫／tooltip 類純呈現 fixture 比較前後能量、牌堆、keyword IDs、具名 RNG 與 queue，既有 mutation 差異先記錄；動到預覽／等待者加生命週期專項。背景斷言不證明命中、遮擋、演出同步或手把；當前不啟動引擎／播放。完成後由 [獎勵流程](rewards-selection.md) 或 [結算流程](menus-collection.md) 接續，回報每條轉場的證據。

## 交接

交畫面節點／資料映射、整套素材與各 cue owner、正常／拒絕／取消／死亡狀態、專項 fixture 和實測限制；內容規則維持戰鬥關卡單一來源。
