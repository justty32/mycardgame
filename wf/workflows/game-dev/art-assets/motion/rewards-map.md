# 獎勵與地圖 — 揭示、取走與旅行

[共通契約](README.md)｜[獎勵 UI](../../ui/screens/rewards-selection.md)｜[地圖 UI](../../ui/screens/map.md)

**何時用**：製作獎勵選取、地圖節點及旅行演出。

**何時不用**：只改布局／互動走 [UI 畫面](../../ui/screens/README.md)。標「新增」者為待實作。

## Done when

用途記錄及所需素材／控制器檔存在，包含時間段、輸入與還原政策；專項日誌列實際斷言及退出碼。未落地者標「僅規格」，視覺未驗明列；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

先讀共通責任，再以場景篇確認現況，選一個用途建立候選；每次只讓一個 owner 寫同一屬性。

### 獎勵：揭示、取走、選牌與跳過

**現況**以 [獎勵 UI](../../ui/screens/rewards-selection.md) 為準：RewardOverlay 建按鈕後清 reward_data，沒有寶箱翻牌／逐列揭示；一般按鈕點擊排 action 後 queue_free，CardRewardButton 只有 picked_cards 非空才移除；draft 選一張立即完成、Skip 只確認；reward_group 決定哪些按鈕被清除。演出必須照實際群組，不是任意一張獎勵互斥。

新增包交獎勵框／圖示、卡背／揭示光層、選取與跳過狀態；定「載入選項→揭示→開放→確認→取走／恢復」。先保存完整 reward 顯示模型與一輪 cue 身分，再建視覺；不能重播 populate 重新發獎勵。揭示裝飾可跳過，真正選牌仍由 ActionBasePickCards 完成，完成動畫不發第二次 card_pick_confirmed。

如果取走演出晚於原按鈕釋放，使用不可互動副本；卡牌選取返回空集合保留原獎勵，不能照成功飛走。飛向牌組的圖像要在 Action 完成資料後才啟動，或採明確受控的等待契約；Skip／離場取消尚未完成的 reveal／tooltip，晚到動畫不得重新開 draft。Continue、Skip、重複按同獎勵與 run_ended 的鎖定政策交獎勵 UI，音訊交 [畫面聲包](../../audio/screen-cues.md)。

**驗收**：金錢／遺物／卡牌草稿各一次、同群組多項與跨群組移除、選牌成功／Skip／Back、揭示期間關閉、取走途中死亡／run_ended、重開不重領；比較資料增量和 cue 次數，結束後零副本／等待。減少動態立即呈現同一批選項，不減少可選內容。

### 地圖：可走節點、路徑移動與開閉

**現況**以 [地圖 UI](../../ui/screens/map.md) 為準：show_map 重建節點、hide_map 只隱藏；map_location_selected 立即關地圖並禁止 travel，沒有旅行中的角色、路徑描線或開關動畫；flash_map_location 只標可走節點；MapLocation 在父層驗可走之前就設 visited，動畫流程不能把它當旅行成功證據。

新包先交未訪／當前／可走／不可走節點、路徑與旅行標記，再定「檢查合法目的地→鎖本次旅行→演出→既有到站事件／畫面開啟」。到站動作由單一 owner 提交，不能在按下和移動完成各造一次拜訪；要延後現有 map_location_selected 必須由機制調整，素材檔無法達成。路徑素材位置需對應 location_position 與捲動容器座標，視覺 root 不借選取按鈕當會移動的 marker。

Map 既有的捲動回呼由 clear／exit 取消，但新增移動／開閉 Tween 仍需自己的取消，不可假定這個 cleanup 包含它。hide 後若保留節點，須明定停止 loop 與重開還原顏色；減少動態保留靜態可走標記。按 Back 取消未提交旅行或只關視圖要選一種，不改已完成的地點狀態。

**驗收**：can_travel=false、非鄰接點、合法點只拜訪一次、快速換目標／Back、移動途中重建或離樹、跨幕換位置、重開 map 無舊 marker／Tween／捲動回呼。

## 專項驗收與交接

依每節驗收建立有限 timeout 的 fixture；另驗跳過與取消不混淆、重開不重領／重訪、減少動態保留可選資訊，關閉後零視覺副本／marker／待執行回呼。fixture 接線與證據判讀見 [verification](../../ui/verification.md)。交付素材分層、節點根、cue 事件與身分、玩法提交點、重播／取消／減少動態、命令／日誌及未驗；下一 agent 先實作一個用途控制器與對應 helper，不把文件規格當成已有功能。
