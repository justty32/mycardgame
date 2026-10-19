# dev-env — 開發環境與指令

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)｜[驗證](testing.md)｜[版本控制](version-control.md)

**何時用**：換機、匯入資源、執行背景檢查或工具無法執行。

## 環境與來源

開發跨平台：公司 Windows、家中 Manjaro Linux 原生。共同需求為 Python 3.10+（runner 只用標準函式庫）與 Godot 4.7.x（2026-10-19 起的基準；4.6 為歷史基準）。引擎政策、官方 4.7.2 四平台 SHA-512、本機已驗 build 與 4.6 遷移比對見 [upstream.json](../../tools/upstream.json) 的 `engine_policy`。文件 lint 需 bash 與 python3，見 [文件檢查](testing.md#文件檢查修改後必跑)；Git 身份見 [版本控制](version-control.md)。

發布 repository 為 `justty32/mycardgame`，外層 snapshot 包含 game 普通檔案與本地修復。原開發機另外保留 game/.git 作上游固定版本 checkout；fresh clone 沒有內層 repository。因此 `git -C game rev-parse HEAD` 可能是外層專案 commit；上游基準須讀來源鎖，不能混用。runner 分開記錄上游、checkout 及實際來源檔雜湊。

## 背景驗證

從專案根使用 [隔離 runner](../../tools/test_game.py)；Windows 也可用參數相同於舊版的 [ps1 包裝](../../tools/test-game.ps1)：

```bash
python3 tools/test_game.py --suite All
python3 tools/test_game.py --suite ResourceLifecycle
# 指定引擎、或重放舊基準
python3 tools/test_game.py --suite Smoke --godot-path /path/to/godot
python3 tools/test_game.py --suite Smoke --accept-engine-version '^4\.6\.'
```

```powershell
./tools/test-game.ps1 -Suite Smoke -GodotPath 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
```

引擎探測順序：`--godot-path` → `.tools/` 下版本符合 `accepted_version_patterns` 者 → PATH 上的 godot／godot4／godot-mono／godot4-mono；版本再以 `--version` 核對，探測方式寫入 results.json。

每次在 artifacts/verification/ 建立獨立副本與 user://，程序一律 headless、不開視窗。Linux 把 HOME、XDG_*、DOTNET_CLI_HOME、NUGET_PACKAGES 導到 run 目錄，並移除 DISPLAY／WAYLAND_DISPLAY；Windows 把 APPDATA、LOCALAPPDATA、TEMP 導到 run 目錄（`--no-isolate-appdata` 可關閉），以 CREATE_NO_WINDOW 啟動、逾時用 taskkill /T。Windows 端這些行為尚未實測。`--source-game` 可指定候選原始碼目錄；來源鎖仍是本專案基準，候選版本須另核對 checkout 與 hashes。驗證規則、歷史紅測開關及套件範圍見 testing，正式綠測不容許資源殘留。

[game.ps1](../../tools/game.ps1) 是 Windows 專用的舊 Run／Import／Smoke 入口，預設路徑已改指 4.7 但未實測。Run 會開 GUI，且會讀寫 game/external 的設定／存檔；不適用目前的 agent 操作授權，需要 GUI 的部分記為未驗證。完整限制見 [user](common/user.md)。

## 換機與重建

clone 本專案即包含已修復的 game，不要再次套用補丁。不需 PAS、Node/npm 或 export template 即可跑現有背景套件；本專案尚未驗證發行匯出。先唯讀核對工具與佈局，缺工具時只記錄缺項，再依當前安裝授權處理；Git 身份不是背景遊戲測試前提。

Linux（2026-10-19 Manjaro 已驗）：發行版套件 godot 或 godot-mono 經 PATH 探測即可；套件 build 不是官方 archive，upstream.json 的 SHA-512 不描述它，以 runner 版本探測與隔離 All 為證據。

換到新平台時，先用 headless 加導向 HOME／XDG_*（Windows 為 APPDATA 等）的最小探針確認引擎可跑，再改 runner；探針不得寫入使用者的 ~/.config/godot（2026-10-19 Manjaro 實證）。

```bash
python3 --version; command -v git godot godot-mono
godot-mono --version
test -f game/project.godot && echo ok
git rev-parse --show-toplevel
```

Windows 取得引擎、PowerShell 檢查與 Git Bash/WSL 文件檢查的步驟見 [Windows 補充](dev-env/windows.md)；Linux 主路徑以上述 `godot-mono` 為準。

環境就緒後，第一個內容變更接 [mod 起步](game-dev/content/bootstrap.md)，不要為了學習範例直接開 GUI 或修改個人存檔。

只有從純上游另建乾淨 checkout 時，才依來源鎖 repository／commit 取得版本，逐一核對 local_patches 雜湊，按照列出順序先 apply --check 再 apply；目前先 framework-fixes.patch，再 resource-lifecycle.patch，最後 content-profile.patch。已套用與未套用的目錄分開辨認，不能重複套用。上游更新走 [upstream](game-dev/upstream.md)。

`.tools/`、artifacts/、Godot cache、個人 profile／settings／saves 不屬於發布原始碼。必要的歷史驗證已另選入 analysis/slay-the-robot/evidence/；發布副本記錄原件與副本 hash 及路徑遮罩，不能當成未處理的原始日誌。

Windows 的文件檢查執行器（WSL／Git Bash）見 [Windows 補充](dev-env/windows.md#windows-文件檢查執行器)。

## 存檔與環境限制

框架除錯模式會使用 game/external/profile.json、user_settings.json 與 saves/。game.ps1 的舊 Smoke 只在 Global 首次 ready 後轉移其後寫入，不能用它直接測使用者存檔；流程驗證一律走隔離 runner。發布省略個人設定，由框架在新環境依預設值建立。

Windows 沙箱（2026-10-19 公司機）曾阻擋 Godot 寫入 user://、編輯器設定，以及 Git Bash 建立 signal pipe（Win32 error 5）；後者改用已驗 WSL lint 入口，其他錯誤依執行環境核准流程處理。不能由權限差異推定遊戲根因，也不能只依 exit 0 宣稱無錯。原生崩潰調查目前依使用者要求擱置。

## Done when

對應背景套件有完成標記、預期退出碼及完整日誌；必要文件 strict lint 回傳 0。來源與 checkout 身份分開記錄，個人資料未被測試或發布涵蓋；未驗 GUI、聽感、實際輸入與匯出範圍明列於交付。
