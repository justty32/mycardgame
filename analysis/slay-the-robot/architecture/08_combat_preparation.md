# 每場戰鬥準備：遷移 A

[分析入口](../README.md)｜[架構與遷移計畫](10_multi_board_encounters.md)｜[模組現行契約](../../../wf/specs/board-module/README.md)

2026-10-21，基於 snapshot `2b3dec8`。本輪只集中開戰準備與資料所有權；每場明確 0／任意 N 盤的資料格式、部署政策與排版尚未實作。

## 已核對的接線

`PreparedEncounter.prepare` 取得 Event、配置來源的 CombatRulesData 與一次查找／合成的 Encounter，保存深複製的序列化屬性；getter 重建獨立 Resource 與巢狀容器。它沒有 runtime Node 或棋盤模組型別，也不將 Variant 經 JSON 字串往返，避免巢狀 Vector2i 失真。這是已載入作者資料的快照，不是新外部 schema。

`Combat._ready` 只接線 UI，不在未知遭遇時先建棋盤模組。正常開場先 prepare，再由場景 `compose_combat_module` 看該份規則與既有場景／檔案能力，最後把同一個 prepared 交 `CombatDirector.begin_prepared_combat`。舊 `begin_combat(event)` 轉送相同準備／裝配入口；舊 `_compose_board_module()` 僅為相容轉送，同場重掛不重新查找遭遇或增加 Director generation。

Director 是當前 prepared 的唯一 owner；Combat 的同名查詢只轉送。`_stop` 使 prepared 失效，既有 generation 機制取消舊工作；停止後無參數裝配沒有當前遭遇，不能復活上一場。正式 setup 失敗的完整場景／訊號交易仍屬後續 C，這次沒有宣稱全部回滾問題已解。

Director 的 Event、Rules、Encounter 都來自此快照。`CombatStartActions` 從 Director Event 取開場 actions，直接指定其他 Event 開戰時，不再混用地圖目前 Event 的開場效果；波次也使用同份遭遇。

## 規則的配置來源與當場值

`Global.get_configured_combat_rules` 取得作者配置，供下一次 prepare 使用。`Global.get_combat_rules` 在有當場 prepared 時回 Director 的規則，否則回配置；ActionGenerator 的抽牌／能量及 HandManager 手牌上限因此與 CTB／棋盤看到同一份當場值。合成 Encounter 亦顯式收到準備中的規則，不再隱式重讀另一份來源。

本輪定域核對 game 的規則讀寫：CombatRulesData 位於 readonly，GlobalTestDataGenerator 註冊預設資料，ActionGenerator／HandManager 消費欄位，沒有戰中修改規則表或對 `get_combat_rules()` 結果賦值的內建 Action。因此當場固定、下一場讀新配置符合現有內建流程；不宣稱任意自訂腳本直接改配置的戰中熱更新仍即時生效。現有 SINGLE／DUAL、省略欄位、空覆寫字典與關閉／刪除模組的行為均保留。

## 驗證與限制

Smoke 的 `prepared_encounter_probe.gd` 核對未開場不掛載、單次 resolver、來源與消費者間的巢狀波次／actions／weights 隔離、Vector2i 型別及舊模式／規則 opt-out。DualBoard 的實場斷言核對共享 prepared、普通卡規則與當場一致、下場讀新配置；`prepared_start_cases.gd` 驗停止後不復掛與直接指定 Event 的實際開場效果／波次。

凍結後在 Linux `4.7.2.stable.mono.arch_linux.ed1daf0bf` 跑 Smoke、DualBoard、Boardless、BoardRemoved、ResourceLifecycle、Board、Ctb、SaveLoad，合計 **1465 checks／0 failures，30 個程序階段全部 exit 0**。沒有未預期引擎錯誤、native crash 或退出資源保留；SaveLoad rejected 的預期拒絕仍依原 runner 契約。GUI、人工點擊、視覺／聽感與新 0~N 功能未驗。

已抽到 [驗證摘要](08_combat_preparation-verification.json)（8 列）；`suite`／`run` 指套件與本機原始 run，`assertions`／`test_phases`／`process_phases` 記斷言與程序數，`verdict` 是結果，`results_sha256` 核對原始 manifest，`markers` 保留完成行。摘要逐一核對最終工作檔與各 run 的全部 source/test hashes，並非直接轉述 agent 回報；來源鎖在部分 run 後追加補丁資訊，產品與測例未變，不據此重跑。

獨立 reviewer `architecture_challenge` 初審指出 Combat 與 Director 雙份 active prepared 會在停止後殘留；已改為 Director 單一 owner，最終複審 PASS。direct 入口專項最初未初始化正常 stats／deck，兩次試驗（`20261021-195715-b935ebdd`、`20261021-195757-43b8e2ac`）因此失敗；修正測試前置，保留其餘正常開場 signal subscribers，再執行直接入口及真實 actions，最終 DualBoard 403 項通過。原始失敗日誌保留在 artifacts，沒有刪除或改寫為首次成功。

## 來源補丁

[combat-preparation.patch](../../../tools/patches/combat-preparation.patch) 接在 board-size-per-encounter.patch 後，SHA-256 為 `62b91863976e55540f836c3e54961e9e3c7c499cc41aa73e112283ab3301381f`。從 `2b3dec8` 的 game snapshot 建隔離副本後 apply check／apply，五份產品檔逐位元組與已驗工作檔一致；本機證據 `artifacts/phase-a-patch-q1zneolv/verification.json`。這次驗增量補丁，不冒稱重新下載或重建全部純上游。

第一次在 repo 內隔離子目錄只用 cwd 執行 git apply，命令雖回 0 卻略過路徑；內容比較抓到未套用，因此改從 repo 根以明確 `--directory` 重建，才接受結果。此可重複檢查已回寫 [版本控制](../../../wf/workflows/version-control.md)。
