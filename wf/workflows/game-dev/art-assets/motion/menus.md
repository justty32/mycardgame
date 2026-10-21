# 畫面轉場 — 回合、選角、選單與結算

[共通契約](README.md)｜[美術入口](../../art-assets.md)

**何時用**：製作回合提示、選角回饋、頁面轉場及終局演出。

**何時不用**：只改布局／互動走 [UI 畫面](../../ui/screens/README.md)。標「新增」者為待實作。

## Done when

用途記錄及所需素材／控制器檔存在，包含時間段、輸入與還原政策；專項日誌列實際斷言及退出碼。未落地者標「僅規格」，視覺未驗明列；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

先讀共通責任，再按以下實碼確認現況，選一個用途建立候選；每次只讓一個 owner 寫同一屬性。

### 回合提示與規則回呼

Root 的 CombatAnimation 有 start_turn（1 秒）／end_turn（0.5 秒）。[CombatDirector](../../../../../game/scripts/combat/CombatDirector.gd) 經 [CombatActionPhases](../../../../../game/scripts/combat/CombatActionPhases.gd) 在主角行動開始／結束時播放並 await animation_finished；動畫內已無流程 callback 與 EndTurnButton 解鎖軌，start_turn 只剩 TurnOverlay 淡入淡出與 update_turn_label method 軌，end_turn 只剩 EndTurnButton:disabled 軌。改時長會直接改變行動節奏。

這段既有動畫仍承載回合標籤更新與按鈕 disabled 狀態，而且行動流程在等它的 animation_finished；縮短、跳過或減少動態不能只停掉動畫，否則可能漏更新回合標籤、留下錯誤的按鈕狀態，或讓流程等不到 finished。若改造，先把一次性回合完成責任與純視覺效果分開，驗 start/end 各一次、無提前輸入與無重複抽牌。人物攻擊動畫則不自動管命中，兩者不可套同一假設。

### 選角、選單與結算

[NewRunMenu](../../../../../game/scripts/ui/menus/NewRunMenu.gd) 以 character ID 建按鈕，預設自動選第一個，再填名字／血量／金錢／描述與初始遺物；圖來自 [CharacterSelectionButton](../../../../../game/scripts/ui/CharacterSelectionButton.gd) 的 character_icon_texture_path。沒有立繪淡入／選角逐格入口。新素材包需頭像各狀態、立繪、資訊安全區；擬定「選擇ID立即成立→立繪交叉淡化→資訊可讀」，快速切角以最新 ID 取代舊演出。啟動 run 仍由現有按鈕 handler，一次執行；不得等過期立繪完成後啟動錯角色。

[BaseMenu](../../../../../game/scripts/ui/menus/BaseMenu.gd) 的 intro/outro hooks 預設 null，子類目前未覆寫。導航先 clear_menu（隱藏且子類可釋放內容）才取得 outro，直接填淡出 Tween 可能已沒有可見內容。新增轉場先重定「鎖導航→保留離場視覺→outro→clear→populate→intro→解除鎖」，或明確同時進出，不能只實作 hook 就回報完成。反覆返回、連點不同目的地、途中離樹都須取消舊導航等待。選單素材交背景／面板／按鈕狀態與視覺根，資料和焦點歸 UI owner。

[RunSummaryOverlay](../../../../../game/scripts/ui/RunSummaryOverlay.gd) 在 run_victory 或 player_death_animation_finished 立即填文字與統計、顯示勝／敗；EndRunButton 呼叫 Global.end_run。沒有計數上升／逐列揭示。新增演出保存最終統計，動畫只顯示插值，跳過立即顯示最終值；勝敗標章、背景與文字分層。終止／重新進入清舊副本，還原按鈕與 alpha，確認不重發勝敗事件、不重寫統計。聲音／選角初始化政策對齊 [畫面 cues](../../audio/screen-cues.md)。


## 專項驗收

驗 start/end 回合各一次、最新選角 ID、導航中斷後不跳舊頁、反覆返回不留輸入鎖、結算跳過顯示最終值、減少動態不漏 method track 的玩法責任。離樹零回呼，沒有重複開始run／發獎／改統計。測試接入與驗收判讀沿 [共通契約](README.md#驗證)。

## 交接

交付素材分層、節點根、cue事件與身分、玩法提交點、重播／取消／減少動態、命令／日誌及未驗。下一 agent 先實作一個用途控制器與對應helper，不把文件規格當成已有功能。
