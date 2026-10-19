# dev-env — 開發環境與指令

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)｜[驗證](testing.md)｜[版本控制](version-control.md)

**何時用**：換機、匯入資源、執行背景檢查或工具無法執行。

## 環境與來源

背景測試使用 Windows PowerShell 7；Godot `4.6.stable.official.89cea1439` 可攜版放在 `.tools/godot-4.6/`，或透過 `-GodotPath` 提供其他位置。官方下載 URL、SHA-512 與本地補丁見 [upstream.json](../../tools/upstream.json)。Git Bash、Python 3.13 用於文件 lint；commit／push 使用 WSL 的 justty32 Git 全域設定與既有 SSH 認證。

發布 repository 為 `justty32/mycardgame`，外層 snapshot 包含 game 普通檔案與本地修復。原開發機另外保留 game/.git 作上游固定版本 checkout；fresh clone 沒有內層 repository。因此 `git -C game rev-parse HEAD` 可能是外層專案 commit；上游基準須讀來源鎖，不能混用。runner 分開記錄上游、checkout 及實際來源檔雜湊。

## 背景驗證

從專案根目錄使用 [隔離 runner](../../tools/test-game.ps1)：

```powershell
./tools/test-game.ps1 -Suite All
./tools/test-game.ps1 -Suite ResourceLifecycle
# 引擎位於其他位置時
./tools/test-game.ps1 -Suite Smoke -GodotPath 'C:/path/to/Godot_v4.6-stable_win64_console.exe'
```

每次在 artifacts/verification/ 建立獨立副本、快取及 user://，使用明確可寫日誌與不開視窗的程序啟動方式。`-SourceGame` 可指定候選原始碼目錄；來源鎖仍是本專案基準，實際候選版本須另核對 checkout 與 hashes。驗證規則、歷史紅測開關及套件範圍見 testing，不在正式綠測容許資源殘留。

[game.ps1](../../tools/game.ps1) 另保留 Run／Import／Smoke 舊入口。Run 會開 GUI，且一般啟動會讀寫 game/external 的設定／存檔；它不適用目前的 agent 操作授權。需要 GUI 的部分記為未驗證，不能因本頁列有入口就自行執行。完整限制見 [user](common/user.md)。

## 換機與重建

clone 本專案即包含已修復的 game，不要再次套用補丁。依來源鎖下載官方 Godot 4.6 Windows x64，核對 SHA-512 後解壓，或指定現有執行檔，再執行隔離 All。不需 PAS、Node/npm 或 export template 即可跑現有背景套件；本專案尚未驗證發行匯出。

只有從純上游另建乾淨 checkout 時，才依來源鎖 repository／commit 取得版本，逐一核對 local_patches 雜湊，按照列出順序先 apply --check 再 apply；目前先 framework-fixes.patch，再 resource-lifecycle.patch。已套用與未套用的目錄分開辨認，不能重複套用或覆寫既有修改。上游更新走 [upstream](game-dev/upstream.md)。

`.tools/`、artifacts/、Godot cache、個人 profile／settings／saves 不屬於發布原始碼。必要的歷史驗證已另選入 analysis/slay-the-robot/evidence/；原件保留本機，發布副本記錄原件與副本 hash 及路徑遮罩，不能當成未處理的原始日誌。

## 存檔與環境限制

框架除錯模式會使用 game/external/profile.json、user_settings.json 與 saves/。舊 Smoke 只在 Global 首次 ready 後轉移其後寫入，不能用它直接測使用者存檔；流程驗證一律走隔離 runner。發布省略個人設定，由框架在新環境依預設值建立。

Windows 沙箱曾阻擋 Godot 寫入 user://、編輯器設定，以及 Git Bash 建立 signal pipe；遇到這些錯誤依執行環境核准流程處理。不能由權限差異推定遊戲根因，也不能只依 exit 0 宣稱無錯。原生崩潰調查目前依使用者要求擱置。

## Done when

對應背景套件有完成標記、預期退出碼及完整日誌；必要文件 strict lint 回傳 0。來源與 checkout 身份分開記錄，個人資料未被測試或發布涵蓋；未驗 GUI、聽感、實際輸入與匯出範圍明列於交付。
