# agent-session — 接手、分工與交付

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)｜[使用者偏好](common/user.md)

**何時用**：新 session 接手、多人並行、工作跨 session，或需要交付供下一個 agent 延續。

**何時不用**：單一低風險小修，不必另建交接檔；仍遵守相關領域的驗證與文件同步。

## 冷啟動

依使用者要求，每位主／子 agent 開工前先通讀核心規矩：根入口、[STRUCTURE](../STRUCTURE.md)、[派發器](../WORKFLOWS.md)、[專案地圖](../INDEX.md)、[PROJECT](../PROJECT.md)、[工作流模板](TEMPLATE.workflow.md) 及本篇。再讀 [common 入口](common/README.md)、[使用者邊界](common/user.md)、[慣例](common/conventions.md)、[code map](common/code-map.md)、[資料檔契約](common/data-files.md) 與 [經驗回寫](learning.md)。簡單雜事可只讀相關規矩；操作邊界與檔案所有權仍須傳遞。同一任務已完整讀過且未變動的內容可沿用，不必每次工具呼叫都重讀。

接著看 SESSION-LOG／WAIT_USER 的 open 項目，再由 [game-dev](game-dev/README.md) 選領域，按需讀分析、實作與測試。來源版本以 tools/upstream.json 和實際 checkout 為準，不依前一個 agent 的記憶。`wf/` 保存可重用的操作流程與判斷邊界；分析保存核實事實及來源，任務結果提供驗證證據，變更後沿這條鏈一起更新。

從專案根檢查：

```powershell
git -C game status --short
git -C game rev-parse HEAD
Get-Content tools/upstream.json
```

依 [dev-env](dev-env.md) 辨認外層 snapshot 與本機保留的 game 上游 checkout；公開 clone 的 `git -C game rev-parse HEAD` 會是專案提交，不能當上游 SHA。上游基準以來源鎖為準。既有變更可能屬於使用者或其他 agent；先辨認歸屬，不能 reset、覆蓋或批次清掉。已有本機存檔要保留，驗證需要乾淨資料時使用獨立測試副本。

## 接受任務後

多步驟工作先在 SESSION-LOG 留一行 open，寫下一步與相關檔案。將完成條件具體化，決定要修改的檔案與測試範圍。可以自行完成授權任務所需的查核、實作、驗證、文件與工作流維護，不因一般工程步驟再次請示。

不要把純建議變成執行中的任務；未決核心玩法、需要帳號或超出既有授權的對外操作才釐清。使用者在工作中提出修正時，更新當前範圍與分工，不遺失先前尚未完成的需求。

## 多 agent 分工

適合拆開的任務包括來源分析、獨立功能、測試與檢閱。主 agent 的派工訊息需含目的、允許修改的檔案、只讀範圍、所依版本、完成證據，以及哪些整合檔由主 agent 負責。

依目前使用者偏好，工作盡量交子 agent，主 agent 負責交流、協調與整合。每次派工必須傳遞有效授權：允許專案檔案修改與不開視窗的背景檢查；禁止桌面／視窗／UI／截圖／焦點操作及啟動 GUI；不得操作或終止既有程序。再委派也須原樣傳遞，不得以隔離副本或測試需要為由放寬。較早的 runtime／capture 流程只有在符合目前邊界時才可用。

同一檔案同時只有一位寫入者。wf/INDEX、WORKFLOWS、code-map、來源鎖與共享測試入口由主 agent 整合；多個 agent 若要改同檔，先交接所有權，不互相覆寫。依賴別人產物的工作，先做獨立部分，收到實際檔案後再接。

子 agent 可再分派獨立子任務；先檢查可用並行額度，避免同一調查重複派工。再派工時附上核心規矩入口、讀寫範圍、共同驗收與回報對象；派出者先核對產物，再向上一層交付。最終遊戲執行與共用導航仍由指定 owner 串行整合。

在符合上述授權的背景 runtime 檢查中，Godot 多實例仍可能共用 game/external 的存檔與設定；同一 checkout 由一位 agent 串行執行，其他 agent 並行讀碼／改獨立文件。需要並行時，各自用隔離副本並記錄路徑。程序控制只能針對本次檢查自行建立且可識別的子程序；不得操作既有程序，也不刪除不屬於本任務的檔案。

主 agent 收到完成報告後檢查實際檔案、必要 diff 與測試證據，不能把子 agent 說「成功」當作唯一驗收。沒有新變更或疑點時重用有效證據，不無限重跑相同測試。

## 中斷時留下什麼

SESSION-LOG 用一句話指向當前工作；複雜任務需要詳細交接時才在 wf/workflows/feature-dev/ 下建立該任務筆記。記錄已完成與尚未完成、修改者／檔案歸屬、已跑指令及結果、保留中的程序／測試副本、下一個可執行步驟。不把全部對話倒入記錄。

只有必須由使用者操作的工作放 WAIT_USER；一般待 agent 開發的項目不丟給使用者。已確認長期行為寫入分析或工作流；可重複經驗交 [learning](learning.md)。

## Done when

交付結果有修改位置、實際驗證結果與限制，受影響文件已同步，open 狀態與真實剩餘工作一致。完成任務移除 open 條目；未完成保留明確下一步。是否 commit／push 依既有授權與使用者指示，不由「工作做完」推導。

## 交接

遊戲修改接 [game-dev](game-dev/README.md)，來源升級接 [upstream](game-dev/upstream.md)，驗收接 [testing](testing.md)。
