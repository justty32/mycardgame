# 疑似原生記憶體讀取錯誤調查

[調查流程](../../workflows/investigation.md)｜[操作邊界](../../workflows/common/user.md)｜[先前驗證](../../../analysis/slay-the-robot/architecture/04_regression_validation.md)

## 問題（issue）

使用者已要求擱置此調查；只保留既有證據，日後明確恢復時再續查。已知資源清理另由 [生命週期修復](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md) 驗收，其通過不代表本事故已定位或修復。

2026-10-19 使用者回報曾出現疑似原生記憶體讀取錯誤；要確認出錯程序、發生情境及原因，並判斷是否與本專案有關。檔名沿用調查主題，並非已確認 Godot 是出錯程序。

## 方法（method）

先核對使用者敘述、既有驗證報告與授權邊界。背景調查 agent 以唯讀方式掃描既有 artifacts 日誌、results.json、當日 Windows Application 故障事件與 WER 目錄，另核對先前工具對話中的原生錯誤輸出。沒有新啟動 Godot、操作既有程序或使用 UI。

本輪文件工作不啟動 Godot，不操作桌面、視窗、UI、截圖或焦點，也不改變既有程序。後續證據由負責背景調查的 agent 提供；缺失的錯誤內容不自行補寫。

## 發現（findings）

使用者未保留錯誤訊息，回報當時處於 idle，並表示也可能不是遊戲所致。目前無法確認出錯執行檔、故障模組、例外碼、精確時間或可重現步驟；idle 只描述當時使用情境，不表示已確認程序內部沒有工作。

先前隔離 All 報告記錄 371 checks／0 failures、各測試程序 exit 0，但總體為 `PASS_WITH_KNOWN_SHUTDOWN_ISSUES`。該報告另定位退出時的 ObjectDB／資源殘留與 action processor 生命週期問題。這些是既有測試與退出現象，尚無證據連接到使用者此次回報；斷言通過不能排除原生崩潰，資源殘留也不能直接證明崩潰原因。

既有 artifacts 的 109 份 `.log` 未命中精準原生崩潰簽章，包括 `CrashHandlerException`、`Program crashed with signal`、`Access violation` 與 `0xc0000005`。四份整合 results.json 共 26 筆引擎紀錄的 exit 均為 0；其中首份 `completed=false`，不能把整合未完成直接解釋成原生崩潰。最新 All manifest 檔案時間為台北 2026-10-19 13:24:02.990；這只是檔案寫入時間，manifest 沒有 PID 或逐程序起迄時間。

當日 Application 的事件 1000／1001／1002 可讀，但未找到 Godot XML 匹配；ProgramData 的 WER ReportArchive／ReportQueue 可讀，未見 Godot 名稱報告，LocalAppData 對應兩個 WER 目錄與 CrashDumps 不存在。這只能說本次查核範圍沒有可連結的事件，不能證明所有程序都未曾崩潰。

後續有界複查僅讀 startup／crash-investigation 頂層及 verification 的 run／suite 層共 69 份 log、json、txt，沒有新增原生崩潰簽章或 manifest，Application 的 Godot 匹配仍為零。`gui-interactive.log` 最後寫入為 UTC 2026-10-19 05:35:52.781，末尾有 ObjectDB leak／28 resources，未見 native crash 或故障模組；`gui-process-id.txt` 記錄的歷史 PID 23864 無法與該日誌或使用者彈窗確定綁定，不能拼接推論出錯程序。此複查未啟動或操作 Godot。

先前工具對話另保留一筆真實 Godot crash-handler 輸出，與上述磁碟日誌結果並存：直接在沙箱以 `--headless --path game --script tests/framework_smoke.gd` 執行時，chunk `a4f830` 回傳 exit 1，明寫 `CrashHandlerException: Program crashed with signal 11`；Godot 為 4.6 stable，C++ backtrace 的 15 層都沒有 PE/COFF debug info。該次未使用 game／test runner，也未把輸出存成當時的 artifact。

