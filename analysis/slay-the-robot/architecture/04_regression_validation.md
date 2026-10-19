# Dictionary 修復、戰鬥與存讀回歸

[分析入口](../README.md)｜[原版啟動紀錄](03_startup_validation.md)｜[重跑方式](../../../wf/workflows/testing.md)

> 本篇保留當時功能通過但退出仍保留資源的歷史結果；後續資源清理工作另記於 [05 資源生命週期](05_resource_lifecycle.md)，不回寫本篇測試數據。

2026-10-19，Windows、Godot `4.6.stable.official.89cea1439`，上游 `4dac5abe0d19382f8ace2cec5ed3fd77e2a0e11d` 加本地修復。來源鎖、補丁與引擎雜湊見 [upstream.json](../../../tools/upstream.json)。本篇接續原版啟動報告，沒有改寫先前未修／未測的歷史結果。

## 實作與紅綠證據

[SerializableData.gd](../../../game/data/SerializableData.gd) 普通 Dictionary JSON 分支原先算出 `patched_dictionary` 卻寫回 `temp_value`；一行修正為寫回真正補丁結果。[dictionary_regression.gd](../../../tests/dictionary_regression.gd) 經實際 JSON 編解碼及公開 patch API，未修版本 **47 checks／8 failures／exit 1**，同測修後 **47／0／exit 0**。

涵蓋 keep／overwrite／erase、預設及未知策略、空字典、null、淺層巢狀覆寫、輸入不變、typed Dictionary 型別與 JSON 往返，以及五種 Array 策略。這不是深合併，也不代表 recursive/native 轉換分支全部已驗。更新後 Smoke **43／0**，Dictionary 的四種策略已成為阻擋失敗的斷言。

存讀探測另重現：壞 JSON 經 `load_json()` 回傳空字典後，原 `load_game()` 仍替換玩家並設定 is_run。原紅測 **4／2**，修後同測 **4／0**。本地 [FileLoader.gd](../../../game/autoload/FileLoader.gd) 現在先檢查指定檔案、JSON、properties／patch_data 包裝及角色，再切換玩家狀態；正確使用傳入的目錄／檔名。這是前置拒絕保護，尚非完整存檔 schema 驗證或版本遷移系統。

## 單場戰鬥

[combat_flow.gd](../../../tests/combat_flow.gd) 使用 [明示資料 fixture](../../../tests/combat_fixture.gd) 與真實 Root、新遊戲 handler、起始選項、地圖按鈕、Hand 出牌、End Turn、獎勵與 Continue 接線。固定 seed 20261019，原生三張 Basic Attack／兩張 Basic Block，無起始遺物；單敵 65 HP、每回合 14 傷。沒有直接扣敵人 HP 或自行送出勝利訊號。

勝利分支 **82 checks／0 failures**：抽牌、選目標、消耗能量、格擋、零能量拒絕出牌、敵方回合、自然擊殺、領錢、選卡、返回可旅行地圖。玩家 HP 80→76，敵人 65→45→25→5→死亡，金錢 100→125，永久牌組 5→6；觀察到五次合法出牌、十次抽牌及一次敵方回合。

這是完整單場生命週期，沒有宣稱完整多幕通關、所有卡牌／敵人或物理滑鼠命中已驗。fixture 只限定測試情境，不是產品平衡修改。

敗北分支使用獨立副本、同種敵人，玩家起始 HP 10；**42 checks／0 failures**。真正敵方攻擊造成 14 傷、實損 10、overkill 4，接續死亡動畫、敗北結算、手牌禁用且清空、無勝利獎勵／不可旅行，End Run 後確認 LOSS、歷史與該測試存檔移除。沒有直接寫入死亡狀態或發送死亡訊號。

## 跨程序存讀與續玩

[save_load_flow.gd](../../../tests/save_load_flow.gd) 的 write／read 是兩個 Godot 程序，共用同一隔離副本。write **28／0**：真實 start_run 與 autosave，新增永久卡並用 upgrade_card 升級，保存生命、金錢、嵌套 values、seed、RNG 等資料。read **56／0**：新程序重建 PlayerData，核對 17 類序列化欄位、卡牌 UID、升級、統計引用及之後五個 RNG 輸出。

