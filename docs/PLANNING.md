# 学習・活動記録アプリ プランニングドキュメント

**アプリ名: ひとつみ**(内部のプロジェクト名・スキーム名は TrackStack のまま)
読書・筋トレ/トレーニング・資格勉強/勉学の記録を 1 つのアプリでまとめて取れる iPhone アプリ。

作成日: 2026-08-08 / 更新日: 2026-08-08 / ステータス: v2(方針確定)

**確定した方針:**
1. アプリ名は「ひとつみ」に決定(内部のプロジェクト名・スキーム名は TrackStack のまま)
2. 同期は軽量路線。MVP は iPhone ローカル完結とし、**エクスポート機能(Obsidian 向け Markdown / AI 分析用 JSON・CSV / 将来的に Notion 書き出し)** を柱に据える
3. 読書の進捗単位は **%**
4. 筋トレの **メニュー(テンプレート)作成機能と前回メニュー複製** を MVP に含める
5. 配布は **個人利用のみ**(App Store 公開は目指さない)

---

## 1. コンセプト

### 1.1 課題
- 読書記録・筋トレ記録・勉強記録は、それぞれ専用アプリ(ブクログ、筋トレMEMO、Studyplus など)が分立しており、複数アプリを行き来する手間で記録が続かない。
- 「自己投資の時間」を横断して振り返る手段がなく、努力の総量が見えない。

### 1.2 提供価値
- **1 アプリで 3 カテゴリを記録**: 読書 / トレーニング / 勉強 を共通の操作感で記録。
- **横断ダッシュボード**: 今日・今週・今月の合計時間、カテゴリ別バランス、継続日数(ストリーク)を一目で確認。
- **最速記録体験**: 「開始→ストップ」のタイマー記録と、あとから手入力の 2 方式。1 記録 10 秒以内を目標。
- **データは自分のもの**: 記録は Obsidian 用 Markdown や JSON/CSV でいつでも書き出せる。Claude / Codex などの AI に食わせて振り返り分析ができる形式を最初から設計する。

### 1.3 ターゲットユーザー
- 開発者自身の個人利用が前提(シングルユーザー、App Store 公開なし)。
- SNS・共有機能は対象外。汎用化は将来必要になったら検討。

---

## 2. 機能要件

### 2.1 MVP(v1.0)

#### 共通
- **セッション記録**: すべてのカテゴリ共通で「日時・所要時間・メモ」を記録。
  - タイマー記録(開始/一時停止/終了)
  - 手動記録(過去日付の入力可)
- **ダッシュボード(ホーム)**:
  - 今日の合計時間 / カテゴリ別内訳
  - 週間バーチャート(カテゴリ別積み上げ)
  - 継続日数(ストリーク)表示
- **履歴一覧**: 日付順のセッション一覧。カテゴリでフィルタ。編集・削除。
- **カレンダービュー**: 記録がある日にドット表示(カテゴリ色)。

#### 読書
- 書籍の登録(タイトル・著者・表紙画像は任意)
- ステータス管理: 読みたい / 読書中 / 読了
- 記録画面から本の **進捗率(%)** を更新(スライダー入力)。進捗は Book 側に保存され、セッションには残らない。100% で読了候補として提示
- 読了時に一言感想・5 段階評価

#### 筋トレ・トレーニング
- 種目マスタ(プリセット + 自由追加): ベンチプレス、スクワット、ランニング等
- 筋トレ: 種目ごとに「重量 × 回数 × セット数」を記録
- 有酸素: 「距離・時間」を記録
- セッション単位でまとめて複数種目を記録可能
- **メニュー(テンプレート)機能**: 種目の組み合わせを「メニュー」として作成・保存(例: 「胸の日」= ベンチプレス + ダンベルフライ + 腹筋)。メニューを選ぶと種目一式がプリセットされた状態で記録開始
- **前回複製**: 「前回と同じ」ボタンで直近セッションの種目・重量・回数を 1 タップ複製し、実績だけ修正

#### 資格勉強・勉学
- 科目/資格の登録(例: 簿記 2 級、TOEIC、大学の講義名)
- 目標設定: 試験日と目標学習時間(任意)
- セッションに科目を紐付けて時間を記録
- 科目別の累計時間・試験日までのカウントダウン表示

#### エクスポート(MVP の柱)
- **AI 分析用 JSON エクスポート**: 全記録をスキーマ付きの単一 JSON で書き出し。Claude / Codex にそのまま渡して「今月の学習バランスを分析して」といった振り返りができる形式(スキーマは §3.5)
- **CSV エクスポート**: セッション一覧のフラットな CSV(表計算・スクリプト分析用)
- **Obsidian 向け Markdown エクスポート**: 日次ノート形式(`YYYY-MM-DD.md`)+ frontmatter 付き。Obsidian の Vault にそのまま取り込める構成
- 出力はシェアシート / Files アプリ経由(AirDrop・iCloud Drive・各種アプリへ渡せる)

