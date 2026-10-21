# selection-cues — 牌庫檢視與非 draft 選牌聲音

[聲音入口](../audio.md)｜[選牌 UI](../ui/screens/card-selection.md)｜[休息服務](../ui/screens/rest-services.md)｜[休息／選牌動畫](../art-assets/motion/rest-selection.md)｜[畫面聲包](screen-cues.md)

**何時用**：CardSelectionOverlay 的 VIEW 牌堆檢視，或 SELECT 模式的暫選、反選、Confirm／Back、quick_pick，以及返回休息或其他 opener；也包括這些情境的專項 fixture 與計數。
**何時不用**：CardDraftSelectionOverlay（點一張就立即完成／Skip）→ [screen-cues](screen-cues.md)；手牌出牌確認 → [combat-cues](combat-cues.md)。不要把暫選當成出牌或獲得卡牌。

Overlay 與 ActionBasePickCards 的程式事實（toggle、Confirm／Back 無 guard、quick_pick、force_action_end、自動旁路、opener 返回）以 [選牌畫面](../ui/screens/card-selection.md) 為準，休息範例見 [休息服務](../ui/screens/rest-services.md)；共同規則見 [audio 入口](../audio.md#場景聲包共同規則)。本檔只寫聲音的語意、owner 與預期計數。

## Done when

- 選牌聲包，以及 opener → modal → 結果／返回 的契約存在，涵蓋 VIEW／SELECT、暫選、提交、正常取消、強制退出與自動完成。
- fixture 有實際 caller、逐事件計數、牌組／服務結果，以及零 stale cue 的日誌；每案記錄 action 與 generation，未實作的 guard 以紅測保留，未執行的替身／Dummy 或聽感驗收明列。

## 流程

### 聲包與播放責任

聲包包含開頁、瀏覽、暫選／反選、足額、提交及取消。升級或移除的結果音屬於 opener，不是 selector 的通用「獲得卡牌」音；ActionPickCards 完成只代表 child 已排入，結果音由 opener 等真實資料差。把足額提示與暫選音合併，可以避免 quick_pick 時疊音。配樂延續 opener；若新增循環則由 modal owner 負責停止。目前沒有選牌 cue 契約；新的 adapter 要在 emit confirmed 前保存 opener、request、action、generation、mode、原因與 picked 快照（理由見選牌畫面）。

### VIEW

開頁音只由 Overlay 的狀態轉移播放，四個牌堆 opener 不各自播。聲音不得依 draw 視圖順序去動抽牌 RNG 或真正的牌堆。VIEW 點牌不播暫選、提交或效果成功音；採用 hover 音時只做低頻瀏覽提示。Back 不發 confirmed，不產生休息成功或旅行；空牌堆時開頁一次、選牌／成功音為零。現行 set_card_mode(VIEW) 不保證清掉舊 action，由 opener 防止 VIEW 蓋掉尚未完成的 SELECT。

### SELECT：暫選到提交

暫選／反選音只在 picked 陣列真的改變後各播一次；超過 max 或驗證拒絕不播暫選音，需要拒絕提示時由明確的拒絕出口提供原因，不把每次查詢都當拒絕。足額提示只在 are_enough_cards_picked 由 false→true 的邊緣發一次，已足額後繼續點或重繪不重播；反選到不足額是否另配提示由 brief 決定。

提交邊界由新的控制器重新驗證並鎖定同一 action。quick_pick 自動提交時記 cause=quick_pick，由同一個提交出口播一次，不讓 click 和 Confirm 各播一次成功音；若把最後一次暫選與提交合成一聲，只改呈現，不延後或重發業務上的 confirmed，glow、數量與 Confirm 狀態仍保留。

### Back、強制退出與自動旁路

- **Back**：在提交邊界驗證是否允許並記 cause=back；一次取消／返回音、零提交確認音。Back 是否仍產生 child 依 min／required 設定而定，依結果判斷，不播假的「已撤銷」。
- **強制退出**：adapter 先讓 generation 失效，正常確認、正常返回、結果音都是零，並停止 modal 循環與 pending 音。
- **自動旁路**：開頁、暫選與手動提交音都是零，opener 依真正結果決定是否播效果音；不為了播聲音而打開原本不會開的 selector。

### 返回 opener 與結果

休息服務 owner 等真實的牌組差異與 rest_action_ended（必要時再等 actions idle），只播一次服務結果音；不要讓 card_upgraded、rest_action_ended 與 modal close 同時播同一個成功聲。休息範例中 Back 的空集合不產生 child：服務未完成也不消耗，回到原選項並播一次取消音。其他 opener（對話或戰鬥效果）各持自己的 request 與結果，不能一律返回休息畫面或播升級音；純 VIEW 沒有結果 owner。opener 已被 Continue、換節點或 run_end 關閉時，舊回呼不得播服務完成音。

### 專項 fixture 與預期計數

擬建的 `tests/ui_card_selection_probe.gd` 與 caller 位置見 [選牌畫面](../ui/screens/card-selection.md#專項-fixture-和-caller)。互動測試走 `_on_card_selected`／Confirm／Back 與 action queue，有界等待 idle，不直接 emit confirmed 取代使用者路徑；signal 總數不能代替語意 cue 計數。

**基準案**：候選數多於 min，min=1、max=2、required=true、quick_pick=false、can_back_out=true。

- 選一張 → 反選 → 選另一張 → Confirm：開頁 1、暫選 2、反選 1、手動提交 1（採用足額邊緣提示則為 2）；效果成功音依實際 child 結果計 1。
- 同設定改走正常 Back：提交 0、取消 1、child 成功 0。
- 不允許 Back 或不足額時直接呼叫 handler：應被新的 guard 拒絕；guard 未實作前保留紅測。

**quick_pick**：選到 max 時只自動提交 1 次，之後再按 Confirm 不再提交；超過 max 或不可選的牌不新增暫選。

**強制退出**：選中後在等待中強制退出：提交 0、正常取消 0、結果 0，action 有界收束；第二次重開時沒有舊 cue。

**自動旁路**：候選 0 且 min=1、required：requested 0、開頁 0、結果 0；候選剛好等於 min：開頁 0、手動提交 0、真實效果 1；min=0 的空集合依 child 的實際效果另定期望。

**VIEW**：四種牌堆及空牌堆：選取、confirmed、結果全為 0；開頁與 Back 各 1；牌堆資料不變。

## 交接

提交、Back、force、自動旁路及 opener 返回的原因交給 UI 與動畫共用；音訊不自行完成 async action。控制器與測試都尚未實作，不宣稱已有完整的選牌聲音。
