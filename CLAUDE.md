# TrackStack(仮)

読書・筋トレ/トレーニング・資格勉強の記録を 1 つにまとめる個人用 iPhone アプリ。
企画・仕様・ロードマップの詳細は `docs/PLANNING.md`、開発状況チェックリストは `README.md` を参照。

## 技術スタック

- iOS 17+ / Swift / SwiftUI / SwiftData / Swift Charts(M4 で導入予定)
- 個人利用のみ(App Store 公開なし)。ローカル完結、iCloud 同期なし
- エクスポート(JSON / CSV / Obsidian Markdown)が MVP の柱。形式仕様は PLANNING.md §3.5

## ビルド・テスト

`.xcodeproj` はコミットされていない。XcodeGen で `project.yml` から生成する:

```bash
xcodegen generate   # Swift ファイルを追加・削除・リネームしたら必ず再実行
xcodebuild -scheme TrackStack -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme TrackStack -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- **新しい Swift ファイルを作ったら `xcodegen generate` を再実行しないとビルド対象に入らない**(project.yml はディレクトリ指定のため、再生成で自動的に拾われる)
- シミュレータ名は `xcrun simctl list devices available` で確認して合わせる
- コード変更後は必ずビルドを通してからコミットすること

## 設計の要点

- `Session` が全カテゴリ共通の記録単位。カテゴリ固有情報(Book / Subject / ExerciseLog)は関連エンティティに逃がし、横断集計(合計時間・ストリーク)は Session だけで完結させる
- enum は SwiftData に rawValue(String)で保存し、computed property で enum に変換(`categoryRaw` / `category` パターン)
- 種目名・メニュー名は Session 側にスナップショットで保持(マスタ削除後も記録が壊れない)
- 読書進捗は %(0–100)のみ。ページ数は持たない
- `WorkoutMenu` は入力の雛形。記録実体は常に Session + ExerciseLog
- 集計ロジックは `Shared/StatsCalculator.swift` に純粋関数で分離(ユニットテスト対象)
- UI 文言は日本語

## 開発状況(2026-08-09 時点)

- 完了: プランニング / M1(基盤) / M2(カテゴリ固有機能) / M3(タイマー記録)
- 次: M4(グラフ・カレンダー)→ M5(エクスポート)→ M6(仕上げ)
  - M3 のタイマーは `Features/Timer/ActiveTimer.swift` に「開始時刻との差分」方式で実装済み(PLANNING.md §5)。状態は UserDefaults(キー `activeTimerState`)に永続化し、アプリ再起動後もダッシュボードの計測中バナーから復元できる

## ブランチ運用

- 開発ブランチ: `claude/iphone-learning-tracker-plan-3ruzgu`
- コミットは機能単位で日本語 or 英語どちらでも可。ビルドが通った状態でコミットする