### 2.2 v1.1 以降(ロードマップ候補)
- **Notion 書き出し**(Notion API 連携。トークン設定が必要なため MVP から外す)
- **Obsidian 自動同期**(iCloud Drive 上の Vault フォルダへ自動書き出し)
- リマインダー通知(記録忘れ防止、目標時間の達成通知)
- ウィジェット(今日の記録時間・クイック記録)
- HealthKit 連携(ワークアウトの自動取り込み)
- 書籍バーコード/ISBN 検索(Google Books API 等)
- 月次レポート・目標達成率のグラフ強化
- Apple Watch アプリ(タイマー操作)
- iCloud 同期(複数端末で使いたくなったら。軽量路線のため当面見送り)

### 2.3 非機能要件
- オフライン完結(ローカル保存のみ。ネットワーク必須機能なし)
- バックアップはエクスポート機能で兼ねる(JSON を書き出しておけば復元・移行の素材になる)
- 起動から記録開始まで 2 タップ以内
- ダークモード対応、Dynamic Type 対応
- 対応 OS: iOS 17+
- 配布: 個人利用のみ(Xcode から実機インストール、または TestFlight 内部配布。App Store 審査対応は不要)

---

## 3. 技術設計

### 3.1 技術スタック(推奨)
| 項目 | 選定 | 理由 |
|---|---|---|
| 言語 | Swift 5.10+ | 標準 |
| UI | SwiftUI | 宣言的 UI、ウィジェット/Watch 展開が容易 |
| データ永続化 | SwiftData | iOS 17+ 前提ならモデル定義が簡潔。将来 CloudKit 同期に移行しやすい |
| グラフ | Swift Charts | 標準フレームワークで週間チャート等を実装 |
| アーキテクチャ | MVVM + Repository | View / ロジック / 永続化を分離しテスト可能に |
| テスト | XCTest / Swift Testing | ViewModel・集計ロジック中心にユニットテスト |
| CI(任意) | Xcode Cloud or GitHub Actions | ビルド・テスト自動化 |

### 3.2 データモデル(SwiftData)

```
Session(共通セッション)
├ id: UUID
├ category: enum { reading, training, study }
├ startedAt: Date
├ duration: TimeInterval
├ note: String?
├ book: Book?             // reading のとき
├ subject: Subject?       // study のとき
└ exercises: [ExerciseLog] // training のとき

Book
├ id, title, author?, coverImage?
├ status: enum { wantToRead, reading, finished }
├ progressPercent: Int    // 最新進捗(0–100)
├ rating: Int?, review: String?  // review は本全体のメモ
├ sessions: [Session]
└ notes: [ReadingNote]    // 読んだ記録(1回ごとの所感。review とは別)

ReadingNote(本ごとの「読んだ記録」)
├ id, text, createdAt
└ book: Book?

Subject(科目・資格)
├ id, name, examDate?, targetHours?
└ sessions: [Session]

Exercise(種目マスタ)
├ id, name, kind: enum { strength, cardio }

ExerciseLog(セッション内の種目実績)
├ id, exercise: Exercise
├ sets: [SetRecord]       // strength: weight × reps
└ distance?, duration?    // cardio

WorkoutMenu(トレーニングメニュー/テンプレート)
├ id, name               // 例: 「胸の日」
└ items: [MenuItem]      // 種目 + デフォルトのセット構成(重量・回数・セット数)
```

**設計方針**:
- 「Session を共通の主軸」に置き、カテゴリ固有情報を関連エンティティに逃がす。ダッシュボードの横断集計(時間合計・ストリーク)がカテゴリ非依存の単純なクエリで済む。
- 読書の進捗は % で持つ(ページ数は持たない)。進捗%は Book だけが持ち、記録画面から本の進捗を更新できるが、記録自体には進捗を残さない。
- WorkoutMenu はあくまで「入力の雛形」。記録実体は常に Session + ExerciseLog に落ちるため、集計・エクスポートはメニューの有無に依存しない。

### 3.3 画面構成

