# ta1 — 名刺管理アプリ（GAS + Sheets + Drive + Gemini）

スマホで**動画を1本撮ると**、映っている名刺を Gemini が一括で認識して、Google スプレッドシートに名刺情報・Google Drive に画像を保存する GAS（Google Apps Script）アプリです。写真1枚モードも用意しています。

## 特徴

- 動画1本で名刺を**まとめて取り込み**（展示会の後処理に便利）
- Gemini 2.5 の **動画ネイティブ入力** + Structured Output で項目を自動抽出
- 抽出結果は保存前に**全件レビュー/修正**可能
- データは自分の Google アカウント配下（スプレッドシート + Drive）で完結
- 将来、同一ドメインのメンバー間での共有に切替可能（行ごとに `owner` 列）

## セットアップ

### 1. Google 側の準備

1. 空の **Spreadsheet** を作成（`SHEET_ID` を控える）
2. 空の **Drive フォルダ** を 2つ作成
   - 画像用（`DRIVE_IMAGE_FOLDER_ID`）
   - 動画アーカイブ用（`DRIVE_VIDEO_FOLDER_ID`）
3. [Google AI Studio](https://aistudio.google.com/) で **Gemini API キー** を発行（`GEMINI_API_KEY`）

### 2. ローカル作業（clasp）

```bash
npm install
npx clasp login
# 初回のみ：Apps Script プロジェクトを作成
npx clasp create --type webapp --title "名刺管理" --rootDir src
cp .clasp.json.example .clasp.json   # 必要に応じて scriptId を差し替え
npx clasp push
```

### 3. Apps Script 側の設定

1. `npx clasp open` で Apps Script エディタを開く
2. `プロジェクト設定` → `スクリプト プロパティ` で以下を登録
   - `SHEET_ID`
   - `DRIVE_IMAGE_FOLDER_ID`
   - `DRIVE_VIDEO_FOLDER_ID`
   - `GEMINI_API_KEY`
   - `GEMINI_MODEL`（任意、既定 `gemini-2.5-flash`）
3. エディタで関数 `setup` を1回実行 → 権限同意 → `cards` / `_meta` シートが生成される
4. `デプロイ` → `新しいデプロイ` → 種類「ウェブアプリ」
   - `実行するユーザー`: 自分
   - `アクセスできるユーザー`: **自分のみ**（最初はこれ）
5. 表示された Web App URL をスマホで開いてホーム画面に追加

### 将来：同一ドメイン内共有に切替

`appsscript.json` の `webapp.access` を `"DOMAIN"` に変更 → `npx clasp push && npx clasp deploy`。
行ごとに `owner` 列が記録されるため、閲覧は全員、更新・削除は登録者のみに制限されます。

## 使い方

### 動画で一括追加
1. 「動画で追加」タブ
2. 「録画開始」→ 名刺を1枚ずつ 1〜2秒ずつ正対させてカメラに見せる
3. 「停止」→「アップロード → 抽出」
4. 検出結果のレビュー画面で内容を確認・修正・不要分を除外
5. 「全件保存」でスプシに一括追加

### 写真1枚で追加
1. 「写真で追加」タブ
2. カメラ起動 or 画像選択 → 「この画像を抽出」
3. 確認して保存

## 項目

`cards` シートの列順（変更しないでください）：

```
id, createdAt, updatedAt, owner,
imageFileId, imageUrl,
sourceVideoFileId, sourceTimestampSec,
氏名, ふりがな, 会社名, 部署, 役職,
Email, 電話, 携帯, FAX,
郵便番号, 住所, URL,
Twitter, LinkedIn, Facebook, Instagram,
出会った日, 出会った場所, メモ, タグ
```

## 技術メモ

- 動画は **Gemini File API**（resumable upload）経由でアップ。`UrlFetchApp` のリクエスト上限対策として、録画は 720p / 2Mbps / 60秒目安。50MB 超は受け付けません。
- 代表フレームの静止画は **クライアント側で `<video>` + `<canvas>` シーク**して JPEG 化 → Drive 保存。サーバーに ffmpeg 不要。
- チャンクアップロードは `CacheService` で一時保管 → 最終コミット時に結合。
- Gemini 出力は `responseSchema` で JSON を強制。失敗時はエラー表示して手動入力に切替可。

## スコープ外（MVP）

- 名刺裏面対応
- 重複検出（氏名＋会社名の完全一致程度のみ）
- タグのマスタ管理
- 外部 CRM / カレンダー連携

## トラブルシュート

- **カメラが起動しない**：Web App URL を HTTPS（script.google.com）で開いているか、ブラウザ側でカメラ権限を許可しているか確認。
- **動画サイズが大きすぎる**：60秒以内・720p 目安で撮り直してください。
- **Gemini がタイムアウト**：動画を短くする、または `GEMINI_MODEL` を軽量モデルに変更。
- **共有ユーザーが編集できない**：`owner` 列が異なる行は登録者本人のみ編集可能です（仕様）。

## 開発ワークフロー

```bash
npx clasp push     # ローカル → GAS
npx clasp logs -w  # ログを監視
npx clasp deploy   # 新バージョンのデプロイ
```

動作確認は Apps Script エディタ上で `setup`・`test_bootstrap` 等を実行してください。
