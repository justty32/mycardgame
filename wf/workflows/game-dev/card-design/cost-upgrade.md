# 卡牌費用、循環與升級

[卡牌設計](../card-design.md)｜[卡牌評量](../card-evaluation.md)｜[核實筆記](../../../../analysis/slay-the-robot/design/cards.md)

**何時用**：設計或修改卡的能量費、X 費、0 費、牌循環去向，或基礎／首升／後續升級的數值。

**何時不用**：只寫卡的意圖與 schema，回 [卡牌設計](../card-design.md)；評量強弱走 [卡牌評量](../card-evaluation.md)；需要新的費用或升級機制，走 [mechanics](../mechanics.md)。

## 費用

普通能量與 X 費不同：X 費由 `card_energy_cost_is_variable` 與 upper bound 控制，實付費用另受攔截及暫時費用覆蓋影響。要測 0 能量、剛好足夠、不足、上限、複製及自動出牌；不要直接寫 `card_energy_cost=-1` 來表達 X。降到 0 費時，重新檢查抽牌與回收是否會形成無限循環。

## 牌循環

以出牌後／回合後的去向、保留、虛無及抽牌觸發，說明卡如何離開牌循環。分別追蹤抽、棄、消耗、生成、回手的成本；一回合內淨能量不減、又能重建手牌或牌堆的組合，列為循環候選，須有行動／回合上限及可重現的 trace。不能只比較面板傷害除以能量，0 費卡尤其需要計入抽牌槽位與時間成本。

## 升級

`upgrade_card()` 第一次升級先套 `card_first_upgrade_value_changes`、`card_first_upgrade_property_changes`，之後每次才加 `card_upgrade_value_improvements`。分別列出基礎、首升、上限時的有效值與敘述。

戰鬥中的牌是永久牌的副本，`parent_card` 指回原牌；永久升級與僅本場戰鬥的升級不能混用。現有 UpgradeCards 的 count／bypass 對副本與 parent 的傳遞不一致；需要多次升級時，依核實筆記先補專項測試。
