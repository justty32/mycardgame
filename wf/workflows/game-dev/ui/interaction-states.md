# UI 互動與狀態

[UI 目錄](README.md)｜[元件與版面](components-layout.md)｜[專項驗證](verification.md)

**何時用**：戰鬥 HUD、出牌／選目標、tooltip、選牌與新 modal、鍵盤／手把需求。**何時不用**：純配色／布局接元件；改效果結果接 [機制](../mechanics.md)。

## Done when

任務 spec（`design/specs/`）記有入口、資料 owner、狀態轉移、確認／取消結果與退出契約；對應 fixture 斷言及文件 lint 回傳預期結果。新增輸入方式沒有實際輸入證據時明列待驗。

## 流程

### A：戰鬥 HUD 與出牌

先讀 [Combat.gd](../../../../game/scripts/ui/Combat.gd) 與 Root 的 `RunScreen/Combat`。`Energy/EnergyCount` 讀 Global.player_data 能量；DrawPile／DiscardPile／ExhaustPile 的 Count 讀 HandManager 對應陣列；MoneyLabel／HealthLabel 讀 player_data。`update_combat_display()` 接 card_played／drawn／deck_shuffled／discarded／exhausted、energy_changed、card_queue_refunded；金錢／生命另接 player_money_changed／player_health_changed。改 HUD 應沿這些來源刷新，不只修改 Label.text。

EndTurnButton.button_up 經 queue_end_turn／CombatEndTurn 等待卡牌與 actions，再進回合動畫。Hand disabled、actions_being_performed 與 card_play_queue 是不同狀態；不要假設所有 action 期間都禁止排隊出牌。敵人意圖在 Enemy 的 `Visible/Intent`、血條／格擋／狀態在 BaseCombatant；動這些顯示要同查其更新方法，不從頂端 HealthLabel 複製資料。

[Card.gd](../../../../game/scripts/ui/card/Card.gd) 的 CardButton.gui_input 在 left_click／right_click **釋放**時發 card_selected／card_right_clicked；[Hand.gd](../../../../game/scripts/ui/Hand.gd) 訂閱後，先拒絕 disabled、右鍵執行中、can_play_card 失敗、同牌已在 queue 的出牌。無目標卡直接建 CardPlayRequest 入列；需目標卡存 current_selected_card，顯示 SelectTargetLabel。Enemy SelectionButton 經 enemy_clicked 讓 Hand 建帶敵人的 request；enemy_hovered（離開時為 null）要求卡面重算預覽。

背景 BackgroundButton.button_up 清 current_selected_card 並隱藏提示；右鍵也先取消目標，但之後可能執行 card_right_click_actions，不能把右鍵視為純取消。disable_hand(true) 會清目標；combat／run ended 會清手牌並隱藏提示。新增目標規則時驗「選牌後目標失效」及送出前重新驗證，不能把舊選取當成永久合法。既有 Card 流程不是拖放 API。

Card 的可用性檢查包含攔截後費用、card_is_playable 與 validators；非手牌（商店／牌堆／draft）can_play_card 直接 true。費用不足目前以費用字色與 speech bubble 表達，CardGlow 是 validator／選牌標記，不能一律解釋為可出牌。手牌選取不合法的牌由 Hand 設 alpha 0.3；新增 disabled 視覺應讓文字／圖示也說明原因。

### Tooltip 與延後刷新

Root 的節點實名是 `Tooptips`，腳本為 [Tooltips.gd](../../../../game/scripts/ui/Tooltips.gd)，HandManager.tooltip 指向它。Card hover 啟動 0.5 秒 KeywordTimer，timeout 呼叫 display_card_keywords；mouse_exited 停 timer、hide_tooltip 並取消 hover。HUD tooltip 由 component_tooltip_data 連 mouse_entered／exited。新增 focus 提示需另外接 focus_entered／exited，不能期待 hover 自動涵蓋鍵盤。

KeywordContainer 依 KeywordData 遞迴建立 KeywordTooltip；hide_tooltip 會 queue_free 子項並隱藏容器。卡牌左右放置使用 DisplayServer.window_get_size 與固定 200 邊界；這不是 viewport 邊界保證，也未限制底部溢出。tooltip 裝飾層目前 mouse_filter=IGNORE；改遮罩時避免吞掉卡牌命中。切 modal／離樹時要取消 timer 和清 tooltip，不能只等待 mouse_exited。

