# dev-env/windows — Windows／WSL／PowerShell 補充

[dev-env](../dev-env.md)｜[驗證](../testing.md)

從 dev-env 抽出的 Windows 專用步驟；Linux 主路徑留在父檔。

**何時用**：在公司 Windows 機取得引擎、跑 ps1 包裝或用 WSL／Git Bash 跑文件 lint。

Windows：依 `engine_policy.official_downloads` 下載官方 4.7.2 win64 ZIP 到 `.tools/`，核對 SHA-512 後解壓；沒有下載／安裝授權時不要執行取得或解壓步驟。勿以檔名推定版本。

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
