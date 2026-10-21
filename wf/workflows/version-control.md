# version-control — 提交與發布

[WORKFLOWS](../WORKFLOWS.md)｜[開發環境](dev-env.md)｜[使用者授權](common/user.md)

**何時用**：整理本專案提交、更新來源補丁、推送至指定 GitHub repository，或檢查 snapshot 的可攜性。

**何時不用**：尚未定位的功能問題先走對應開發流程；有修改檔案不代表已完成驗收。MCP 或其他服務整合另待需求，不屬於發布前置條件。

## Done when

提交包含已授權範圍內的程式、測試、分析與工作流；index 檢查沒有意外 gitlink、個人資料或生成快取。驗證紀錄存在，commit／push 指令回傳成功，遠端 ref 與已驗提交 SHA 一致。首次發布另有 fresh clone／提交樹讀回的檔案、補丁雜湊及文件連結檢查結果。

## 流程

### 確認身份與範圍

commit／push 授權、Git 全域身份 justty32 與各機器的執行環境見 [user](common/user.md#版本控制與授權)；作業系統登入帳號與 Git 作者身份分開辨認。執行前只讀核對 `git config --global --get user.name`、`user.email` 與 origin，不列印完整 credential 設定、不改全域身份。遠端為 `git@github.com:justty32/mycardgame.git`；既有 SSH 認證對應 justty32，認證失效時報具體阻礙，不開登入 UI。

以下 Git 提交操作均在上述環境的專案根目錄執行。先看 `git status --short`、待提交的 diff 與遠端 refs，辨認使用者及其他 agent 的變更；不要因本機有工作就覆寫遠端。多人變更由整合 owner 確認歸屬後一起驗收，正常推送不包含強制重寫或刪除歷史。

### 辨認 snapshot 與內層 checkout

公開 clone 的 game/ 是一般檔案，來源由 tools/upstream.json 記錄。本機原開發目錄仍可能有 game/.git；保留它，不搬移或刪掉。首次建立外層 repository 時，單獨 `git add game` 可能建立 gitlink，不能當成已發布本地修復。

首次匯入以唯一 staging 目錄建立普通檔案 snapshot：按核對過的 allowlist 複製專案檔；game 按其 tracked 清單複製**目前工作檔內容**，新增檔另行列入，排除內層 Git metadata 與個人資料。使用外層 git-dir、staging work-tree 建 index，保持外層原 worktree 設定；不把 core.worktree 永久指到暫存目錄。

外層已有普通檔案 index 後，既有 game 變更可由外層 `git add -u -- game` 暫存；新增檔使用明確檔案清單。提交前讀 `git ls-files --stage` 確認沒有非預期的 mode 160000，並核對 staged game blob 與已驗工作檔的內容相同。fresh clone 沒有內層 Git 時仍採明確範圍暫存。

### 保留來源與可攜證據

保留框架、addons 與 workflows 原授權。純上游重建用的補丁需核對 git diff、apply --check／反向檢查及 SHA-256；來源鎖記錄順序、用途與驗證報告。snapshot 已含補丁結果，不能在 clone 後重複套用。

引擎、測試遊戲副本、個人 profile／settings／saves、憑證與 cache 按 .gitignore 排除。文件若直接連到未發布的 artifacts，選必要小型證據另存 analysis 的 evidence/，保留原件不動；副本遮罩個人／絕對路徑，manifest 記錄來源、原件與副本雜湊及轉換。更新文件指向可攜副本，再驗 fresh clone 的連結。

### 驗收與推送

變更穩定後依 testing 跑適當背景套件與 strict lint；來源變動後不能沿用不相符的舊 pass。先檢查 staged diff、排除項與版本身份，再 commit 建立可描述的變更；push 更新已核對的分支。遠端有新提交時先讀取並整合，不強制覆蓋。

首次發布在獨立 clone 或 archive 讀回檔案，核對 game 不是 gitlink、來源補丁與證據 hashes、來源 metadata 的 snapshot 分支，以及文件 lint。若與已驗來源完全一致，這些發布檢查不需要重跑所有遊戲場景；發現內容差異才回到對應驗證。

artifacts/ 下 ignored 的歷史驗證副本可能含安裝後不成立的連結；文件 lint 在 git 工作樹內不掃 .gitignore 路徑（見 [文件檢查](testing.md#文件檢查修改後必跑)），因此不影響結果。在非 git 目錄（staging、archive 讀回）跑 lint 時，只放入全部 tracked 現檔加明確核准的非 ignored 新檔，逐檔核對雜湊後在其根目錄執行相同的 `bash wf/tools/wf-lint.sh --strict .` 與 `python3 tools/boundary_lint.py`。不得縮成只驗 wf/，也不得為過關刪除歷史副本或放寬 broken 規則；交付需記錄檢查範圍與結果。

shell 檔以 `.gitattributes` 的 `*.sh text eol=lf` 保持 LF：CRLF 的 shell 檔在 Git Bash 可跑，在 WSL 會出現 `set: -\r: invalid option`。遇到同類錯誤先查檔案換行與實際執行器，再在 staging／fresh clone 跑相同 lint。此修正只處理 shell 可攜性，不證明遊戲或其他環境已驗收。

## 交接

回報分支、commit、遠端連結、實際驗證與限制。更新 SESSION-LOG 的 open 狀態；可重用的發布經驗留在本流程。操作邊界見 [user.md](common/user.md#桌面與程序邊界)。
