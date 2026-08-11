#!/bin/zsh
# TrackStack を実機へ毎日再ビルド&再インストールするスクリプト
# 目的: 無料の Apple Personal Team 署名は7日で失効するため、launchd から毎日実行し
#       接続中のiPhoneへ再インストールすることで失効を防ぐ。
#
# 手動実行:
#   /Users/taguchi/ai-work/ai-workspace/ta1/scripts/reinstall-device.sh
# launchd からの実行を想定し、標準出力/標準エラーはplist側でログファイルへリダイレクトされる。

set -u

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

DEVICE_ID="C2199995-AD9E-50EF-9C57-417A3C638B85"
REPO_DIR="/Users/taguchi/ai-work/ai-workspace/ta1"
SCHEME="TrackStack"
# ビルド出力先を固定する(Xcode既定の DerivedData はハッシュ付きで場所が変わるため)
DERIVED_DATA="$REPO_DIR/.build-device"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "===== TrackStack reinstall-device.sh 開始 ====="

cd "$REPO_DIR" || {
  log "エラー: REPO_DIR に移動できません: $REPO_DIR"
  exit 1
}

# 1. デバイス接続確認
# devicectl の State は接続方法で表記が変わる:
#   有線接続   -> "connected"
#   無線ペア済 -> "available (paired)"
# どちらもインストール可能なので両方を受け付ける("unavailable" だけを弾く)。
log "デバイス接続状況を確認します (DEVICE_ID=$DEVICE_ID)"
DEVICE_LINE="$(xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_ID")"

if [[ -z "$DEVICE_LINE" ]] \
  || [[ "$DEVICE_LINE" == *unavailable* ]] \
  || { [[ "$DEVICE_LINE" != *available* ]] && [[ "$DEVICE_LINE" != *connected* ]]; }; then
  log "デバイス未接続のためスキップします"
  log "===== TrackStack reinstall-device.sh 終了(スキップ) ====="
  exit 0
fi

log "デバイス接続を確認しました: $DEVICE_LINE"

# 2. ビルド
log "ビルドを開始します (scheme=$SCHEME)"
BUILD_LOG="$(mktemp -t trackstack-build)"

xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?

# 要約行のみログへ出力(BUILD SUCCEEDED/FAILED, error行)
grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" "$BUILD_LOG" | while IFS= read -r line; do
  log "$line"
done

if [[ $BUILD_STATUS -ne 0 ]]; then
  log "エラー: ビルドに失敗しました (exit=$BUILD_STATUS)。詳細ログ: $BUILD_LOG"
  exit 1
fi

log "ビルドに成功しました"
rm -f "$BUILD_LOG"

# 3. APP_PATH を決定
# -derivedDataPath で出力先を固定しているため、成果物の場所は一意に決まる。
# (-showBuildSettings は実機 destination 指定だと何も返さないことがあるため使わない)
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/${SCHEME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  log "エラー: ビルド成果物が見つかりません: $APP_PATH"
  exit 1
fi

log "ビルド成果物: $APP_PATH"

# 4. インストール
log "実機へインストールします"
INSTALL_OUTPUT="$(xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>&1)"
INSTALL_STATUS=$?

log "$INSTALL_OUTPUT"

if [[ $INSTALL_STATUS -ne 0 ]]; then
  log "エラー: インストールに失敗しました (exit=$INSTALL_STATUS)"
  exit 1
fi

log "インストールに成功しました"
log "===== TrackStack reinstall-device.sh 終了(成功) ====="
exit 0