再經 MainMenu Continue handler 重新進入，執行相鄰地圖位置 action，確認活敵、可出牌手牌、行動佇列結束與新 checkpoint 寫入。這驗證「讀回後可繼續」，不是只比較 JSON 文字；仍遵循框架 checkpoint 契約，不恢復任意中途戰鬥 SceneTree。

rejected 分支 **73／0**：十種缺檔／壞 JSON／不合法包裝或角色輸入，逐次確認玩家物件、內容、is_run、統計引用不變，不送 run／location 訊號，且各報一次明確拒絕；另驗自訂目錄／檔名與預設存檔保留。特別補「只有自訂合法檔、預設檔不存在」回歸，原版獨立測試 **8／1**、修後 **8／0**，隔離預設檔暫移後完整還原。錯誤回報是負向測試的預期結果，不當成乾淨正向日誌。

## 隔離與可重跑證據

執行 `./tools/test-game.ps1 -Suite All`；也可選 Dictionary、Smoke、Combat、SaveLoad。每 suite 在 artifacts/verification/ 建唯一副本，排除 .git、.godot、profile、settings、saves，並隔離 user://；原 game 存檔不作測試資料。先 cold import，已定位的 SoundManager UID 若需快取，第二次 import 必須乾淨通過。每程序有外層硬期限，取消時只結束該次程序樹。

紅綠原始日誌在 artifacts/dictionary-regression/ 的 red.log、green.log、smoke.log；存讀原始缺陷在 artifacts/save-load-flow/invalid.log、invalid-fixed.log，正向與拒絕測試在 `*-final.log`。戰鬥初次證據在 artifacts/combat-flow/run-06eb4ddd8ff1/，含 combat-result.json。整合 runner 的每次目錄保存 results.json、命令、引擎及 console 日誌，失敗也保留。

最終 All 證據在 artifacts/verification/20261019-132225-619f8c98/：Dictionary 47、Smoke 43、勝利 82、敗北 42、write 28、read 56、rejected 73，合計 **371 checks／0 failures**，所有測試程序 exit 0。整體標記為 `PASS_WITH_KNOWN_SHUTDOWN_ISSUES`；下列資源問題仍存在。文件 strict lint 的 broken、residue、oversize、biglist、querycmd 均為 0。

## 已知資源清理問題

功能 assertions 全數通過仍不能宣稱零 ERROR。啟動／Smoke 的舊 icon UID fallback、external image 警告及退出 1 resource 問題仍存在。新增流程的退出資源數實測為戰鬥勝利 27、敗北 23、存檔 write 6、read 21；已另外查核，沒有當作原本的 1 resource 直接略過。

verbose 戰鬥列出 168 個未掛樹 Node；[ActionInterceptorProcessor.gd](../../../game/scripts/action_interceptors/ActionInterceptorProcessor.gd) 繼承 Node 並持有 parent_action，而 [BaseAction.gd](../../../game/scripts/actions/BaseAction.gd) `_intercept_action()` 建立 processor 後未掛樹或釋放。存讀 write/read 在正常 QUIT 與釋放 Root 後仍保留相關 action 資源。這提供上游生命週期問題的定位證據，本輪沒有擴大修復它。

runner 僅接受各測試階段已查核的精確退出數量，明確警告並標為 `PASS_WITH_KNOWN_SHUTDOWN_ISSUES`；其他 ERROR、數量變更、SCRIPT ERROR、失敗斷言或逾時均阻擋。rejected 階段只接受逐案例 BEGIN／END 內各一個明確 Save rejected 訊息。資源清理驗收仍未通過，不能將此狀態當成沒有問題的發行基準。

## 後續原生錯誤調查

使用者另回報記憶體讀取錯誤；[調查筆記](../../../wf/notes/investigations/godot-native-crash.md) 保存既有日誌、歷史工具中的 signal 11 與官方來源比對。尚未確認使用者彈窗的出錯程序與原因；上述 371 項結果只描述當次功能驗證，不能排除此事件，也不能將 action processor 資源殘留直接當成原生崩潰原因。後續 runner 診斷強化的驗證與這份歷史遊戲測試分開記錄，操作遵守目前禁止桌面及視窗操作的授權。
