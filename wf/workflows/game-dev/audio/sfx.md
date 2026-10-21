# sfx — 一次性音效、語意接線與變體

[聲音子流程](../audio.md)｜[混音與驗證](mixing.md)｜[出牌時序](../presentation-delivery.md)｜[核實分析](../../../../analysis/slay-the-robot/design/audio.md)

**何時用**：出牌／攻擊／命中／拒絕、按鈕與角色選擇等短音。
**何時不用**：音樂與循環環境音交 [music](music.md)；玩法結果由機制流程決定。

## Done when

素材／來源紀錄及事件接線檔存在；任務證據記每一情境的預期／實際播放次數、停止與變體策略。接入測試有對應的 `AUDIO:` 斷言與 suite 完成標記，未執行時明列缺口，不以載入通過代替語意驗證。

## 流程

### 先選語意與唯一播放者

出牌與攻擊的事件鏈（開始／完成信號、雙播來源、Attack 在扣血前播音、blocked／block_broken／damaged 的分界）見 [出牌時序](../presentation-delivery.md#攻擊畫面命中與實際扣血) 與 [核實分析](../../../../analysis/slay-the-robot/design/audio.md#事件語意與畫面轉移補查)。聲音這一側要做的選擇：

**成功出牌**：先決定「接受並開始」或「效果完成」，只接其中一個 signal；若用卡片 `card_play_actions` 的 ACTION_PLAY_SOUND，就不要再在成功 signal 播同一聲。預覽、選目標與按下卡片都不是成功。自動／複製出牌是否播放以 `CardPlayRequest.is_duplicate_play` 等資料明定，不用真實滑鼠次數推斷。

**攻擊與扣血分開**：新需求先選唯一接點並補計數回歸，不能直接填 audio_path 宣稱一擊一次。多段／多目標明定「每卡、每段、每受傷目標」哪一種；死亡目標略過、merge_attacks 改成一次攻擊也要驗。

**零扣血格擋**：需求若是「任何零扣血格擋一次」，要同時涵蓋 blocked 與 block_broken，或建立有明確語意的新事件，避免破盾與命中重複。死亡、格擋、命中優先級及同 frame 聚合屬該任務的音效政策，現框架沒有通用仲裁。

**拒絕**：目前沒有統一拒絕 signal。先區分手動輸入失敗、取消選取與系統取消；由單一控制器回報原因並播放一次，不能把 `can_play_card()` 的每次查詢／顯示更新當拒絕音。保留視覺原因提示。

介面音綁實際被接受的啟用操作（例如既有 `button_up` handler），hover、選取、確認分開，disabled 控件不得回成功音；不要同時接 pressed、button_up 與 domain signal 播同一提示。Button 不自帶音效。頁面重建時避免重複 connect，跨場景 listener 離樹時 disconnect，不把臨時節點捕獲在長期 callback。

### 製作與接線

先做一個可辨識基準短音，再做同一語意的變體；比較起音、尾音、峰值及連續重播疲勞。記 pitch／gain 允許範圍、相鄰不重複、冷卻時間與同時發聲上限；這些是待實作政策，現有池沒有上限。若採隨機變體，用獨立呈現 RNG，不能消耗抽牌／傷害 RNG；可測試 seed、可重播序列與聽感自然度是不同證據。

最短資料接線為 ACTION_PLAY_SOUND 的 `audio_path` 與 `audio_path_is_absolute`，或 `ActionGenerator.generate_sound_action(path, false)`；後者立即 perform，不走佇列等待。ActionPlaySound 強制不循環且走 ALWAYS 的 UI pool（見 [核實分析](../../../../analysis/slay-the-robot/design/audio.md#action-與地點音樂)）；若暫停時音效應停止，要選一般 sound pool 或調整政策，不能因名稱含 Sound 就推定 PAUSABLE。

變體可由控制器選 path 再載入，或另行實作 AudioStreamRandomizer 資源；FileLoader 沒有變體清單 schema。插件雖辨識 Randomizer，pool 管理仍須測。停止一次性 UI 音用 `stop_ui_sound(resource)`；stop 只延後呼叫 player.stop，回池限制見 mixing。

### 驗證橋接

先跑 mixing 的檔頭／引用及 loader probe。語意測試沿 [combat_flow](../../../../tests/combat_flow.gd) 的 `_play()`、`_wait()`、`_idle()` 與 `_connect_observers()` 延伸；改牌後不要照用原 20 傷害期望值。替身記錄播放請求的 path、事件 ID、次數、bus 及時間序，不只觀察 card_played。

成功一次、預覽零次、選目標尚未出牌零次、拒絕時成功音零次，是最小配對。拒絕音若在範圍內則手動拒絕一次；退款／取消依 brief。另驗多段、多目標、全格擋與等額破盾、零傷害、死亡及快速連按，確保沒有雙播、重入或 RNG 改變。直接 perform 音訊 action 只驗局部接線，沒有通過真實出牌路徑。

## 交接

交 [mixing](mixing.md) 驗 bus、設定與池，並把跨媒體同步所用的同一事件／時點交動畫及 VFX owner。聽感爆音、遮蔽、延遲與疲勞尚未驗時明列。
