# selection-cues-fixtures — 選牌聲音的專項測試與計數

[選牌聲包](selection-cues.md)｜[mixing](mixing.md)｜[聲音入口](../audio.md)

[selection-cues](selection-cues.md) 的驗證部分：fixture 怎麼接、每個案例預期幾次 cue。行為語意（VIEW／SELECT、Back、強制退出、自動旁路、返回 opener）以 selection-cues 為準，本檔只寫測法。

**何時用**：要為非 draft 選牌聲音建立或執行專項 fixture。
**何時不用**：還在決定聲包與 owner → [selection-cues](selection-cues.md)；draft 選牌 → [screen-cues](screen-cues.md)。

## Done when

下列各案例都有 fixture 結果，每案記錄 action 與 generation，逐項 `_check()` 通過；尚未實作的 guard 以紅測保留，不標為通過。

## 接法

先照 [mixing](mixing.md) 核實播放替身／Dummy；核實之前只做查碼。目前沒有 Selection／Audio suite。

擬建 `tests/ui_card_selection_probe.gd`，由兩種 caller 之一呼叫：

- 設施 fixture 在休息按鈕產生真實的 pick action 之後呼叫；
- 新的選牌情境 caller 以 runtime load 載入。

靜態節點檢查可以接在 Smoke 的 Root ready 兩個 frame 之後。互動測試必須走 `_on_card_selected`／Confirm／Back 與 action queue，再逐項 `_check()`，並有界地等待 idle；不能直接 emit confirmed 來取代使用者路徑。每案都記錄 action 與 generation；signal 總數不能代替語意 cue 的計數。

## 案例與預期計數

**基準案**：候選數多於 min，min=1、max=2、required=true、quick_pick=false、can_back_out=true。

- 選一張 → 反選 → 選另一張 → Confirm：開頁 1、暫選 2、反選 1、手動提交 1；若採用足額邊緣提示則為 2；效果成功音依實際 child 結果計 1。
- 同設定改走正常 Back：提交 0、取消 1、child 成功 0。
- 不允許 Back 或不足額時直接呼叫 handler：應被新的 guard 拒絕；guard 未實作前保留此現況缺陷的紅測。

**quick_pick**：選到 max 時只自動提交 1 次，之後再按 Confirm 不再提交；超過 max 或不可選的牌不新增暫選。

**強制退出**：選中後在等待中強制退出：提交 0、正常取消 0、結果 0，action 有界收束；第二次重開時沒有舊 cue。

**自動旁路**：

- 候選 0 且 min=1、required：requested 0、開頁 0、結果 0；
- 候選剛好等於 min 的合法案：開頁 0、手動提交 0、真實效果 1；
- min=0 的空集合：依 child 的實際效果另定期望。

**VIEW**：四種牌堆及空牌堆：選取、confirmed、結果全為 0；開頁與 Back 各 1；牌堆資料不變。
