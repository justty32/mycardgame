# 非戰鬥事件與設施 — 選擇、代價與離開

[關卡入口](../level-design.md)｜[核實來源](../../../../analysis/slay-the-robot/design/noncombat.md)｜[地圖接線](map-act.md)

**何時用**：帶選項的事件，或商店、休息、寶箱內容及其資源變化。**何時不用**：戰鬥遭遇走 [combat](combat.md)，完整開始／存讀／結算走 [game-flow](../game-flow.md)。

## Done when

設計檔存在，寫明節點種類、選項與門檻、成本／收益、取消／離開／死亡、下一節點及存讀政策。資料 ID 可解析且從路線到達；專項斷言驗合法與拒絕路徑、只執行一次、資源差值、返回與續玩。未執行的 runtime、視覺及輸入驗收明列；文件 lint 通過（見 [testing](../../testing.md#文件檢查修改後必跑)）。

## 流程

### 先選真正的內容種類

EVENT、SHOP、REST_SITE、TREASURE 是四種不同節點，各有自己的資料與消費端（見[核實的種類路由](../../../../analysis/slay-the-robot/design/noncombat.md#種類路由與資料註冊)），不能用 EventData 加任意同名欄位代替。

先定義玩家看見什麼、可拒絕什麼、付出什麼、獲得什麼，以及是否允許致死或取消。設計選擇須有可解釋的取捨；別把「全部鎖住時的錯誤離開按鈕」當正常分支。

### 建一個可運作的選項事件

最短範例是 [GlobalTestDataGenerator.add_test_dialogue()](../../../../game/autoload/GlobalTestDataGenerator.gd) 的 `dialogue_pick_something`；schema、範例數值與 validator 門檻見[核實的最小構造](../../../../analysis/slay-the-robot/design/noncombat.md#選項事件的最小構造)。數值只是範例。每個狀態提供可到達的正常出口，或明確測試不可取消的需求；next ID 指向不存在的 state 也會結束，不能當成功轉移，非空 ID 應先驗存在。

成本與獎勵由 action payload 實現，文字不會自動扣資源；validator 門檻要讓扣成本後仍合法（例如扣 10 HP 用 `health_amount=11`）。GDScript 可用 Scripts 常數，JSON 的 action/validator key 必須是對應腳本路徑；數值和 target override 以 [Scripts](../../../../game/autoload/Scripts.gd) 與 BaseAction 為準。

頂層 actions 經 stack 反序執行，選項只在建立時驗 validator，沒有重驗或回滾（見[核實的執行與退出](../../../../analysis/slay-the-robot/design/noncombat.md#選項執行與退出)）。「先扣成本再給獎勵」須依真實時序排列並斷言；需要重入保護、交易原子性或動態刷新時先交 mechanics，別把兩個 actions 當交易 API。

依 [content](../content.md) 為獨立 mod 登記 DialogueData、EventData、EventPoolData、ActData；states/options 嵌入 dialogue，不另建全域表。Event 的 `event_dialogue_object_id` 指向 dialogue，non-combat pool 接 Act 的 `act_non_combat_event_pool_object_id`。預設生成器只按機率把普通戰鬥轉 EVENT；若必須出現，設固定 EVENT 位置或自訂生成。接線測例須同時驗「能抽中」與「玩家可走到」。

### 調整商店、休息與寶箱

三種設施的資料流、參數位置與未完成欄位（商店沒有移除卡牌服務、休息清單須接入玩家、寶箱 consumables 仍是 TODO）見核實的[商店](../../../../analysis/slay-the-robot/design/noncombat.md#商店的商品價格與購買)、[休息](../../../../analysis/slay-the-robot/design/noncombat.md#休息的可用選項與次數)、[寶箱](../../../../analysis/slay-the-robot/design/noncombat.md#寶箱獎勵與未完成欄位)段；數量、價格與開箱參數都不是 ActData／EventData 欄位，客製前先核對真正 action／interceptor 接點。商店驗足額／不足額、扣款／入庫／下架、消耗品滿槽及重複購買，不能只看標價；休息的可取消選牌設 `rest_action_auto_end=false` 並驗取消不消耗次數，原版 upgrade 可重複，不套用其他遊戲的單次升級規則；寶箱驗開箱、各獎勵領取／放棄、Continue 與重複開箱。

### 驗出口與存讀

EVENT、REST、SHOP 與 Reward 的出口及轉幕差異見 [map-act](map-act.md#指定跨幕終局與保存邊界)；非戰鬥放幕尾須補機制／專項。存檔時點見 [存讀與局外進度](../game-flow/persistence.md#先選保存承諾)，非戰鬥互動的保存邊界（dialogue state、休息次數、已開箱都不在快照）見[核實的保存段](../../../../analysis/slay-the-robot/design/noncombat.md#保存與幕尾邊界)。設計保存策略時驗當前位置重新進入、下一位置存讀及重複收益。

至少驗每個選項的門檻前／正好門檻、未選項無副作用、結束與死亡；設施按上述資源及次數斷言。runner、路線與 GUI 的共同規則見[共同驗收](../level-design.md#共同驗收)。

## 交接

交付 schema 與 ID 鏈、選項／設施語意、action 順序、每條分支的驗證結果、退出與存讀政策。真正未實作機制交 mechanics，路線／資源節奏交 map-act，核實事實同步 noncombat 分析。
