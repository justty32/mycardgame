# combat-cues — 一場戰鬥的組合聲音流程

[聲音場景入口](../audio.md)｜[戰鬥 UI](../ui/screens/combat.md)｜[短音接線](sfx.md)｜[配樂切換](music.md)

**何時用**：要完成戰鬥進場、出牌、傷害／格擋、死亡、回合與退出整組聲音。
**何時不用**：只替換單一音檔走 sfx；傷害／死亡規則交機制流程。

## Done when

戰鬥聲包 brief 與採用素材紀錄存在，列出每卡／每擊／每目標的次數、回合與死亡優先、中斷責任及視覺替代。測試記錄包含完整戰鬥鏈及負例的音訊請求次數；未執行 Dummy／聽感時明列，不以 Combat PASS 冒充聲音覆蓋。

## 流程

### 組成一份戰鬥聲包

先把進場提示、戰鬥循環曲／環境層、選牌／選目標、成功出牌、攻擊風聲、扣血、格擋／破盾、敵我死亡、玩家／敵人回合、勝敗收束一起設計。這是採用項目，不要求每項都有聲；brief 可明定某項靜音。主題與辨識碼共用，確認／拒絕要能區分，敵我死亡及回合提示不能被連擊掩蓋。

規格逐項記一次／循環、長度上限、前置延遲、尾音、變體、gain／pitch 範圍、冷卻、併發及可否打斷；共用格式與來源契約沿 [audio 入口](../audio.md#來源與製作共同契約)。高頻連擊先確定每段或每目標，不能靠壓低總音量掩蓋重複事件。視覺仍保留卡片移動、傷害／格擋數字、意圖、回合狀態與死亡／勝敗結果。

### 時序與唯一 owner

進場以已接受的戰鬥狀態為界，位置配樂目前由 Combat._on_map_location_selected 呼叫 music；不要在 combat_started 再播同一曲。若需要戰鬥開場短句，給該次 encounter ID 的單一呈現 owner 一次觸發，與循環曲分軌但仍遵守現有 bus 限制。

出牌確認選 card_play_started 或 card_played 一處；選牌、瞄準、預覽與不足能量不算出牌成功。攻擊風聲用已接受的攻擊段，扣血用 combatant_damaged；AttackGenerator／Attack 現有雙播及 block == damage 的例外先按 sfx 修測。多目標同 frame 可聚合為一聲，但需保留每目標視覺；不能更改傷害迴圈來節流音效。若要跟動畫接觸幀同步，先建立同次攻擊識別與呈現 cue，既有 damage 前音效不保證對齊動畫幀。

敵人／玩家死亡音選 `enemy_killed`／`player_killed` 的邏輯死亡，或 `enemy_death_animation_finished`／`player_death_animation_finished` 的呈現完成之一。需要兩段演出時以不同 cue 明列，不把同音播兩次。收束 owner 以 actor instance＋本次 encounter 去重，防重複傷害或結算回呼重播；autoplay／重複卡亦沿同一語意政策。

回合音用已發生的 `player_turn_started/ended`（CTB 下＝主角一次行動的開始／結束）、`enemy_turn_started/ended`（＝單一敵人的一次行動，每個敵人各發一次），不要用 end_action_requested（舊名 end_turn_requested）當行動已結束。一般選「玩家開始」與「敵人開始」兩個明確提示即可；多敵連續行動時要定冷卻或合併規則，加入結束音也要定與開始音重疊規則。敵人 intent 音屬行動語意，不能代替整個敵人行動提示。玩家死亡後排隊中的回合提示必須失效。

### 中斷、退出與混音

集中 owner 保存 encounter generation、正播放長音／循環 handle 及 listener；戰鬥結束、死亡結算、run_ended、場景離樹時使舊 generation 失效，取消尚未播出的連擊／回合 cue。短尾音能否自然留到獎勵頁寫在 brief；循環則交 music 明確停止或轉曲，不能只隱藏 Combat。

優先關係先定死亡／回合提示與連擊的競爭；插件沒有 ducking 或優先權系統，降低其他聲部或搶占播放都需要新控制器與測試。暫停時一般 sound PAUSABLE，但 ActionPlaySound 使用 ALWAYS 的 UI pool；明定哪些戰鬥聲要暫停、哪些選單聲要繼續，再選正確出口。停止和回池不是同一件事，依 mixing 驗兩者。

### 測試接法

先依 [mixing](mixing.md) 核實替身／Dummy，再由 `tests/combat_flow.gd` 的真實 `_play()`、`_wait()` 與 observers 接入本次 cue recorder，透過既有 Combat suite 執行。以 fixture 的 encounter／actor／request ID 關聯聲音請求，不只數 signal；修改連擊或牌組後同步 HP／費用期望值。

一條最小完整鏈是進戰鬥→玩家回合→選目標→成功出牌→扣血／格擋→敵回合→敵死→獎勵；另做玩家死→結算。斷言每狀態次數及順序、預覽／拒絕零成功音、等額破盾零扣血音、每段攻擊無雙播、最後一敵死亡後無舊回合提示。快速連按、未播放即取消、暫停恢復與重開第二場後，舊 listener 不得再記錄。

## 交接

音訊與 [場景編排](../art-assets/motion/README.md) 共用 trigger／資料 ID／呈現 root／取消 token，跨領域只交語意事件；播放器及 pool 仍歸聲音 owner。戰後獎勵與結算接 [畫面聲包](screen-cues.md)，聽感及實體音訊輸出均另驗。
