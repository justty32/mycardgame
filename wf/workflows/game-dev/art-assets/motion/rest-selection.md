# 休息與牌庫選牌 — 服務、暫選與返回

[共通契約](README.md)｜[休息 UI](../../ui/screens/rest-services.md)｜[選牌 UI](../../ui/screens/card-selection.md)

**何時用**：休息服務、牌庫／牌堆 VIEW／SELECT 的演出。

**何時不用**：草稿走 [獎勵](rewards-map.md)，升級結果走 [卡牌](cards.md)。本篇的新增演出與防護均待實作。

## Done when

用途包有素材、根、request 身分、階段與輸入政策，成功／取消／重開專項有日誌；僅規劃明標未實作，觀感與真人操作未驗；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

節點根、資料來源、rest action 範例、excluded 規則、Back／quick_pick／自動旁路與過期回呼等程式事實以 [休息 UI](../../ui/screens/rest-services.md) 與 [選牌 UI](../../ui/screens/card-selection.md) 為準，本篇只寫演出的時點與 owner。

### 視覺根與素材

RestActionContainer 與 CardSelectionOverlay 的 CardContainer 都是 Grid，Grid 管布局；新增 wrapper 只動 alpha／scale，收尾回基線。CardSelectionOverlay 以 init(data,0,false,true) 建 Card，不接戰鬥訊號，hover 為 pass，沒有入場序列。CardGlow 由暫選控制，演出不得寫 glow 或永久 CardData。服務圖示、已用章與鎖定標記須先有 UI 節點及消費端；素材交尺寸、裁切、安全區、hash。

### 休息：可用→接受→選牌／效果→完成

先完整顯示服務名稱及可用／disabled 狀態，再開放操作；空服務／全禁用仍提供合法離場。入場短淡入可跳過，輸入不能只靠透明度阻擋。新增 owner 在接受點重驗並鎖本服務與 Continue，不把按下當已完成。

時序為「接受標記→如有 SELECT 則父畫面保持可見但不可操作→子畫面關閉→等待效果→完成標記→互斥與 validator 刷新→恢復可用輸入」。rest_action_ended 才是服務完成 cue，之後仍等行動收束及資料斷言再解鎖。Back 時取消接受標記，不播完成章、不耗服務；動畫不得自行補發結束或再做治療／升級。excluded 會隨重建重設，不能新增動畫記憶宣稱服務使用跨重進持久化。

### SELECT：候選→暫選→提交／Back

opener 記 location、Action 實例及 generation 後才交輸入；候選到位才 reveal／開輸入。暫選亮燈、反選熄燈；max／validator 拒絕不演成選中。足額提示只在 are_enough_cards_picked false→true 播一次。Confirm 後鎖牌與按鈕，收尾不再發 card_pick_confirmed；quick_pick 的自動提交也只演一次。

完成、Back、強制取消與自動旁路都可能經同一全域 confirmed，須由 request 結果與 generation 區分，不能只聽 confirmed 播成功；opener 不得無限等 card_pick_requested。ActionPickCards 排入 child 後，返回 opener 時保留提交中狀態，等 actions_ended 並核對效果；休息還要同一服務的 rest_action_ended。選牌 Grid 未接升級卡面的戰鬥訊號；成功後由 opener 依結果重建，演出用前後唯讀快照。

### VIEW、退出與聲音

VIEW 點牌不暫選；進 VIEW 不沿用 SELECT action，返回仍存活 opener 並恢復輸入（返回管理尚未實作）。新演出在選牌等待時禁用 Continue；強制換點／死亡／run_end／離樹要取消自建序列、失效 request、釋放子項並還原輸入。RestOverlay 的舊 rest_action_ended 防護需要 location＋generation＋鍵存在與節點有效檢查，不能只 kill Tween。CardSelectionOverlay 新增清理需停卡片提示 timer、撤銷所屬提示與 wrapper，再 queue_free，下一 frame 驗零殘留。

聲音沿 [選牌聲包](../../audio/selection-cues.md) 與 [畫面聲包](../../audio/screen-cues.md)：服務成功取同身分 rest_action_ended，升級／取得聲取 child 真正結果，不能每層各播一次。減少動態版直接顯示完整候選、靜態選中／已用標記；取消、完成及資料提交次數不變，設定與各 owner 消費仍需新實作。

### 專項接入與交接

fixture 情境與 caller 見 [休息四種 fixture](../../ui/screens/rest-services.md#四種-fixture-的具體接法) 與 [選牌 fixture](../../ui/screens/card-selection.md#專項-fixture-和-caller)；本篇另加 cue 次數、wrapper／提示殘留、等待時換點／run_end、重開只完成一次與減少動態斷言，以有界 action idle 等待並記 stale callback=0。接線與證據判讀見 [verification](../../ui/verification.md)。交接素材、根、opener token、cue owner、取消結果、命令／斷言日誌與未驗項，再請獨立復走。
