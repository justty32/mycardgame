# 每場 0~N 盤：漸進遷移計畫

[架構草案](../../specs/multi-board/README.md)｜[planning](../../workflows/planning.md)｜[遊戲驗收](../../workflows/game-dev/validation.md)

狀態：2026-10-21 規劃先於 `2b3dec8` 交付，持續工作已完成 A／B；C 尚未實作。使用者要求先把結構規劃乾淨；本計畫不是部署玩法的定案。開工依 game-dev，先在 SESSION-LOG 記實際範圍，再分配檔案唯一 owner 與單一背景 runtime owner。上游身份看 tools/upstream.json，A／B 的外層基準分別為 `2b3dec8`／`7b26416`。

## A．集中每場準備，保持既有行為

將 Global 取得／合成 Encounter 的呼叫集中到開戰準備入口，讓 Combat 裝配與 Director 共用結果；消除 `_ready` 未知遭遇便先掛載的前提。先只對舊資料轉譯，不引入新的部署或排版。由場景 owner 修改 Combat、Director、Encounter 接點；普通抽牌、費用與 CTB 演算法不動。

完成條件：同一事件只解析一次；缺模組檔仍可 import／普通戰鬥；省略欄位的舊 SINGLE／DUAL、規則／場景關閉行為有斷言。新增準備結果不能含 runtime Node 或可變別名。舊入口需要保持時提供單一 forwarding 路徑，不能維持兩份解析邏輯。

2026-10-21 已完成：PreparedEncounter、Combat／Director 共用入口、當場／配置規則分流、明確 Event 開場 actions 與停止後單一 prepared 失效。獨立最終 review PASS；8 套件合計 1465 checks／0 failures，包含 Smoke、DualBoard、Boardless、BoardRemoved、ResourceLifecycle、Board、Ctb、SaveLoad。來源／測例 hash 已與最終版本核對，增量補丁重建五產品檔一致；詳細結果與早期失敗保留見 [分析](../../../analysis/slay-the-robot/architecture/08_combat_preparation.md)。這不代表 C 的新盤數格式或完整開場交易已完成。

## B．抽離盤定義、部署與排版

模組 owner 使 Battlefield 使用正規化盤集合，把 faction→預設盤與初始主角部署搬入相容政策。生成目的盤解析集中，保留 UnitSpawner 的 admission／重試責任。呈現 owner 把雙槽計算移成純 layout，View 使用傳入槽尺寸。不同 owner 不同時改 BoardCombatModule；先交界面草稿再由唯一 owner 整合。

完成條件：runtime 不依 SINGLE／DUAL enum 建盤；相容轉譯仍保持舊結果。部署政策測試只產位置要求，幾何負責可放性，生成 owner 不變；新棋盤生成數量不受 EnemyContainer 的畫面 slot 限制，舊 positional event 相容測例不變；layout 重排不改 ID／anchor／faction。先保留舊 helper/getter 的必要轉送與測試，再依引用消除，不能批次刪除相容面。

2026-10-21 已完成：BoardSetup 幾何集合、獨立 BoardDeployment、空間／舊 mode 驗證分流、BoardLayout 與 View 槽尺寸。新首波路徑由內部明確參數和實場 fixture 驗證，所有舊內容仍保留 positional 預設；C 才把新格式接到該路徑。任意三盤及變更矩形不定義產品 N 排法。獨立靜態 review PASS，8 套 1711 checks／0 failures，來源／測例 hash 與補丁重建一致；證據及限制見 [分析](../../../analysis/slay-the-robot/architecture/09_board_setup_layout.md)。

## C．接明確空集合與任意正盤集合

在內部結構穩定後才定外部序列化契約：必須區分未指定與明確空集合，並保留舊 `encounter_boards={}` 的覆寫語意；欄位/版本選擇是工程工作，不要求使用者選名字。正盤 fixture 顯式設定位置政策，驗 1、2、3 與更多盤及順序改變；這些數字是測試樣本，不能成為產品上限。0 走真正無模組，不能只讓 `get_board_ids()` 回空陣列。

完成條件：省略／空集合在真實反序列化後仍可區分，新舊欄位衝突有測例；錯誤資料不降級為 0，新格式明確正盤缺能力回 unavailable，舊 BoardRemoved 仍相容。同場景 0→DUAL→0→正盤與 setup 失敗後重開通過；失敗前不發初始場域效果，場景 HUD／輸入與啟動狀態確實復原；普通牌／盤面牌能力拒絕、generation、呈現清理符合 [生命週期](../../specs/multi-board/lifecycle.md)。無設定的新部署政策要回明確缺資料，不能用第一盤或 faction 猜出玩法。

## D．整合與可攜交付

新增 helper 接到既有 suite，必要時才新增 runner suite（新增時同步 Python、ps1 與 diagnostics）。核心／裝配變更必驗 Smoke、Boardless、BoardRemoved、DualBoard；集合／尺寸／幾何回歸加 Board；生命週期變更驗 ResourceLifecycle，若波次/場域/存讀受影響再驗 Wave／Field／SaveLoad。每階段只跑相應必要範圍，最終覆蓋所有受影響路徑，不能以 Smoke 代替專項。

程式修改後同步 board-module 現行契約、code map、suite coverage、受影響 analysis 與來源補丁／upstream 鎖。補丁按明確來源基準產生並檢查順序／hash；未改遊戲的本輪不產生空補丁。測試副本留 artifacts，必要證據才依版本控制流程取可攜副本。

所有階段完成後依 STRUCTURE 封存 plan；目前 A／B 完成，保留 C open，不將 0~N 目標標完成。GUI、所有內容包、多幕通關與大規模效能未經實測都另列限制。

## 初次規劃驗收（2b3dec8）

已核對 Combat／Director／Encounter／Battlefield／Controller／Presentation 的現況與缺口，已提出資料所有權、可移除模組依賴、部署與排版分離、失敗清理與相容遷移。本輪未改程式、未跑 Godot。

2026-10-21 獨立 reviewer `architecture_challenge`（無對話歷史啟動，先讀 wf 規矩）完整讀取本計畫與 spec 三檔，第二次審查 PASS、無必要修正。首輪指出並已納入的缺口為真實反序列化區分省略／空集合、顯式正盤缺能力、初始場域訊號不可撤銷、場景啟動回滾及畫面 slot 限制生成；只證明規劃一致性，不代表 runtime 通過。

文件驗證：`bash wf/tools/wf-lint.sh --strict .` 回傳 0，broken／residue／oversize／biglist／querycmd 全 0；`python3 tools/boundary_lint.py` 回傳 0、violations=0；`git diff --check` 無錯。接手導航另有獨立初讀／復走，見 [情境紀錄](../../../analysis/slay-the-robot/onboarding/README.md)。
