# selection-cues — 牌庫檢視與非 draft 選牌聲音

[聲音入口](../audio.md)｜[選牌 UI](../ui/screens/card-selection.md)｜[休息／選牌動畫](../art-assets/motion/rest-selection.md)｜[畫面聲包](screen-cues.md)｜[專項 fixture](selection-cues-fixtures.md)

**何時用**：CardSelectionOverlay 的 VIEW 牌堆檢視，或 SELECT 模式的暫選、反選、Confirm／Back、quick_pick，以及返回休息或其他 opener。
**何時不用**：CardDraftSelectionOverlay（點一張就立即完成／Skip）→ [screen-cues](screen-cues.md)；手牌出牌確認 → [combat-cues](combat-cues.md)。不要把暫選當成出牌或獲得卡牌。

## Done when

- 選牌聲包，以及 opener → modal → 結果／返回 的契約存在，涵蓋 VIEW／SELECT、暫選、提交、正常取消、強制退出與自動完成。
- fixture 有實際 caller、逐事件計數、牌組／服務結果，以及零 stale cue 的日誌（案例見 [selection-cues-fixtures](selection-cues-fixtures.md)）；未執行的替身／Dummy 或聽感驗收明列。

## 流程

### 聲包、資料與播放責任

聲包包含開頁、瀏覽、暫選／反選、足額、提交及取消。升級或移除的結果音屬於 opener，不是 selector 的通用「獲得卡牌」音。把足額提示與暫選音合併，可以避免 quick_pick 時疊音。規格記錄時長、尾音、變體、冷卻、合併及重播規則；配樂延續 opener 的，若新增循環則由 modal owner 負責停止。來源、格式與 bus 沿 [audio 入口](../audio.md) 與 [mixing](mixing.md)。

[CardSelectionOverlay](../../../../game/scripts/ui/CardSelectionOverlay.gd) 的 Grid 候選透過 Card.card_selected 進入 `_on_card_selected()`；這個 signal 只表示「卡被操作了」。只有 SELECT 模式會改 picked_cards 與 glow，VIEW 分支直接 pass。候選由 get_pickable_cards 提供，只有 DECK_PICK_TYPES 才會開 SELECT。

目前沒有選牌 cue 契約。新的 adapter 要保存 opener 弱引用、request、action instance、generation、mode 與原因。picked_cards 快照與原因必須在 emit confirmed **之前**記下，因為 Overlay 的 confirmed listener 會清掉 current_card_pick_action，事後就無法再判斷這次確認來自哪個畫面。全域 confirmed 沒有 payload，而且其他選牌流程與強制取消也會用到它。

### VIEW：四種牌堆與 Back

[Combat](../../../../game/scripts/ui/Combat.gd) 的 deck／draw／discard／exhaust 按鈕分別呼叫 view_deck／view_draw_pile／view_discard／view_exhaust。開頁音只由 Overlay 的狀態轉移播放，四個 opener 不再各自播。draw 顯示的是洗過的副本，聲音不得依視圖順序去動抽牌 RNG 或真正的牌堆。

VIEW 下的 Card.card_selected 不會改選取，因此不播暫選、提交或效果成功音；若採用 hover 音，只做低頻瀏覽提示。Back 在正常情況下只 hide；因為沒有 action，所以不會發 confirmed。它返回原本 Combat 的牌堆入口，不產生休息成功或旅行。視覺上保留牌堆名、牌資料與 Back。空牌堆時開頁音一次、選牌／成功音為零。

由 opener 負責防止 VIEW 蓋掉尚未完成的 SELECT：現行 set_card_mode(VIEW) 不保證會清掉舊 action。

### SELECT：從暫選到提交

`_on_card_selected()` 的行為：若已選了該 CardData，就 erase 並關掉 glow；否則通過 is_card_pickable 後才 append 並點亮 glow。暫選／反選音只在陣列真的改變後各播一次。超過 max 或驗證拒絕時不播暫選音；若需要拒絕提示，由這個明確的拒絕出口提供原因，不能把每次查詢都當成拒絕。

