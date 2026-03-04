# Daily Note Generator

iPhoneからタスクメモを送信して、Obsidianの日々のメモと統合したDaily Noteを自動生成し、通知してくれるシステム。

## 概要

```
iPhone (ショートカット)
    ↓ テキスト or ファイル送信
FastAPI サーバー
    ↓ Obsidian Vault 読み取り
Daily Note 生成 + 保存
    ↓
通知 (Google Chat / LINE / Slack / Pushover)
    ↓
Google Chat / iPhone に通知到着
```

## 機能

- **タスク送信**: iPhoneからテキスト入力 or ファイルアップロードでタスクを送信
- **Obsidian連携**: 既存のObsidian Daily Noteにタスクを追記（上書きしない）
- **Daily Note生成**: 既存ノートがなければテンプレートから新規作成
- **通知**: Google Chat / LINE / Slack / Pushover で通知
- **API認証**: Bearerトークンによるセキュアなアクセス

## セットアップ

### 1. リポジトリをクローン

```bash
git clone <repository-url>
cd ta1
```

### 2. 環境設定

```bash
cp .env.example .env
# .env を編集して設定を入力
```

主な設定項目:
| 変数 | 説明 |
|------|------|
| `DN_OBSIDIAN_VAULT_PATH` | Obsidian Vaultのパス |
| `DN_API_TOKEN` | API認証トークン |
| `DN_NOTIFICATION_METHOD` | 通知方法 (`google_chat`, `line`, `slack`, `pushover`, `none`) |
| `DN_GOOGLE_CHAT_WEBHOOK_URL` | Google Chat Webhook URL |

### 3. 起動

#### Python で直接起動

```bash
pip install -r requirements.txt
python run.py
```

#### Docker で起動

```bash
docker compose up -d
```

### 4. iPhoneショートカットの設定

[iOS ショートカット設定ガイド](docs/ios_shortcut_setup.md) を参照してください。

## API エンドポイント

### `POST /api/daily-note`
タスクリストからDaily Noteを作成。

```json
{
  "tasks": ["タスク1", "タスク2"],
  "memo": "メモ内容（任意）",
  "date": "2025-01-15"
}
```

### `POST /api/daily-note/upload`
テキストファイルをアップロードしてDaily Noteを作成。
- `file`: アップロードファイル（multipart/form-data）
- `target_date`: 日付（任意、デフォルトは今日）

### `GET /api/daily-note/{date}`
既存のDaily Noteを取得。

### `GET /api/recent-notes?days=7`
直近の Daily Note を取得。

### `GET /health`
ヘルスチェック。

全APIは `Authorization: Bearer <token>` ヘッダーが必要です（`/health` を除く）。

## テスト

```bash
pip install pytest
python -m pytest tests/ -v
```

## プロジェクト構成

```
ta1/
├── app/
│   ├── main.py              # FastAPIアプリケーション
│   ├── config.py             # 設定管理
│   ├── auth.py               # API認証
│   ├── routers/
│   │   └── daily_note.py     # APIルーター
│   └── services/
│       ├── obsidian.py       # Obsidian Vault連携
│       ├── note_generator.py # Daily Note生成
│       └── notifier.py       # 通知送信
├── templates/
│   └── daily_note.md.j2      # Daily Noteテンプレート
├── tests/
│   └── test_api.py           # APIテスト
├── docs/
│   └── ios_shortcut_setup.md # iOSショートカット設定ガイド
├── .env.example              # 環境変数テンプレート
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── run.py                    # 起動スクリプト
```
