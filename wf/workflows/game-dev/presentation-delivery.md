# presentation-delivery — 一次出牌的跨領域交付

[遊戲開發](README.md)｜[完整畫面交付](scene-pack.md)｜[美術](art-assets.md)｜[聲音](audio.md)｜[UI](ui.md)

本篇是出牌與攻擊**事件鏈**的單一來源；音效、動畫、VFX 與 UI 篇只連過來，補各自領域的接法。

**何時用**：同一張卡或戰鬥事件同時涉及人物動畫、VFX、音效與 UI，需要交接事件、素材和清理責任。
**何時不用**：只替換單張圖或單段音檔走對應子流程；改傷害、等待、攔截或取消語意走 [mechanics](mechanics.md)。

## Done when

任務交付記錄存在，填明每個事件的唯一觸發 owner、素材版本、消費欄位、數量、回退、離場清理與已測／待測結果。來源查核和適用的專項命令有結果；文件 lint 通過（見 [testing](../testing.md)）。沒有執行證據的項目明列未驗，不能用動畫完成、靜態路由或 Smoke 成功代替命中／聲音／輸入驗收。

## 流程

### 先鎖定語意和所有權

從 [Hand](../../../game/scripts/ui/Hand.gd)、[HandManager](../../../game/autoload/HandManager.gd) 到 [ActionHandler](../../../game/autoload/ActionHandler.gd) 追同一 CardPlayRequest。內容 owner 管 card／animation ID、actions 與資料引用；動畫 owner 管人物 frame／狀態；VFX owner 管短效建立／消失；音訊 owner 管事件播放及停止；UI owner 管選取、回饋與資料刷新。指定一位整合 owner 保管這條事件契約；不是各領域各接一份成功 listener。

先決定「成功」指開始或完成，「命中」指攻擊嘗試或實際扣 HP；每卡、每擊、每目標是不同計數。自動／複製出牌是否演出以 `CardPlayRequest.is_duplicate_play` 等資料明定，不用真實滑鼠次數推斷。定義失敗回饋要覆蓋哪些 return、取消是否只撤回尚未送出的選取。這些是待填產品需求。

### 成功出牌與完成

