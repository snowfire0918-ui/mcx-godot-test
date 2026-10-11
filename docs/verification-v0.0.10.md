# 三國工部 V0.0.10 施工紀錄

工程：《三國：我的三國我做主》第一代豪華重製版，Godot 4.4.1。
依據：`docs/specs/handoff-v1.2.txt`。本批範圍 P0／P1；正式平衡及 P2／P3 不在本批。

## GitHub 基線與查核

- 已驗證登入 `snowfire0918-ui`，可存取 `snowfire0918-ui/mcx-godot-test`。
- 基線 `feature/battle-prototype-v0.0.9`：`74501530a8ef6fb15ba2f943f22e5e5b599e1a58`。
- 中文化 HEAD：Add system CJK font fallback for Android Chinese UI。
- 原 Actions [38137658294](https://github.com/snowfire0918-ui/mcx-godot-test/actions/runs/38137658294) 是 success；[APK artifact 11702086489](https://github.com/snowfire0918-ui/mcx-godot-test/actions/runs/38137658294/artifacts/11702086489) 已存在且查核時未過期。
- 但原日誌含 `ci/export_diagnostics.gd` 的 `EditorExport` 解析錯誤。Godot editor import 在這種情況仍返回0；因此原綠燈不是腳本全部正常的證據。
- 修復提交 `80121161648f44e4773a2cd36e9f54358c06ab1a` 的 [Actions 38139013107](https://github.com/snowfire0918-ui/mcx-godot-test/actions/runs/38139013107) success，APK artifact `11701734645` 存在；真正的解析錯誤已消除。CI guard 的負向測試會刻意輸出一條標有 `deliberate fixture` 的測試錯誤，並確認被拒絕。

## 已實裝

- 獨立施工分支 `feature/battle-prototype-v0.0.10`，未修改原封版 HTML、未合併 main。
- `BattleCampaign` 保存隊伍、每位武將的生命與士兵代理的精確傷勢；選隊不重新配置兵力。
- 每隊1～3將；我軍最多5隊、敵軍最多10隊；每場只選雙方各1隊。
- 主將倒下仍有副將就繼續；兵力歸零不判敗；全隊武將歸零才敗。全部隊伍失能才結束戰役。
- 99秒雙方撤回，不比HP／兵力；可繼續派同隊或換隊。
- 未上陣隊伍每完整休息一場，存活武將+10 HP，封頂自身最大HP；不復活、不補兵；重複開選隊畫面不重複恢復。
- 返回首頁暫停，繼續戰役保留當場；清空戰役另需確認。
- 武力丹遵守255；技力靈藥遵守自身最大MP；無效果／無使用對象不消耗庫存。測試道具指定我軍第1隊主將，交戰暫停期間禁用。
- 士兵本幀死亡後不再反擊。保留三兵種克制、士兵攻擊武將、武將相互攻擊。
- 中文使用共用 SystemFont 及系統字型回退；加入可捲動畫面與每位武將HP顯示。
- CI 檢查腳本錯誤、執行整套測試，再匯出 Android versionCode 10／versionName 0.0.10；測試與診斷檔排除在 APK 資源之外。

## 測試證據

本地 Godot `4.4.1.stable.official.49a5bc7b6`：

| 類別 | 結果 |
|---|---:|
| CI 錯誤攔截 | 3/3 |
| 屬性、技力與道具庫存 | 6/6 |
| 隊伍驗證、勝敗、撤退、休整、兵力守恆 | 64/64 |
| 真實場景選隊／換場／暫停／窄版畫面 | 25/25 |
| 整場自動交戰及兵種／武將攻擊 | 8/8 |
| 合計 | 106/106 |

完整自動交戰案例：767幀（以每幀1/30秒推進），敵隊獲勝，雙方各剩400兵；檢查整段戰鬥兵力不增加、HP不超界。這只是原型參數案例，不是平衡結論。

重跑方式：先執行 `godot --headless --editor --path . --import --quit`，再執行 `bash ci/test.sh`。可用 `MCX_GODOT_BIN` 指定Godot執行檔。
桌面截圖：在有顯示環境及中文系統字型時，執行 `godot --rendering-method gl_compatibility --path . --script ci/capture_preview.gd`，輸出至 `build/qa/`。

## 尚待驗收／已知限制

- 最終候選提交的 Actions、APK、桌面截圖及独立複核結果須以最終回報為準。
- **未做 Android 真機驗收。** 桌面字型與預覽不代表 Android 字型回退、觸控或效能已通過。
- 首頁可設定每隊1～3人，當前同一場測試戰役採一致人数；資料模型接受不同隊伍各1～3人。此為測試配置器，尚非正式武將編隊編輯器。
- 敵方選隊目前開放人工指定以便驗收，尚非正式敵方策略AI。
- 戰役只在記憶體保存；關閉程式會清空。永久存檔、正式道具種類／背包、成長公式與軍師技仍待P2。
- 原型HP240、傷害、初始兵力與道具數值都不是正式平衡；現有測試道具不提供復活功能。
- 沿用原型美術，尚未接入正式Logo／圖示；匯出日誌會有缺少專案圖示提示，APK可正常匯出。
- P3仍須陛下驗收戰鬥核心後，再取得第一代封版HTML實碼；不可憑摘要搬遷。

## Android 實機驗收

1. 安裝0.0.10，核對首頁版本、中文有無方框、捲動及按鈕能否點擊。
2. 建立3將隊伍，確認一邊最多3名武將同場；主將倒下後副將存活時不提前結束。
3. 一場結束後重新選隊，核對原队HP／兵力保留；換隊休息一場後只恢復活將10HP。
4. 若發生99秒撤回，確認沒有按血量判勝負，仍能選隊再戰。
5. 戰鬥中返回首頁再繼續，確認不重置；回報裝置、畫面及是否卡頓。