```
TabView
├ ホーム(ダッシュボード)
│   ├ 今日のサマリー / 週間チャート / ストリーク
│   └ クイック記録ボタン(カテゴリ選択 → タイマー開始)
├ 記録(履歴)
│   ├ セッション一覧(フィルタ・編集・削除)
│   └ カレンダービュー切替
├ ライブラリ
│   ├ 読書タブ: 本棚(ステータス別・進捗%バー)
│   ├ トレーニングタブ: メニュー一覧 / 種目一覧・種目別記録推移
│   └ 勉強タブ: 科目一覧・累計時間・試験カウントダウン
└ 設定
    ├ エクスポート(JSON / CSV / Obsidian Markdown)
    └ カテゴリ色、週の開始曜日、データ管理 など

モーダル: タイマー画面 / 手動記録フォーム / 書籍・科目・種目・メニューの追加編集
```

### 3.4 プロジェクト構成(案)

```
TrackStack/
├ App/               // エントリポイント、Tab 構成
├ Models/            // SwiftData モデル
├ Features/
│   ├ Dashboard/     // ホーム画面 + ViewModel
│   ├ Timer/         // 計測フロー
│   ├ History/       // 履歴・カレンダー
│   ├ Reading/
│   ├ Training/
│   ├ Study/
│   └ Settings/
├ Shared/            // 共通 UI コンポーネント、拡張、集計ロジック
├ Export/            // JSON / CSV / Markdown の書き出しロジック
└ Tests/
```

### 3.5 エクスポート形式仕様(M5 実装版。`Export/ExportService.swift` 準拠)

#### AI 分析用 JSON(全量・単一ファイル)
Claude / Codex に添付して「分析して」と頼める、自己記述的なフォーマットにする。

```json
{
  "app": "hitotsumi",
  "schemaVersion": 1,
  "exportedAt": "2026-08-11T00:30:00+09:00",
  "sessions": [
    {
      "id": "…", "category": "study", "startedAt": "…",
      "durationMinutes": 45, "note": "過去問 3 回分",
      "subject": { "name": "簿記2級" }
    },
    {
      "id": "…", "category": "reading", "startedAt": "…",
      "durationMinutes": 30,
      "book": { "title": "…", "author": "…", "genre": "…" }
    },
    {
      "id": "…", "category": "training", "startedAt": "…",
      "durationMinutes": 60, "menu": "胸の日",
      "exercises": [
        { "name": "ベンチプレス", "bodyPart": "chest",
          "sets": [ { "weightKg": 60, "reps": 10, "isSingleArm": false },
                    { "weightKg": 60, "reps": 8, "isSingleArm": false } ] },
        { "name": "ランニング", "bodyPart": "cardio",
          "distanceKm": 3.0, "durationMinutes": 20 }
      ]
    }
  ],
  "books": [ { "title": "…", "author": "…", "genre": "…", "status": "reading",
               "progressPercent": 62, "rating": 4, "review": "…",
               "startedOn": "2026-08-01", "finishedOn": null,
               "notes": [ { "text": "…", "createdAt": "2026-08-05T21:00:00+09:00" } ] } ],
  "subjects": [ { "name": "…", "examDate": "2026-11-15", "targetHours": 100, "memo": "…" } ],
  "exercises": [ { "name": "…", "bodyPart": "chest", "memo": "…" } ]
}
```

- キーは英語・camelCase、値の自由記述は日本語のまま。日時(`startedAt` / `exportedAt`)は ISO 8601(タイムゾーン付き)。日付のみの項目(`startedOn` / `finishedOn` / `examDate`)は `yyyy-MM-dd`。
- `schemaVersion` を持たせ、将来の形式変更に備える。
- 種目の分類は「筋トレ/有酸素」の2種ではなく、8部位(`BodyPart`: chest/shoulders/biceps/triceps/back/legs/abs/cardio)の rawValue を `bodyPart` として出力する(`kind` は使わない)。
- `SetRecord` には片手セットかどうかを示す `isSingleArm` を含む。`weightKg` は加重アシスト種目のためマイナス値もあり得る。
- `Session` は `progressPercent`(読書の進捗)を持たない。進捗は `Book` 側のみが保持するため、JSON にセッションごとの進捗差分は出力しない。
- `Book.coverImageData`(表紙写真)はサイズが大きいため JSON には含めない。
- `Book.notes`(読んだ記録)は `createdAt` 昇順で出力する。記録がない本では `notes` キー自体を出力しない。

#### CSV(セッションのフラット表)
`date,category,duration_minutes,title,detail,note` の 1 行 1 セッション。表計算やスクリプトでの軽い集計用。`date` は `yyyy-MM-dd HH:mm`、`category` は日本語ラベル(読書/トレーニング/勉強)、`detail` はトレーニングの種目名を「・」区切りにしたもの(読書・勉強は空)。値に `,` `"` 改行が含まれる場合は RFC4180 に従いダブルクォートで囲みエスケープする。

