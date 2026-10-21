# 卡牌動態 — 抽取到升級

[共通契約](README.md)｜[戰鬥 UI](../../ui/screens/combat.md)｜[出牌時序](../../presentation-delivery.md)

**何時用**：抽牌、hover、選目標、出牌、棄牌與升級的整組演出。

**何時不用**：只改布局／互動走 [UI 畫面](../../ui/screens/README.md)。標「新增」者為待實作。

## Done when

用途記錄及所需素材／控制器檔存在，包含時間段、輸入與還原政策；專項日誌列實際斷言及退出碼。未落地者標「僅規格」，視覺未驗明列；文件 lint 通過（見 [testing](../../../testing.md)）。

## 流程

先讀共通責任；出牌選取與拒絕檢查見 [互動狀態](../../ui/interaction-states.md#戰鬥-hud-與出牌)，事件先後見出牌時序。每次只讓一個 owner 寫同一屬性。

### 抽取、hover 與選目標

實際來源為 [Hand](../../../../../game/scripts/ui/Hand.gd)、[HandManager](../../../../../game/autoload/HandManager.gd)、[Card](../../../../../game/scripts/ui/card/Card.gd) 與 [Card.tscn](../../../../../game/scenes/ui/card/Card.tscn)。手牌根是 Root/RunScreen/Combat/Hand，Card 的 $Pivot 管位置／旋轉，$Pivot/CardVisual 包卡圖、框、名稱／描述／費用；美術交卡面、卡背、框、glow 與安全區，不把可變文字烘進圖。

抽取現況：HandManager 把資料移入 hand、建立 Card、發 card_drawn，最後 Hand.tween_hand 對各 Pivot 的 position／rotation 建兩個 0.2 秒 Tween；沒有從牌庫飛入／翻背面的序列。新增可定「資料入手→不可交互的卡背副本飛入→正面可見→可選」，但須說明是否改既有可操作時點；動畫不得再抽一次牌。多次 tween_hand 不保存／取消舊 Tween，連抽與重排需驗競爭。

hover 現況是 Hand 直接設 Card.position.y=-30、z_index=50，離開回 0／排序；KeywordTimer 為 0.5 秒。Card.tscn 雖有 0.2 秒 card_hover／card_unhover 動畫，腳本沒有 play 呼叫，不可宣稱正在用。新增縮放／彈起時保留 Pivot 重排與 Card hover 的層級分工，快速移入移出後回基準位置，不殘留 tooltip 或高 z_index。

選目標現況沒有拖曳箭頭／瞄準線。新增箭頭交透明材質、起終點與無效目標樣式，掛 Hand 管理的獨立視覺層，選卡／換目標只更新同一實例，取消及出牌清除；裝飾線不得擋選取。棋盤未掛時目標是敵人節點，不能假設有格子座標。

### 出牌、棄牌與升級

現況 Card 收 card_play_started、card_discarded、card_exhausted、card_added_to_draw 時呼叫 Hand.create_card_trail_from_card，再 queue_free；banished 直接釋放。尾跡來源是 [CardTrail](../../../../../game/scripts/ui/card/CardTrail.gd)／[場景](../../../../../game/scenes/ui/card/CardTrail.tscn)，是每 frame 移動 Line2D，不是卡片本體飛行的 Tween。起點是 Pivot.global_position，目的地取 HandManager.card_destination_to_ui_elements；未知 pile 沒有尾跡。不能等已釋放的 Card 播完動畫。

新增「出牌到中央→施放→入指定牌堆」先建立唯讀視覺副本並快照卡面／起點，再讓原邏輯移牌；副本不接 Card 的戰鬥／點擊 signals，避免重複行動。接觸與傷害交 [人物動畫](../animation.md)，聲音交 [戰鬥聲包](../../audio/combat-cues.md)；started、played 與每擊不能混成同一事件。拒絕出牌保留原手牌、能量與目標狀態，不播成功飛出；棄牌／消耗／放逐的終點與外觀分開。

CardTrail 目前 init 的 destination_node／is_combat_trail 自指賦值與同名參數遮蔽有疑點，_on_combat_ended 未在 _ready 連線。這是靜態待修，不保證 combat 結束立即清尾跡；新實作須測目的地釋放、移位、戰鬥結束與 run_ended，不照抄成已可靠的通用動態元件。

升級現況：Card._on_card_upgraded 只 update_card_display；[ActionPickUpgradeCards](../../../../../game/scripts/actions/card_actions/pick_card_actions/ActionPickUpgradeCards.gd) 完成選擇才升級，選牌 overlay 的 Card 也未接 combat signals。新增「舊卡→強調→新卡」由選擇／升級 owner 保存前後顯示快照，在 card_upgraded 對應正確實例後刷新，不以翻面 callback 再升級。美術交升級框／光層與前後比較位置；取消選取不得產生升級 cue，最大升級與批次多卡要專項驗證。

## 專項驗收與交接

驗連抽重排終點、快速 hover 還原、選目標取消零出牌、拒絕零飛出、成功一次副本／正確 pile、升級取消零變更／上限與批次；預覽不得啟動成功 cue，清手牌及離樹後零舊回呼。fixture 接線與證據判讀見 [verification](../../ui/verification.md)。交付素材分層、節點根、cue 事件與身分、玩法提交點、重播／取消／減少動態、命令／日誌及未驗；下一 agent 先實作一個用途控制器與對應 helper，不把文件規格當成已有功能。
