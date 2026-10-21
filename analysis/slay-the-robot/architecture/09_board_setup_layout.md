# 盤定義、部署與排版：遷移 B

[分析入口](../README.md)｜[遷移計畫](../../../wf/plans/multi-board/README.md)｜[模組流程](../../../wf/workflows/game-dev/mechanics/board-module.md)

2026-10-21，基於 snapshot `7b26416`。B 把既有棋盤建置、初始位置政策與畫面矩形分開；新外部 0／N 盤格式、沒有預設的部署政策及完整開場失敗交易仍由 C 接續。

## 盤定義與部署

`BoardSetup.from_legacy` 是舊 Encounter／SINGLE／DUAL 的轉譯入口。它先保留原規則與遭遇驗證，再建立帶穩定 ID 的盤定義集合；`CombatBattlefield` 按定義建 `BoardData`，不再以 enum 決定盤數。原 Encounter 建構輸入與 `default_board_id` 只保留相容轉送，沒有新增 N 盤 enum。核心 EncounterData 不引用可移除的棋盤類別，因此沒有把 BoardRemoved 的缺檔情境變成編譯依賴。

`BoardDeployment` 集中舊 party／enemy 的預設目的盤、主角部署候選與首波生成位置。它只產出位置要求；占格與最近可放格仍由 Battlefield／BoardData 處理，生成、admission、延後與重試仍由 UnitSpawner 負責。既有單位的位置以 membership 為準，初始 faction 預設不能用來重新解釋移動後的位置。這是舊玩法的相容政策，沒有定義新 home 或其他單位上盤規則。

`from_definitions` 只驗幾何，不要求主角或敵人的預設目的盤；相容 factory 才附上 BoardDeployment。正規化輸入與 getter 都隔離巢狀容器，未驗證的 `BoardSetup.new()` 不能直接建有效世界。定義集合與部署政策的驗證分開，無政策的幾何不是「允許單位自動在盤外出生」的新玩法。

`CombatRulesData.validate_spatial_configuration` 專驗跨盤政策與尺寸限制；原 `validate_configuration` 保留舊 mode 檢查後轉送。正規化 factory 與 CrossBoardPolicy 使用前者，因此任意 ID 世界不會間接受 SINGLE／DUAL 限制。EncounterData 的舊 getters、波次缺省目的盤及 mode 驗證仍是相容輸入 API，沒有被宣稱為新格式解析器。

獨立 review 的全域搜尋另確認：Controller／Battlefield 的舊 helper 轉送相容部署，已存在 membership 優先；BoardData／BoardView 的 `shared` 預設在正常 setup 被明確 ID 覆蓋。BoardTargeting 對獨立 BoardData 的測例 fallback 仍用舊建構入口；實場直接使用當前 Battlefield，沒有另猜第一盤或最後一盤。

## 生成與呈現容量

首波新增明確的內部 `use_event_slots` 相容選項，預設保留舊 `spawn_event_enemy`；舊顯式 Encounter ID 同樣不能被當成取消 positional 截斷的暗號。掛載 placement module 且明確選擇不使用事件槽時，改用既有 `spawn_board_enemy` 建實體，後續走相同的空間 admission。這條路徑不讀畫面位置數量；未掛棋盤仍保留普通 UI 生成。

B 的新路徑由內部實場 fixture 驗證，正式內容目前仍走相容預設。C 必須由已解析的新格式明確選擇政策，不能把預設 bool 或 Event ID 當作第二份盤數真相；本輪沒有增加公開 JSON 旗標。

## 畫面矩形

`BoardLayout` 純計算 `board_id → Rect2`。相容 layout 保留原單盤與雙盤座標、460×280 槽尺寸；超過兩盤需要呼叫者顯式提供矩形，沒有沿用 clamp 最後一槽，也沒有宣稱某種 N 盤排法是產品決策。專案既有 viewport 為 1200×700，本輪沒有加入比例縮放規則。

`BoardView` 依輸入槽尺寸計算方格並置中；Presentation 每次同步套用矩形，而不只在 ID 清單變動時更新。相同 ID 保留相同 View，顯示順序與矩形不回寫盤 ID、陣營或 anchor。人工畫面與可讀性仍需實機驗收。

## 驗證與限制

Linux `4.7.2.stable.mono.arch_linux.ed1daf0bf` 的 Board、DualBoard、Smoke、Boardless、BoardRemoved、Wave、Field、ResourceLifecycle 全部通過，合計 **1711 checks／0 failures，28 個程序階段全部 exit 0**。沒有未預期引擎錯誤、native crash、ObjectDB leak 或退出資源保留；所有 runtime 自然完成。

[驗證摘要](09_board_setup_layout-verification.json) 保存 8 套 run ID、斷言、階段數、完成行與原始 results.json 雜湊。整合 owner 逐一核對所有 source/test hashes 與最終工作檔；BoardRemoved 確實移除新增 helper，普通戰鬥仍通過。來源鎖在較早 run 後加入補丁 metadata，產品與測例未變。

Board 純物件專項驗任意 ID、幾何無部署政策、來源與 getter 修改隔離、非法尺寸正常回錯誤，以及非舊 enum 的真跨盤解析。DualBoard 實場專項驗三盤視圖、同 ID 改槽、重排維持 View 身分與 membership；首波專項比較內部三敵／一槽與舊顯式 Encounter 的一敵截斷，核對實際 registry、占格與呈現容器。後者驗生成與 placement，沒有宣稱新增 CTB admission 流程。

獨立 reviewer `architecture_challenge` 最終 review PASS，另核對八套結果及產品來源 hash。初審指出幾何 factory 強制敵我部署、尺寸先轉型及間接 enum 驗證，均在凍結前解除。首次 Board（`20261021-201627-2e2e8e53`）因新增測例硬寫 `res://tests`，與 runner sidecar 路徑不符而 FAIL；改為既有 script 相鄰路徑後重跑通過，失敗原件保留。

Ctb／SaveLoad 本輪不重跑：未改 Director 時序、普通卡費用、序列化格式及 A 的規則快照接點，相關 A 證據仍有效；共享生成／場域與新增持有關係由 Wave／Field／ResourceLifecycle 驗證。未驗 GUI、人工操作感、新外部 0／N 格式及完整 setup 失敗交易，不把 B 宣稱為完整 0~N 功能。

## 來源補丁

[board-setup-layout.patch](../../../tools/patches/board-setup-layout.patch) 接在 combat-preparation.patch 後，SHA-256 為 `507677f96702faf793ed400cea41a0757f250cc26aa22d062edd08b92fe02d05`。以 `7b26416` 的 game snapshot 建立隔離副本，從 repo 根指定相對 `--directory` 完成 apply check／apply；11 個產品檔逐位元組一致。本機證據 `artifacts/phase-b-patch-8m3z9gjb/verification.json`；此為增量重建，不是重新下載純上游。
