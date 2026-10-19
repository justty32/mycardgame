# 演出共通契約 — owner、輸入、取消與還原

[UI 動態入口](../ui-motion.md)｜[場景編排入口](../scene-choreography.md)

**何時用**：製作完整用途演出前固定共同生命週期。**何時不用**：人物 frame 格式回 [人物動畫](../animation.md)，玩法數值不在本篇決定。

## Done when

用途記錄填有資料身分、視覺根、屬性owner、觸發／完成、輸入／取消／還原及未驗項；新實作有背景專項日誌，純規劃明標未實作，文件 lint 通過。

## 流程

<!-- wf-nav -->
| 用途 | 子流程 |
|---|---|
| 抽牌至升級的卡牌演出 | [卡牌](cards.md) |
| 回合、選角、選單、結算 | [畫面轉場](menus.md) |
| 對話內容與商品操作 | [對話與商店](dialogue-shop.md) |
| 獎勵選取與地圖旅行 | [獎勵與地圖](rewards-map.md) |
| 休息服務與非 Draft 牌庫 VIEW／SELECT | [休息與牌庫選牌](rest-selection.md) |

### 一個演出責任者

從 [Root.tscn](../../../../../game/scenes/Root.tscn) 找場景根與控制腳本，再核對 signal 消費端；本篇以 2026-10-19、4dac5abe 加本地修復靜態查核。不要因節點有 AnimationPlayer 就推定有播放呼叫。先做一套短流程，再沿相同契約擴到其他用途。

每個 cue 記「觸發／成功條件、資料 ID 或 request 身分、所屬根、被寫屬性、開始／持續／完成、可否輸入、被誰取消、最終狀態、音訊 owner」。這是交付規格，不是現有 loader schema；同質清單超過 1 KB 用 [資料檔契約](../../../common/data-files.md)。音效共用同一成功事件，不能讓視覺及音訊各自再執行購買／出牌／升級。

新增控制器應保存自己的 Tween／timer／連線與本次 generation。重播先取消同屬性舊演出，再從可觀察的當前值或指定起點開始；完成回呼必須檢查 generation、資料身分與節點存活。關閉／切場／死亡時失效舊回呼、釋放自己建立的節點，明確回復 modulate、position、scale、rotation、z_index、visible 與輸入狀態。不要依賴動畫結束才解除輸入鎖。

採用 [Godot 4.6 Tween](https://docs.godotengine.org/en/4.6/classes/class_tween.html) 時，同一屬性只給一個 Tween owner；保存引用以 kill 中斷，每次重播建立新 Tween。Container 負責的布局位置不與補間搶寫：新增動畫包裹節點，由 UI owner 定布局根，動畫 owner 只動內層視覺。alpha=0 不等於禁止點擊，需明定 disabled／mouse_filter 與鍵盤確認政策。


### 資料狀態與演出階段

沿 [Root.tscn](../../../../../game/scenes/Root.tscn) 找實際節點，子流程的根均相對 Root。先依 UI 畫面流程確認資料與合法操作，再套演出；沒有有效資料時顯示可用的錯誤／返回狀態，不等無窮動畫。共用本篇責任契約，不另造全域未實作服務。

演出開始前保存待顯示資料與節點歸屬；關閉先鎖住舊輸入並使舊回呼失效，完成視覺收尾後才釋放。若既有流程立即 queue_free／hide，新增轉場須修改其責任邊界或用唯讀視覺副本，不能在已釋放物件上排 Tween。新 wrapper 的相對尺寸／clip／mouse_filter 交 UI owner，不直接搶寫 Container 子項位置。


### 減少動態與跳過

UserSettingsData 目前沒有 reduced-motion 欄位；需新實作設定及各 owner 消費，不能只寫 JSON。先準備無飛行／搖晃／循環閃爍版本，以靜態高亮及完整文字保留資訊；選擇、升級、回合與結算語意一致。跳過演出、取消任務、完成動畫是三種結果，只有成功邏輯一次提交。取消自建 Tween 後自行結束等待／還原，不把其 finished 當唯一出口。

### 驗證與交接

沿 [驗證](../../validation.md) 將用途 helper 接既有 Smoke／Combat；helper 只存檔不會自動執行。記入口、目標斷言、timeout、命令／退出碼與日誌。背景能驗事件、屬性、輸入旗標與回呼數，不能驗視覺節奏或真實點擊。本輪只文件／靜態，不跑 Godot、GUI、聲音或製作素材。

## 交接

每個用途交一個成功、拒絕／取消及重開情境；列素材hash、場景根、cue owner、玩法提交點、輸入／減少動態政策與未驗。重做通用動態系統不是素材交付前置；先選一個用途建候選及 helper。動畫／聲音完成不得自行再次提交玩法。
