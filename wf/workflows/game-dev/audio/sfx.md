# sfx — 一次性音效、語意接線與變體

[聲音子流程](README.md)｜[混音與驗證](mixing.md)｜[核實分析](../../../../analysis/slay-the-robot/design/audio.md)

**何時用**：出牌／攻擊／命中／拒絕、按鈕與角色選擇等短音。
**何時不用**：音樂與循環環境音交 [music](music.md)；玩法結果由機制流程決定。

## Done when

素材／來源紀錄及事件接線檔存在；任務證據記每一情境的預期／實際播放次數、停止與變體策略。接入測試有本次 `AUDIO:` 斷言與 suite 完成標記，未執行時明列缺口，不以載入通過代替語意驗證。

## 流程

### 先選語意與唯一播放者

成功出牌先決定「接受並開始」或「效果完成」。[HandManager](../../../../game/autoload/HandManager.gd) 的 `_play_card()` 移入 limbo 後發 `Signals.card_play_started`；[ActionCardPlayEnd](../../../../game/scripts/actions/card_actions/card_play_actions/ActionCardPlayEnd.gd) 才發 `card_played`。預覽、選目標與按下卡片都不是成功。若用卡片 `card_play_actions` 的 ACTION_PLAY_SOUND，就不要再在同一成功 signal 播同一聲。自動／複製出牌是否播放要以 `CardPlayRequest.is_duplicate_play` 等資料明定，不用真實滑鼠次數推斷。

攻擊風聲與扣血命中分開。[ActionAttack](../../../../game/scripts/actions/combatant_actions/ActionAttack.gd) 在 `target.damage()` 前播 `audio_path`，不能保證扣血；[ActionAttackGenerator](../../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 又追加 ACTION_PLAY_SOUND，並把同 path 傳給 Attack，已有雙播來源。新需求先選唯一接點並補計數回歸，不能直接填 path 宣稱一擊一次。多段／多目標明定「每卡、每段、每受傷目標」哪一種；死亡目標略過、merge_attacks 改成一次攻擊也要驗。

實際扣血可觀察 `combatant_damaged`，完全吸收不能只觀察 `combatant_blocked`：Player／Enemy 在 block > damage 才發 blocked；block == damage 發 block_broken，然後返回零傷害。若需求是「任何零扣血格擋一次」，要結合結果或建立有明確語意的新事件，避免破盾與命中重複。死亡、格擋、命中優先級及同 frame 聚合屬本次音效政策，現框架沒有通用仲裁。

拒絕讀 [Hand](../../../../game/scripts/ui/Hand.gd) 的 `_on_card_selected()`（禁用、不可出、已排隊）及 HandManager（能量不足、死亡目標退款）。目前沒有統一拒絕 signal。先區分手動輸入失敗、取消選取與系統取消；由單一控制器回報原因並播放一次，不能把 `can_play_card()` 的每次查詢／顯示更新當拒絕音。保留視覺原因提示。

介面音綁實際被接受的啟用操作，例如按鈕既有 `button_up` handler；hover、選取、確認分開，禁止 disabled 控件也回成功音。不要同時接 pressed、button_up 與 domain signal 播同一提示。現有 NewRunMenu 有 character_selection_audio_path；不代表所有 Button 自帶音效。頁面重建時避免重複 connect，跨場景 listener 明確離樹 disconnect／釋放，不把臨時節點捕獲在長期 callback。

### 製作與接線

按 README 保存來源與母檔。先做一個可辨識基準短音，再做同一語意的變體；比較起音、尾音、峰值及連續重播疲勞。記 pitch／gain 允許範圍、相鄰不重複、冷卻時間與同時發聲上限；這些是待實作政策，現有池沒有上限。若採隨機變體，用獨立呈現 RNG，不能消耗抽牌／傷害 RNG；可測試 seed、可重播序列與聽感自然度是不同證據。

最短資料接線為 ACTION_PLAY_SOUND 的 `audio_path` 與 `audio_path_is_absolute`，或 `ActionGenerator.generate_sound_action(path, false)`；後者立即 perform，不走佇列等待。ActionPlaySound 強制不循環，實際呼叫 `play_ui_sound()`，其 process_mode 為 ALWAYS。若暫停時音效應停止，要選一般 sound pool 或調整政策；不能因名稱含 Sound 就推定使用 PAUSABLE pool。

變體可由控制器選 path 再載入，或另行實作 AudioStreamRandomizer 資源；FileLoader 沒有變體清單 schema。插件雖辨識 Randomizer，pool 管理仍須測，不把引擎型別存在當已整合。停止一次性 UI 音用 `stop_ui_sound(resource)`；stop 只延後呼叫 player.stop，回池限制見 mixing。

### 驗證橋接

先跑 mixing 的檔頭／引用及 loader probe。語意測試沿 [combat_flow](../../../../tests/combat_flow.gd) 的 `_play()`、`_wait()`、`_idle()` 與 `_connect_observers()` 延伸，保留既有 fixture 或明確另設情境；不要改牌後照用原 20 傷害期望值。替身記錄播放請求的 path、事件 ID、次數、bus 及時間序，而不是只觀察 card_played。

成功一次、預覽零次、選目標尚未出牌零次、拒絕時成功音零次，是最小配對。拒絕音若在範圍內則手動拒絕一次；退款／取消依 brief。另驗多段、多目標、全格擋與等額破盾、零傷害、死亡及快速連按，確保沒有雙播、重入或 RNG 改變。直接 perform 音訊 action 只驗局部接線，沒有通過真實出牌路徑。

## 交接

交 [mixing](mixing.md) 驗 bus、設定與池，並把跨媒體同步所用的同一事件／時點交動畫及 VFX owner。聽感爆音、遮蔽、延遲與疲勞尚未驗時明列；當前不播放聲音。
