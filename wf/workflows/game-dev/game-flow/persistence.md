# 整局的存讀、結算與局外進度

[整局入口](../game-flow.md)｜[最小開發順序](vertical-slice.md)｜[存讀核實](../../../../analysis/slay-the-robot/design/game-flow.md#存讀與局外資料)

**何時用**：規劃續玩、返回標題、放棄、重開、結算、局外成長，或改動這些流程的保存承諾。**何時不用**：只修 JSON patch 的底層行為，走 [mechanics](../mechanics.md)；本篇不替代完整 schema 或遷移設計。

## Done when

任務 spec（`games/<game>/design/specs/`）寫明 run／profile／settings 的資料責任、保存時機、中斷恢復結果、結算後檔案狀態及舊檔政策。實作任務有隔離跨程序的語意與續玩斷言，拒絕載入時原 run 不變；未驗 GUI／匯出明列；文件 lint 通過（見 [testing](../../testing.md#文件檢查修改後必跑)）。

## 流程

### 先選保存承諾

框架目前是「開始新局及進入節點前」checkpoint。ActionVisitLocation 先更新位置、清商店、保存，再送訪問訊號；載入會重建 PlayerData 並重新訪問該位置。玩家能量／格擋、手牌、場上敵人、action queue、獎勵 overlay 不形成任意時點的完整快照。

先寫明是否接受此契約。接受時，UI 與說明應能反映重新進點的行為；不接受時，先明確設計哪些狀態可保存及如何恢復，再交 mechanics 實作。不能為了「更常保存」直接在戰鬥、選牌、領獎中途呼叫 save_game：PlayerData 片段與重建入口可能組成不一致狀態。

進點後的起點選擇、戰後領獎、購物、休息與事件結果，在下一次進點以前沒有新的自動保存。Pause 返回標題用 QUIT，也不補存；因此 Continue 可能回到最近 checkpoint 並重做節點。產品若要求「領獎後回標題仍保留獎勵」或「跨幕後立即可續玩」，要新增完成標記／適當保存入口與恢復路由，不能只修改按鈕文案。

### 區分離開與結算

QUIT 離開當前 run 畫面並保留既有 save，不記勝敗；LOSS／VICTORY 在 Global.end_run 刪 run save、交 StatsHandler 記結果、保存 profile。勝敗摘要出現時尚未完成這段持久化，End Run 按鈕才結算。因此「死亡／勝利後直接關閉」與「按結算後關閉」應各有預期，不假設它們相同。

主選單 Forfeit 先載入保存資料再記敗北，Pause Forfeit 使用當前資料。若需要防止重複結算、壞檔放棄或寫檔失敗，必須補 guard 與針對性測試；當前流程沒有已驗的交易性保證。不能在真實玩家檔案測刪檔或失敗恢復。

### 分開三種資料

run save 保存 PlayerData 的局內成長，例如永久牌組、升級、HP／金錢、幕／地圖、池、RNG 與本局統計。「永久牌組」在此指跨戰鬥保留，並不表示跨新局保留。

profile 保存跨局勝敗、歷史、連勝敗、時間與各角色最高通過難度；settings 保存音量等使用者設定。現成 ProfileData 不是一般角色／卡牌解鎖或永久升級系統。需要新增局外成長時，明定解鎖條件、讀取端、保存時機、舊資料預設及重複事件處理，再新增契約；不要把 run 的 player_values 當唯一永久進度。

難度選擇雖讀 profile 最高難度，當前 NewRunMenu setter 仍有靜態缺口，不能只驗欄位保存就宣稱局外遞進完成。若初版只有固定難度，將其明列範圍；要成長曲線則先把低難度勝利→下次選擇的行為做成可失敗的測例。

### 驗證合法、回退及拒絕路徑

沿 [testing](../../testing.md) 使用隔離副本與獨立 user://，保留來源與測試 hashes。預設 FileLoader 的 saves 目錄是固定路徑，只重導 profile 不足以隔離；新測試需確認 autosave、delete_save 及設定寫入都在 fixture 裡。既有測試和使用者存檔不可當自動清理對象。

先記錄不中斷基準的關鍵資料與後續 RNG／事件，再保存，在另一程序載入並執行下一步。比較語意、UID、引用、下一事件與資源，並核對契約要求的回退；JSON 相同或 load_game 沒報錯都不夠。比較完整快照以外的項目時，要把 runtime 重建產物與真正保存欄位分開。

跨程序比較保存欄位時，先保留原始差值，再把記憶體的完整選定欄位經 `JSON.parse_string(JSON.stringify(value))` 轉成與檔案相同的 JSON 語意後比較；牌組仍比每張牌的所有保存屬性、UID、順序與數量，不能退化成只比 ID。原生 Dictionary 內整數與 JSON 浮點數可能讓直接深層相等失敗，例如升級值 `{damage: 1}` 對 `{damage: 1.0}`。失敗時印卡牌索引／欄位／值／型別，確認差異後才判定是否只是表示形式；正規化後仍不同必須失敗。這不適用於要求原生型別、引用身分或逐位元組一致的契約，這些另設斷言。2026-10-20 Windows Godot 4.7.2 的 [Boardless 四程序](../../../../tests/boardless_campaign.gd) 已觀察六張牌的 `card_upgrade_value_improvements` 整數 1／3 與 JSON 1.0／3.0 差異；完整語意與續玩均通過，沿用既有 [SaveLoad 快照](../../../../tests/save_load_flow.gd) 的處理方式，驗收映射見 [棋盤模組回歸](../../../../analysis/slay-the-robot/design/board-module-verification.json)。

依變更覆蓋缺檔、壞 JSON、無效角色、舊 ID、缺欄位、版本或 mod 不相容。現有 load_game 只做部分前置拒絕，不是完整 schema／內容引用驗證，也沒有通用遷移。主選單 Continue 只看檔案存在；壞檔存在時的錯誤呈現、可重開路徑和 Forfeit 應另驗，不由底層拒絕通過推出整體 UI 可恢復。

## 交接

現有 [SaveLoad](../../../../tests/save_load_flow.gd) 驗跨程序還原、Continue 後下一遭遇與拒絕保護；[Combat](../../../../tests/combat_flow.gd) 有敗北結算刪檔／profile 寫入。它們未驗全部中斷點、完整勝利 profile、永久解鎖或寫入失敗交易。將新增結果放任務證據，穩定契約同步 [核實筆記](../../../../analysis/slay-the-robot/design/game-flow.md)，舊存檔相容與 ID 變更另交 content／mechanics。
