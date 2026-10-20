# fields-zoc — 場域、控制區與位置反應

[機制入口](mechanics.md)｜[場域接線分析](../../../analysis/slay-the-robot/architecture/07_fields_zoc.md)｜[驗證](validation.md)

**何時用**：新增場域、移動成本、借機攻擊、位移反應或跨盤場域接線。

**何時不用**：只調卡牌數值走 [卡牌設計](card-design.md)；純圖像／場域特效走 [美術素材](art-assets.md)，仍沿用本頁的資料觸發點。

## Done when

對應 Field／DualBoard 回歸命令有成功結果，新增情境可在 assertion 定位；公開 schema、分析與受影響工作流已更新，strict lint／boundary 回傳 0。只有取得實際執行證據才能寫通過，headless 的成功不代表視覺或硬體輸入已驗。

## 流程

先讀 [雙棋盤契約](../../../analysis/slay-the-robot/design/dual-board/README.md) 與 [場域規格](../../specs/combat-framework/13-movement-fields-position.md)，查 source／tests 的當前行為。記錄一個具體事件：誰在何盤何格，何時進入／離開、站著不動或跨越刻邊界，目標是誰、生命週期在哪中止。

資料用 `fields/` 的 FieldData；內容包依 [內容入口](content.md) 接載入。不為單張場域牌新建控制器。確認 filter 相對 owner 陣營或絕對 PARTY／ENEMY；盤身分與陣營獨立，入侵者不能被誤判成該盤的原陣營。明確指定堆疊策略、時長、interval、是否中途經過／生成觸發；多格不同 cell 的場域實例會各自觸發，不能假設同 id 自動合成一片區域。

建立／移除／障礙使用既有 Action；顯式 `board_id` 優先，未給才依 request 或 parent 實際盤。測試至少包含同座標另一盤不受影響。卡牌 shape 的局部格由目標盤解析，SELF_AREA 仍在施法者盤；首版跨盤方向型拒絕不可用場域 helper 偷繞過。

執行順序交給 FieldController 與 movement sequence。不要手發 `unit_moved` 冒充逐格進入，也不要在直接 BoardData.place／move 的 fixture 安排位置後宣稱 enter 整合已驗。跨盤幾何先完整提交，才執行舊盤 leave／新盤 enter；測預檢拒絕與第二端提交失敗位置均不變，也驗反應致死／轉移使舊續步停止。

新增或改反應 payload 時讀 [資源生命週期](resource-lifecycle.md)。owner 可死亡、釋放或跨盤；依 UID 重新找活來源，不能以強參照保留已離場角色。測 controller clear 後已展開子行動不再套效果；同刻 STACK 刷新要以 revision 阻止舊到期工作誤刪新狀態。

有序反應使用 opt-in `add_ordered_actions`，保留一般 Action 的 LIFO／enqueue 契約。子樹由同步執行範圍或明確 parent action 祖先識別，不能只用「目前正在等待場域 action」旗標：await 期間加入的獨立工作不應變成其子動作。測巢狀 async、外部重入、取消 callback 與整棵引用釋放；取消測試的 WeakRef 應在建立它的 async helper 完全返回後檢查。

推進時鐘要測一次跨越多刻與逐段推進的結果、事件次序相同，並涵蓋新建、刷新、死亡及兩盤同刻。場域子行動須沿 parent action／`inherit_execution_context` 傳遞有效刻；signal listener 另造獨立行動時不能假定會繼承。

## 預覽與成本

危險預覽只支援分析列出的 action，不是任意腳本模擬。未知效果須明列估值缺口，不能以零估值宣稱安全；preview 不能消耗 RNG、充能、HP 或 block。至少比對一次實際 handler 結果，並加入 target override、block、多控制者及已用借機配對。

區分三種限制：免費點數吃地形／ZOC 成本，付費額度按實際格數，卡牌 `distance` 是實際步數上限。不要把同一個 budget 參數傳遍所有入口。測高成本一格、八向但曼哈頓射程、穿友不准停、撤銷被出牌／場域事件失效；強制位移另驗抗性、多格與碰撞 tick。

## 驗證與交接

從根目錄執行隔離 runner 的 `Field` 與 `DualBoard`，命令形式及無窗／headless 邊界見 [testing](../testing.md)。改共用 ActionHandler、targeting 或時間軸還要完整 All；改資料載入另驗 Smoke。純文件變更只跑文件檢查。

交接列清楚是資料 fixture、純查詢、真實 action、實際 CTB 還是人工視覺證據。待 agent 工程工作留 SESSION，只有需使用者操作的 GUI 驗收才留 WAIT_USER。新 policy、Phase 4 AI 或未定跨盤玩法另立需求，不把保留擴充位置當作已完成。
