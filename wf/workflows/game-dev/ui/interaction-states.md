# UI 互動與狀態

[UI 入口](../ui.md)｜[tooltip 與延後刷新](tooltip-refresh.md)｜[選牌與獎勵](card-pick-modal.md)｜[元件與版面](components-layout.md)｜[專項驗證](verification.md)

**何時用**：戰鬥 HUD、出牌／選目標、新 modal、確認取消、鍵盤／手把需求。

**何時不用**：純配色／布局接 [元件與版面](components-layout.md)；tooltip 顯示與卡面刷新接 [tooltip 與延後刷新](tooltip-refresh.md)；選牌 Action、獎勵與 draft 接 [選牌與獎勵](card-pick-modal.md)；改效果結果接 [機制](../mechanics.md)。

## Done when

- 任務 spec（`games/<game>/design/specs/`）記有入口、資料 owner、狀態轉移、確認／取消結果與退出契約。
- 對應 fixture 斷言回傳預期結果；文件 lint 通過（見 [testing](../../testing.md)）。
- 新增輸入方式沒有實際輸入證據時明列待驗。

## 流程

### 戰鬥 HUD 與出牌

先讀 [Combat.gd](../../../../game/scripts/ui/Combat.gd) 與 Root 的 `RunScreen/Combat`。`Energy/EnergyCount` 讀 Global.player_data 的能量；DrawPile／DiscardPile／ExhaustPile 的 Count 讀 HandManager 對應陣列；MoneyLabel／HealthLabel 讀 player_data。`update_combat_display()` 接 card_played／drawn／deck_shuffled／discarded／exhausted、energy_changed、card_queue_refunded；金錢／生命另接 player_money_changed／player_health_changed。改 HUD 應沿這些來源刷新，不只修改 Label.text。

EndTurnButton 發 end_action_requested，CombatDirector 經 CombatEndAction 等卡牌與 actions 完成，再播結束動畫；主角抽牌後才啟用。Hand disabled、actions_being_performed 與 card_play_queue 是不同狀態；不要假設所有 action 期間都禁止排隊出牌。敵人意圖在 Enemy 的 `Visible/Intent`，血條／格擋／狀態在 BaseCombatant；動這些顯示要同時查它們的更新方法，不從頂端 HealthLabel 複製資料。

[Card.gd](../../../../game/scripts/ui/card/Card.gd) 的 CardButton.gui_input 在 left_click／right_click **釋放**時發 card_selected／card_right_clicked；[Hand.gd](../../../../game/scripts/ui/Hand.gd) 訂閱後，先拒絕 disabled、右鍵執行中、can_play_card 失敗、同牌已在 queue 的出牌。無目標卡直接建 CardPlayRequest 入列；需目標卡存 current_selected_card，並顯示 SelectTargetLabel。

選目標有兩條入口，都經場景的 [CardPlayAdapter](../../../../game/scripts/combat/CardPlayAdapter.gd)：

- **未掛棋盤**時 Enemy 發 enemy_clicked，Hand._on_enemy_clicked 以 adapter.selection_for_target(enemy) 出牌。這是普通出牌路徑，不能拿掉。
- **已掛棋盤**時 BoardView 的格子點擊經 adapter.handle_cell_clicked 交 BoardCardAdapter 建 request（未選牌則移動）；基底 adapter 對格子點擊不做事。

enemy_hovered（離開時為 null）要求卡面重算預覽。

背景 BackgroundButton.button_up 清 current_selected_card 並隱藏提示；右鍵也先取消目標，但之後可能執行 card_right_click_actions，不能把右鍵視為純取消。disable_hand(true) 會清目標；combat／run ended 會清手牌並隱藏提示。新增目標規則時要驗「選牌後目標失效」及送出前重新驗證，不能把舊選取當成永久合法。既有 Card 流程不是拖放 API。

Card 的可用性檢查包含攔截後費用、card_is_playable 與 validators；非手牌（商店／牌堆／draft）的 can_play_card 直接回 true。費用不足目前以費用字色與 speech bubble 表達；CardGlow 是 validator／選牌標記，不能一律解釋為可出牌。手牌選取時不合法的牌由 Hand 設 alpha 0.3；新增 disabled 視覺應讓文字／圖示也說明原因。

### 新 modal 與鍵盤／手把

先沿 Root 的 CardSelectionOverlay／CardDraftSelectionOverlay 比較：兩者都是直接內嵌的 Control、固定 1200×700、z_index=10、process_mode=PAUSABLE；PauseOverlay 則有自己的暫停契約。新畫面先指定 opener、結果 owner、是否允許取消、一次完成／重入規則、底層輸入如何被擋、退出目的地。沒有共用 modal 基底；不要無條件複製 pause 語意。

鍵盤／手把需求須定 action map（方向／確認／取消）、初始 focus、順序及關閉後還原的對象；不可用／隱藏元件跳過，沒有候選時焦點落在允許的 Back／Skip。設定可見的 focus 樣式；ScrollContainer.follow_focus 只負責捲動，不能替 Card.gui_input 建確認行為。取消應先交給最上層允許關閉的 modal，再交給選目標；不可取消的狀態保留提示，避免同一次輸入再觸發底層。這些是待實作契約，現有自訂 InputMap 只有兩個滑鼠 action，控制器流程未核實。

### 清理與交接

關閉畫面需解開自己新增的訂閱、清參照／timer／tween，並恢復輸入 owner；queue_free 延至 frame 結束，重開前不要把待刪節點當新候選。重複 init 的 Card 會再 connect，需測重入。強制離開沿 ActionHandler.clear_all_actions → force_action_end 清空 picked_cards、設 async_cancelled、釋放等待；UI 只設 visible=false 會留下 action。Root._exit_tree 已有此清理，但不代表所有自建 modal 都安全。

動態戰鬥 UI 的 owner 生命週期另見 [元件與版面](components-layout.md)。將成功、拒絕、正常取消、強制退出交 [專項驗證](verification.md)，不以關閉成功推定 Action 已結束。