緊接未再改檔、相同命令在核准的沙箱外執行，chunk `1911ba` 出現正常引擎 banner 與 GDScript 識別字／PROFILE_DIR_PATH 錯誤，當段沒有 signal 11；對話沒有保存其最終退出碼。此差異不足以認定沙箱是根因。先前崩潰沒有 PID、故障模組、例外碼／地址或精確時間，尚不能對應使用者的 idle 彈窗；詳見 [歷史工具證據](../../../analysis/slay-the-robot/evidence/2026-10-19/crash-prior-tool-evidence.md)。

官方來源比對提供另一條待驗假說：[Godot issue #120468](https://github.com/godotengine/godot/issues/120468) 描述 Windows restricted user 存取 userdata/config 受限時的相似訊息，尚非本案證據。[4.6-stable logger.cpp](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/core/io/logger.cpp) 的 `RotatedFileLogger::rotate_file()` 在 `FileAccess::open()` 後直接呼叫 `file->detach_from_objectdb()`；若 open 失敗回傳 null，該處存在空指標解參照的可能。[main.cpp](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/main/main.cpp) 的 PC 預設 file logging 指向 `user://logs/godot.log`，不因 headless 就停用。這是原始碼推論；本機未取得對應 ACCESS DENIED 事件或可符號化 stack，不能將它寫為已確認根因，也不構成自動提權的授權。

## 結論（conclusion）

已確認先前有一次 Godot 原生 signal 11 輸出，但使用者此次錯誤的出錯程序與原因仍未確認。現有證據不足以把兩者、沙箱差異或 shutdown 資源殘留連成因果。本輪未重現或修復 native crash，也不以 371 項回歸通過宣稱此問題消失。

下一個有效證據是可對應回報事件的時間、執行檔、故障模組、例外碼或 dump。維持既有程序與桌面不變，保留現有證據；若唯讀來源沒有這些資料，結論就保持未確認，不以試開 GUI 或操作既有程序補齊。

本輪另補強 runner 的程序、退出與逐階段紀錄，加入日誌寫入預檢及原生 crash 標記判讀；[32 項合成檢查](../../../analysis/slay-the-robot/evidence/2026-10-19/runner-diagnostics-results.json) 通過，沒有啟動 Godot。這只驗證診斷工具，並非事故重現或修復；實際欄位與限制見 [testing](../../workflows/testing.md)。

後續唯讀交付審查已核對目前兩處遊戲修復與 All 隔離副本雜湊一致、補丁雜湊吻合來源鎖，且原始七組 console 合計 371 checks，沒有發現先前指定交付漏項。原生事故仍缺程序與時間證據；官方 Windows API 查核亦不足以保證刻意重現時所有錯誤對話框均受抑制，限制與來源已納入 [native-crash 工作流](../../workflows/game-dev/native-crash.md)。因此不以新增崩潰實驗代替缺失的原事件證據。

## 來源（sources）

使用者情境與授權來自本聊天 2026-10-19 補充，由主 agent 派工摘要傳遞；持久邊界見 [使用者偏好](../../workflows/common/user.md)。

[先前回歸報告](../../../analysis/slay-the-robot/architecture/04_regression_validation.md) 保存 371 項結果與「已知資源清理問題」；整合證據位於 `artifacts/verification/20261019-132225-619f8c98/`。背景 agent `runtime_probe` 同日唯讀核對 109 logs、四份 results.json、Application 1000／1001／1002，以及 ProgramData／LocalAppData WER 與 CrashDumps；不包含新 runtime 測試。

[歷史工具證據](../../../analysis/slay-the-robot/evidence/2026-10-19/crash-prior-tool-evidence.md) 保存 chunk `a4f830`／`1911ba` 的先前輸出與限制，原始輸出位於聊天工具歷史。官方 issue 與 4.6-stable 原始碼由 `upstream_reference` 唯讀比對，直接連結列於發現段；只用於形成待驗假說，不替代本機故障證據。
