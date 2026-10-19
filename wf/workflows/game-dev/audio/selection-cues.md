# selection-cues — 牌庫檢視與非 draft 選牌聲音

[聲音入口](README.md)｜[選牌 UI](../ui/screens/card-selection.md)｜[休息／選牌動畫](../art-assets/motion/rest-selection.md)｜[畫面聲包](screen-cues.md)

**何時用**：CardSelectionOverlay 的 VIEW 牌堆檢視，或 SELECT 暫選、反選、Confirm／Back、quick_pick 及返回休息／其他 opener。
**何時不用**：CardDraftSelectionOverlay 點一張立即完成／Skip 走 screen-cues；手牌出牌確認走 combat-cues，不把暫選當出牌或獲得。

## Done when

選牌聲包及 opener→modal→結果／返回契約存在，含 VIEW／SELECT、暫選、提交、正常取消、強制退出與自動完成。fixture 有實際 caller、逐事件計數、牌組／服務結果與零 stale cue 日誌；未執行替身／Dummy 或聽感明列。

## 流程

### 聲包、資料與播放責任

聲包含開頁、瀏覽、暫選／反選、足額、提交及取消；升級或移除結果音屬 opener，不是 selector 的通用「獲得卡牌」。合併足額與暫選可避免 quick_pick 疊音。規格記時長、尾音、變體、冷卻、合併及重播；配樂延續 opener，新增循環由 modal owner 停止。來源／格式與 bus 沿 README／mixing。

[CardSelectionOverlay](../../../../game/scripts/ui/CardSelectionOverlay.gd) 的 Grid 候選以 Card.card_selected 進 `_on_card_selected()`；這個 signal 只是卡被操作。SELECT 才改 picked_cards／glow，VIEW 分支 pass。候選由 get_pickable_cards 供給，DECK_PICK_TYPES 才開 SELECT。

新 adapter 保存 opener 弱引用、request、action instance、generation、mode 與原因；現無此 cue 契約。在 emit confirmed **之前**記 picked_cards 快照與原因，因為 Overlay 的 confirmed listener 會清 current_card_pick_action，不能在其後再猜確認來自哪個畫面。全域 confirmed 無 payload，亦供其他選牌及強制取消使用。

### VIEW：四種牌堆與 Back

[Combat](../../../../game/scripts/ui/Combat.gd) 的 deck／draw／discard／exhaust 按鈕分別呼叫 view_deck／view_draw_pile／view_discard／view_exhaust。開頁音只由 Overlay 狀態轉移播放，四個 opener 不再播。draw 用 shuffle 副本顯示，聲音不得以視圖次序改抽牌 RNG 或真牌堆。

VIEW Card.card_selected 不改選取，不播暫選／提交／效果成功音；hover 若本次採用則只低頻瀏覽。Back 正常情況只 hide，沒有 action 因此不發 confirmed；返回原 Combat 牌堆入口，不新增休息成功或旅行。視覺保留牌堆名、資料與 Back；空態開頁一次、零選牌／成功音。由 opener 防止 VIEW 覆蓋尚未完成的 SELECT，現 set_card_mode(VIEW) 未保證清掉舊 action。

### SELECT：暫選到提交

`_on_card_selected()` 若已有該 CardData 就 erase 並關 glow；否則通過 is_card_pickable 才 append 並亮 glow。只在陣列真的改變後各播一次暫選／反選；超過 max 或驗證拒絕零暫選音，若需拒絕提示則由此明確出口提供原因，不能把每次查詢當拒絕。

更新文字及 are_enough_cards_picked 後，只有 false→true 邊緣可發一次「可確認」提示；足額後繼續點或重繪不重播。反選跌到不足只更新視覺，是否有短提示依 brief。Confirm 現只 hide 並 emit confirmed，handler 沒有重新驗足額或防重；新 adapter／控制器必須在提交邊界再驗與鎖定同一 action，不能以按鈕不可見證明非法呼叫安全。

quick_pick=true 且 picked 數達 max，`_on_card_selected()` 會自動呼叫 Confirm。記 cause=quick_pick，由同一提交出口播一次，不能 click 與 Confirm 各播成功。若選擇合併短音，將最後暫選與提交合成一次；此政策只改呈現，不延後或重發業務 confirmed。保留 glow、數量及 Confirm 狀態。