update_card_display 以 `_card_is_rerendering` 合併到下一 process_frame；同 frame 後來的目標更新可能直接 return。名稱／描述後還有 RichLabelAutoSizer 延後處理，KeywordTooltip 的 fit_content 亦 set_deferred。fixture 等狀態完成再取字串／尺寸；若改刷新策略，補快速換目標與等待中移除案例。預覽會生成 Action／Interceptor；不得改能量、牌堆、具名 RNG 或留下持有鏈。KeywordContainer 目前直接取 card_keyword_object_ids 再追加推導關鍵字，不能假設 tooltip 完全不改 CardData；改這段時專測原資料與重複展開。

### B：選牌、獎勵與取消不是同一語意

[ActionBasePickCards](../../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 先算合法卡與 min；不足／剛好或 random_selection 可能自動完成，只有需人工選取才發 card_pick_requested 並 await card_pick_confirmed。fixture 必須提供多於 min 的合法候選，否則根本不會開 UI。

HAND_PILE 由 Hand 的 CardPicking／ConfirmPickButton 處理，合法卡可切換選取，足額才 enable。DECK_PICK_TYPES 由 [CardSelectionOverlay](../../../../game/scripts/ui/CardSelectionOverlay.gd) 處理；VIEW 用於牌堆檢視，SELECT 使用 ScrollContainer/MarginContainer/CardContainer。SELECT 以 are_enough_cards_picked 控制 Confirm 可見性，is_quick_pick 會自動確認，get_card_pick_can_back_out 決定 Back 可見。Back 在 VIEW 只關閉，在 SELECT 清空 picked_cards 並發 card_pick_confirmed；它不是獨立 cancelled signal，也不是強制中止 Action。

[RewardOverlay](../../../../game/scripts/ui/RewardOverlay.gd) 用 reward_data 建 RewardContainer；BaseRewardButton 入列 Action 後釋放，但 CardRewardButton override 等 action_async_finished，只有 picked_cards 非空才釋放，Skip 後保留獎勵可重開。CardDraftSelectionOverlay 用 PICK_DRAFT，點牌立即 append 並發完成，Skip 空選取完成。群組選中會移除其他 group；Continue 走 map／下一幕／run_victory。完整畫面、分組及取消條件見 [獎勵與選牌](screens/rewards-selection.md)。

Back 清零不保證子 action 零次；ActionPickCards 要 min_card_amount=1 且 min_cards_are_required_for_action=true 才阻止零選取生成子 action，can_back_out 只控制 Back。

三個 consumer 共用 card_pick_confirmed，仰賴單一待選 Action，沒有通用 modal stack。新增「先選後確認」時，需同改 draft 狀態、按鈕、一次送出保護與 consumer；不能只多一顆 Confirm 卻保留點牌立即發送。

### 新 modal 與鍵盤／手把

先沿 Root 的 CardSelectionOverlay／CardDraftSelectionOverlay 比較：都是直接內嵌 Control、固定 1200×700、z_index=10、process_mode=PAUSABLE；PauseOverlay 則有自己的暫停契約。新畫面先指定 opener、結果 owner、是否允許取消、一次完成／重入規則、底層輸入如何被擋、退出目的地。沒有共用 modal 基底；不要無條件複製 pause 語意。

鍵盤／手把需求須定 action map（方向／確認／取消）、初始 focus、順序及關閉還原對象；不可用／隱藏元件跳過，沒有候選時焦點落在允許的 Back／Skip。設定可見 focus 樣式，ScrollContainer.follow_focus 只負責捲動，不能替 Card.gui_input 建確認行為。取消應先交最上層允許關閉的 modal，再交選目標；不可取消狀態保留提示，避免同次輸入再觸發底層。這些是待實作契約，現有自訂 InputMap 只有兩個滑鼠 action；未核實控制器流程。

### 清理與交接

關閉畫面需解開自己新增的訂閱、清參照／timer／tween，恢復輸入 owner；queue_free 延至 frame，重開前別把待刪節點當新候選。重複 init 的 Card 會再 connect，需測重入。強制離開則沿 ActionHandler.clear_all_actions → force_action_end 清空 picked_cards、設 async_cancelled、釋放等待；UI 只 visible=false 會留下 action。Root._exit_tree 已有此清理，但不代表所有自建 modal 都安全。

動態戰鬥 UI 的 owner 生命週期另見 [元件](components-layout.md)。將成功、拒絕、正常取消、強制退出交 [專項驗證](verification.md)，不以關閉成功推定 Action 已結束。
