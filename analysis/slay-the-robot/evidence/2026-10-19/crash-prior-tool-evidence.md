# Godot 先前工具輸出轉錄：A／B 嘗試

本檔於 2026-10-19 由 runtime_probe agent 依本對話仍可見的工具結果整理。**這是歷史工具輸出轉錄，不是本輪重現，也尚未與使用者所見的原生記憶體錯誤對應。** 本輪只讀取既有檔案／事件，並依明示授權新增本檔；未啟動 Godot、操作視窗、截圖或接觸已開程序。

## A：預設 sandbox 下的直接命令

來源識別：`functions.exec` 內的 `tools.exec_command` 回傳 `chunk_id=a4f830`。呼叫未指定 `sandbox_permissions`，因此使用預設 `use_default`。工作目錄為 `{PROJECT_ROOT}`。

同一個 PowerShell 命令先改寫 `tests/framework_smoke.gd`：將本腳本的 FileLoader／Global／ActionGenerator singleton 參照改為動態節點參照，再直接執行下列命令；不是透過 `tools/game.ps1` 或 `tools/test-game.ps1` runner：

```powershell
& .\.tools\godot-4.6\Godot_v4.6-stable_win64_console.exe --headless --path game --script {PROJECT_ROOT}/tests/framework_smoke.gd
```

工具結果的 metadata：`exit_code=1`，`wall_time_seconds=1.6258040999999999`。此退出碼由 exec_command 回報，不是取得的 Windows exception code。結果沒有 PID、絕對發生時刻、故障模組或指令位址。

以下為該結果中完整可見的 crash 輸出；未補寫遺失的堆疊資訊：

```text
================================================================
CrashHandlerException: Program crashed with signal 11
Engine version: Godot Engine v4.6.stable.official (89cea143987d564363e15d207438530651d943ac)
Dumping the backtrace. Please include this when reporting the bug on: https://github.com/godotengine/godot/issues
[1] error(-1): no debug info in PE/COFF executable
[2] error(-1): no debug info in PE/COFF executable
[3] error(-1): no debug info in PE/COFF executable
[4] error(-1): no debug info in PE/COFF executable
[5] error(-1): no debug info in PE/COFF executable
[6] error(-1): no debug info in PE/COFF executable
[7] error(-1): no debug info in PE/COFF executable
[8] error(-1): no debug info in PE/COFF executable
[9] error(-1): no debug info in PE/COFF executable
[10] error(-1): no debug info in PE/COFF executable
[11] error(-1): no debug info in PE/COFF executable
[12] error(-1): no debug info in PE/COFF executable
[13] error(-1): no debug info in PE/COFF executable
[14] error(-1): no debug info in PE/COFF executable
[15] error(-1): no debug info in PE/COFF executable
-- END OF C++ BACKTRACE --
================================================================
```

`signal 11` 出現在命令輸出的 Godot CrashHandlerException 訊息中；工具本身成功回傳命令結果，沒有 transport error。不能由此轉寫為「已取得 0xC0000005」或斷定是哪個 exe／DLL 的 fault module。

## B：緊接 A 的 escalation 嘗試

來源識別：`chunk_id=1911ba`。A 後未再修改檔案，以相同 Godot 命令單獨呼叫 exec_command，但設定 `sandbox_permissions=require_escalated`。當時提出此重試是為了檢查環境限制是否相關，**不是已證明 sandbox 導致 A**。

該結果回傳 `session_id=65475`、`wall_time_seconds=10.0150074`，代表當次取回結果時命令仍在執行，沒有 exit_code。現有對話未保留此 session 的最終 wait 結果，因此不推測最終退出碼。

以下是 B 輸出的非連續節錄，不是完整輸出：

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org
SCRIPT ERROR: Compile Error: Identifier not found: DebugLogger
   at: GDScript::reload (res://autoload/FileLoader.gd:66)
SCRIPT ERROR: Compile Error: Identifier not found: DebugLogger
   at: GDScript::reload (res://data/SerializableData.gd:284)
SCRIPT ERROR: Compile Error: Identifier not found: Global
   at: GDScript::reload (res://data/prototype/CardData.gd:199)
SCRIPT ERROR: Compile Error: Identifier not found: Global
   at: GDScript::reload (res://scripts/actions/BaseAction.gd:126)
SCRIPT ERROR: Invalid assignment of property or key 'PROFILE_DIR_PATH' with value of type 'String' on a base object of type 'Node'.
   at: _run ({PROJECT_ROOT}/tests/framework_smoke.gd:41)
```

B 所展示的輸出沒有 A 的 signal 11 字樣。它顯示 GDScript 編譯／執行錯誤，不能作為 A 原生崩潰的根因定位，也不能視為同一錯誤的確定重現。

## user:// 訊息與版本限制

**A 的上述原始輸出沒有 user:// 開啟或寫入失敗訊息，B 的已展示輸出也沒有。** 不能把別次啟動的訊息插入 A 的 crash 前文。

另有實際保存的 [早期 editor import 日誌](startup-import.log)，第 3 行起的原文為：

```text
ERROR: Failed to read the root certificate store.
   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2570)
ERROR: Could not open 'user://' directory: 'user://'.
   at: _get_and_create_snapshot_storage_dir (modules/objectdb_profiler/editor/objectdb_profiler_panel.cpp:154)
```

此檔的 CreationTimeUtc 為 `2026-10-19T04:00:20.6759816Z`、LastWriteTimeUtc 為 `2026-10-19T04:00:33.6790262Z`（台北約 12:00），是檔案 metadata，不是 A 的時間證據。訊息是另一份 editor import 日誌中的 directory-open failure，沒有直接建立與 A 的同程序／同因果關係，不能擴寫成 A 已確認的權限或 log 寫入問題。

A／B 時的 smoke 原稿仍有靜態 `ExampleModLoader extends res://autoload/FileLoader.gd`，以及 CharacterData／CardData／BaseAction 型別／建構參照。後來才將上游 Script 改為 autoload 初始化後動態載入，mod-list adapter 也改用執行期 GDScript 編譯。之後又增加子測試完成檢查、capture，以及 Dictionary 修復的斷言。上游本地程式亦已修改 FileLoader／SerializableData。

本輪唯讀核查的 [目前 smoke 腳本](../../../../tests/framework_smoke.gd) SHA-256 為 `66455D901AA3411689F8040A13735BC8BCE579B5AE0BAABE1CE0D078A164A517`。A／B 當時沒有保存腳本 hash 或完整原始碼快照；現行腳本不能當作 A 的同版本復現材料。

## 可確認與尚缺證據

可以確認歷史 A 輸出有 Godot crash-handler 的 signal 11，且 exec_command 回報 exit 1。尚缺精確 PID／時刻、fault module、Windows exception code、可符號化的位址堆疊或 dump，以及使用者事故與 A 的對應關係。

本輪原有 artifacts 的 109 份 log 與既有 JSON／TXT 中未找到上述精準原生崩潰特徵；4 份 verification results.json 共 26 筆既有引擎退出碼皆為 0，且沒有 PID／逐程序起迄時間。當日 Application event 1000／1001／1002 可讀，但 Godot XML 匹配為零；限定 WER Archive／Queue 未見 Godot 報告，LocalAppData CrashDumps 不存在。以上缺口不代表崩潰未發生，也不足以將 A、使用者彈窗、或已知 processor 資源未釋放問題建立因果連結。
