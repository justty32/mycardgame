# 內容包的獨立可玩副本

[內容子流程](README.md)｜[內容包契約](pack.md)｜[驗證](../../testing.md)

**何時用**：包已有角色／地圖／遭遇等必要內容，要準備一份讓使用者自行開啟的獨立專案，保留來源、個人 mod 清單與進度。

**何時不用**：只驗載入或自動流程，使用內容包契約的隔離 runner；要修改實際內容，回 [內容入口](../content.md)。建立副本不代表包已可完成一局。

## Done when

準備命令 exit 0，輸出路徑的 `game/project.godot` 與 `manifest.json` 存在；manifest 的 `status` 為 `prepared`、`content_profile` 為 `pack`，包含來源／內容包／副本 SHA-256。工具回歸 `python3 -I tests/test_prepare_pack.py` exit 0。遊戲執行與實機觀感是否已驗須另列證據。

## 流程

從專案根執行，`--pack` 可重複；名稱取自包內 `mod_info.json` 宣告的安裝前綴，不取來源資料夾名：

```bash
python3 tools/prepare_pack.py --pack games/<game>/pack
```

工具只寫全新的 `artifacts/playable/<uuid>/`。若需事先決定位置，可給 `--output artifacts/playable/<32 位小寫 UUID>`；已存在、其他父層、連結或 junction 路徑皆拒絕。沒有覆蓋、重用或清除模式。若寫入中失敗，保留副本供診斷，改用新的 UUID 重做，不刪來源或舊證據。

來源沿回歸 runner 的 Git／Godot cache／profile／settings 排除規則，並排除 saves、私有環境與憑證檔（含既有 Git 排除契約的 `.pem`／`.key`／`.p12`／`.pfx`）。來源的 `external/mods/`、`external/mod_list.json` 及 `override.cfg` 不複製，避免個人啟用項或專案覆寫污染副本。被保留的內容若有連結則拒絕；被整個排除的私人 mods 不跟隨也不帶入。副本清單只啟用 `external/` 與明示的包，各包 priority 從 10 依參數順序遞增；重複安裝名拒絕。

副本 `project.godot` 設定 `game/content_profile="pack"`，停用框架範例內容生成。包須自備引用資料；副本設定唯一 `config/custom_user_dir_name`，user:// 與其他副本分開。框架除錯存檔仍寫在這份副本自己的 `external/`，不共享來源進度。

工具不啟動引擎。輸出提供絕對專案路徑、manifest 路徑，以及使用者自行操作的 PowerShell／POSIX 編輯器、首次 headless import、直接遊玩命令；可加 `--godot-path <執行檔>` 將本機 Godot 4.7.x 路徑寫進命令，僅列印、不執行。未指定時以 `godot` 代稱。首次直接遊玩前需匯入建立 class cache。agent 仍遵守 [操作邊界](../../common/user.md)，不得因工具印出命令便啟動 GUI。

runner 若要驗這份已安裝內容的副本，先用工具的純讀取 `validate_prepared_game(game)` 檢查 manifest identity、完整副本與每包雜湊、專案 profile 與精確 mod 清單。額外包檔、變動來源副本或 `override.cfg` 會被拒絕；勿再次安裝同名包來規避衝突。實際 runner 參數與流程入口依 [驗證](../../testing.md)，不由準備工具啟動引擎。

## 驗收與交接

2026-10-20 的純 Python fixture 回歸覆蓋私有資料排除、來源逐位元組不變、專案 profile 覆寫、manifest hash、輸出邊界與連結拒絕；不呼叫引擎。實作在 [prepare_pack.py](../../../../tools/prepare_pack.py)，回歸在 [test_prepare_pack.py](../../../../tests/test_prepare_pack.py)。manifest 保留實際來源路徑，屬 ignored 本機證據，對外分享前依證據工作流處理路徑。

先凍結框架與包，再產最終副本；整合驗證必須指向該份 prepared game，不能用較早的來源或另一版包代替。交接時提供準備出的專案與 manifest 路徑，再連結該包的 headless 流程結果；區分「副本建立成功」「內容流程通過」與「使用者實機驗收」。新增工具導航由整合 owner 同步內容子流程與 code map，不把單包內容寫進框架流程。
