# motion — UI 動態與場景演出的共通契約

[美術入口](../../art-assets.md)｜[整套畫面](../../scene-pack.md)｜[人物逐格](../animation.md)｜[UI 畫面入口](../../ui/screens/README.md)

本篇是 UI 動態（卡牌、回合、選角、選單、結算）與場景演出（對話、設施、選牌、地圖）的入口：先固定共同生命週期——單一 owner、generation、輸入、跳過／取消、減少動態與還原——再依用途進子流程。一個完整用途指「進入→展示→操作→成功／拒絕→離開」，包含圖片、文字、節點動態與聲音時點。

**何時用**：依完整用途交付動態、素材、事件、輸入及音訊接線；製作完整用途演出前固定共同生命週期。

**何時不用**：只改布局／互動走 [UI 畫面入口](../../ui/screens/README.md)；只換圖走 [美術入口](../../art-assets.md)；人物 frame 格式與逐格走 [人物動畫](../animation.md)；玩法數值不在本篇決定。

## Done when

用途記錄填有事件→資料 ID（或 request 身分）→視覺根→屬性 owner→素材與引用→觸發／完成時間段→輸入／取消／重入／還原政策→成功提交點→驗收與未驗項。新實作有控制器檔與背景專項日誌；只完成規格時明標「未實作」，不用幾張素材代表場景已接完，也不把未驗畫面寫成完整演出通過。文件 lint 通過（見 [testing](../../../testing.md)）。

## 依用途選子流程

<!-- wf-nav -->
| 用途 | 子流程 |
|---|---|
| 抽牌、hover、選目標、出牌、棄牌、升級 | [卡牌動態](cards.md) |
| 回合提示、選角、選單、結算 | [畫面轉場](menus.md) |
| 對話面板／頭像姓名／本文／選項；商店商品／成交拒絕／售罄 | [對話與商店](dialogue-shop.md) |
| 獎勵揭示／取走／草稿／跳過；地圖節點／路徑旅行／開閉 | [獎勵與地圖](rewards-map.md) |
| 休息服務／選牌 Back／完成互斥；非 Draft 牌庫 VIEW／SELECT／Confirm／返回 | [休息與牌庫選牌](rest-selection.md) |

現況不是所有 UI 都有動畫，現有 overlay 多半是立即顯示、填資料、清子項；新增序列需要自己的控制器與取消契約。各子流程區分「既有」「待實作」「未驗」，不以存在動畫節點代替消費端證據，也不把資料事件當成任意動畫的完成事件（例如商店 purchased 早於扣款）。程式事實以 [UI 場景篇](../../ui/screens/README.md) 為準。

## 流程

### 一個演出責任者

從 [Root.tscn](../../../../../game/scenes/Root.tscn) 找場景根與控制腳本，再核對 signal 消費端；靜態查核基準是 4dac5abe 加本地修復。不要因節點有 AnimationPlayer 就推定有播放呼叫。先做一套短流程，再沿相同契約擴到其他用途。

每個 cue 記「觸發／成功條件、資料 ID 或 request 身分、所屬根、被寫屬性、開始／持續／完成、可否輸入、被誰取消、最終狀態、音訊 owner」。這是交付規格，不是現有 loader schema；同質清單超過 1 KB 用 [資料檔契約](../../../common/data-files.md)。音效共用同一成功事件，不能讓視覺及音訊各自再執行購買／出牌／升級。

新增控制器應保存自己的 Tween／timer／連線與本次 generation。重播先取消同屬性舊演出，再從可觀察的當前值或指定起點開始；完成回呼必須檢查 generation、資料身分與節點存活。關閉／切場／死亡時失效舊回呼、釋放自己建立的節點，明確回復 modulate、position、scale、rotation、z_index、visible 與輸入狀態。不要依賴動畫結束才解除輸入鎖。

採用 [Godot Tween（stable）](https://docs.godotengine.org/en/stable/classes/class_tween.html) 時，同一屬性只給一個 Tween owner；保存引用以 kill 中斷，每次重播建立新 Tween。Container 負責的布局位置不與補間搶寫：新增動畫包裹節點，由 UI owner 定布局根，動畫 owner 只動內層視覺。alpha=0 不等於禁止點擊，需明定 disabled／mouse_filter 與鍵盤確認政策。

### 資料狀態與演出階段

子流程的節點根均相對 Root。先依 UI 畫面流程確認資料與合法操作，再套演出；沒有有效資料時顯示可用的錯誤／返回狀態，不等無窮動畫，也不另造全域未實作服務。

演出開始前保存待顯示資料與節點歸屬；關閉時先鎖住舊輸入並使舊回呼失效，完成視覺收尾後才釋放。若既有流程立即 queue_free／hide，新增轉場須修改其責任邊界或用唯讀視覺副本，不能在已釋放物件上排 Tween。新 wrapper 的相對尺寸／clip／mouse_filter 交 UI owner，不直接搶寫 Container 子項位置。

### 減少動態與跳過

UserSettingsData 目前沒有 reduced-motion 欄位；需新實作設定及各 owner 的消費端，不能只寫 JSON。先準備無飛行／搖晃／循環閃爍的版本，以靜態高亮及完整文字保留資訊；選擇、升級、回合與結算語意一致。跳過演出、取消任務、完成動畫是三種結果，只有成功邏輯提交一次。取消自建 Tween 後要自行結束等待並還原，不把其 finished 當唯一出口。

### 驗證

helper 接線與證據判讀見 [verification](../../ui/verification.md)：用途 helper 要接到既有 Smoke／Combat caller，記入口、目標斷言、timeout、命令／退出碼與日誌。演出另斷言屬性還原、輸入旗標與回呼數。

## 交接

每個用途交成功、拒絕／取消、重開三種情境；列素材 hash 與分層／尺寸、場景根、cue owner 與唯一 cue 事件、玩法提交點、輸入／還原／減少動態政策與未驗項。美術交素材分層／尺寸，UI 交視覺根與輸入／還原政策，音訊交唯一 cue 事件。重做通用動態系統不是素材交付前置：下一位 agent 先選一個用途，在隔離候選建 helper，再實作控制器與演出；來源與限制見 [動畫分析](../../../../../analysis/slay-the-robot/design/animation.md)。動畫／聲音完成不得自行再次提交玩法。
