# TrackStack(仮)

読書・筋トレ/トレーニング・資格勉強/勉学の記録を 1 つにまとめて取れる iPhone アプリ。
企画・仕様は [docs/PLANNING.md](docs/PLANNING.md) を参照。

- iOS 17+ / SwiftUI / SwiftData
- 個人利用前提・ローカル完結(エクスポートで Obsidian / AI 分析用 JSON に書き出し予定)

## セットアップ(Mac)

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で `project.yml` から生成します。

```bash
brew install xcodegen
git clone https://github.com/tgc-takara/ta1.git && cd ta1
xcodegen generate
open TrackStack.xcodeproj
```

Xcode 上で Signing の Team を自分の Apple ID に設定すれば、シミュレータ・実機で実行できます。

## 構成

```
project.yml          # XcodeGen 定義(xcodeproj はコミットしない)
TrackStack/
├ App/               # エントリポイント・Tab 構成
├ Models/            # SwiftData モデル(Session を共通軸にした設計)
├ Features/          # 画面ごとのモジュール(Dashboard / History / Record / Library / Settings)
└ Shared/            # 共通 UI・集計ロジック(StatsCalculator)
TrackStackTests/     # ユニットテスト
docs/PLANNING.md     # 企画・仕様・ロードマップ
```

## 開発状況

- [x] プランニング
- [x] M1: 基盤(モデル・Tab 骨格・手動記録・ダッシュボード最小版・履歴)
- [x] M2: カテゴリ固有機能(本棚・科目・種目・トレーニングメニュー・前回複製)
- [x] M3: タイマー記録
- [x] M4: 可視化(Swift Charts・カレンダー)
- [ ] M5: エクスポート(JSON / CSV / Obsidian Markdown)
- [ ] M6: 仕上げ
