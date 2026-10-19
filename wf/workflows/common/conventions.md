# conventions — 專案慣例

[common/README](README.md)｜[INDEX](../../INDEX.md)｜[code-map](code-map.md)

目前以 game/ 的固定上游版本為基準，分析依實際原始碼與測試結果維護。下列 game/、wf/、analysis/、tools/、tests/ 是題材中立的框架目錄；各款遊戲的 design、wf overlay、內容包與 probe 放 `games/<game>/`，框架目錄不引用它，也不寫題材名詞。

- 工作流放 wf/，遊戲放 game/，分析放 analysis/，本專案工具與測試放 tools/、tests/；不把 Godot 內容攤入工作流目錄。
- 文件用繁中、UTF-8；識別字沿用上游命名。
- 工作流文件大小與分層遵循 [STRUCTURE](../../STRUCTURE.md)，以 strict lint 驗證。
- 上游框架、參考資料與本專案原創內容分開記錄來源；保留採用內容的授權文字。
- 變動公開介面或資料 schema 前，以 rg 找出引用；同時更新相關實作、資料及必要驗證。
- 新增依賴要有任務需求、版本與用途記錄；Godot 下載與來源 commit 見 [upstream.json](../../../tools/upstream.json)。
- 新內容優先獨立 mod，見 [擴充分析](../../../analysis/slay-the-robot/architecture/02_extension_points.md)；修改框架須保留差異並做回歸驗證。
- 搬移檔案須同步導航，流程見 [refactor](../refactor/README.md)。
