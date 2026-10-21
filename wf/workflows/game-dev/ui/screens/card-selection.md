# 牌庫檢視與效果選牌 — VIEW／SELECT 的完整返回契約

[獎勵入口](rewards-selection.md)｜[休息服務](rest-services.md)｜[互動契約](../interaction-states.md)｜[驗證接線](../verification.md)

**何時用**：CardSelectionOverlay 的牌堆 VIEW 或效果 SELECT，多牌 Grid、暫選／反選、Confirm／Back 與返回來源。**何時不用**：CardDraftSelectionOverlay 的獎勵點牌立即完成沿獎勵入口；兩者不共用取牌動畫假設。

## Done when

畫面規格記有 mode、opener、action 身分、generation、候選／選取、每種完成原因及退出 owner；fixture 涵蓋 VIEW、SELECT、旁路完成、退出／重入，相關檢查通過；文件 lint 通過（見 [testing](../../../testing.md)）。新 controller／cue／動畫與 guard 未實作時明列待工程驗收。

## 流程

### 用途、素材與視覺根

玩家在 VIEW 了解目前牌堆，在 SELECT 為某個效果選合法牌；「暫選」不是取得、升級或移除已完成。[Root](../../../../../game/scenes/Root.tscn) 的 RunScreen/CardSelectionOverlay 以 ScrollContainer/MarginContainer/CardContainer 五欄 Grid、CardPickLabel、ConfirmButton、BackButton 組成。素材包包含多牌面板、Card 圖／框、暫選／反選／不可選原因、足額確認、返回與空態，交 [介面素材](../../art-assets/interface-assets.md)。

Grid 決定 Card 的 layout 位置，新增 reveal 動態用每張卡的視覺 wrapper；UI 的 `Card.set_card_glow()` 管暫選，動畫不得同時控制 CardGlow.visible。動態可改獨立 wrapper alpha／scale，收尾回基線；不得把 Grid 子節點 position tween 與容器佈局互搶。完整時序接 [休息／選牌動畫](../../art-assets/motion/rest-selection.md)。

### Opener 與正常返回

VIEW 的 opener 是 Combat 的 DeckButton／DrawPile／DiscardPile／ExhaustPile：各 handler 呼叫 view_deck／view_draw_pile／view_discard／view_exhaust，資料來自持久 deck 或 HandManager pile。返回只隱藏 CardSelectionOverlay，顯露原本底層畫面；沒有返回導航 action，不應開新地圖／營地。draw view shuffle 的是副本，畫面排序不代表抽牌順序。

SELECT 的 opener 是發起 ActionPickCards 的效果 owner，例如 RestOverlay 的升級／移除服務，也可能是戰鬥效果。DECK_PICK_TYPES 的 card_pick_requested 交 [CardSelectionOverlay.gd](../../../../../game/scripts/ui/CardSelectionOverlay.gd)，記 current_card_pick_action，取 get_pickable_cards，再顯示計數／Confirm／Back。UI 目前沒記 opener；新增 controller 需要在發起端記 owner、location/run 身分與 generation，不能從 pick type 猜「關閉就回休息」。

正常流程為候選 ready→可暫選／反選→足額可確認→提交→效果 owner 接結果→解除父畫面鎖。休息結果交 RestOverlay，戰鬥結果交原 Action，不用通用飛往牌組或獲得卡牌 cue。原父畫面保持在底層；只有仍有效的原 opener 可恢復輸入，已離場則不導航、不重開。focus 還原需求先記目的節點；背景專項不呼叫真實 focus。

### 選取、確認與所有旁路

SELECT `_on_card_selected` 會 toggle picked_cards／glow，is_card_pickable 檢驗新增選取，更新 CardPickLabel 與 are_enough_cards_picked 決定 Confirm 可見性；不是 disabled。Confirm handler 直接 hide 並發全域無參數 card_pick_confirmed，未自行重驗足額。Back 可見性取 can_back_out，但 handler 也未 guard 禁止返回；直接呼叫／過期輸入仍需防護。

SELECT Back 清 picked_cards 再發同一 confirmed；VIEW Back 只 hide、不發 confirmed。要取消時零 child effects，fixture 明設 min_card_amount=1、min_cards_are_required_for_action=true、can_back_out=true；只設 can_back_out 不構成回滾。quick_pick 在選取 handler 內直接呼叫 Confirm，不能再讓動畫結束第二次發送；需另驗不合法點擊／反選與 quick_pick 的足額防護。

ActionBasePickCards 在候選不足 min 且 required=true 時自動結束無效果；不足但非 required 會選全部並執行；剛好 min 自動選全部；random_selection 另有自動路徑。零候選也走這些條件，不保證顯示空 Grid。opener 必須能處理「從未收到 modal open 就完成」；無 open 不播開窗／關窗聲，也不能永遠保持等待遮罩。

### Cue、完成身分與中斷

[選牌音訊](../../audio/selection-cues.md) 分 VIEW 開啟／返回、SELECT 暫選／反選／達足額、Confirm／Back／強制取消；暫選不播成功取得。新 controller 在 emit confirmed 前保存 mode、action、opener、generation、reason 和 picked 快照；因全域 signal 無 payload 且各 consumer 會清參照，不能在 signal 後才猜取消原因。reason／generation 是新增設計，不是既有欄位。

ActionPickCards.action_async_finished 只表示其子 actions 已排入，不保證升級／移除等效果完成；結果聲與結果動畫由 opener 等真實資料差及所屬完成訊號。每個請求只提交一次，晚到的 reveal／Confirm callback 不得套到下一個同 ID 的 action。

現況 confirmed／run_ended 只 hide+清 action，VIEW Back 只 hide，均沒有 clear_cards；下次 populate 才 queue_free 舊 children。新增 close 需清 children、KeywordTimer／tooltip、自建 tween／音訊與 controller 參照，再恢復仍有效的 opener。force_action_end 清 picked／標 async_cancelled／釋放等待，不能把它當正常 Back 或成功結果。run end／換 location／離樹先失效 generation，ActionHandler 負責取消 action，UI 收晚到完成只忽略呈現；Root 清理不能代替局部 owner 保護。

### 專項 fixture 和 caller

建議 tests/ui_card_selection_probe.gd（未建立）：VIEW probe 接 Combat `_scenario()` 的 `_player_ready` 成功後、既有勝敗分支前，從四個牌堆按鈕開 VIEW 再 Back，核對牌堆／HP／energy／queue 不變。SELECT probe 由 [休息服務 fixture](rest-services.md) 在選牌服務已發 requested 後 runtime load 並 await；戰鬥效果則在自己的 Action 發起處接。所有斷言由 caller 交 `_check()`；沒有 CardSelection suite 自動發現。

提供兩張合法和一張不合法牌、min=1/max=2/required=true/quick=false；驗暫選／反選、min/max、不可選、Confirm、Back允許／禁止、返回正確 opener，成功只一次。另用 quick=true 與零／剛好 min／random 情境驗旁路，無 modal 也能解除父鎖。結果核對 child idle 與永久資料，不只看 overlay hidden。

退出測例在 reveal、暫選、提交待 child 結果三階段結束 run／換節點，核對 async、children、tooltip 和 cue owner 清理；舊 generation callback 不開畫面、不改下一個 opener。重入同一服務測一次完成；現有無 guard／清卡缺口先留失敗條件。執行前按 verification 排除 Map grab_focus／音訊出口。

## 交接

UI、效果 owner、音訊／動畫共用 opener／action／generation／reason／結果快照契約；返回、取消和業務效果各有唯一 owner。視覺／真實輸入／同步仍需獨立證據，不以 handler 成功代稱整套驗收。
