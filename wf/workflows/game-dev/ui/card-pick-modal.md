# UI 選牌、獎勵與取消語意

[UI 入口](../ui.md)｜[互動與狀態](interaction-states.md)｜[獎勵與選牌畫面](screens/rewards-selection.md)｜[牌庫 VIEW／SELECT](screens/card-selection.md)｜[專項驗證](verification.md)

**何時用**：改 ActionPickCards 的人工選取 UI、手牌選牌、牌堆 VIEW／SELECT、獎勵領取與 draft，或新增「先選後確認」。

**何時不用**：完整畫面旅程、素材與 cue 走 [獎勵與選牌畫面](screens/rewards-selection.md) 或 [牌庫 VIEW／SELECT](screens/card-selection.md)；卡池與獎勵生成走內容／整局流程。

## Done when

- 任務 spec 記有 pick type、min／max、quick pick、can_back_out、每個 consumer 的確認／返回／略過結果與退出契約。
- [專項驗證](verification.md) 的 modal 斷言回傳預期結果；文件 lint 通過（見 [testing](../../testing.md)）。

## 流程

### 選牌、獎勵與取消不是同一語意

[ActionBasePickCards](../../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 先算合法卡與 min；候選不足／剛好，或 random_selection 時可能自動完成，只有需要人工選取才發 card_pick_requested 並 await card_pick_confirmed。fixture 必須提供多於 min 的合法候選，否則根本不會開 UI。

HAND_PILE 由 Hand 的 CardPicking／ConfirmPickButton 處理，合法卡可切換選取，足額才 enable。DECK_PICK_TYPES 由 [CardSelectionOverlay](../../../../game/scripts/ui/CardSelectionOverlay.gd) 處理；VIEW 用於牌堆檢視，SELECT 使用 ScrollContainer/MarginContainer/CardContainer。SELECT 以 are_enough_cards_picked 控制 Confirm 可見性，is_quick_pick 會自動確認，get_card_pick_can_back_out 決定 Back 是否可見。Back 在 VIEW 只關閉，在 SELECT 清空 picked_cards 並發 card_pick_confirmed；它不是獨立的 cancelled signal，也不是強制中止 Action。

[RewardOverlay](../../../../game/scripts/ui/RewardOverlay.gd) 用 reward_data 建 RewardContainer；BaseRewardButton 入列 Action 後釋放，但 CardRewardButton override 為等待 action_async_finished，只有 picked_cards 非空才釋放，因此 Skip 後保留獎勵、可重開。CardDraftSelectionOverlay 用 PICK_DRAFT，點牌立即 append 並發完成，Skip 以空選取完成。選中一個群組會移除其他 group；Continue 走 map／下一幕／run_victory。完整畫面、分組及取消條件見 [獎勵與選牌](screens/rewards-selection.md)。

Back 清零不保證子 action 執行零次；ActionPickCards 要 min_card_amount=1 且 min_cards_are_required_for_action=true 才會阻止零選取時生成子 action，can_back_out 只控制 Back。

三個 consumer 共用 card_pick_confirmed，仰賴同一時間只有單一待選 Action，沒有通用 modal stack。新增「先選後確認」時，需同時改 draft 狀態、按鈕、一次送出保護與 consumer；不能只多一顆 Confirm 卻保留點牌立即發送。

## 交接

清理與強制離開沿 [互動與狀態](interaction-states.md#清理與交接)；成功、Back、Skip、強制退出的斷言交 [專項驗證](verification.md)。