Hand 通過 [互動狀態](ui/interaction-states.md#戰鬥-hud-與出牌) 所列檢查後，直接送出或選目標；HandManager 再核能量並先扣／保留能量、更新 HUD。排入佇列不等於開始執行，失效目標會退款。

選目標、驗證與執行資料由場景提供的 [CardPlayAdapter](../../../game/scripts/combat/CardPlayAdapter.gd) 決定：未掛棋盤時是基底 adapter（點敵人選目標）；掛棋盤時是 [BoardCardAdapter](../../../game/scripts/combat/board/BoardCardAdapter.gd)（選格、跨盤、盤面專屬效果在費用前拒絕）。adapter 不扣費也不入列，演出事件要在兩種模式下都有觸發點，不能只掛在 BoardView 或格子節點上。

`_play_card()` 移卡到 limbo 後發 `Signals.card_play_started`；完成 action 為 [ActionCardPlayEnd](../../../game/scripts/actions/card_actions/card_play_actions/ActionCardPlayEnd.gd) 的 `card_played`。後者仍在 action 處理中，目的牌堆移動在 HandManager 等待 actions_ended 之後；不要把 card_played 說成卡已入棄牌堆。預覽、選目標與按下卡片都不是成功。成功音選開始或完成其中一個信號；若卡片 `card_play_actions` 已有 ACTION_PLAY_SOUND，就不再在同一成功 signal 或 CardButton 重複播放。

`add_actions()` 預設每項推 stack、後項先執行；enqueue 的 current queue 才是 FIFO。HandManager 將完成 action 放在陣列前端，因而最後執行。新增 presentation action 要寫實際執行序，不按 JSON 由上往下閱讀。

### 攻擊、畫面命中與實際扣血

[ActionAttackGenerator](../../../game/scripts/actions/combatant_actions/ActionAttackGenerator.gd) 先要求人物 attack，產生每擊 actions；全數啟用時，每擊陣列為 attack、sound、per-attack animation、VFX，預設 stack 反序執行。VFX 先於 [ActionAttack](../../../game/scripts/actions/combatant_actions/ActionAttack.gd) 的 `target.damage()`，不表示已扣血。多擊／多目標要沿 interceptor 展開數量重新核算：ALL_ENEMIES 依每次 action 的存活目標產生，死亡目標略過，merge_attacks 會改成一次攻擊。

VFX 與 Attack 各自攔截、各自解析目標，RANDOM_ENEMY 可能各抽一次；傷害被阻止不保證 VFX 零次，要保證同一目標須先建立共享的已決定目標契約。ActionPlayAnimation／ActionCreateEffectAnimation／ActionPlaySound 都是 instant BaseAction，不等待媒體完結；ActionHandler 執行後仍讓出 frame，非 instant 的 time_delay 也是執行**後**等待。調 fps 或效果長度不會把 damage 對齊命中幀。若需等待投射物／命中幀，交 mechanics 設計可取消 action，不能順帶改 delay 或扣血位置。

目前 AttackGenerator 同時加入聲音 action 並傳 audio_path 給 Attack；Attack 在 `target.damage()` 前又立即呼叫 generate_sound_action，因此非空值存在重複播放來源。這是待修接線，不是「每擊一次」保證。實際扣血依 Player／Enemy.damage 的 `combatant_damaged`；格擋大於傷害才發 `combatant_blocked`，剛好相等會發 `combatant_block_broken` 並回傳零傷害。需要零 HP 損失提示須覆蓋兩者，不可只聽 blocked。聲音接法見 [音效](audio/sfx.md)。

### 拒絕、取消與離場

Hand／HandManager 的拒絕 return 沒有統一拒絕信號。UI 回饋如需新增，指定一個能辨識實際拒絕原因的 owner；預覽／hover 不得播放成功或命中媒體，也不得改 energy、牌堆或戰鬥 RNG（KeywordContainer 的既有副作用見 [tooltip 與延後刷新](ui/tooltip-refresh.md#延後刷新與預覽副作用)）。

背景取消與右鍵（可能執行 `card_right_click_actions`）的差異見互動狀態，右鍵不能一概當無副作用取消。排隊退款與已執行傷害的回滾不是同一功能，沒有既定需求時不得新增。

[Root._exit_tree](../../../game/scripts/Root.gd) 清 action／interceptor；ActionHandler 以 generation 失效舊 continuation，取消 async action 並清 queue。這不會自動停止 SoundManager 已接手的聲音，也不會遍歷刪除已生成 VFX（回收方式見 [VFX](art-assets/vfx.md#所有權與取消)）。新 listener、持續效果、音樂或環境音需另定註銷／停止 owner；參照 [音樂](audio/music.md) 與 [生命週期](resource-lifecycle.md)。

### 素材契約與回退

把母稿／輸出版本接到穩定內容 ID 和消費欄位：卡圖是 card_texture_path，人物是 character_animation_id／enemy_animation_id，命中特效是 impact_vfx_animation_id，聲音是 audio_path。動畫交尺寸、原點、frame 順序、duration／fps、loop／next；UI 交顯示框與安全區，音訊交格式、bus、loop、停止及無聲替代。批次同質記錄超過 1 KB 依 [資料契約](../common/data-files.md) 落資料檔。

完整路徑、FileLoader 快取與 MISSING fallback 判讀見 [靜態素材整合](art-assets/static-assets.md#整合完整路徑與可重現替換)；音訊 fallback 也不代表靜音。缺 AnimationData 時效果略過，缺軌／錯 loop 可能無法完成清理。回退應明列沿用哪個已驗資產或停用哪個純呈現接點，不能改規則值補救。

### 最小驗收與交接

交付同一可取得卡牌與 fixture，記錄正常一次、全格擋、等額破盾、多擊／多目標、不可出牌、選目標取消、預覽及離場的預期事件數和資料狀態，未掛／已掛棋盤兩種模式都要有（見 [validation 的棋盤開關](validation.md#棋盤開關兩種模式都要驗)）。先以引用／檔頭／JSON／source 核對，實作時由 runtime owner 接專項 helper；直接執行聲音 action 不算成功出牌鏈已驗。背景音訊驗證先證明 Dummy 或替身沒有實體輸出（[mixing](audio/mixing.md)）；證據層級見 [verification](ui/verification.md#證據層級與判讀)。

## 交接

整合 owner 將素材／事件契約和未驗項交給對應領域；規則或等待需求接 mechanics，獨立冷接手復走接 [agent-session](../agent-session.md)。查碼基準是 2026-10-19 固定的上游加 lifecycle 修復；更換版本後重查事件序。