#### Obsidian 向け Markdown(日次ノート)
Vault にコピーするだけで使える、frontmatter 付き日次ファイル群(`2026-08-08.md` のような構成で zip 出力)。記録のない日のファイルは作らない。

```markdown
---
date: 2026-08-08
total_minutes: 135
reading_minutes: 30
training_minutes: 60
study_minutes: 45
---

## 📚 読書 30分
- 『本のタイトル』 — メモ

## 💪 トレーニング 60分(胸の日)
- ベンチプレス 60kg×10, 60kg×8
- ランニング 3.0km 20分

## ✏️ 勉強 45分
- 簿記2級 — 過去問3回分
```

- frontmatter に数値を持たせることで、Obsidian の Dataview 等でも集計可能。
- メモがない場合は「 — メモ」の部分を出さない。カテゴリの見出しはその日に記録があるものだけ出す。
- セットは「60kg×10」形式。片手セットは「60kg×10(片手)」、マイナス重量は「-20kg×10」とそのまま出す。有酸素は「3.0km 20分」形式(距離・時間が無ければある方だけ)。
- 読書進捗の差分表示(旧仕様の「55% → 62%」)は行わない。`Session` が進捗を持たずデータがないため。
- Notion 書き出し(v1.1)はこの Markdown をベースに、Notion API でのページ作成に対応する。

---

## 4. 開発ロードマップ

| フェーズ | 内容 | 目安 |
|---|---|---|
| M1: 基盤 | プロジェクト作成、SwiftData モデル、Tab 骨格、手動記録(全カテゴリ共通の時間+メモ) | 1 週 |
| M2: カテゴリ固有 | 書籍(進捗%)/科目/種目の CRUD、カテゴリ別入力フォーム、トレーニングメニュー作成・前回複製 | 2 週 |
| M3: タイマー | タイマー記録フロー(バックグラウンド継続対応) | 1 週 |
| M4: 可視化 | ダッシュボード(Swift Charts)、カレンダー、ストリーク | 1–2 週 |
| M5: エクスポート | JSON / CSV / Obsidian Markdown 書き出し + シェアシート | 1 週 |
| M6: 仕上げ | ダークモード・Dynamic Type、空状態 UI、ユニットテスト、実機運用開始 | 1 週 |
| v1.1〜 | Notion 書き出し、Obsidian 自動同期、通知、ウィジェット、HealthKit、ISBN 検索 | 順次 |

**MVP 完成目安: 6〜8 週間**(週 10〜15 時間の開発想定)。自分専用のため、M4 完了時点から実機で使い始めながら M5 以降を進める(ドッグフーディング)。

---

## 5. リスクと対応

| リスク | 対応 |
|---|---|
| 3 カテゴリ分の UI で MVP が肥大化 | M1 で「共通セッション記録」だけ先に完成させ、カテゴリ固有機能は後乗せする設計にする |
| タイマーのバックグラウンド計測 | 経過時間は「開始時刻との差分」で算出し、バックグラウンド実行に依存しない実装にする |
| SwiftData の成熟度 | モデルを Repository 層で抽象化し、問題があれば Core Data / GRDB に差し替え可能にする |
| 記録の習慣化(継続率) | クイック記録の導線を最短化。v1.1 で通知・ウィジェットを優先投入 |
| 端末故障・機種変更でのデータ消失(ローカルのみのため) | JSON エクスポートをバックアップとして定期実行する運用。将来は JSON からのインポート(復元)機能を追加 |
| 個人開発の無料 Apple Developer 枠は実機アプリが 7 日で失効 | 有料の Developer Program(年 ¥12,800)加入か TestFlight 内部配布で回避。開発着手前に決める |

---

## 6. 決定済み事項

1. **アプリ名**: 「ひとつみ」に決定(内部のプロジェクト名・スキーム名は TrackStack のまま)。
2. **同期**: 軽量路線。MVP は iPhone ローカルのみ。エクスポート(Obsidian Markdown / AI 分析用 JSON / CSV)を MVP の柱とし、Notion 書き出しは v1.1。iCloud 同期は当面見送り。
3. **読書の進捗単位**: %(スライダー入力)。
4. **筋トレ**: メニュー作成機能 + 前回複製を MVP に含める。
5. **配布**: 個人利用のみ。App Store 公開は目指さない。

## 7. 未決事項

1. **Apple Developer Program に加入するか**(無料枠は実機インストールが 7 日で失効するため、常用するなら実質必須)
2. **Obsidian Vault の場所**(iCloud Drive 上なら v1.1 の自動同期が可能になる)
3. **JSON インポート(復元)機能を MVP に入れるか**(バックアップの実効性に関わる)
