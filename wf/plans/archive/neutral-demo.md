> 封存 2026-10-20，已完成；現況由 analysis/slay-the-robot/design/board-module.md 與 examples/board-lab/README.md 取代。

# 中性棋盤示範包：執行計畫

基準 `9ced42f`；2026-10-20 使用者授權製作可玩的短流程，僅檔案及隔離 headless，不操作桌面或既有程序。內容置於 `examples/board-lab/pack/`，採既有 mod 結構，ID 前綴 `demo_`、安裝名 `board_lab`；不同於題材樹，也不加入 `game/external/mod_list.json`。

## 可玩流程

提供隔離可玩副本的準備入口，採 pack profile，只有示範內容；玩家自行啟動 GUI，agent 不執行。選示範角色、開始新局、起點說明、三場相鄰戰鬥（前兩場戰後領獎回地圖，第三場終局），可敗北／重開；地圖 checkpoint 跨程序讀回後繼續。卡牌全部由起始牌組取得，不靠獎勵 RNG 才能展示核心機制。

保留既有雙棋盤 A；控制區先採現有 OPPORTUNITY_ATTACK 模式，僅在示範副本的規則資料啟用。卡牌與敵人可用現有素材作工程呈現，不新增核心玩法或 Phase 4 AI。特殊卡明確描述選哪張盤與格，方向型推拉只同盤合法；場域與交換讓位置有實際影響。

## 分工與依賴

2026-10-20 使用者追加架構要求：棋盤作為戰鬥場景的可選模組，普通卡牌核心不解讀棋盤規則。既有 Hand／HandManager 的幾何、前置拒絕、舊移動欄位轉譯移到 board adapter；Director 的棋盤生命週期與呈現移到場景模組。先盤點責任與共用 hook，再分檔實作；不建立通用插件系統。真正未掛模組仍須敵人行動、普通選敵出牌與完整流程可用；誤帶棋盤效果則費用前拒絕。雙盤示範與原有回歸不得退化。

卡牌 owner 管 cards／fields／color／card pack；遭遇 owner 管 enemies／encounters／events／event pools；流程 owner 管 mod_info／角色／player prototype／Act／固定短路線生成與基礎呈現資料；測試 owner 管包內正常流程與存讀 scenarios。工具 owner 管可玩副本準備與純 Python 測試。整合 owner 管共用 Global 初始 Act 接點、通用 PackScenario runner、來源補丁、導航與唯一 runtime。

先確認資料 IDs 與短流程契約，再跑真實載入與新局。正常流程不得覆寫正式牌組／遭遇／卡值，不可把 direct fixture 安排位置當作玩家可玩證據。測試可選 seed、透過正常 handler 出牌與移動；負例若需要設狀態，與完整自然流程分開標記。

## 驗收

Smoke 同時驗未載入包的框架與示範載入；通用 scenario 接點執行包內腳本，核選角、新局、自然牌組、相鄰地圖、每張示範牌的資源／目標／位置／場域／借機效果、敵意圖、獎勵取得、勝敗與重開。跨程序 write/read 保留真實存檔驗 deck／位置 checkpoint，讀回再進遭遇。改共用 Global 要跑 All；工具合成與 source patch 重建另驗。最後 strict 根 lint、boundary、分析與 workflow 同步，主審核證據後正常 WSL 發布。

具體卡／敵人／遭遇的同質需求與驗證映射記於示範包的資料表；GUI 觀感、實際鍵鼠、聽感與平衡仍不宣稱已驗。
