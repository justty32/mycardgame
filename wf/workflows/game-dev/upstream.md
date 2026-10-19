# upstream — 升級框架與 Godot

[game-dev](README.md)｜[環境](../dev-env.md)｜[驗證選擇](validation.md)

**何時用**：使用者要求更新 Slay-The-Robot、Godot 或相關 addon，或已授權功能明確需要版本升級。

**何時不用**：一般卡牌／玩法開發沿目前鎖定版本；只查新版可行性先走 [investigation](../investigation.md)。不以發現新版為由自行升級。

## 先保留比較基準

讀取 [upstream.json](../../../tools/upstream.json)，依 [環境佈局](../dev-env.md) 區分上游 checkout 與外層 snapshot。snapshot 中的 game HEAD 是專案提交，不能拿來驗上游 SHA；上游版本應由來源鎖與隔離的純上游 checkout 核對。記錄本地改動及未提交檔案歸屬；不在有未知改動的 checkout 執行 pull、reset 或覆寫。

先在隔離 checkout 評估候選 commit，避免改掉目前可啟動版本。原始版本、候選版本、Godot 版本、授權／addons 變動與比較結果寫在 analysis/slay-the-robot/ 的升級筆記，第一份出現時才建檔。來源內容以實際 commit 為準，README 版本宣告只是核對入口。

## 差異評估

先看 project.godot 的引擎與 autoload／主場景差異；再沿 code-map 核對 FileLoader、SerializableData、ActionHandler、資料 schema、mod 載入與存檔。只升引擎時也不能略過 script parse、資源重新匯入與渲染差異。

將本地功能改動與上游差異分開評估。欄位／ID／腳本路徑被移除時，找出本專案所有引用；既有存檔與 mod 在隔離副本上驗證，不拿使用者正在玩的存檔當升級試驗品。

下載引擎時使用官方來源與對應 checksum；版本、URL、雜湊寫入來源紀錄。升級不自動包含 export template 或發行流程，只有任務需要時另驗。

## 驗收再切換

候選版本先透過隔離 runner 的 `-SourceGame` 指向候選原始碼，完成背景 import、框架 smoke、受影響的功能回歸及必要存讀相容驗證。實際渲染與輸入依有效授權處理，目前禁止桌面／視窗操作，保留為未驗。工具 game.ps1 固定針對正式 game/，不能誤跑舊版後宣稱新版通過。

與原基準比較新增／消失的警告。當前已有 Dictionary merge 等本地修復，先核對 upstream.json 的 local_patches，確認候選是否包含等效修正；以公開 JSON 回歸與跨程序存讀測試驗證，不能只刪補丁或 KNOWN ISSUE 文字。原 dated 驗證報告保持歷史事實，新增當前版本結果並更新現行指引。

有可重現的新失敗時維持原 game/，留下候選與問題證據。通過後在當前授權範圍內整合：保留本地變更、切到指定 commit、同步工具引擎位置／版本檢查、來源紀錄、code-map、dev-env、testing 與受影響教學。不要在確認來源前改 lock 檔假裝已升級。

## Done when

- 升級筆記存在，含新舊 commit、引擎、相容性差異與實跑結果。
- 純上游 checkout 的實際 HEAD 與來源紀錄一致；snapshot 的本地差異與補丁已核對並記錄。
- validation 選出的測試回傳符合預期，strict lint 回傳 0。
- 原基準可追溯；新增缺陷與未驗範圍在目前文件可見。

## 交接

升級導致功能修正接 [mechanics](mechanics.md) 或 [content](content.md)；可重複的升級經驗交 [learning](../learning.md)。只有實際需要新的外部授權或使用者操作時，才記 WAIT_USER。
