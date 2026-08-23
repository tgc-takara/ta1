# ひとつみ

読書・筋トレ/トレーニング・資格勉強の記録を 1 つにまとめる個人用 iPhone アプリ。
企画・仕様・ロードマップの詳細は `docs/PLANNING.md`、開発状況チェックリストは `README.md` を参照。

## 技術スタック

- iOS 17+ / Swift / SwiftUI / SwiftData / Swift Charts(M4 で導入済み)
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

- カテゴリは3つ(読書 / トレーニング / 勉強)。`ActivityCategory` の case 順がそのまま選択肢・凡例・内訳の表示順になる
- 記事・動画音声カテゴリは廃止済み(setupVersion 4 で該当記録を削除)。過去に存在した rawValue: `newspaper` / `podcast` / `article` / `media`
- 使うカテゴリは設定で取捨選択できる(`Shared/EnabledCategories.swift`、既定は全表示)。非表示でもその期間に記録があるカテゴリは内訳・凡例に出す(合計と内訳を一致させるため)。各画面は `.onAppear` で設定を読み直す
- 設定の切り替え UI に `Toggle` + カスタム `Binding` を使うと2回目以降の操作を取りこぼしたため、行タップ(Button)+チェックマークで実装している。`@State` は書き換え直後に読み返すと古い値が返るため、必ずローカル変数で新しい値を作ってから反映・保存する
- `Session` が全カテゴリ共通の記録単位。カテゴリ固有情報(Book / Subject / ExerciseLog)は関連エンティティに逃がし、横断集計(合計時間・ストリーク)は Session だけで完結させる
- enum は SwiftData に rawValue(String)で保存し、computed property で enum に変換(`categoryRaw` / `category` パターン)
- 種目名・メニュー名・本のタイトル・科目名は Session 側にスナップショットで保持(マスタ削除後も記録が壊れない)
- 読書進捗は Book のみが持つ(記録側には持たない)。%(0–100)のみでページ数は持たない
- 本の「読んだ記録」は読書セッションそのもの(専用エンティティは持たない)。本全体のメモだけ `Book.review` に持つ
- `WorkoutMenu` は入力の雛形。記録実体は常に Session + ExerciseLog
- トレーニングだけ「記録開始」でタイマー画面ではなく記録フォームを開く(計測しながら書き込む運用)。終了ボタンで開始からの経過時間を実施時間として保存し、`TrainingSummaryView` でその日の内容をスクショ共有用に表示する
- 勉強・読書のタイマーにはポモドーロモードがある(`Features/Timer/Pomodoro.swift` が純粋ロジック、状態は `ActiveTimerState.pomodoro` に同居)。記録時間は作業局面の合計のみ。局面の切り替わりはフォアグラウンドで音、バックグラウンドではローカル通知
- 入力欄を UIViewRepresentable(UITextField)で包むと List の行内でタップを受け取れない。数値欄は SwiftUI の TextField + FocusState で実装する
- 起動時のデータ移行・プリセット投入は `TrackStackApp.setupVersion` で初回のみ実行する。毎回走らせると起動のたびに全レコードをフェッチすることになるため、プリセットを追加したときだけこの版数を上げる
- 週の始まり(日曜/月曜/システム)は `Shared/WeekStart.swift` の設定で切り替える。「今週」の集計とカレンダーは `Calendar.current` ではなく `AppCalendar.current` を使う(ホームのグラフは暦週ではなく直近7日なので対象外)
- 集計ロジックは `Shared/StatsCalculator.swift` に純粋関数で分離(ユニットテスト対象)
- UI 文言は日本語

## 開発状況(2026-08-15 時点)

- M6完了・MVP完成。実機運用中
- MVP後に記事・動画音声カテゴリを一度追加したが、運用してみて記録の手間に見合わないため廃止。エクスポート JSON は `schemaVersion: 4`
  - M3 のタイマーは `Features/Timer/ActiveTimer.swift` に「開始時刻との差分」方式で実装済み(PLANNING.md §5)。状態は UserDefaults(キー `activeTimerState`)に永続化し、アプリ再起動後もダッシュボードの計測中バナーから復元できる
  - M4 の可視化は `StatsCalculator` に `dailyMinutes` / `minutesByDay` / `dominantCategoryByDay` を追加。ダッシュボードに週間積み上げ棒グラフ(`Features/Dashboard/WeeklyChartView.swift`)、履歴タブにリスト/カレンダー切替(`Features/History/CalendarView.swift` の `MonthCalendarView`)を実装
  - M5 のエクスポートは `Export/ExportService.swift` に UI 非依存の純粋関数(`makeJSON` / `makeCSV` / `makeMarkdownFiles`)として実装。設定画面の `Features/Settings/ExportView.swift` から JSON(AI分析用)/ CSV(表計算用)/ Obsidian用 Markdown(zip)の3形式を生成し、`UIActivityViewController` のシェアシートで共有する。zip 化は外部ライブラリを使わず `NSFileCoordinator(.forUploading)` を利用。形式仕様は PLANNING.md §3.5 参照(JSON の `app` は `"hitotsumi"`、種目は8部位の `bodyPart`、`SetRecord` に `isSingleArm` あり、Session に進捗差分は含まれない)
  - M6 の仕上げ: 記録タブのリスト/カレンダー切替をツールバーの小さな Picker から画面内の全幅 segmented Picker に変更(`Features/History/HistoryView.swift`、`LibraryView.swift` と同じパターンに統一)。ダークモード・Dynamic Type(特にアクセシビリティ文字サイズ)・タップ領域を点検し、`WeeklyChartView` の X 軸日付ラベル重なり、部位ジャンプボタン/メニュー名の文字切れ、トレーニング記録のセット入力行のレイアウト崩れ、カレンダー日付セルとインターバルタイマープリセットの小さいタップ領域を修正済み(詳細は変更履歴参照)

## ブランチ運用

- 開発ブランチ: `claude/iphone-learning-tracker-plan-3ruzgu`
- コミットは機能単位で日本語 or 英語どちらでも可。ビルドが通った状態でコミットする
