# dev-env/windows — Windows／WSL／PowerShell 補充

[dev-env](../dev-env.md)｜[驗證](../testing.md)

從 dev-env 抽出的 Windows 專用步驟；Linux 主路徑留在父檔。

**何時用**：在公司 Windows 機取得引擎、跑 ps1 包裝或用 WSL／Git Bash 跑文件 lint。

Windows：依 `engine_policy.official_downloads` 核對官方 4.7.2 win64 ZIP，再解壓到 `.tools/` 的獨立目錄；沒有下載／安裝授權時不要執行取得步驟。使用者提供 ZIP 時先核對該檔名對應的 SHA-512，Mono 與非 Mono 不共用 hash；保留原件，不覆蓋既有引擎。勿以檔名推定版本。雜湊只證明 ZIP 符合來源鎖，runner 的版本探測與隔離 All 才是本機執行證據。

```powershell
$PSVersionTable.PSVersion   # ps1 包裝要求 7 以上
Get-Command git, python
python --version
$policy = (Get-Content tools/upstream.json -Raw | ConvertFrom-Json).engine_policy
$engineZip = '.tools/Godot_v4.7.2-stable_win64.exe.zip'
$expected = $policy.official_downloads.files.'Godot_v4.7.2-stable_win64.exe.zip'
if ((Get-FileHash $engineZip -Algorithm SHA512).Hash -ne $expected) { throw 'Godot archive SHA-512 mismatch' }
# 僅首次解壓；已有檔案時核對或使用 -GodotPath，不覆蓋。
Expand-Archive -LiteralPath $engineZip -DestinationPath '.tools/godot-4.7'
```

2026-10-20 公司機為 PowerShell 7.6.5、Python 3.13.0；使用者提供的 Mono ZIP 核對後位於 `.tools/godot-4.7-mono/`。同時存在多個 build 時指定 `-GodotPath`，不可把路徑探測當作每個 build 都實跑過：

```powershell
./tools/test-game.ps1 -Suite All -GodotPath '.tools/godot-4.7-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
```

背景工具的所有 Windows 子程序（含 Git、tasklist、假引擎的孫程序）都須保留 `CREATE_NO_WINDOW`。繁中 `cmd`／`tasklist` 輸出以 OEM 解碼，避免 UTF-8 解碼錯誤掩蓋真正失敗。junction 沙箱權限拒絕須依環境核准後重驗，不能以跳過測試代替。

### Windows 文件檢查執行器

WSL 原生 python3 為已驗入口。Git Bash 需以函式把 python3 指向 Windows Python，避免商店別名：

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -c 'function python3() { python "$@"; }; export -f python3; python3 --version && bash wf/tools/wf-lint.sh --strict .'
```

### WSL 文件檢查範例

`--cd` 依實際 checkout 調整：

```powershell
wsl.exe --cd /mnt/c/code/mine/mycardgame bash -lc 'python3 --version && bash wf/tools/wf-lint.sh --strict .'
```

## Done when

引擎版本探測與 `wf-lint.sh --strict .` 皆實際成功。
