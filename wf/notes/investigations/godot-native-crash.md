# 疑似原生記憶體讀取錯誤調查

[調查流程](../../workflows/investigation.md)｜[操作邊界](../../workflows/common/user.md#桌面與程序邊界)｜[先前驗證](../../../analysis/slay-the-robot/architecture/04_regression_validation.md)｜[驗收分流](../../workflows/game-dev/validation.md)

本檔同時是原生崩潰、記憶體讀取錯誤、Godot 程序異常消失或非預期退出碼的調查方法來源（見文末「調查方法」）；已定位的 GDScript 邏輯錯誤或序列化差異直接走對應修復與回歸流程。

## 問題（issue）

使用者已要求擱置此調查；只保留既有證據，日後明確恢復時再續查。已知資源清理另由 [生命週期修復](../../../analysis/slay-the-robot/architecture/05_resource_lifecycle.md) 驗收，其通過不代表本事故已定位或修復。

2026-10-19 使用者回報曾出現疑似原生記憶體讀取錯誤；要確認出錯程序、發生情境及原因，並判斷是否與本專案有關。檔名沿用調查主題，並非已確認 Godot 是出錯程序。

## 方法（method）

先核對使用者敘述、既有驗證報告與授權邊界。背景調查 agent 以唯讀方式掃描既有 artifacts 日誌、results.json、當日 Windows Application 故障事件與 WER 目錄，另核對先前工具對話中的原生錯誤輸出。沒有新啟動 Godot、操作既有程序或使用 UI。

後續證據由負責背景調查的 agent 提供；缺失的錯誤內容不自行補寫。

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

已確認先前有一次 Godot 原生 signal 11 輸出，但使用者此次錯誤的出錯程序與原因仍未確認。現有證據不足以把兩者、沙箱差異或 shutdown 資源殘留連成因果。調查期間未重現或修復 native crash，也不以 371 項回歸通過宣稱此問題消失。

下一個有效證據是可對應回報事件的時間、執行檔、故障模組、例外碼或 dump。維持既有程序與桌面不變，保留現有證據；若唯讀來源沒有這些資料，結論就保持未確認，不以試開 GUI 或操作既有程序補齊。

調查期間另補強 runner 的程序、退出與逐階段紀錄，加入日誌寫入預檢及原生 crash 標記判讀；[32 項合成檢查](../../../analysis/slay-the-robot/evidence/2026-10-19/runner-diagnostics-results.json) 通過，沒有啟動 Godot。這只驗證診斷工具，並非事故重現或修復；實際欄位與限制見 [testing](../../workflows/testing.md)。

後續唯讀交付審查已核對目前兩處遊戲修復與 All 隔離副本雜湊一致、補丁雜湊吻合來源鎖，且原始七組 console 合計 371 checks，沒有發現先前指定交付漏項。原生事故仍缺程序與時間證據；官方 Windows API 查核亦不足以保證刻意重現時所有錯誤對話框均受抑制，限制與來源見下方「調查方法」。因此不以新增崩潰實驗代替缺失的原事件證據。

## 來源（sources）

使用者情境與授權來自本聊天 2026-10-19 補充，由主 agent 派工摘要傳遞；持久邊界見 [使用者偏好](../../workflows/common/user.md)。

[先前回歸報告](../../../analysis/slay-the-robot/architecture/04_regression_validation.md) 保存 371 項結果與「已知資源清理問題」；整合證據位於 `artifacts/verification/20261019-132225-619f8c98/`。背景 agent `runtime_probe` 同日唯讀核對 109 logs、四份 results.json、Application 1000／1001／1002，以及 ProgramData／LocalAppData WER 與 CrashDumps；不包含新 runtime 測試。

[歷史工具證據](../../../analysis/slay-the-robot/evidence/2026-10-19/crash-prior-tool-evidence.md) 保存 chunk `a4f830`／`1911ba` 的先前輸出與限制，原始輸出位於聊天工具歷史。官方 issue 與 4.6-stable 原始碼由 `upstream_reference` 唯讀比對，直接連結列於發現段；只用於形成待驗假說，不替代本機故障證據。

## 調查方法（之後恢復調查或遇到新事故時照做）

**完成條件**：已區分哪一個程序在何時發生什麼結果，保存可追溯的命令／版本／退出資料及來源日誌；能確認的原因有對應證據，無法確認的列出缺口。若進行修復，同一重現情境要有修前失敗與修後結果；尚未重現或未證實因果時，只能寫調查狀態，不能宣稱已修復。

### 保留現場

先讀已存在的日誌、測試結果與可讀取的系統錯誤事件；不要關閉錯誤視窗、重啟使用者實例、按名稱結束全部 Godot，或用重新執行覆寫原日誌。自行建立的背景測試程序使用獨立副本、唯一輸出目錄及外層期限；逾時只處理該次自行建立的程序樹，沒有程序身分證據的既有實例不屬於清理範圍。

`--headless` 與 `CreateNoWindow` 不足以保證刻意觸發原生崩潰時不出現系統錯誤對話框。[SetErrorMode](https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-seterrormode) 的部分設定可由子程序繼承，但 [WerSetFlags](https://learn.microsoft.com/en-us/windows/win32/api/werapi/nf-werapi-wersetflags) 作用於目前程序；不能把父程序設定視為已驗證目標引擎的所有錯誤路徑。在不得開窗的邊界下，未確認目標的錯誤處理路徑前不刻意觸發 native crash；runner 的失敗分支改用合成文字與退出碼驗證。

### 建立程序與事件證據鏈

先核對 executable 完整路徑與版本、PID、程序開始／結束時間、命令參數、工作目錄及對應的遊戲副本。PID 可能重用，必須連同開始時間與路徑識別；記錄原始時區或 UTC，向使用者呈現時用 Asia/Taipei。

再對照該時間區間的程序退出紀錄、引擎／console log，以及已存在且可讀取的 Windows 錯誤事件或 crash report。故障模組、模組版本、例外碼、offset 與 report ID 有資料才填，缺少的寫未取得。僅憑「時間接近」或同名 executable，不能把系統事件配到某個測試；記憶體位址或讀取失敗文字本身也不足以定位到某段 GDScript。

退出碼保留原始值，工具另提供十六進位時一併保留。逾時後由 runner 終止、正常退出、GDScript 錯誤及 native crash 分別記錄；不要把任何非零退出都稱為原生記憶體錯誤。某次 log 有 PASS，仍須核對那個程序最終的 exit，不能拿另一個舊的 exit 0 代表使用者回報的實例。

### 逐步縮小問題

用 [test_game.py](../../../tools/test_game.py)（Windows 亦可經 test-game.ps1 包裝）的相關 suite，先驗背景能涵蓋的邊界，保持來源版本、fixture 與參數可比。一次只改一個會影響結果的條件；同一命令沒有重現時，記為「該條件下未重現」，不等於問題不存在。headless 可檢查載入與邏輯，但不驗證實際 GPU 驅動、視窗呈現、桌面輸入或 GUI 事件路徑；原錯誤只發生於這些路徑時保留待補證據，不用無關的 headless 成功代替。

Dictionary 合併 bug 是資料行為缺陷，ObjectDB／resource still in use 是資源保留觀察；兩者可以與 crash 同時出現，卻不能直接當成 crash 原因。只有匹配的故障堆疊、模組證據或可控重現能支持因果；不得因修了合併或減少退出警告，就宣稱原生崩潰已修好。

原始日誌與事件摘錄放入該次唯一的 artifacts 目錄，記錄取得方式及時間；即使失敗也保留已取得的資料。持久分析只記程序身分、可確認事實、排除／未排除範圍、下一個可區分假設的檢查與證據連結。只有改過程式但尚未執行時，記為已實作／未執行；純語法檢查不算重現 native crash。

### 現有 runner 的診斷範圍

[test_game.py](../../../tools/test_game.py) 在 starting、running 與 phase finally 更新同次 `results.json`，以暫存檔原子替換。phase 記錄 executable、參數、工作目錄、`launched_pid`、`status`、`exit_code`／`exit_code_hex`、timeout 與 `native_crash_signatures`。`started_utc`／`ended_utc` 是 runner 在啟動後與 finally 的觀察時間，不是作業系統提供的精確開始／死亡時刻。Linux 上程序被訊號終止時，`exit_code` 依 shell 慣例記 128+N，另存 `exit_signal`=N 與 `exit_code_raw`=-N（如 SIGSEGV 為 139／11）；Windows 的退出碼原樣保留，`exit_code_hex` 對應 0xC0000005 類狀態。

`launched_pid_kind` 按 executable 名稱標示 `console_wrapper` 或 `invoked_executable`；前者的 PID／exit 屬於 console wrapper，不能冒充實際的 engine 子程序。這套診斷不會自動收集 WER、故障模組或子程序身分，仍需另以可讀的現場證據關聯。

啟動前的 `log_write_preflight` 用相同權限開啟精確的 log 目標、不截斷既有內容；失敗時記錄失敗且 PID 為 null，不啟動引擎。精確匹配行首 `CrashHandlerException`／`handle_crash` 的 `Program crashed with signal N` 會使該 phase 失敗，即使有 PASS 且啟動程序 exit 0；沒有匹配也不等於排除了所有原生 crash。

runner 改為 Python 後（2026-10-19），[test_runner_diagnostics.py](../../../tests/test_runner_diagnostics.py) 於 Linux 執行 105 項合成檢查通過：以假引擎程序走真實判讀流程，沒有啟動 Godot。案例包括 log 無法寫入時不啟動、正常退出、crash 標記、訊號結束碼及失敗／逾時記錄；Windows 端尚未實測。舊 PowerShell 版 32 項的[歷史結果](../../../analysis/slay-the-robot/evidence/2026-10-19/runner-diagnostics-results.json)保留各 phase。這驗的是 runner 的判讀與留證，不能寫成 Godot crash 修復或 GUI 穩定性驗收。