更新文字與 are_enough_cards_picked 之後，只有在 false→true 的邊緣才發一次「可確認」提示；已足額後繼續點或重繪都不重播。反選到不足額時只更新視覺，是否另配短提示由 brief 決定。

Confirm 現在只 hide 並 emit confirmed，handler 不會重新驗證足額，也沒有防重。新的 adapter／控制器必須在提交邊界重新驗證並鎖定同一個 action；不能用「按鈕不可見」證明非法呼叫是安全的。

quick_pick=true 時，picked 數量達到 max 後，`_on_card_selected()` 會自動呼叫 Confirm。這時記 cause=quick_pick，由同一個提交出口播一次，不能 click 和 Confirm 各播一次成功音。若決定合併短音，就把最後一次暫選與提交合成一聲；這個政策只改呈現，不延後也不重發業務上的 confirmed。glow、數量與 Confirm 狀態仍要保留。

### Back、強制退出與自動旁路

**Back**：SELECT 下的 Back 會清空 picked_cards 再 emit confirmed。can_back_out 只控制按鈕是否顯示，handler 本身沒有 guard。正常取消要在提交邊界驗證是否允許，記 cause=back；預期一次取消／返回音、零提交確認音。Back 不保證不產生 child：只有像 min≥1 且 min_cards_are_required_for_action=true 這類設定下，ActionPickCards 的條件才會阻止空集合產生 child；其他設定必須依 payload 判斷結果，不能播一個假的「已撤銷」。

**強制退出**：[ActionBasePickCards.force_action_end](../../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 會設 async_cancelled、清空 picked；若正在等待，會 emit 同一個 confirmed 來解除 await，再 finish。run_end 或 Root 離樹經 ActionHandler 清理時，聲音 adapter 要先讓 generation 失效：強制退出時正常確認、正常返回、結果音都是零，並停止 modal 循環與 pending 音。hide／confirmed 不會自動 clear_cards，舊控件、tooltip、回呼與播放 handle 仍要由 owner 清理。

**自動旁路**：ActionBasePickCards 在下列情況不會開 UI，也沒有 requested：

- 候選不足 min 且 required=true：等一個 frame 後直接 finish；
- 候選剛好等於 min：自動選全部並執行；
- 候選少於 min 但非 required：同樣自動選；
- 零候選且 min=0：可能走自動 child 路徑，不一定是取消。

旁路時開頁、暫選與手動提交音都是零；opener 依真正的結果決定是否播效果音。不可為了播聲音而強制打開原本不會開的 selector。

### 返回 opener 與結果成功

休息的 Upgrade／Remove Cards 範例在 [GlobalTestDataGenerator](../../../../game/autoload/GlobalTestDataGenerator.gd)：auto_end=false、required=true、min=1、can_back_out=true、quick_pick=false；成功的 child 包含升級／移除與 REST_ACTION_END。ActionPickCards.finish 只代表 child 已排入，不代表效果全部完成。

selector 提交後返回 RestOverlay 的本次服務 generation。服務 owner 等到真實的牌組差異與 rest_action_ended（必要時再等 actions idle），只播一次服務結果音。不要讓 card_upgraded、rest_action_ended 與 modal close 同時播同一個成功聲。

在這個範例中，Back 的空集合不會產生 child：休息服務沒有完成也不消耗，回到原選項並播一次取消音。其他 opener（對話或戰鬥效果）同樣持有自己的 request 與結果，不能一律返回休息畫面或播升級音。純 VIEW 沒有結果 owner。

若 modal 等待期間 opener 已被 Continue、換節點或 run_end 關閉，舊回呼不得重開原畫面，也不得播服務完成音。RestOverlay 的直接字典 lookup 另由 UI owner 加 guard；音訊冷卻不能掩蓋失效的回呼。

## 交接

- 提交、Back、force、自動旁路及 opener 返回的原因交給 UI 與動畫共用；音訊不自行完成 async action。
- 專項測試接法與逐案計數見 [selection-cues-fixtures](selection-cues-fixtures.md)。控制器與測試都尚未實作，不宣稱已有完整的選牌聲音。
