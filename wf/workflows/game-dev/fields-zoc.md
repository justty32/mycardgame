# fields-zoc — 場域、控制區與位置反應

[機制入口](mechanics.md)｜[場域接線分析](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md)｜[驗證](validation.md)

**何時用**：新增場域、移動成本、借機攻擊、位移反應或跨盤場域接線。

**何時不用**：只調卡牌數值走 [卡牌設計](card-design.md)；純圖像／場域特效走 [美術素材](art-assets.md)，仍沿用本頁的資料觸發點。

## Done when

對應 Field／DualBoard 回歸命令有成功結果，新增情境可在 assertion 定位；公開 schema、分析與受影響工作流已更新；文件 lint 與 boundary 檢查通過（見 [testing](../testing.md#文件檢查修改後必跑)）。只有取得實際執行證據才能寫通過，headless 的成功不代表視覺或硬體輸入已驗。

## 流程

先讀 [雙棋盤契約](../../../analysis/slay-the-robot/design/dual-board/README.md) 與 [場域規格](../../specs/combat-framework/13-movement-fields-position.md)，查 source／tests 的當前行為。記錄一個具體事件：誰在何盤何格，何時進入／離開、站著不動或跨越刻邊界，目標是誰、生命週期在哪中止。

資料用 `fields/` 的 FieldData；內容包依 [內容入口](content.md) 接載入。不為單張場域牌新建控制器。堆疊策略、到期與 interval、中途經過／生成觸發、每格各自觸發與 owner 陣營 filter 的語意見 [場域資料與生命週期](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md#場域資料與生命週期)；設計時逐項明確指定，不假設同 id 自動合成一片區域，入侵者也不能被誤判成該盤的原陣營。

建立／移除／障礙使用既有 Action，盤的解析順序見 [局部棋盤與跨盤](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md#局部棋盤與跨盤)；測試至少包含同座標另一盤不受影響。卡牌 shape 的局部格由目標盤解析，SELF_AREA 仍在施法者盤；首版跨盤方向型拒絕不可用場域 helper 偷繞過。

執行順序交給 FieldController 與 movement sequence。不要手發 `unit_moved` 冒充逐格進入，也不要在直接 BoardData.place／move 的 fixture 安排位置後宣稱 enter 整合已驗。跨盤幾何先完整提交，才執行舊盤 leave／新盤 enter；測預檢拒絕與第二端提交失敗位置均不變，也驗反應致死／轉移使舊續步停止。

新增或改反應 payload 時讀 [資源生命週期](resource-lifecycle.md)；owner 依 UID 重查、revision 與 generation 的契約見 [場域資料與生命週期](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md#場域資料與生命週期)。測 controller clear 後已展開子行動不再套效果，同刻 STACK 刷新不被舊到期工作誤刪。

有序反應使用 opt-in `add_ordered_actions`，保留一般 Action 的 LIFO／enqueue 契約；子樹由同步執行範圍或明確 parent 祖先識別（見同一核實節），不能只用「目前正在等待場域 action」旗標。測巢狀 async、外部重入、取消 callback 與整棵引用釋放；取消測試的 WeakRef 應在建立它的 async helper 完全返回後檢查。

推進時鐘要測一次跨越多刻與逐段推進的結果、事件次序相同（等價契約與有效刻的傳遞範圍見 [局部棋盤與跨盤](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md#局部棋盤與跨盤)），並涵蓋新建、刷新、死亡及兩盤同刻。

## 預覽與成本

危險預覽只支援 [預覽的實際邊界](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md#預覽的實際邊界) 列出的 action，不是任意腳本模擬。未知效果須明列估值缺口，不能以零估值宣稱安全；preview 不能消耗 RNG、充能、HP 或 block。至少比對一次實際 handler 結果，並加入 target override、block、多控制者及已用借機配對。

區分三種限制：免費點數吃地形／ZOC 成本，付費額度按實際格數，卡牌 `distance` 是實際步數上限。不要把同一個 budget 參數傳遍所有入口。

<!-- TODO(程式 agent)：M1「移動預檢步數／費用」修正中（ValidatorPathExists 的 `max_length` 與 `consumes_move_points`、BoardPathfinding.reachable_active 的付費格優先）；完成後依新程式補述出牌預檢與實際移動如何共用同一可達查詢。 -->測高成本一格、八向但曼哈頓射程、穿友不准停、撤銷被出牌／場域事件失效；強制位移另驗抗性、多格與碰撞 tick。

## 驗證與交接

從根目錄執行隔離 runner 的 `Field` 與 `DualBoard`，命令形式及無窗／headless 邊界見 [testing](../testing.md)。改共用 ActionHandler、targeting 或時間軸還要完整 All；改資料載入另驗 Smoke。純文件變更只跑文件檢查。

交接列清楚是資料 fixture、純查詢、真實 action、實際 CTB 還是人工視覺證據。待 agent 工程工作留 SESSION，只有需使用者操作的 GUI 驗收才留 WAIT_USER。新 policy、Phase 4 AI 或未定跨盤玩法另立需求，不把保留擴充位置當作已完成。
