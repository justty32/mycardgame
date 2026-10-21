# 獎勵與地圖 — 揭示、取走與旅行

[共通契約](README.md)｜[美術入口](../../art-assets.md)

**何時用**：製作獎勵選取、地圖節點及旅行演出。

**何時不用**：只改布局／互動走 [UI 畫面](../../ui/screens/README.md)。標「新增」者為待實作。

## Done when

用途記錄及所需素材／控制器檔存在，包含時間段、輸入與還原政策；專項日誌列實際斷言及退出碼。未落地者標「僅規格」，視覺未驗明列；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

先讀共通責任，再按以下實碼確認現況，選一個用途建立候選；每次只讓一個 owner 寫同一屬性。

### 獎勵：揭示、取走、選牌與跳過

**現況**：[RewardOverlay](../../../../../game/scripts/ui/RewardOverlay.gd) 控制 RunScreen/RewardOverlay/RewardContainer；combat_ended 等 actions_ended 且活著／非終局後顯示，chest_opened 直接 populate。populate 建按鈕後清 reward_data，並沒有寶箱翻牌／逐列揭示。一般 BaseRewardButton 點擊排 action 後 queue_free；CardRewardButton 等選牌 action 結束且 picked_cards 非空才移除。

卡牌草稿另由 [CardDraftSelectionOverlay](../../../../../game/scripts/ui/CardDraftSelectionOverlay.gd) 的 CardContainer 顯示；hover handler 是 pass。選一張立即加入 picked_cards、發 card_pick_confirmed 並清卡，Skip 只確認、不加入卡。不同 reward_group 的按鈕在選中群組時清除，同群組可留多項；這不是任意一張獎勵互斥，演出必須照實際群組。

新增包交獎勵框／圖示、卡背／揭示光層、選取與跳過狀態；定「載入選項→揭示→開放→確認→取走／恢復」。先保存完整 reward 顯示模型與一輪 cue 身分，再建視覺；不能重播 populate 重新發獎勵或依已清空 reward_data 推回原選項。揭示裝飾可跳過，真正選牌仍由 ActionBasePickCards 完成，完成動畫不發第二次 card_pick_confirmed。

如果取走演出晚於原按鈕釋放，使用不可互動副本；卡牌選取返回空集合保留原獎勵，不能照成功飛走。Continue、Skip、重複按同獎勵與 run_ended 的鎖定／取消政策交 [獎勵 UI](../../ui/screens/rewards-selection.md)，音訊交 [畫面 cues](../../audio/screen-cues.md)。

**驗收**：金錢／遺物／卡牌草稿各一次、同群組多項與跨群組移除、選牌成功／Skip／Back、揭示期間關閉、取走途中死亡／run_ended、重開不重領；比較資料增量和 cue 次數，結束後零副本／等待。減少動態立即呈現同一批選項，不減少可選內容。

### 地圖：可走節點、路徑移動與開閉

**現況**：[Map](../../../../../game/scripts/ui/Map.gd) 根為 RunScreen/Map，節點在 ScrollContainer/LocationContainer；show_map 重建節點並顯示，hide_map 只隱藏。can_travel 加 Global.get_next_locations 才允許 generate_visition_location。map_location_selected 立即關地圖及 can_travel=false，沒有旅行中的角色、路徑描線或門開關動畫。

[MapLocation](../../../../../game/scripts/ui/MapLocation.gd) 的 flash_location 有實際 play 呼叫；[MapLocation.tscn](../../../../../game/scenes/ui/MapLocation.tscn) 的 flash_map_location 是 2 秒 loop，對 TextureButton.self_modulate 做白→藍→白。這只標可走節點，並不動畫角色移動。按鈕自身 _on_button_up 在父層驗可走之前就設 visited，動畫流程不能把這個值直接當旅行成功證據，需交 UI／機制確認語意。

新包先交未訪／當前／可走／不可走節點、路徑與旅行標記，再定「檢查合法目的地→鎖本次旅行→演出→既有到站事件／畫面開啟」。到站動作由單一 owner 提交，不能在按下和移動完成各造一次拜訪；要延後現有 map_location_selected 必須由機制調整，素材檔無法達成。路徑素材位置需對應 location_position 與捲動容器座標，視覺 root 不借選取按鈕當會移動的 marker。

原本 Map 的捲動回復用一次 process_frame＋weakref，clear／exit 已取消；新增移動／開閉 Tween 仍需自己的取消，不可假定這個 cleanup 包含它。hide 後若保留節點，須明定停止 loop 與重開還原顏色；減少動態保留靜態可走標記。按 Back 取消未提交旅行或只關視圖要選一種，不改已完成的地點狀態。

**驗收**：can_travel=false、非鄰接點、合法點只拜訪一次、快速換目標／Back、移動途中重建或離樹、跨幕換位置、重開 map 無舊 marker／Tween／捲動回呼。對應 [地圖 UI](../../ui/screens/map.md) 與畫面 cues；背景能驗節點與事件，不能證明實際路徑對齊或點擊命中。


## 專項驗收

依每節驗收建立有限 timeout 的 fixture；另驗跳過與取消不混淆、重開不重領／重訪、減少動態保留可選資訊。關閉後零視覺副本／marker／待執行回呼。測試接入與驗收判讀沿 [共通契約](README.md#驗證)。

## 交接

交付素材分層、節點根、cue事件與身分、玩法提交點、重播／取消／減少動態、命令／日誌及未驗。下一 agent 先實作一個用途控制器與對應helper，不把文件規格當成已有功能。