### Back、強制退出與自動旁路

SELECT Back 清 picked_cards 再 emit confirmed；can_back_out 只控制按鈕顯示，handler 本身沒 guard。正常取消須在提交邊界驗允許，記 cause=back；預期一次取消／返回、零提交確認。Back 不保證零 child：只有例如 min≥1 且 min_cards_are_required_for_action=true，ActionPickCards 的條件才阻止空集合產生 child；其他設定必須按 payload 判結果，不能播放假「已撤銷」。

[ActionBasePickCards.force_action_end](../../../../game/scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd) 設 async_cancelled、清 picked，若正在等會 emit 同一 confirmed 解除 await，再 finish。run_end／Root 離樹經 ActionHandler 清理時，聲音 adapter 先使 generation 失效；強制退出零正常確認、零正常返回、零結果音，停止 modal 循環與 pending 音。hide／confirmed 不會自動 clear_cards，舊控件、tooltip、回呼與播放 handle 仍需 owner 清理。

ActionBasePickCards 在候選不足 min 且 required=true 時等一 frame 後 finish，沒有 requested／UI；剛好 min 自動選全部並執行，少於 min 但非 required 也自動選。零候選＋min=0 可走自動 child 路徑，不是必然取消。旁路零開頁／暫選／手動提交音；opener 依真正結果決定是否播效果音。不可為了聲音而強制打開原本不會開的 selector。

### 返回 opener 與結果成功

休息 Upgrade／Remove Cards 例在 [GlobalTestDataGenerator](../../../../game/autoload/GlobalTestDataGenerator.gd)：auto_end=false，required=true、min=1、can_back_out=true、quick_pick=false；成功 child 包含升級／移除和 REST_ACTION_END。ActionPickCards.finish 只代表 child 已排入，不代表效果全部完成。selector 提交後返回 RestOverlay 的本次服務 generation；服務 owner 等真實牌組差及 rest_action_ended，必要時再等 actions idle，只播一次服務結果。不要同時讓 card_upgraded／rest_action_ended／modal close 播相同成功聲。

Back 的空集合在此範例不生成 child：休息服務不完成、不消耗，回原選項一次取消音。其他 opener（對話或戰鬥效果）同樣持有自己的 request／結果，不能統一返回休息或播放升級音。純 VIEW 沒有結果 owner。若 modal 等待時 opener 被 Continue／換節點／run_end 關閉，舊回呼不得重開原畫面或播放服務完成；RestOverlay 的直接字典 lookup 另由 UI owner guard，音訊冷卻不能掩蓋失效回呼。

### 專項測試接法與計數

按 [mixing](mixing.md) 先核實播放替身／Dummy；尚未允許時只查碼。擬建 `tests/ui_card_selection_probe.gd` 由設施 fixture 在休息按鈕產生真實 pick action 後呼叫，或由新選牌情境 caller runtime load。靜態節點檢查可接 Smoke Root ready 兩 frame 後；互動須走 `_on_card_selected`／Confirm／Back 與 action queue，再逐項 `_check()`、有界等 idle，不能直接 emit confirmed 取代使用者路徑。沒有 Selection／Audio suite。

固定候選多於 min、min=1/max=2、required=true、quick_pick=false、can_back_out=true：選一張→反選→選另一張→Confirm，預期開頁1、暫選2、反選1、手動提交1；足額邊緣提示2（若採用），效果成功由實際 child 結果計1。以正常 Back 重跑，提交0／取消1／child成功0；禁 Back 或不足額的直接 handler 呼叫應被新 guard 拒絕，保留現況缺陷的紅測。

quick_pick 案選到 max，僅自動提交1且後續 Confirm不再提交；超 max／不可選零新增暫選。強制退出選中等待案：提交0／正常取消0／結果0、action有界收束、重開第二次無舊cue。候選0且min1 required案：requested0／開頁0／結果0；剛好min合法案：開頁0／手動提交0、真實效果1；min0空集合另按child實際效果定期望。VIEW四牌堆及空牌堆：選取／confirmed／結果全0，開頁及Back各1、資料不變。每案記 action與generation，signal總數不能代替語意cue計數。

## 交接

提交／Back／force／自動旁路及 opener 返回原因交 UI 與動畫共用，音訊不自行完成 async action。控制器及測試尚未實作，不宣稱已有完整選牌聲音。
