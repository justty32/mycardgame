# native-crash — 原生崩潰與異常退出

[testing](../testing.md)｜[驗證分流](validation.md)｜[investigation](../investigation.md)

**何時用**：回報記憶體讀取錯誤、Godot 程序異常消失、原生例外或非預期退出碼。**何時不用**：已定位的 GDScript 邏輯錯誤或序列化結果差異，直接走對應修復與回歸流程。

## Done when

已區分哪一個程序在何時發生什麼結果，保存可追溯的命令／版本／退出資料及來源日誌；能確認的原因有對應證據，無法確認的列出缺口。若進行修復，同一重現情境有修前失敗與修後結果；尚未重現或未證實因果時，只能寫調查狀態，不能宣稱已修復。

## 先保留現場並確認授權

本次只允許檔案修改及不開視窗的背景檢查，禁止 UI／桌面操作、截圖、切換焦點、啟動 GUI 與干預既有程序。先讀已存在的日誌、測試結果與可讀取的系統錯誤事件；不要關閉錯誤視窗、重啟使用者實例、按名稱結束全部 Godot，或用重新執行覆寫原日誌。

後續若在授權範圍建立自己的背景測試程序，使用獨立副本、唯一輸出目錄及外層期限；逾時只處理該次自行建立的程序樹。沒有程序身分證據的既有實例不屬於測試清理範圍。

`--headless` 與 `CreateNoWindow` 不足以保證刻意觸發原生崩潰時不出現系統錯誤對話框。[SetErrorMode](https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-seterrormode) 的部分設定可由子程序繼承，但 [WerSetFlags](https://learn.microsoft.com/en-us/windows/win32/api/werapi/nf-werapi-wersetflags) 作用於目前程序；不能把父程序設定視為已驗證目標引擎的所有錯誤路徑。在目前禁止開窗的邊界下，未確認目標處理路徑前不刻意觸發 native crash，runner 的失敗分支用合成文字與退出碼驗證。

## 建立程序與事件證據鏈

先核對 executable 完整路徑與版本、PID、程序開始／結束時間、命令參數、工作目錄及對應的遊戲副本。PID 可能重用，必須連同開始時間與路徑識別；記錄原始時區或 UTC，向使用者呈現時用 Asia/Taipei。

再對照該時間區間的程序退出紀錄、引擎／console log，以及已存在且可讀取的 Windows 錯誤事件或 crash report。故障模組、模組版本、例外碼、offset 與 report ID 有資料才填；缺少的寫未取得。僅憑「時間接近」或同名 executable 不能把系統事件配到某個測試。記憶體位址或讀取失敗文字本身也不足以定位到某段 GDScript。

退出碼保留原始值，若工具另提供十六進位也一併保留。逾時後由 runner 終止、正常退出、GDScript 錯誤及 native crash 分別記錄；不要把任何非零退出都稱為原生記憶體錯誤。某次 log 有 PASS 仍須核對那個程序最終 exit，不能拿另一個舊 exit 0 代表使用者回報的實例。

## 逐步縮小問題

使用 [test-game.ps1](../../../tools/test-game.ps1) 的相關 suite 先驗可在背景涵蓋的邊界，保持來源版本、fixture 與參數可比。一次只改一個會影響結果的條件；同一命令沒有重現時，記為該條件下未重現，不等於問題不存在。

headless 可檢查載入與邏輯，但不驗證實際 GPU 驅動、視窗呈現、桌面輸入或 GUI 事件路徑。若原錯誤只發生於這些路徑，本次保留待補證據，不用無關 headless 成功代替。

Dictionary 合併 bug 是資料行為缺陷；ObjectDB／resource still in use 是資源保留觀察。兩者可以與 crash 同時出現，卻不能直接當成 crash 原因。只有匹配的故障堆疊、模組證據或可控重現能支持因果；不得因修了合併或減少退出警告，就宣稱原生崩潰已修好。

## 保存與交接

把原始日誌與事件摘錄放入該次唯一 artifacts 目錄，記錄取得方式及時間；即使失敗，也保留已取得的資料。持久分析只記程序身分、可確認事實、排除／未排除範圍、下一個可區分假設的檢查與證據連結。

runner 的實際診斷欄位以當前程式與輸出為準；只有改過程式但尚未執行時，記為已實作／未執行。純語法檢查不算重現 native crash，也不證明新的背景測試能成功完成。

## 現有 runner 的診斷範圍

[test-game.ps1](../../../tools/test-game.ps1) 在 starting、running 與 phase finally 更新同次 `results.json`；[diagnostics helper](../../../tools/test-game-diagnostics.ps1) 以暫存檔原子替換。phase 記錄 executable、參數、工作目錄、`launched_pid`、`status`、`exit_code`／`exit_code_hex`、timeout 與 `native_crash_signatures`。`started_utc` 是被啟動程序的 StartTime；`ended_utc` 是 runner finally 的觀察時間，不是作業系統提供的精確死亡時刻。

`launched_pid_kind` 按 executable 名稱標示 `console_wrapper` 或 `invoked_executable`；前者的 PID／exit 屬於 console wrapper，不能冒充實際 engine 子程序。這套診斷沒有自動收集 WER、故障模組或子程序身分，仍需另以可讀的現場證據關聯。

啟動前的 `log_write_preflight` 用相同權限開啟精確 log 目標，不截斷既有內容；失敗時記錄失敗且 PID 為 null，不啟動引擎。精確匹配行首 `CrashHandlerException`／`handle_crash` 的 `Program crashed with signal N` 會使該 phase 失敗，即使有 PASS 且啟動程序 exit 0；沒有匹配也不等於排除了所有原生 crash。

2026-10-19 已執行 [test_runner_diagnostics.ps1](../../../tests/test_runner_diagnostics.ps1)：32 項合成檢查通過，使用隱藏的非互動 PowerShell fixture，沒有啟動 Godot。案例包括 log 無法寫入時不啟動、正常退出、crash 標記及失敗／逾時記錄；[結果](../../../analysis/slay-the-robot/evidence/2026-10-19/runner-diagnostics-results.json) 保留各 phase。這驗的是 runner 判讀與留證，不能寫成 Godot crash 修復或 GUI 穩定性驗收。
